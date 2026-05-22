import Foundation

public struct LargeFileScanner {
    private static let warnThresholdBytes = 5 * 1024 * 1024   // 5 MB
    private static let errorThresholdBytes = 20 * 1024 * 1024 // 20 MB

    private static let binaryExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "ico", "tiff", "bmp", "heic",
        "mp4", "mov", "avi", "mkv", "mp3", "wav", "aac", "flac",
        "zip", "tar", "gz", "bz2", "xz", "7z", "rar",
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "dmg", "pkg", "exe", "dll", "so", "dylib", "a",
        "jar", "war", "class", "pyc",
        "xcarchive", "ipa", "apk",
        "db", "sqlite", "sqlite3"
    ]

    public init() {}

    public func scan(files: [AuditedFile]) -> [Finding] {
        var findings: [Finding] = []

        for file in files {
            guard file.size >= Self.warnThresholdBytes else { continue }
            let ext = file.url.pathExtension.lowercased()
            let isBinary = Self.binaryExtensions.contains(ext)
            let sizeStr = formatBytes(file.size)

            if file.size >= Self.errorThresholdBytes {
                findings.append(Finding(
                    severity: .high,
                    category: .riskyFiles,
                    title: "Very large file: \(file.url.lastPathComponent) (\(sizeStr))",
                    detail: "This \(isBinary ? "binary" : "file") is \(sizeStr) and will bloat the public repository. GitHub warns at 50 MB and blocks at 100 MB.",
                    path: file.relativePath,
                    remediation: "Remove from git history with git filter-repo, or use Git LFS for large assets."
                ))
            } else {
                findings.append(Finding(
                    severity: .medium,
                    category: .riskyFiles,
                    title: "Large \(isBinary ? "binary" : "file"): \(file.url.lastPathComponent) (\(sizeStr))",
                    detail: "Large \(isBinary ? "binary files" : "files") increase clone time and repository size for all future contributors.",
                    path: file.relativePath,
                    remediation: isBinary
                        ? "Consider Git LFS or hosting this asset externally and referencing it by URL."
                        : "Review whether this file should be committed or listed in .gitignore."
                ))
            }
        }

        return findings
    }

    private func formatBytes(_ bytes: Int) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        return mb >= 1 ? String(format: "%.1f MB", mb) : "\(bytes / 1024) KB"
    }
}
