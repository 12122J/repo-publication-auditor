import Foundation

public struct CommitAuthorScanner {
    private static let personalDomains: Set<String> = [
        "gmail.com", "yahoo.com", "hotmail.com", "outlook.com",
        "icloud.com", "me.com", "mac.com", "protonmail.com",
        "proton.me", "live.com", "msn.com", "googlemail.com"
    ]

    public init() {}

    public func scan(rootURL: URL) -> [Finding] {
        let output = ProcessRunner.run(
            "git",
            arguments: ["log", "--all", "--format=%ae"],
            workingDirectory: rootURL
        )
        guard output.status == 0 else { return [] }

        var domainCounts: [String: Int] = [:]
        for email in output.stdout.split(separator: "\n").map(String.init) {
            let parts = email.split(separator: "@")
            guard parts.count == 2 else { continue }
            let domain = String(parts[1]).lowercased()
            if Self.personalDomains.contains(domain) {
                domainCounts[domain, default: 0] += 1
            }
        }

        guard !domainCounts.isEmpty else { return [] }

        let summary = domainCounts
            .sorted { $0.value > $1.value }
            .map { "\($0.value) commit\($0.value == 1 ? "" : "s") from @\($0.key)" }
            .joined(separator: ", ")

        return [Finding(
            severity: .low,
            category: .gitHygiene,
            title: "Personal email addresses in git history",
            detail: "Commit authors used personal email accounts: \(summary). These will be publicly visible.",
            remediation: "Consider whether exposing personal emails is acceptable. You can rewrite history with git filter-repo to replace emails before publishing."
        )]
    }
}
