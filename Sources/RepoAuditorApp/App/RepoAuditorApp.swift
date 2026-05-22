import SwiftUI

@main
struct RepoAuditorApp: App {
    @StateObject private var appVM = AppViewModel()
    @StateObject private var github = GitHubService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appVM)
                .environmentObject(github)
                .frame(minWidth: 720, minHeight: 500)
        }
        .defaultSize(width: 800, height: 560)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appVM: AppViewModel

    var body: some View {
        Group {
            switch appVM.phase {
            case .welcome:      WelcomeView()
            case .githubAuth:   GitHubAuthView()
            case .repoPicker:   RepoPickerView()
            case .auditing(let url, let name): ContentView(url: url, repoName: name)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: appVM.phase.id)
    }
}

extension AppPhase {
    var id: Int {
        switch self {
        case .welcome:    0
        case .githubAuth: 1
        case .repoPicker: 2
        case .auditing:   3
        }
    }
}
