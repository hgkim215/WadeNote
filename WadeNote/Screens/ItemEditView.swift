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
    @State private var captureEngine = SmartCaptureEngine.makeIfAvailable()
    @State private var isAnalyzing = false
    @State private var analyzingImage: UIImage?
    @State private var needsReview: Set<String> = []
    @State private var photoCaptureItem: PhotosPickerItem?
    @State private var captureToast: String?
    @State private var showingCamera = false

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
                if isCreate, let engine = captureEngine {
                    Section {
                        Group {
                            if let img = analyzingImage {
                                ScanningView(image: img, accent: type.accent)
                            } else {
                                GlassCard(cornerRadius: 18) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("캡쳐로 한 번에 채우세요")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(Color.primaryText)
                                            .padding(.bottom, 8)
                                        Button {
                                            if let image = UIPasteboard.general.image,
                                               let data = image.jpegData(compressionQuality: 0.9) {
                                                runSmartCapture(data, engine: engine)
                                            } else {
                                                captureToast = "클립보드에 이미지가 없어요"
                                            }
                                        } label: {
                                            CaptureSourceRow(title: "붙여넣기로 채우기", subtitle: "클립보드 이미지", systemImage: "doc.on.clipboard", accent: type.accent)
                                        }
                                        Divider()
                                        PhotosPicker(selection: $photoCaptureItem, matching: .images) {
                                            CaptureSourceRow(title: "사진첩에서 채우기", subtitle: "앨범에서 선택", systemImage: "photo.on.rectangle", accent: type.accent)
                                        }
                                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                            Divider()
                                            Button { showingCamera = true } label: {
                                                CaptureSourceRow(title: "카메라로 촬영", subtitle: "바로 찍어서", systemImage: "camera", accent: type.accent)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("스마트 캡처")
                    } footer: {
                        Text("캡처를 넣으면 '\(type.displayName)' 칸을 자동으로 채워요. 값은 기기에서만 처리됩니다.")
                    }
                    .onChange(of: photoCaptureItem) { _, item in
                        guard let item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                runSmartCapture(data, engine: engine)
                            }
                            photoCaptureItem = nil
                        }
                    }
                    .sheet(isPresented: $showingCamera) {
                        CameraPicker { data in
                            if let engine = captureEngine { runSmartCapture(data, engine: engine) }
                        }
                        .ignoresSafeArea()
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
                    // 로컬 Bool 로 캡처: PhotosPicker label 클로저는 Sendable 로 취급되어
                    // 메인액터 격리된 @State 를 직접 참조하면 Swift 6 모드에서 컴파일 에러가 난다.
                    let attaching = isAttaching
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        if attaching {
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
            .brandGlow(type.accent)
            .tint(Color.actionBlue)
            .dismissKeyboardOnTap()
            .navigationTitle(isCreate ? "추가" : "편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { cancelEdit() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { commit() }
                        .buttonStyle(.glassProminent)
                        .tint(Color.actionBlue)
                        .disabled(!canSave)
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = captureToast {
                    Text(toast)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.black.opacity(0.8), in: Capsule())
                        .padding(.bottom, 24)
                        .transition(.opacity)
                        .task(id: toast) {
                            try? await Task.sleep(for: .seconds(2))
                            captureToast = nil
                        }
                }
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
                HStack(spacing: 6) {
                    Text(displayLabel(for: field.wrappedValue))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if needsReview.contains(field.wrappedValue.label) {
                        Text("확인 필요")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(hex: "0C8E84"))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(hex: "0FA99D").opacity(0.13), in: Capsule())
                    }
                }
                inputField(field)
            }
            .onChange(of: field.wrappedValue.value) { _, _ in
                needsReview.remove(field.wrappedValue.label)
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

    /// 캡처 데이터로 추출을 돌려 draft 를 채우고, 채워진 칸을 "확인 필요"로 표시한다.
    private func runSmartCapture(_ imageData: Data, engine: SmartCaptureEngine) {
        Task {
            isAnalyzing = true
            analyzingImage = UIImage(data: imageData)
            defer { isAnalyzing = false; analyzingImage = nil }
            let result = (try? await engine.fill(imageData: imageData, type: type))
                ?? ExtractionResult(values: [:])
            let filled = applyExtraction(result, to: draft)
            needsReview = Set(filled)
            captureToast = filled.isEmpty ? "텍스트를 찾지 못했어요" : "\(filled.count)개 항목을 채웠어요 · 확인해 주세요"
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

/// 스마트 캡처 소스 행: 유형색 틴트 아이콘 + 제목 + 부제 + 화살표.
private struct CaptureSourceRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 38, height: 38)
                .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primaryText)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.tertiaryText)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 7)
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
