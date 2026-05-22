import Foundation

public struct RiskyFileScanner {
    public init() {}

    public func scan(files: [AuditedFile]) -> [Finding] {
        files.compactMap { finding(for: $0) }
    }

    private func finding(for file: AuditedFile) -> Finding? {
        let lowerPath = file.relativePath.lowercased()
        let lowerName = file.url.lastPathComponent.lowercased()
        let ext = file.url.pathExtension.lowercased()

        if lowerName == ".env" || lowerName.hasPrefix(".env.") {
            return Finding(
                severity: .high,
                category: .riskyFiles,
                title: "Environment file",
                detail: "Environment files often contain credentials or private deployment settings.",
                path: file.relativePath,
                remediation: "Keep only sanitized `.env.example` files in public repositories."
            )
        }

        if ["pem", "key", "p12", "pfx", "mobileprovision"].contains(ext) || lowerName.hasPrefix("id_rsa") {
            return Finding(
                severity: .high,
                category: .riskyFiles,
                title: "Key or certificate file",
                detail: "Key and certificate files should not be published unless they are intentionally public test fixtures.",
                path: file.relativePath,
                remediation: "Remove the file, rotate the credential if real, and publish from clean history."
            )
        }

        if ["sqlite", "sqlite3", "db"].contains(ext) {
            return Finding(
                severity: .medium,
                category: .riskyFiles,
                title: "Database file",
                detail: "Database files may contain private data, test users, tokens, or customer records.",
                path: file.relativePath,
                remediation: "Replace with generated fixtures or documented seed scripts."
            )
        }

        if ["pdf", "doc", "docx"].contains(ext) && (lowerPath.contains("cv") || lowerPath.contains("resume") || lowerPath.contains("cover")) {
            return Finding(
                severity: .medium,
                category: .riskyFiles,
                title: "Personal document",
                detail: "Personal documents such as CVs and cover letters are usually not part of an open source repository.",
                path: file.relativePath,
                remediation: "Remove personal documents from the public repository or host them separately on purpose."
            )
        }

        if ["dmg", "zip", "tar", "gz"].contains(ext) {
            return Finding(
                severity: .low,
                category: .riskyFiles,
                title: "Packaged artifact",
                detail: "Packaged artifacts can bloat the repository and may contain generated or private files.",
                path: file.relativePath,
                remediation: "Prefer reproducible build instructions and release artifacts outside the source tree."
            )
        }

        if file.size > 5_000_000 {
            return Finding(
                severity: .low,
                category: .riskyFiles,
                title: "Large file",
                detail: "Large files should be reviewed for licensing, privacy, and repository weight before publication.",
                path: file.relativePath,
                remediation: "Keep only intentional assets and move large generated artifacts to releases."
            )
        }

        return nil
    }
}
