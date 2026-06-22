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
                TypeTile(type: item.type, size: 72).padding(.top, 10)
                Text(item.title)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Color.primaryText)
                    .padding(.top, 14)
                HStack(spacing: 8) {
                    Text(item.type.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 5)
                        .background(item.type.accent.opacity(0.12), in: Capsule())
                        .foregroundStyle(item.type.accent)
                    Button { try? store.toggleFavorite(item) } label: {
                        Image(systemName: item.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(item.isFavorite ? Color.favoriteStar : Color.secondaryText)
                    }
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
                .padding(.horizontal, 22)
                .padding(.top, 20)

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
        }
        .background(Color.appBackground)
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
