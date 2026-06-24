struct FieldSpec {
    let label: String
    let kind: FieldKind
    var required: Bool = false
}

enum Template {
    static func fields(for type: ItemType) -> [FieldSpec] {
        switch type {
        case .login:
            [.init(label: "서비스명", kind: .text, required: true),
             .init(label: "아이디", kind: .email),
             .init(label: "비밀번호", kind: .secret, required: true),
             .init(label: "URL", kind: .url),
             .init(label: "메모", kind: .text)]
        case .card:
            [.init(label: "카드/계좌명", kind: .text, required: true),
             .init(label: "번호", kind: .secretNumber, required: true),
             .init(label: "유효기간", kind: .number),
             .init(label: "CVC", kind: .secretNumber),
             .init(label: "비밀번호", kind: .secretNumber),
             .init(label: "메모", kind: .text)]
        case .identity:
            [.init(label: "종류", kind: .text, required: true),
             .init(label: "번호", kind: .secretNumber, required: true),
             .init(label: "발급일", kind: .date),
             .init(label: "만료일", kind: .date),
             .init(label: "메모", kind: .text)]
        case .apiKey:
            [.init(label: "서비스·용도", kind: .text, required: true),
             .init(label: "API 키 · 토큰", kind: .secret, required: true),
             .init(label: "엔드포인트 URL", kind: .url),
             .init(label: "발급일", kind: .date),
             .init(label: "만료일", kind: .date),
             .init(label: "메모", kind: .text)]
        case .memo:
            [.init(label: "본문", kind: .multiline, required: true)]
        }
    }

    static func makeFields(for type: ItemType) -> [Field] {
        fields(for: type).enumerated().map { index, spec in
            let field = Field(label: spec.label, value: "", kind: spec.kind, order: index)
            field.isRequired = spec.required
            return field
        }
    }

    /// 필수 필드가 모두(공백 제외) 채워졌는지. 저장 가능 여부 판단에 사용.
    static func requiredFieldsSatisfied(_ fields: [Field]) -> Bool {
        fields.allSatisfy { field in
            !field.isRequired || !field.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
