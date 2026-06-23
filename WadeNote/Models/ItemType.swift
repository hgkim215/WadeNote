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
    case text          // 일반 텍스트
    case secret        // 가려지는 비밀값(비밀번호 등) — 기본 키보드
    case secretNumber  // 가려지는 숫자값(카드번호·CVC·신분증번호 등) — 숫자패드
    case email         // 이메일 키보드
    case number        // 숫자패드(가리지 않음, 유효기간 등)
    case url           // URL 키보드
    case date          // 날짜 선택기
    case multiline     // 여러 줄 텍스트

    /// 가려서 표시(•••• + 눈 토글)해야 하는 종류인지.
    var isMasked: Bool { self == .secret || self == .secretNumber }
}
