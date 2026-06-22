import SwiftUI

struct FieldRow: View {
    let field: Field
    var onCopy: (String) -> Void
    @State private var revealed = false

    private var isSecret: Bool { field.kind == .secret }

    private var display: String {
        guard isSecret, !revealed else { return field.value }
        return String(repeating: "•", count: max(8, min(field.value.count, 12)))
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(field.label)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondaryText)
                Text(display)
                    .font(.system(size: 16, design: isSecret ? .monospaced : .default))
                    .foregroundStyle(Color.primaryText)
            }
            Spacer()
            if isSecret {
                Button { revealed.toggle() } label: {
                    Image(systemName: revealed ? "eye.fill" : "eye")
                }
                .tint(revealed ? Color.actionBlue : Color.secondaryText)
            }
            Button { onCopy(field.value) } label: {
                Image(systemName: "doc.on.doc")
                    .padding(8)
                    .background(Circle().fill(Color.actionBlue.opacity(0.1)))
            }
            .tint(Color.actionBlue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
