# Repo Publication Auditor

Audit private repositories before making them public.

Repo Publication Auditor is a local-first Swift tool with a CLI and a small macOS app. It checks for common reasons a private repository should not be made public yet: secrets, risky files, git history exposure, deployment infrastructure, missing licenses, and unfinished project metadata.

Secret values are never printed in reports.

## Usage

```bash
swift run repo-auditor /path/to/repo --output OPEN_SOURCE_AUDIT.md
```

Run without writing a file:

```bash
swift run repo-auditor .
```

Skip git history scanning:

```bash
swift run repo-auditor . --no-history
```

Fail CI when findings meet a threshold:

```bash
swift run repo-auditor . --fail-on high
```

## macOS App

```bash
./script/build_and_run.sh
```

The app lets you choose a repository folder, run the same local audit engine, review findings, and export a Markdown report.

## Checks

- Secret-like patterns in current files
- Secret-like patterns in git history
- Risky files such as `.env`, keys, certificates, database files, and personal documents
- Infrastructure files such as deploy scripts, systemd units, nginx configs, Docker Compose files, and deployment workflows
- Public IPs, private server paths, and deployment target references
- Missing README and license
- `package.json` metadata issues

## Prior Art

This project is inspired by dedicated secret scanners and open source health tools such as Gitleaks, TruffleHog, Yelp detect-secrets, git-secrets, and OpenSSF Scorecard. The focus here is narrower and more personal: deciding whether an old private repository is safe and ready to make public.
