import SwiftData

@Model final class Field {
    var label: String = ""
    var value: String = ""
    var kindRaw: String = FieldKind.text.rawValue
    var order: Int = 0
    var item: Item?

    var kind: FieldKind {
        get { FieldKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }

    init(label: String, value: String, kind: FieldKind, order: Int) {
        self.label = label
        self.value = value
        self.kindRaw = kind.rawValue
        self.order = order
    }
}
