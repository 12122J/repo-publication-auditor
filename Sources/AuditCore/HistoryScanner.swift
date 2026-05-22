import Foundation

public struct HistoryScanner {
    private let combinedSecretPattern = [
        "gh[pousr]_[A-Za-z0-9_]{20,}",
        "github_pat_[A-Za-z0-9_]{20,}",
        "sk-[A-Za-z0-9_-]{20,}",
        "AKIA[0-9A-Z]{16}",
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "xox[baprs]-[A-Za-z0-9-]{20,}",
        "(postgresql?|mysql|mongodb(\\+srv)?|redis)://[^[:space:]@:]+:[^[:space:]@]+@[^[:space:]]+"
    ].joined(separator: "|")

    public init() {}

    public func scan(rootURL: URL, maxFindings: Int) -> [Finding] {
        guard isGitRepository(rootURL) else {
            return []
        }

        var findings: [Finding] = []
        findings.append(contentsOf: scanSecretHistory(rootURL: rootURL, maxFindings: maxFindings))

        if findings.count < maxFindings {
            findings.append(contentsOf: scanRiskyFileHistory(rootURL: rootURL, maxFindings: maxFindings - findings.count))
        }

        return Array(findings.prefix(maxFindings))
    }

    private func isGitRepository(_ rootURL: URL) -> Bool {
        let output = ProcessRunner.run("git", arguments: ["rev-parse", "--is-inside-work-tree"], workingDirectory: rootURL)
        return output.status == 0 && output.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    private func scanSecretHistory(rootURL: URL, maxFindings: Int) -> [Finding] {
        let commitsOutput = ProcessRunner.run("git", arguments: ["rev-list", "--all"], workingDirectory: rootURL)
        guard commitsOutput.status == 0 else {
            return []
        }

        let commits = commitsOutput.stdout.split(separator: "\n").map(String.init)
        guard !commits.isEmpty else {
            return []
        }

        var findings: [Finding] = []
        let batchSize = 24

        for batchStart in stride(from: 0, to: commits.count, by: batchSize) {
            if findings.count >= maxFindings {
                break
            }

            let batch = Array(commits[batchStart..<min(batchStart + batchSize, commits.count)])
            let args = ["grep", "-I", "-n", "-E", combinedSecretPattern] + batch + ["--"]
            let output = ProcessRunner.run("git", arguments: args, workingDirectory: rootURL)

            guard output.status == 0 else {
                continue
            }

            for line in output.stdout.split(separator: "\n") {
                if findings.count >= maxFindings {
                    break
                }

                if SecretScanner.isAllowlisted(String(line)) {
                    continue
                }

                let parts = line.split(separator: ":", maxSplits: 3, omittingEmptySubsequences: false)
                guard parts.count >= 3 else {
                    continue
                }

                let commit = String(parts[0].prefix(12))
                let path = String(parts[1])
                let lineNumber = Int(parts[2])

                findings.append(Finding(
                    severity: .high,
                    category: .gitHistory,
                    title: "Secret-like pattern in git history",
                    detail: "A secret-like pattern appears in historical commit \(commit). Values are intentionally redacted.",
                    path: path,
                    line: lineNumber,
                    remediation: "Rotate the credential if it was real, then publish from a fresh clean repository or rewritten history."
                ))
            }
        }

        return findings
    }

    private func scanRiskyFileHistory(rootURL: URL, maxFindings: Int) -> [Finding] {
        let output = ProcessRunner.run("git", arguments: ["log", "--all", "--name-only", "--pretty=format:"], workingDirectory: rootURL)
        guard output.status == 0 else {
            return []
        }

        let riskyPattern = try! NSRegularExpression(
            pattern: #"(^|/)(\.env($|\.)|id_rsa|.*\.(pem|key|p12|pfx|mobileprovision|sqlite|db)$)"#,
            options: [.caseInsensitive]
        )

        var seen: Set<String> = []
        var findings: [Finding] = []

        for rawPath in output.stdout.split(separator: "\n").map(String.init) {
            if findings.count >= maxFindings {
                break
            }

            guard !rawPath.isEmpty, !seen.contains(rawPath) else {
                continue
            }

            let range = NSRange(rawPath.startIndex..<rawPath.endIndex, in: rawPath)
            if riskyPattern.firstMatch(in: rawPath, options: [], range: range) != nil {
                seen.insert(rawPath)
                findings.append(Finding(
                    severity: .medium,
                    category: .gitHistory,
                    title: "Risky file path appears in git history",
                    detail: "A historical file path looks like it may have contained secrets or private data.",
                    path: rawPath,
                    remediation: "Review the historical file contents before publishing the repository."
                ))
            }
        }

        return findings
    }
}
