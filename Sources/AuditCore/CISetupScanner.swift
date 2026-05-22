import Foundation

public struct CISetupScanner {
    public init() {}

    public func scan(rootURL: URL, files: [AuditedFile]) -> [Finding] {
        var findings: [Finding] = []
        let paths = Set(files.map { $0.relativePath })
        let rootNames = Set(files.filter { !$0.relativePath.contains("/") }.map { $0.url.lastPathComponent.lowercased() })

        // CI configuration
        let ciIndicators = [
            ".github/workflows",
            ".gitlab-ci.yml",
            ".circleci/config.yml",
            "Jenkinsfile",
            ".travis.yml",
            "azure-pipelines.yml",
            ".buildkite/pipeline.yml"
        ]
        let hasCI = ciIndicators.contains { indicator in
            paths.contains { $0 == indicator || $0.hasPrefix(indicator + "/") }
        }
        if !hasCI {
            findings.append(Finding(
                severity: .low,
                category: .cicd,
                title: "No CI configuration found",
                detail: "Public repositories benefit from automated testing via CI. Contributors expect to see test results on pull requests.",
                remediation: "Add a GitHub Actions workflow or similar CI configuration before publishing."
            ))
        }

        // CONTRIBUTING guide
        let hasContributing = rootNames.contains { $0 == "contributing.md" || $0 == "contributing" || $0.hasPrefix("contributing.") }
        if !hasContributing {
            findings.append(Finding(
                severity: .info,
                category: .readiness,
                title: "No CONTRIBUTING guide",
                detail: "A CONTRIBUTING.md explains how others can submit issues and pull requests, reducing friction for new contributors.",
                remediation: "Add a CONTRIBUTING.md with setup instructions, coding conventions, and PR guidelines."
            ))
        }

        // Changelog
        let hasChangelog = rootNames.contains { $0.hasPrefix("changelog") || $0.hasPrefix("history") || $0.hasPrefix("releases") || $0 == "news" }
        if !hasChangelog {
            findings.append(Finding(
                severity: .info,
                category: .readiness,
                title: "No changelog file",
                detail: "A CHANGELOG.md helps users understand what changed between versions and is expected by most open source consumers.",
                remediation: "Add a CHANGELOG.md or HISTORY.md documenting releases and notable changes."
            ))
        }

        // .gitignore
        let hasGitignore = rootNames.contains(".gitignore")
        if !hasGitignore {
            findings.append(Finding(
                severity: .medium,
                category: .gitHygiene,
                title: "No .gitignore file",
                detail: "Without a .gitignore, build artifacts, editor configs, and OS files may be accidentally committed and published.",
                remediation: "Add a .gitignore appropriate for your project's language and toolchain."
            ))
        }

        // Security policy
        let hasSecurityPolicy = paths.contains("SECURITY.md") || paths.contains(".github/SECURITY.md")
        if !hasSecurityPolicy {
            findings.append(Finding(
                severity: .info,
                category: .readiness,
                title: "No SECURITY.md",
                detail: "A security policy tells researchers how to report vulnerabilities responsibly rather than filing public issues.",
                remediation: "Add a SECURITY.md explaining your vulnerability disclosure process."
            ))
        }

        return findings
    }
}
