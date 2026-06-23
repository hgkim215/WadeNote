import SwiftUI
import PhotosUI

enum EditMode {
    case create
    case edit(Item)
}

struct ItemEditView: View {
    let mode: EditMode
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AttachmentHolder.self) private var attachments

    @State private var type: ItemType = .login
    @State private var title = ""
    @State private var draft: [Field] = []
    @State private var working: Item?
    @State private var pickerItem: PhotosPickerItem?

    private var store: ItemStore { ItemStore(context: context) }
    private var isCreate: Bool { if case .create = mode { true } else { false } }

    var body: some View {
        NavigationStack {
            Form {
                if isCreate {
                    Picker("유형", selection: $type) {
                        ForEach(ItemType.allCases) { Text($0.displayName).tag($0) }
                    }
                    .onChange(of: type) { _, newType in
                        if working == nil { draft = Template.makeFields(for: newType) }
                    }
                }
                Section("제목") {
                    TextField("제목", text: $title)
                }
                Section("필드") {
                    ForEach($draft) { $field in
                        fieldRow($field)
                    }
                    Button { addCustomField() } label: {
                        Label("필드 추가", systemImage: "plus.circle.fill")
                            .font(.system(size: 15))
                    }
                    .tint(Color.actionBlue)
                }
                if working != nil {
                    Section("사진") {
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Label("사진 추가", systemImage: "photo")
                        }
                        .onChange(of: pickerItem) { _, newItem in
                            guard let newItem else { return }
                            Task { await attach(newItem) }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .tint(Color.actionBlue)
            .navigationTitle(isCreate ? "추가" : "편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") { commit() } }
            }
            .onAppear(perform: load)
        }
    }

    @ViewBuilder
    private func fieldRow(_ field: Binding<Field>) -> some View {
        if field.wrappedValue.kind == .multiline {
            multilineField(field)
        } else if field.wrappedValue.isCustom {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    TextField("필드 이름", text: field.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("값", text: field.value)
                }
                Button { removeField(field.wrappedValue) } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(Color(hex: "FF3B30"))
                }
                .buttonStyle(.plain)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(field.wrappedValue.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if field.wrappedValue.kind == .secret {
                    SecureField(field.wrappedValue.label, text: field.value)
                } else {
                    TextField(field.wrappedValue.label, text: field.value)
                }
            }
        }
    }

    private func addCustomField() {
        let f = Field(label: "", value: "", kind: .text, order: draft.count)
        f.isCustom = true
        withAnimation { draft.append(f) }
    }

    private func removeField(_ field: Field) {
        withAnimation { draft.removeAll { $0 === field } }
    }

    @ViewBuilder
    private func multilineField(_ field: Binding<Field>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(field.wrappedValue.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(field.wrappedValue.label, text: field.value, axis: .vertical)
                .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
        }
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
    }

    private func load() {
        if case let .edit(item) = mode {
            type = item.type
            title = item.title
            draft = item.orderedFields
            working = item
        } else if draft.isEmpty {
            draft = Template.makeFields(for: type)
        }
    }

    private func commit() {
        let item: Item
        if let existing = working {
            item = existing
        } else {
            item = Item(title: title, type: type)
            context.insert(item)
        }
        item.title = title
        item.updatedAt = Date()

        let existingFields = item.fields ?? []
        // 드래프트에서 빠진(삭제된) 필드 제거
        for f in existingFields where !draft.contains(where: { $0 === f }) {
            context.delete(f)
        }
        // 새 필드 삽입 + 순서 갱신
        for (index, f) in draft.enumerated() {
            f.order = index
            if f.item == nil {
                f.item = item
                context.insert(f)
            }
        }
        try? store.save()
        dismiss()
    }

    private func attach(_ pickerItem: PhotosPickerItem) async {
        guard let data = try? await pickerItem.loadTransferable(type: Data.self),
              let id = try? attachments.store.save(data) else { return }
        working?.attachmentIDs.append(id)
        try? store.save()
    }
}
