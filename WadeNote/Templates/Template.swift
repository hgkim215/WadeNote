struct FieldSpec {
    let label: String
    let kind: FieldKind
}

enum Template {
    static func fields(for type: ItemType) -> [FieldSpec] {
        switch type {
        case .login:
            [.init(label: "서비스명", kind: .text),
             .init(label: "아이디", kind: .text),
             .init(label: "비밀번호", kind: .secret),
             .init(label: "URL", kind: .url),
             .init(label: "메모", kind: .text)]
        case .card:
            [.init(label: "카드/계좌명", kind: .text),
             .init(label: "번호", kind: .secret),
             .init(label: "유효기간", kind: .text),
             .init(label: "CVC", kind: .secret),
             .init(label: "비밀번호", kind: .secret),
             .init(label: "메모", kind: .text)]
        case .identity:
            [.init(label: "종류", kind: .text),
             .init(label: "번호", kind: .secret),
             .init(label: "발급일", kind: .date),
             .init(label: "만료일", kind: .date),
             .init(label: "메모", kind: .text)]
        case .memo:
            [.init(label: "본문", kind: .multiline)]
        }
    }

    static func makeFields(for type: ItemType) -> [Field] {
        fields(for: type).enumerated().map { index, spec in
            Field(label: spec.label, value: "", kind: spec.kind, order: index)
        }
    }
}
