import Foundation

public struct MarkdownReportRenderer {
    public init() {}

    public func render(_ report: AuditReport) -> String {
        var lines: [String] = []
        lines.append("# Repository Publication Audit")
        lines.append("")
        lines.append("- Repository: `\(report.rootPath)`")
        lines.append("- Generated: \(Self.dateFormatter.string(from: report.generatedAt))")
        lines.append("- Files scanned: \(report.scannedFileCount)")
        lines.append("- Safety: secret values are never printed in this report")
        lines.append("")
        lines.append("## Summary")
        lines.append("")
        lines.append("| Severity | Count |")
        lines.append("| --- | ---: |")
        for severity in Severity.allCases {
            lines.append("| \(severity.displayName) | \(report.count(for: severity)) |")
        }
        lines.append("")

        if report.findings.isEmpty {
            lines.append("No findings. This does not guarantee the repository is safe to publish, but no configured checks fired.")
            lines.append("")
            return lines.joined(separator: "\n")
        }

        for severity in Severity.allCases {
            let severityFindings = report.findings.filter { $0.severity == severity }
            guard !severityFindings.isEmpty else {
                continue
            }

            lines.append("## \(severity.displayName) Findings")
            lines.append("")

            for finding in severityFindings {
                lines.append("- **\(finding.category.rawValue): \(finding.title)**")
                if let path = finding.path {
                    if let line = finding.line {
                        lines.append("  - Location: `\(path):\(line)`")
                    } else {
                        lines.append("  - Location: `\(path)`")
                    }
                }
                lines.append("  - Detail: \(finding.detail)")
                if let remediation = finding.remediation {
                    lines.append("  - Suggested fix: \(remediation)")
                }
            }

            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
