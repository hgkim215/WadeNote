import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Item.updatedAt, order: .reverse) private var items: [Item]
    @Environment(\.scenePhase) private var scenePhase
    @State private var search = ""
    @State private var showingAdd = false
    @State private var sync = SyncStatusMonitor()
    @AppStorage("didShowADPNotice") private var didShowADPNotice = false

    private var filtered: [Item] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { item in
            item.title.lowercased().contains(q)
            || item.type.displayName.lowercased().contains(q)
            || (item.fields ?? []).contains { $0.label.lowercased().contains(q) }
        }
    }

    private var favorites: [Item] { filtered.filter(\.isFavorite) }

    private var groups: [(ItemType, [Item])] {
        ItemType.allCases.compactMap { type in
            let xs = filtered.filter { $0.type == type }
            return xs.isEmpty ? nil : (type, xs)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                syncBanner
                if didShowADPNotice == false && sync.status == .synced {
                    adpNotice
                }
                if !favorites.isEmpty {
                    sectionHeader("즐겨찾기")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(favorites) { item in
                                NavigationLink { ItemDetailView(item: item) } label: { favCard(item) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 22)
                    }
                }
                ForEach(groups, id: \.0) { type, xs in
                    sectionHeader(type.displayName)
                    VStack(spacing: 0) {
                        ForEach(xs) { item in
                            NavigationLink { ItemDetailView(item: item) } label: { row(item) }
                                .buttonStyle(.plain)
                        }
                    }
                    .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 22)
                }
                if items.isEmpty {
                    emptyState
                }
            }
            .background(Color.appBackground)
            .navigationTitle("WadeNote")
            .searchable(text: $search, prompt: "검색")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) { ItemEditView(mode: .create) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { sync.refresh() }
            }
        }
    }

    @ViewBuilder
    private var syncBanner: some View {
        switch sync.status {
        case .synced:
            statusPill(text: "iCloud 동기화됨", systemImage: "checkmark.icloud.fill",
                       tint: Color(hex: "1FB866"))
        case .needsLogin:
            statusBanner(
                systemImage: "exclamationmark.icloud.fill",
                tint: Color(hex: "E8A317"),
                title: "iCloud에 로그인되어 있지 않습니다",
                subtitle: "동기화가 꺼져 있어 이 기기에만 저장됩니다. 설정 앱 > Apple 계정에 로그인하면 자동으로 동기화됩니다."
            )
        case .localOnly:
            statusBanner(
                systemImage: "icloud.slash.fill",
                tint: Color.secondaryText,
                title: "이 기기에만 저장됨",
                subtitle: "iCloud 동기화가 꺼져 있어 다른 기기와 공유되지 않습니다. 기기를 바꾸면 이 데이터는 복원되지 않습니다."
            )
        }
    }

    private func statusBanner(systemImage: String, tint: Color,
                              title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primaryText)
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(tint.opacity(0.3)))
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }

    private func statusPill(text: String, systemImage: String, tint: Color) -> some View {
        HStack {
            Label(text, systemImage: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var adpNotice: some View {
        Button { didShowADPNotice = true } label: {
            Label("설정 > Apple 계정 > iCloud > 고급 데이터 보호를 켜면 데이터가 종단간 암호화됩니다. (확인)",
                  systemImage: "checkmark.shield")
                .font(.footnote)
                .multilineTextAlignment(.leading)
        }
        .tint(Color.actionBlue)
        .padding(12)
        .background(Color.actionBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(Color.secondaryText)
            Text("첫 정보를 추가해 보세요")
                .font(.system(size: 15))
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Color.secondaryText)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private func row(_ item: Item) -> some View {
        HStack(spacing: 13) {
            TypeTile(type: item.type, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primaryText)
                if let sub = item.orderedFields.first(where: { !$0.value.isEmpty && $0.kind != .secret })?.value {
                    Text(sub)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer()
            if item.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(Color.favoriteStar)
                    .font(.system(size: 13))
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private func favCard(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TypeTile(type: item.type, size: 32)
            Text(item.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.primaryText)
                .lineLimit(1)
        }
        .padding(14)
        .frame(width: 150, alignment: .leading)
        .background(item.type.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}
