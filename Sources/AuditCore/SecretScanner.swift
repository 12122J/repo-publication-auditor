import Foundation

public struct SecretScanner {
    public init() {}

    public func scan(files: [AuditedFile], rootURL: URL) -> [Finding] {
        var findings: [Finding] = []

        for file in files {
            guard file.size <= 1_000_000,
                  let data = try? Data(contentsOf: file.url),
                  PathUtilities.isLikelyText(data),
                  let text = String(data: data, encoding: .utf8) else {
                continue
            }

            findings.append(contentsOf: scanText(text, path: file.relativePath))
        }

        return findings
    }

    public func scanText(_ text: String, path: String) -> [Finding] {
        var findings: [Finding] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        for (index, line) in lines.enumerated() {
            let lineString = String(line)
            guard !Self.isAllowlisted(lineString) else {
                continue
            }

            let range = NSRange(lineString.startIndex..<lineString.endIndex, in: lineString)

            for pattern in PatternLibrary.secretPatterns {
                if pattern.regex.firstMatch(in: lineString, options: [], range: range) != nil {
                    findings.append(Finding(
                        severity: pattern.severity,
                        category: pattern.category,
                        title: pattern.title,
                        detail: "\(pattern.detail) Matched pattern: \(pattern.name). Secret values are intentionally redacted.",
                        path: path,
                        line: index + 1,
                        remediation: pattern.remediation
                    ))
                }
            }
        }

        return findings
    }

    static func isAllowlisted(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        return lowercased.contains("repo-auditor: allow-secret")
            || lowercased.contains("detect-secrets: allow")
            || lowercased.contains("pragma: allowlist secret")
            || lowercased.contains("gitleaks:allow")
    }
}
