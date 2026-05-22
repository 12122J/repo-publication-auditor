import Foundation

enum PathUtilities {
    static func relativePath(for fileURL: URL, rootURL: URL) -> String {
        let rootPath = rootURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path

        if filePath == rootPath {
            return "."
        }

        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        if filePath.hasPrefix(prefix) {
            return String(filePath.dropFirst(prefix.count))
        }

        return fileURL.lastPathComponent
    }

    static func isLikelyText(_ data: Data) -> Bool {
        if data.isEmpty {
            return true
        }

        let sample = data.prefix(min(data.count, 4096))
        if sample.contains(0) {
            return false
        }

        return String(data: sample, encoding: .utf8) != nil
    }
}
