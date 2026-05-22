import Foundation

public struct AuditedFile: Hashable {
    public let url: URL
    public let relativePath: String
    public let size: Int

    public init(url: URL, relativePath: String, size: Int) {
        self.url = url
        self.relativePath = relativePath
        self.size = size
    }
}

public enum FileWalker {
    static let skippedDirectoryNames: Set<String> = [
        ".git",
        ".build",
        ".next",
        ".venv",
        "DerivedData",
        "__pycache__",
        "build",
        "dist",
        "node_modules",
        "vendor"
    ]

    public static func files(in rootURL: URL, maxTextFileBytes: Int) -> [AuditedFile] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        var results: [AuditedFile] = []

        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent

            if let values = try? fileURL.resourceValues(forKeys: Set(keys)),
               values.isDirectory == true {
                if skippedDirectoryNames.contains(name) {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else {
                continue
            }

            let size = values.fileSize ?? 0
            if size > maxTextFileBytes {
                let relativePath = PathUtilities.relativePath(for: fileURL, rootURL: rootURL)
                results.append(AuditedFile(url: fileURL, relativePath: relativePath, size: size))
                continue
            }

            let relativePath = PathUtilities.relativePath(for: fileURL, rootURL: rootURL)
            results.append(AuditedFile(url: fileURL, relativePath: relativePath, size: size))
        }

        return results
    }
}
