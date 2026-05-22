import Foundation

struct RepoCloner {
    enum ClonerError: LocalizedError {
        case cloneFailed(String)
        var errorDescription: String? {
            if case .cloneFailed(let msg) = self { return msg }
            return nil
        }
    }

    func clone(repo: GitHubRepo, token: String) async throws -> URL {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("repoauditor-\(repo.id)")
        try? FileManager.default.removeItem(at: dest)

        guard var comps = URLComponents(string: repo.cloneUrl) else {
            throw ClonerError.cloneFailed("Bad clone URL")
        }
        comps.user = "x-access-token"
        comps.password = token
        guard let authURL = comps.url else {
            throw ClonerError.cloneFailed("Could not build authenticated URL")
        }

        return try await withCheckedThrowingContinuation { cont in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            p.arguments = ["git", "clone", "--depth=1", authURL.absoluteString, dest.path]
            let errPipe = Pipe()
            p.standardOutput = Pipe()
            p.standardError = errPipe
            p.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    cont.resume(returning: dest)
                } else {
                    let msg = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Clone failed"
                    cont.resume(throwing: ClonerError.cloneFailed(msg.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }
            do { try p.run() } catch {
                cont.resume(throwing: ClonerError.cloneFailed("git not found"))
            }
        }
    }
}
