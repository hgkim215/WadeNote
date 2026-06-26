import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ClipboardHolder.self) private var clip
    @Query(sort: \Item.updatedAt, order: .reverse) private var items: [Item]
    @State private var search = ""
    @State private var showingAdd = false
    @State private var sync = SyncStatusMonitor()
    @State private var toast: String?
    @AppStorage("didShowADPNotice") private var didShowADPNotice = false

    // MARK: Data

    private var store: ItemStore { ItemStore(context: context) }

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

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        searchBar
                        syncAlert
                        if didShowADPNotice == false && sync.status == .synced { adpNotice }
                        favoritesSection
                        groupsSection
                        if items.isEmpty { emptyState }
                    }
                    .padding(.bottom, 28)
                }
            }
            .brandGlow()
            .toolbar(.hidden, for: .navigationBar)




            .sheet(isPresented: $showingAdd) { ItemEditView(mode: .create) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { sync.refresh() }
            }
            .toast($toast)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("WadeNote")
                    .font(.system(size: 33, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(Color.primaryText)
                if sync.status == .synced { syncedPill }
            }
            Spacer()
            Button { showingAdd = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(ItemType.login.gradient, in: Circle())
                    .shadow(color: Color.actionBlue.opacity(0.35), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
    }

    private var syncedPill: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.icloud.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: "1FB866"))
            Text("iCloud 동기화됨")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.secondaryText)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(Color.primaryText.opacity(0.05), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.cardBorder))
    }

    private var searchBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.tertiaryText)
            TextField("검색", text: $search)
                .font(.system(size: 15))
                .tint(Color.actionBlue)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .padding(.horizontal, 22)
        .padding(.top, 16)
    }

    // MARK: Sections

    @ViewBuilder
    private var favoritesSection: some View {
        if !favorites.isEmpty {
            sectionHeader("즐겨찾기")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(favorites) { item in
                        NavigationLink { ItemDetailView(item: item) } label: { favCard(item) }
                            .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, 22)
            }
        }
    }

    private var groupsSection: some View {
        ForEach(groups, id: \.0) { type, xs in
            sectionHeader(type.displayName)
            VStack(spacing: 0) {
                ForEach(Array(xs.enumerated()), id: \.element.persistentModelID) { idx, item in
                    SwipeToDelete(content: { itemRow(item) }, onDelete: { delete(item) })
                    if idx < xs.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .padding(.horizontal, 22)
        }
    }

    private func itemRow(_ item: Item) -> some View {
        HStack(spacing: 13) {
            NavigationLink { ItemDetailView(item: item) } label: {
                HStack(spacing: 13) {
                    TypeTile(type: item.type, size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.primaryText)
                            .lineLimit(1)
                        if let sub = subtitle(item) {
                            Text(sub)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Color.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())

            if item.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(Color.favoriteStar)
                    .font(.system(size: 14))
            }
            if let value = quickCopyValue(item) {
                Button {
                    Haptics.tap()
                    clip.clipboard.copy(value)
                    toast = "복사됨"
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.actionBlue)
                        .frame(width: 30, height: 30)
                        .background(Color.actionBlue.opacity(0.1), in: Circle())
                }
                .pressable(scale: 0.85)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
    }

    private func favCard(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TypeTile(type: item.type, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(1)
                if let sub = subtitle(item) {
                    Text(sub)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .frame(width: 150, alignment: .leading)
        .background(
            LinearGradient(colors: [item.type.accent.opacity(0.13), item.type.accent.opacity(0.03)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(item.type.accent.opacity(0.18)))
    }

    // MARK: Sync alert (non-synced states)

    @ViewBuilder
    private var syncAlert: some View {
        switch sync.status {
        case .synced:
            EmptyView()
        case .needsLogin:
            statusBanner(systemImage: "exclamationmark.icloud.fill", tint: Color(hex: "E8A317"),
                         title: "iCloud에 로그인되어 있지 않습니다",
                         subtitle: "동기화가 꺼져 있어 이 기기에만 저장됩니다. 설정 앱 > Apple 계정에 로그인하면 자동으로 동기화됩니다.")
        case .localOnly:
            statusBanner(systemImage: "icloud.slash.fill", tint: Color.secondaryText,
                         title: "이 기기에만 저장됨",
                         subtitle: "iCloud 동기화가 꺼져 있어 다른 기기와 공유되지 않습니다. 기기를 바꾸면 이 데이터는 복원되지 않습니다.")
        }
    }

    private func statusBanner(systemImage: String, tint: Color,
                              title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage).foregroundStyle(tint).font(.system(size: 18))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.primaryText)
                Text(subtitle).font(.system(size: 12.5)).foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(tint.opacity(0.3)))
        .padding(.horizontal, 22)
        .padding(.top, 14)
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
        .padding(.top, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            // 유형 타일을 부채꼴로 펼친 일러스트
            ZStack {
                let mid = Double(ItemType.allCases.count - 1) / 2  // 4개→1.5, 5개→2.0
                ForEach(Array(ItemType.allCases.enumerated()), id: \.offset) { i, type in
                    TypeTile(type: type, size: 58)
                        .rotationEffect(.degrees((Double(i) - mid) * 8))
                        .offset(x: (Double(i) - mid) * 34, y: abs(Double(i) - mid) * 6)
                }
            }
            .frame(height: 90)
            .padding(.bottom, 4)

            VStack(spacing: 7) {
                Text("아직 저장된 정보가 없어요")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.primaryText)
                Text("로그인 · 카드 · 신분증 · API 키 · 메모를\n안전하게 한곳에 보관하세요")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Button {
                Haptics.tap()
                showingAdd = true
            } label: {
                Label("첫 정보 추가하기", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 13)
                    .background(ItemType.login.gradient, in: Capsule())
                    .shadow(color: Color.actionBlue.opacity(0.35), radius: 12, x: 0, y: 6)
            }
            .pressable()
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
        .padding(.horizontal, 40)
    }

    private func delete(_ item: Item) {
        Haptics.tap()
        try? store.delete(item)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Color.tertiaryText)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    // MARK: Helpers

    private func subtitle(_ item: Item) -> String? {
        item.orderedFields.first(where: { !$0.value.isEmpty && !$0.isMasked })?.value
    }
    private func quickCopyValue(_ item: Item) -> String? {
        let nonEmpty = item.orderedFields.filter { !$0.value.isEmpty }
        return nonEmpty.first(where: { $0.isMasked })?.value ?? nonEmpty.first?.value
    }
}
