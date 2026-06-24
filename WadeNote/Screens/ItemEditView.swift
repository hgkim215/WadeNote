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
    @State private var attachmentIDs: [String] = []
    @State private var originalAttachmentIDs: [String] = []
    @State private var isAttaching = false

    private var store: ItemStore { ItemStore(context: context) }
    private var isCreate: Bool { if case .create = mode { true } else { false } }

    private var canSave: Bool {
        Template.requiredFieldsSatisfied(draft)
    }

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
                Section {
                    ForEach($draft) { $field in
                        fieldRow($field)
                    }
                    Button { addCustomField() } label: {
                        Label("필드 추가", systemImage: "plus.circle.fill")
                            .font(.system(size: 15))
                    }
                    .tint(Color.actionBlue)
                } header: {
                    Text("필드")
                } footer: {
                    if !canSave {
                        Text("필수 필드를 모두 입력해야 저장할 수 있어요")
                            .foregroundStyle(Color(hex: "FF3B30"))
                    }
                }
                Section("사진") {
                    if !attachmentIDs.isEmpty || isAttaching {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(attachmentIDs, id: \.self) { id in
                                    attachmentThumb(id)
                                }
                                if isAttaching { uploadingThumb }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        if isAttaching {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("사진 추가 중…").foregroundStyle(Color.secondaryText)
                            }
                            .font(.system(size: 15))
                        } else {
                            Label("사진 추가", systemImage: "photo")
                        }
                    }
                    .disabled(isAttaching)
                    .onChange(of: pickerItem) { _, newItem in
                        guard let newItem else { return }
                        Task { await attach(newItem) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .tint(Color.actionBlue)
            .dismissKeyboardOnTap()
            .navigationTitle(isCreate ? "추가" : "편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { cancelEdit() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") { commit() }.disabled(!canSave) }
            }
            .onAppear(perform: load)
        }
    }

    /// 비커스텀 선택 필드는 라벨에 " (선택)" 을 덧붙여 보여준다.
    private func displayLabel(for field: Field) -> String {
        (!field.isCustom && !field.isRequired) ? "\(field.label) (선택)" : field.label
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
        } else if field.wrappedValue.kind == .date {
            DateFieldEditor(label: displayLabel(for: field.wrappedValue), value: field.value)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayLabel(for: field.wrappedValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                inputField(field)
            }
        }
    }

    @ViewBuilder
    private func inputField(_ field: Binding<Field>) -> some View {
        let kind = field.wrappedValue.kind
        let style = inputStyle(for: kind)
        if field.wrappedValue.isMasked {
            SecretFieldEditor(label: field.wrappedValue.label, value: field.value, keyboard: style.keyboard)
        } else {
            TextField(field.wrappedValue.label, text: field.value)
                .keyboardType(style.keyboard)
                .textInputAutocapitalization(style.autocap)
                .autocorrectionDisabled(style.disableAutocorrect)
        }
    }

    private func inputStyle(for kind: FieldKind) -> (keyboard: UIKeyboardType, autocap: TextInputAutocapitalization, disableAutocorrect: Bool) {
        switch kind {
        case .email: (.emailAddress, .never, true)
        case .url: (.URL, .never, true)
        case .number, .secretNumber: (.numberPad, .never, true)
        case .secret: (.default, .never, true)
        default: (.default, .sentences, false)
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
            Text(displayLabel(for: field.wrappedValue))
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
            attachmentIDs = item.attachmentIDs
            originalAttachmentIDs = item.attachmentIDs
        } else if draft.isEmpty {
            draft = Template.makeFields(for: type)
        }
    }

    @ViewBuilder
    private func attachmentThumb(_ id: String) -> some View {
        if let data = try? attachments.store.load(id: id), let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topTrailing) {
                    Button { removeAttachment(id) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                }
        }
    }

    private func removeAttachment(_ id: String) {
        withAnimation { attachmentIDs.removeAll { $0 == id } }
    }

    /// 첨부 처리 중 보여줄 자리표시 썸네일(스피너).
    private var uploadingThumb: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.secondaryText.opacity(0.12))
            .frame(width: 76, height: 76)
            .overlay { ProgressView() }
            .transition(.opacity)
    }

    /// 취소 시 이번 편집에서 새로 추가한 사진 파일만 정리한다(기존 사진은 보존).
    private func cancelEdit() {
        for id in attachmentIDs where !originalAttachmentIDs.contains(id) {
            try? attachments.store.delete(id: id)
        }
        dismiss()
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
        // 사진 반영 + 이번 편집에서 삭제된 사진 파일 정리
        item.attachmentIDs = attachmentIDs
        for id in originalAttachmentIDs where !attachmentIDs.contains(id) {
            try? attachments.store.delete(id: id)
        }
        try? store.save()
        dismiss()
    }

    private func attach(_ pickerItem: PhotosPickerItem) async {
        withAnimation { isAttaching = true }
        defer { withAnimation { isAttaching = false } }
        guard let data = try? await pickerItem.loadTransferable(type: Data.self),
              let id = try? attachments.store.save(data) else { return }
        withAnimation { attachmentIDs.append(id) }
    }
}

/// 날짜 필드 — 값은 "yyyy-MM-dd" 문자열로 저장하고 캘린더 선택기를 보여준다.
private struct DateFieldEditor: View {
    let label: String
    @Binding var value: String
    @State private var date = Date()
    @State private var isSet = false

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundStyle(Color.primaryText)
            Spacer()
            if isSet {
                Button {
                    isSet = false
                    value = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.tertiaryText)
                }
                .buttonStyle(.plain)
            }
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .opacity(isSet ? 1 : 0.45)
                .onChange(of: date) { _, newDate in
                    isSet = true
                    value = formatter.string(from: newDate)
                }
        }
        .onAppear {
            if let parsed = formatter.date(from: value) {
                date = parsed
                isSet = true
            }
        }
    }
}

/// 비밀값 입력 필드 — 기본은 가려서(SecureField) 입력하고, 오른쪽 눈 버튼으로 보기/숨기기 전환.
private struct SecretFieldEditor: View {
    let label: String
    @Binding var value: String
    let keyboard: UIKeyboardType
    @State private var revealed = false

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if revealed {
                    TextField(label, text: $value)
                } else {
                    SecureField(label, text: $value)
                }
            }
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)

            Button {
                Haptics.tap()
                revealed.toggle()
            } label: {
                Image(systemName: revealed ? "eye.fill" : "eye")
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(revealed ? Color.actionBlue : Color.secondaryText)
            }
            .buttonStyle(.plain)
        }
    }
}
