import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var selectedTab = 0
    @StateObject private var gmailManager = GmailConnectionManager()

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.NeoPop.Black.c300   // #161616  Pop Black 300

        let item    = UITabBarItemAppearance()
        let dim     = UIColor.NeoPop.Black.c100                   // #8A8A8A  Pop Black 100
        let active  = UIColor.white
        let tabFont = UIFont.gilroy(.medium, size: 10)
        item.normal.iconColor             = dim
        item.normal.titleTextAttributes   = [.foregroundColor: dim,    .font: tabFont]
        item.selected.iconColor           = active
        item.selected.titleTextAttributes = [.foregroundColor: active, .font: tabFont]

        appearance.stackedLayoutAppearance = item
        UITabBar.appearance().standardAppearance  = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CardsTab(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "creditcard.fill" : "creditcard")
                    Text("Cards")
                }
                .tag(0)

            UtilityListView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "bolt.fill" : "bolt")
                    Text("Utility")
                }
                .tag(1)

            AnalysisView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "chart.bar.fill" : "chart.bar")
                    Text("Analysis")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(3)
        }
        .environmentObject(gmailManager)
        .task { await gmailManager.checkStatus() }
    }
}

// MARK: - Cards Tab

private struct CardsTab: View {
    @Binding var selectedTab: Int

    var body: some View {
        NavigationStack {
            CardListView(selectedTab: $selectedTab)
        }
        .tint(.ctTextPrimary)
    }
}

