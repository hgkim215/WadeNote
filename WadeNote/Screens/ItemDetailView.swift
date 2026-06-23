import SwiftUI

struct ItemDetailView: View {
    let item: Item
    @Environment(\.modelContext) private var context
    @Environment(ClipboardHolder.self) private var clip
    @Environment(AttachmentHolder.self) private var attachments
    @State private var toast: String?

    private var store: ItemStore { ItemStore(context: context) }
    private var sortedFields: [Field] { item.orderedFields }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TypeTile(type: item.type, size: 72)
                    .shadow(color: item.type.accent.opacity(0.4), radius: 14, x: 0, y: 8)
                    .padding(.top, 12)
                Text(item.title)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Color.primaryText)
                    .padding(.top, 16)
                HStack(spacing: 8) {
                    Text(item.type.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 5)
                        .background(item.type.accent.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(item.type.accent.opacity(0.25)))
                        .foregroundStyle(item.type.accent)
                    Button { try? store.toggleFavorite(item) } label: {
                        Image(systemName: item.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 18))
                            .foregroundStyle(item.isFavorite ? Color.favoriteStar : Color(hex: "c4c4cc"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 9)

                VStack(spacing: 0) {
                    let visible = sortedFields.filter { !$0.value.isEmpty }
                    ForEach(Array(visible.enumerated()), id: \.element.persistentModelID) { idx, field in
                        FieldRow(field: field) { value in
                            clip.clipboard.copy(value)
                            toast = "복사됨"
                        }
                        if idx < visible.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.black.opacity(0.04)))
                .shadow(color: Color(hex: "141428").opacity(0.10), radius: 16, x: 0, y: 8)
                .padding(.horizontal, 22)
                .padding(.top, 22)

                if !item.attachmentIDs.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 10) {
                        ForEach(item.attachmentIDs, id: \.self) { id in
                            if let data = try? attachments.store.load(id: id),
                               let ui = UIImage(data: data) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 90, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
                }
            }
            .padding(.bottom, 24)
        }
        .background(
            ZStack(alignment: .top) {
                Color.appBackground
                RadialGradient(colors: [Color.actionBlue.opacity(0.10), .clear],
                               center: .top, startRadius: 0, endRadius: 360)
                    .frame(height: 300)
            }.ignoresSafeArea()
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("편집") { ItemEditView(mode: .edit(item)) }
            }
        }
        .toast($toast)
    }
}
