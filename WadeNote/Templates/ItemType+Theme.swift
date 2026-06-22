extension ItemType {
    var accentHex: String {
        switch self {
        case .login: "2D5BFF"
        case .card: "1FB866"
        case .identity: "8741E6"
        case .memo: "7C828F"
        }
    }

    var gradientHex: (String, String) {
        switch self {
        case .login: ("4F8BFF", "2D5BFF")
        case .card: ("34D27B", "13A958")
        case .identity: ("B26BF7", "8741E6")
        case .memo: ("AAB0BD", "7C828F")
        }
    }

    var symbolName: String {
        switch self {
        case .login: "lock.fill"
        case .card: "creditcard.fill"
        case .identity: "person.text.rectangle.fill"
        case .memo: "doc.text.fill"
        }
    }
}
