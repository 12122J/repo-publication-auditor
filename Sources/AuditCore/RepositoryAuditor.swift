import Foundation

public struct RepositoryAuditor {
    public init() {}

    public func audit(rootURL: URL, configuration: AuditConfiguration = AuditConfiguration()) -> AuditReport {
        let standardizedRoot = rootURL.standardizedFileURL
        let files = FileWalker.files(in: standardizedRoot, maxTextFileBytes: configuration.maxTextFileBytes)

        var findings: [Finding] = []
        findings.append(contentsOf: SecretScanner().scan(files: files, rootURL: standardizedRoot))
        findings.append(contentsOf: RiskyFileScanner().scan(files: files))
        findings.append(contentsOf: LargeFileScanner().scan(files: files))
        findings.append(contentsOf: InfrastructureScanner().scan(files: files))
        findings.append(contentsOf: ReadinessScanner().scan(rootURL: standardizedRoot, files: files))
        findings.append(contentsOf: CISetupScanner().scan(rootURL: standardizedRoot, files: files))

        if configuration.scanGitHistory {
            findings.append(contentsOf: HistoryScanner().scan(
                rootURL: standardizedRoot,
                maxFindings: configuration.maxHistoryFindings
            ))
            findings.append(contentsOf: CommitAuthorScanner().scan(rootURL: standardizedRoot))
        }

        return AuditReport(
            rootPath: standardizedRoot.path,
            scannedFileCount: files.count,
            findings: deduplicate(findings)
        )
    }

    private func deduplicate(_ findings: [Finding]) -> [Finding] {
        var seen: Set<String> = []
        var results: [Finding] = []

        for finding in findings {
            let key = [
                finding.severity.rawValue,
                finding.category.rawValue,
                finding.title,
                finding.path ?? "",
                finding.line.map(String.init) ?? ""
            ].joined(separator: "|")

            if seen.insert(key).inserted {
                results.append(finding)
            }
        }

        return results
    }
}
