import Foundation
import Testing
@testable import AuditCore

struct AuditCoreTests {
    @Test
    func secretScannerFindsDatabaseURLWithoutLeakingValue() throws {
        let text = #"let url = "postgresql://user:super-secret-value@example.com/db""# // repo-auditor: allow-secret
        let findings = SecretScanner().scanText(text, path: "Config.swift")
        let rendered = MarkdownReportRenderer().render(AuditReport(rootPath: "/tmp/repo", scannedFileCount: 1, findings: findings))

        #expect(findings.contains { $0.title == "Database connection string with credentials" })
        #expect(!rendered.contains("super-secret-value"))
    }

    @Test
    func readinessScannerFlagsMissingReadmeAndLicense() throws {
        let root = try makeTempRepo()
        let file = root.appendingPathComponent("main.swift")
        try "print(\"hello\")".write(to: file, atomically: true, encoding: .utf8)

        let report = RepositoryAuditor().audit(
            rootURL: root,
            configuration: AuditConfiguration(scanGitHistory: false)
        )

        #expect(report.findings.contains { $0.title == "Missing README" })
        #expect(report.findings.contains { $0.title == "Missing license" })
    }

    @Test
    func riskyFileScannerFlagsEnvFiles() throws {
        let root = try makeTempRepo()
        let env = root.appendingPathComponent(".env")
        try "TOKEN=not-for-public".write(to: env, atomically: true, encoding: .utf8) // repo-auditor: allow-secret

        let report = RepositoryAuditor().audit(
            rootURL: root,
            configuration: AuditConfiguration(scanGitHistory: false)
        )

        #expect(report.findings.contains { $0.title == "Environment file" && $0.severity == .high })
    }

    @Test
    func historyScannerFindsSecretInOldCommit() throws {
        let root = try makeTempRepo()
        #expect(ProcessRunner.run("git", arguments: ["init"], workingDirectory: root).status == 0)
        #expect(ProcessRunner.run("git", arguments: ["config", "user.email", "test@example.com"], workingDirectory: root).status == 0)
        #expect(ProcessRunner.run("git", arguments: ["config", "user.name", "Test User"], workingDirectory: root).status == 0)

        let config = root.appendingPathComponent("Config.swift")
        try #"let url = "postgresql://user:old-secret-value@example.com/db""#.write(to: config, atomically: true, encoding: .utf8) // repo-auditor: allow-secret
        #expect(ProcessRunner.run("git", arguments: ["add", "Config.swift"], workingDirectory: root).status == 0)
        #expect(ProcessRunner.run("git", arguments: ["commit", "-m", "add config"], workingDirectory: root).status == 0)

        try #"let url = "env.DATABASE_URL""#.write(to: config, atomically: true, encoding: .utf8)
        #expect(ProcessRunner.run("git", arguments: ["add", "Config.swift"], workingDirectory: root).status == 0)
        #expect(ProcessRunner.run("git", arguments: ["commit", "-m", "remove config"], workingDirectory: root).status == 0)

        let report = RepositoryAuditor().audit(rootURL: root)
        let rendered = MarkdownReportRenderer().render(report)

        #expect(report.findings.contains { $0.category == .gitHistory && $0.title == "Secret-like pattern in git history" })
        #expect(!rendered.contains("old-secret-value"))
    }

    private func makeTempRepo() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("repo-publication-auditor-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
