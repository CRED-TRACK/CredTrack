import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var selectedTab = 0

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)

        let item = UITabBarItemAppearance()
        let dimGray  = UIColor(red: 0.54, green: 0.54, blue: 0.54, alpha: 1)
        let gold     = UIColor(red: 0.79, green: 0.66, blue: 0.30, alpha: 1)
        let tabFont  = UIFont.gilroy(.medium, size: 10)
        item.normal.iconColor             = dimGray
        item.normal.titleTextAttributes   = [.foregroundColor: dimGray,  .font: tabFont]
        item.selected.iconColor           = gold
        item.selected.titleTextAttributes = [.foregroundColor: gold, .font: tabFont]

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

            PlaceholderTab(title: "Profile")
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
