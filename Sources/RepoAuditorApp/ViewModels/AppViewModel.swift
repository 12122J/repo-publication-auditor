import AppKit
import Foundation

enum AppPhase {
    case welcome
    case githubAuth
    case repoPicker
    case auditing(URL, String?)
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var phase: AppPhase = .welcome

    func chooseLocalFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Audit"
        if panel.runModal() == .OK, let url = panel.url {
            phase = .auditing(url, nil)
        }
    }

    func startAudit(url: URL, repoName: String? = nil) {
        phase = .auditing(url, repoName)
    }
}
