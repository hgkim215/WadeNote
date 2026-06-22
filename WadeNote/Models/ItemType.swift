enum ItemType: String, Codable, CaseIterable, Identifiable {
    case login, card, identity, memo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .login: "로그인"
        case .card: "카드·은행"
        case .identity: "신분증"
        case .memo: "보안 메모"
        }
    }
}

enum FieldKind: String, Codable {
    case text, secret, url, date
}
