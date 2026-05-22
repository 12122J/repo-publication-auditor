import AppKit
import AuditCore
import Foundation

@MainActor
final class AuditViewModel: ObservableObject {
    @Published var report: AuditReport?
    @Published var isRunning = false
    @Published var errorMessage: String?

    var findings: [Finding] { report?.findings ?? [] }

    func runAudit(url: URL) {
        isRunning = true
        errorMessage = nil
        report = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let r = RepositoryAuditor().audit(rootURL: url)
            DispatchQueue.main.async {
                self.report = r
                self.isRunning = false
            }
        }
    }

    func exportMarkdown() {
        guard let report else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "OPEN_SOURCE_AUDIT.md"
        panel.allowedContentTypes = [.plainText]
        panel.prompt = "Export"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try MarkdownReportRenderer().render(report).write(to: url, atomically: true, encoding: .utf8)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
