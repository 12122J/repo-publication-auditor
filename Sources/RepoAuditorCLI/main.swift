import AuditCore
import Foundation

struct CLIOptions {
    var path: String = "."
    var outputPath: String?
    var scanHistory = true
    var failOn: Severity?
}

func printUsage() {
    print("""
    Usage:
      repo-auditor [path] [--output OPEN_SOURCE_AUDIT.md] [--no-history] [--fail-on high|medium|low]

    Examples:
      repo-auditor .
      repo-auditor ~/Projects/private-repo --output OPEN_SOURCE_AUDIT.md
      repo-auditor . --no-history
    """)
}

func parseOptions(_ arguments: [String]) throws -> CLIOptions {
    var options = CLIOptions()
    var index = 0

    while index < arguments.count {
        let argument = arguments[index]

        switch argument {
        case "--help", "-h":
            printUsage()
            Foundation.exit(0)
        case "--output", "-o":
            guard index + 1 < arguments.count else {
                throw CLIError.message("Missing value for \(argument)")
            }
            options.outputPath = arguments[index + 1]
            index += 1
        case "--no-history":
            options.scanHistory = false
        case "--fail-on":
            guard index + 1 < arguments.count else {
                throw CLIError.message("Missing value for \(argument)")
            }
            guard let severity = Severity(rawValue: arguments[index + 1].lowercased()) else {
                throw CLIError.message("Unsupported severity: \(arguments[index + 1])")
            }
            options.failOn = severity
            index += 1
        default:
            if argument.hasPrefix("-") {
                throw CLIError.message("Unknown option: \(argument)")
            }
            options.path = argument
        }

        index += 1
    }

    return options
}

enum CLIError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case .message(let message): message
        }
    }
}

do {
    let options = try parseOptions(Array(CommandLine.arguments.dropFirst()))
    let rootURL = URL(fileURLWithPath: NSString(string: options.path).expandingTildeInPath)
    var isDirectory: ObjCBool = false

    guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        throw CLIError.message("Path is not a directory: \(rootURL.path)")
    }

    let report = RepositoryAuditor().audit(
        rootURL: rootURL,
        configuration: AuditConfiguration(scanGitHistory: options.scanHistory)
    )
    let markdown = MarkdownReportRenderer().render(report)

    if let outputPath = options.outputPath {
        let outputURL = URL(fileURLWithPath: NSString(string: outputPath).expandingTildeInPath)
        try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
        print("Wrote \(outputURL.path)")
    } else {
        print(markdown)
    }

    if let threshold = options.failOn,
       report.findings.contains(where: { $0.severity.rank <= threshold.rank }) {
        Foundation.exit(1)
    }
} catch {
    fputs("repo-auditor: \(error)\n", stderr)
    printUsage()
    Foundation.exit(2)
}
