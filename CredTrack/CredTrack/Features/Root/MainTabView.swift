import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var selectedTab = 0

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

            PlaceholderTab(title: "Analytics")
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "chart.bar.fill" : "chart.bar")
                    Text("Analytics")
                }
                .tag(1)

            PlaceholderTab(title: "Rewards")
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "star.fill" : "star")
                    Text("Rewards")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(3)
        }
    }
}

// MARK: - Cards Tab

private struct CardsTab: View {
    @Binding var selectedTab: Int

    var body: some View {
        CardListView(selectedTab: $selectedTab)
    }
}

// MARK: - Placeholder Tab

private struct PlaceholderTab: View {
    let title: String

    var body: some View {
        ZStack {
            Color.ctBackground.ignoresSafeArea()
            Text(title)
                .font(.ctHeadline)
                .foregroundColor(.ctTextSecondary)
        }
    }
}
