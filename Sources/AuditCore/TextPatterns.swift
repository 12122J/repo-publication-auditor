import Foundation

struct TextPattern {
    let name: String
    let severity: Severity
    let category: FindingCategory
    let title: String
    let detail: String
    let remediation: String
    let regex: NSRegularExpression

    init(
        name: String,
        severity: Severity,
        category: FindingCategory,
        title: String,
        detail: String,
        remediation: String,
        pattern: String,
        options: NSRegularExpression.Options = []
    ) {
        self.name = name
        self.severity = severity
        self.category = category
        self.title = title
        self.detail = detail
        self.remediation = remediation
        self.regex = try! NSRegularExpression(pattern: pattern, options: options)
    }
}

enum PatternLibrary {
    static let secretPatterns: [TextPattern] = [
        TextPattern(
            name: "Private key",
            severity: .high,
            category: .secrets,
            title: "Private key material",
            detail: "A private key block appears in source. Publishing this can compromise systems that trust the key.",
            remediation: "Remove the key, rotate any dependent credential, and publish from clean history.",
            pattern: "-----BEGIN [A-Z ]*PRIVATE KEY-----"
        ),
        TextPattern(
            name: "GitHub token",
            severity: .high,
            category: .secrets,
            title: "GitHub token",
            detail: "A GitHub token pattern appears in source.",
            remediation: "Revoke the token and publish from clean history.",
            pattern: "(gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})"
        ),
        TextPattern(
            name: "OpenAI key",
            severity: .high,
            category: .secrets,
            title: "OpenAI-style API key",
            detail: "An OpenAI-style API key pattern appears in source.",
            remediation: "Revoke the key and publish from clean history.",
            pattern: "\\bsk-[A-Za-z0-9_-]{20,}\\b"
        ),
        TextPattern(
            name: "AWS access key",
            severity: .high,
            category: .secrets,
            title: "AWS access key",
            detail: "An AWS access key id pattern appears in source.",
            remediation: "Rotate the AWS credential and check cloud audit logs before publishing.",
            pattern: "\\bAKIA[0-9A-Z]{16}\\b"
        ),
        TextPattern(
            name: "Slack token",
            severity: .high,
            category: .secrets,
            title: "Slack token",
            detail: "A Slack token pattern appears in source.",
            remediation: "Revoke the token and publish from clean history.",
            pattern: "\\bxox[baprs]-[A-Za-z0-9-]{20,}\\b"
        ),
        TextPattern(
            name: "Database URL with credentials",
            severity: .high,
            category: .secrets,
            title: "Database connection string with credentials",
            detail: "A database URL with an embedded username and password appears in source.",
            remediation: "Rotate the database credential and move configuration into an ignored environment file.",
            pattern: "\\b(?:postgres(?:ql)?|mysql|mongodb(?:\\+srv)?|redis)://[^\\s:@]+:[^\\s@]+@[^\\s]+",
            options: [.caseInsensitive]
        ),
        TextPattern(
            name: "Credential assignment",
            severity: .low,
            category: .secrets,
            title: "Credential-like assignment",
            detail: "A variable or configuration key looks like it may contain a credential.",
            remediation: "Confirm this is not a real secret. If it is real, rotate it and move it to ignored configuration.",
            pattern: "\\b(?:api[_-]?key|secret|token|password|passwd|client[_-]?secret|jwt[_-]?secret|session[_-]?secret|auth[_-]?secret|database_url)\\b\\s*[:=]\\s*[\"'][^\"']{8,}[\"']",
            options: [.caseInsensitive]
        )
    ]

    static let infrastructurePatterns: [TextPattern] = [
        TextPattern(
            name: "Root SSH target",
            severity: .high,
            category: .infrastructure,
            title: "Root SSH deployment target",
            detail: "A root SSH deployment target appears in source.",
            remediation: "Remove private deployment targets from public history or replace with placeholders.",
            pattern: "\\broot@(?:\\d{1,3}\\.){3}\\d{1,3}\\b"
        ),
        TextPattern(
            name: "Server path",
            severity: .medium,
            category: .infrastructure,
            title: "Private server path",
            detail: "A deployment or server filesystem path appears in source.",
            remediation: "Replace private server paths with generic examples before publishing.",
            pattern: "(?:/opt/apps|/etc/nginx|/etc/systemd|/var/www)" // repo-auditor: allow-infra
        ),
        TextPattern(
            name: "GitHub Actions secret reference",
            severity: .low,
            category: .infrastructure,
            title: "Deployment secret reference",
            detail: "A workflow references deployment secrets. The values are not exposed, but the deployment model may be private context.",
            remediation: "Keep only generic CI examples in public repos unless the deployment workflow is intentionally public.",
            pattern: "\\$\\{\\{\\s*secrets\\.[A-Z0-9_]+\\s*\\}\\}"
        )
    ]
}
