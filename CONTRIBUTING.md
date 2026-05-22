# Contributing to Repo Auditor

Contributions are very welcome — whether it's a new scanner, a UI tweak, a bug fix, or just improving documentation. This project is small enough that a first-time contributor can have a real impact.

## Getting started

```bash
git clone https://github.com/12122J/repo-publication-auditor.git
cd repo-publication-auditor
swift build
```

Open in Xcode if you want to work on the macOS app:

```bash
open Package.swift
```

Run tests:

```bash
swift test
```

## Project layout

```
Sources/
  AuditCore/          — shared scan engine (CLI + app use this)
    RepositoryAuditor.swift
    Models.swift
    MarkdownReportRenderer.swift
    *Scanner.swift    — one file per scanner
  RepoAuditorApp/     — macOS SwiftUI app
  RepoAuditorCLI/     — CLI entry point
Tests/
  AuditCoreTests/
```

## Adding a new scanner

A scanner is a struct with a single `scan(...)` method that returns `[Finding]`. The simplest form:

```swift
// Sources/AuditCore/MyScanner.swift

import Foundation

struct MyScanner {
    func scan(rootURL: URL, files: [URL]) -> [Finding] {
        var findings: [Finding] = []
        // inspect files and append findings
        return findings
    }
}
```

Then register it in `RepositoryAuditor.swift`:

```swift
findings.append(contentsOf: MyScanner().scan(rootURL: rootURL, files: files))
```

A `Finding` needs at minimum a `title`, `detail`, `severity`, and `category`. Optional fields (`path`, `line`, `remediation`) make findings much more useful.

### Severity guide

| Severity | Use when |
|---|---|
| `.high` | Must fix before making public. Secrets, exposed credentials, active infrastructure references. |
| `.medium` | Should fix. Information that reveals private details or creates reputation risk. |
| `.low` | Worth considering. Personal data, missing best-practice files. |
| `.info` | Nice to have. Improvements that make the repo more welcoming. |

### Finding categories

`Secrets`, `Infrastructure`, `RiskyFiles`, `GitHygiene`, `CICD`, `OSSReadiness`. Add a new case to `FindingCategory` in `Models.swift` if none of these fit.

## What makes a good scanner

- **Be specific in `detail`** — tell the user exactly what was found and why it matters, not just "secret detected".
- **Never print secret values** — log paths and line numbers, mask or omit values.
- **Add `remediation`** — even a one-sentence fix makes the tool far more useful.
- **Handle missing state gracefully** — if `git` is not available or the directory is empty, return an empty array, don't throw.

## UI contributions (macOS app)

The app targets macOS 14+. SwiftUI only, no AppKit views. If you add a new finding category, make sure the sidebar filter and severity bar handle it.

## Pull requests

- Open an issue first for anything larger than a bug fix — a quick discussion saves time.
- PRs don't need to be perfect. If it's useful and doesn't break existing tests, it can land and be improved.
- Keep commits focused; a clear commit message beats squashing everything.

## Reporting bugs

Open a GitHub issue. Include: macOS version, what you scanned, the command you ran or what you clicked, and what you expected vs what happened.

---

Thanks for taking the time to contribute.
