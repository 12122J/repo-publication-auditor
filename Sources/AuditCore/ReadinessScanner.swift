import Foundation

public struct ReadinessScanner {
    public init() {}

    public func scan(rootURL: URL, files: [AuditedFile]) -> [Finding] {
        var findings: [Finding] = []
        let rootNames = Set(files.filter { !$0.relativePath.contains("/") }.map { $0.url.lastPathComponent.lowercased() })

        if !rootNames.contains(where: { $0 == "readme.md" || $0 == "readme" || $0.hasPrefix("readme.") }) {
            findings.append(Finding(
                severity: .medium,
                category: .readiness,
                title: "Missing README",
                detail: "Public repositories need a clear README explaining purpose, setup, usage, and project status.",
                remediation: "Add a README before publishing."
            ))
        }

        if !rootNames.contains(where: { $0 == "license" || $0.hasPrefix("license.") }) {
            findings.append(Finding(
                severity: .medium,
                category: .readiness,
                title: "Missing license",
                detail: "Without a license, other developers do not have clear permission to use, modify, or redistribute the code.",
                remediation: "Add an explicit license file such as MIT, Apache-2.0, or another license that matches your intent."
            ))
        }

        if let packageFile = files.first(where: { $0.relativePath == "package.json" }) {
            findings.append(contentsOf: packageJSONFindings(packageFile))
        }

        return findings
    }

    private func packageJSONFindings(_ file: AuditedFile) -> [Finding] {
        guard let data = try? Data(contentsOf: file.url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var findings: [Finding] = []

        if json["private"] as? Bool == true {
            findings.append(Finding(
                severity: .medium,
                category: .metadata,
                title: "`package.json` is private",
                detail: "`private: true` usually means the package was not prepared for public reuse or publication.",
                path: file.relativePath,
                remediation: "Decide whether this should remain private or update package metadata for public use."
            ))
        }

        if (json["description"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            findings.append(Finding(
                severity: .low,
                category: .metadata,
                title: "Missing package description",
                detail: "A short package description helps people understand the project from GitHub and package tooling.",
                path: file.relativePath,
                remediation: "Add a concise description."
            ))
        }

        if json["license"] == nil {
            findings.append(Finding(
                severity: .low,
                category: .metadata,
                title: "Missing package license metadata",
                detail: "`package.json` does not declare a license.",
                path: file.relativePath,
                remediation: "Add license metadata that matches the repository license."
            ))
        }

        return findings
    }
}
