import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        Group {
            if appState.currentUser == nil {
                AuthGateView()
                    .environmentObject(appState)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else if appState.currentFamily == nil {
                FamilyOnboardingView()
                    .environmentObject(appState)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else {
                MainTabView()
                    .environmentObject(appState)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .animation(.easeInOut(duration: 0.3), value: appState.currentUser)
        .animation(.easeInOut(duration: 0.3), value: appState.currentFamily)
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedSection: AppSection = .home
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedSection {
                case .home:
                    NavigationStack { HomeDashboardView() }
                case .tasks:
                    NavigationStack { TaskBoardView() }
                case .calendar:
                    NavigationStack { ScheduleBoardView() }
                case .chat:
                    NavigationStack { CommunicationHubView() }
                case .expenses:
                    NavigationStack { ExpenseLedgerView() }
                }
            }
            .id(selectedSection)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: selectedSection)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PrimaryTabBar(selectedTab: $selectedSection)
        }
        .background(AppStyle.Palette.canvas.ignoresSafeArea())
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
