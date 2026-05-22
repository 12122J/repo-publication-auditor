import Foundation

public struct InfrastructureScanner {
    public init() {}

    public func scan(files: [AuditedFile]) -> [Finding] {
        var findings: [Finding] = []

        for file in files {
            findings.append(contentsOf: pathFindings(for: file))
            findings.append(contentsOf: contentFindings(for: file))
        }

        return findings
    }

    private func pathFindings(for file: AuditedFile) -> [Finding] {
        let lowerPath = file.relativePath.lowercased()
        var findings: [Finding] = []

        if lowerPath.contains("/deploy") || lowerPath.hasPrefix("deploy") || lowerPath.contains("deploy.sh") {
            findings.append(Finding(
                severity: .medium,
                category: .infrastructure,
                title: "Deployment file",
                detail: "Deployment files can expose private server layout, domains, users, or release process.",
                path: file.relativePath,
                remediation: "Replace private deployment files with generic docs or keep them private."
            ))
        }

        if lowerPath.contains(".github/workflows") && lowerPath.contains("deploy") {
            findings.append(Finding(
                severity: .medium,
                category: .infrastructure,
                title: "Deployment workflow",
                detail: "Deployment workflows often reveal private infrastructure assumptions even when secrets are masked.",
                path: file.relativePath,
                remediation: "Remove private deployment workflows or convert them to generic examples."
            ))
        }

        if lowerPath.hasSuffix(".service") || lowerPath.contains("systemd") {
            findings.append(Finding(
                severity: .medium,
                category: .infrastructure,
                title: "Systemd configuration",
                detail: "Systemd service files can reveal private paths, users, process names, and server layout.",
                path: file.relativePath,
                remediation: "Keep production service files private or sanitize them thoroughly."
            ))
        }

        if lowerPath.contains("nginx") || lowerPath.contains("docker-compose") {
            findings.append(Finding(
                severity: .low,
                category: .infrastructure,
                title: "Infrastructure configuration",
                detail: "Infrastructure config should be reviewed for private domains, paths, and deployment assumptions.",
                path: file.relativePath,
                remediation: "Use placeholders for private domains and paths if this config is meant to be public."
            ))
        }

        return findings
    }

    private func contentFindings(for file: AuditedFile) -> [Finding] {
        guard file.size <= 1_000_000,
              let data = try? Data(contentsOf: file.url),
              PathUtilities.isLikelyText(data),
              let text = String(data: data, encoding: .utf8) else {
            return []
        }

        var findings: [Finding] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        for (index, line) in lines.enumerated() {
            let lineString = String(line)
            guard !Self.isAllowlisted(lineString) else {
                continue
            }

            let range = NSRange(lineString.startIndex..<lineString.endIndex, in: lineString)

            for pattern in PatternLibrary.infrastructurePatterns {
                if pattern.regex.firstMatch(in: lineString, options: [], range: range) != nil {
                    findings.append(Finding(
                        severity: pattern.severity,
                        category: pattern.category,
                        title: pattern.title,
                        detail: "\(pattern.detail) Matched pattern: \(pattern.name). Values are intentionally redacted.",
                        path: file.relativePath,
                        line: index + 1,
                        remediation: pattern.remediation
                    ))
                }
            }

            if let publicIP = firstPublicIPAddress(in: lineString), !publicIP.isEmpty {
                findings.append(Finding(
                    severity: .medium,
                    category: .infrastructure,
                    title: "Public IP address",
                    detail: "A public IP address appears in source. Values are intentionally redacted.",
                    path: file.relativePath,
                    line: index + 1,
                    remediation: "Replace private infrastructure addresses with placeholders before publishing."
                ))
            }
        }

        return findings
    }

    private func firstPublicIPAddress(in line: String) -> String? {
        let regex = try! NSRegularExpression(pattern: "\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b")
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let swiftRange = Range(match.range, in: line) else {
            return nil
        }

        let candidate = String(line[swiftRange])
        let octets = candidate.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else {
            return nil
        }

        if octets[0] == 10 || octets[0] == 127 || octets[0] == 0 {
            return nil
        }
        if octets[0] == 172 && (16...31).contains(octets[1]) {
            return nil
        }
        if octets[0] == 192 && octets[1] == 168 {
            return nil
        }

        return candidate
    }

    static func isAllowlisted(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        return lowercased.contains("repo-auditor: allow-infra")
            || lowercased.contains("repo-auditor: allow-secret")
    }
}
