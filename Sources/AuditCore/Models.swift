import Foundation

public enum Severity: String, CaseIterable, Codable, Hashable, Comparable {
    case high
    case medium
    case low
    case info

    public var rank: Int {
        switch self {
        case .high: 0
        case .medium: 1
        case .low: 2
        case .info: 3
        }
    }

    public var displayName: String {
        rawValue.capitalized
    }

    public static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.rank < rhs.rank
    }
}

public enum FindingCategory: String, CaseIterable, Codable, Hashable {
    case secrets = "Secrets"
    case gitHistory = "Git History"
    case riskyFiles = "Risky Files"
    case infrastructure = "Infrastructure"
    case readiness = "Open Source Readiness"
    case metadata = "Metadata"
    case gitHygiene = "Git Hygiene"
    case cicd = "CI / CD"
}

public struct Finding: Identifiable, Codable, Hashable {
    public let id: UUID
    public let severity: Severity
    public let category: FindingCategory
    public let title: String
    public let detail: String
    public let path: String?
    public let line: Int?
    public let remediation: String?

    public init(
        id: UUID = UUID(),
        severity: Severity,
        category: FindingCategory,
        title: String,
        detail: String,
        path: String? = nil,
        line: Int? = nil,
        remediation: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.category = category
        self.title = title
        self.detail = detail
        self.path = path
        self.line = line
        self.remediation = remediation
    }
}

public struct AuditConfiguration: Codable, Hashable {
    public var scanGitHistory: Bool
    public var maxTextFileBytes: Int
    public var maxHistoryFindings: Int

    public init(
        scanGitHistory: Bool = true,
        maxTextFileBytes: Int = 1_000_000,
        maxHistoryFindings: Int = 100
    ) {
        self.scanGitHistory = scanGitHistory
        self.maxTextFileBytes = maxTextFileBytes
        self.maxHistoryFindings = maxHistoryFindings
    }
}

public struct AuditReport: Codable, Hashable {
    public let rootPath: String
    public let generatedAt: Date
    public let scannedFileCount: Int
    public let findings: [Finding]

    public init(rootPath: String, generatedAt: Date = Date(), scannedFileCount: Int, findings: [Finding]) {
        self.rootPath = rootPath
        self.generatedAt = generatedAt
        self.scannedFileCount = scannedFileCount
        self.findings = findings.sorted { lhs, rhs in
            if lhs.severity != rhs.severity {
                return lhs.severity < rhs.severity
            }
            if lhs.category != rhs.category {
                return lhs.category.rawValue < rhs.category.rawValue
            }
            return lhs.title < rhs.title
        }
    }

    public func count(for severity: Severity) -> Int {
        findings.filter { $0.severity == severity }.count
    }

    public var highestSeverity: Severity? {
        findings.map(\.severity).min()
    }
}
