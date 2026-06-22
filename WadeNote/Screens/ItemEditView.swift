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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(field.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if field.kind == .secret {
                                SecureField(field.label, text: $field.value)
                            } else {
                                TextField(field.label, text: $field.value)
                            }
                        }
                    }
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
            .navigationTitle(isCreate ? "추가" : "편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") { commit() } }
            }
            .onAppear(perform: load)
        }
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
        if let item = working {
            item.title = title
            item.updatedAt = Date()
            try? store.save()
        } else {
            let item = store.create(type: type, title: title)
            let sorted = item.orderedFields
            for (i, field) in draft.enumerated() where i < sorted.count {
                sorted[i].value = field.value
            }
            try? store.save()
        }
        dismiss()
    }

    private func attach(_ pickerItem: PhotosPickerItem) async {
        guard let data = try? await pickerItem.loadTransferable(type: Data.self),
              let id = try? attachments.store.save(data) else { return }
        working?.attachmentIDs.append(id)
        try? store.save()
    }
}
