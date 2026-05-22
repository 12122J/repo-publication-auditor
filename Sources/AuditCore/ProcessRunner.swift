import Foundation

struct ProcessOutput {
    let stdout: String
    let stderr: String
    let status: Int32
}

enum ProcessRunner {
    static func run(_ command: String, arguments: [String], workingDirectory: URL) -> ProcessOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        process.currentDirectoryURL = workingDirectory

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ProcessOutput(stdout: "", stderr: error.localizedDescription, status: 127)
        }

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ProcessOutput(stdout: stdout, stderr: stderr, status: process.terminationStatus)
    }
}
