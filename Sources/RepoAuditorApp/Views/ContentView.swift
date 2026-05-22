import AuditCore
import SwiftUI

struct ContentView: View {
    let url: URL
    let repoName: String?
    @EnvironmentObject var appVM: AppViewModel
    @StateObject private var model = AuditViewModel()
    @State private var selectedFinding: Finding.ID?
    @State private var selectedCategory: FindingCategory?

    private var displayName: String { repoName ?? url.lastPathComponent }

    private var visibleFindings: [Finding] {
        guard let cat = selectedCategory else { return model.findings }
        return model.findings.filter { $0.category == cat }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailArea
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { appVM.phase = .welcome } label: {
                    Label("Home", systemImage: "chevron.left").labelStyle(.iconOnly)
                }
            }
            ToolbarItemGroup {
                if model.isRunning { ProgressView().scaleEffect(0.7).frame(width: 16) }
                Button { model.runAudit(url: url) } label: {
                    Label("Re-run", systemImage: "arrow.clockwise")
                }
                .disabled(model.isRunning)
                Button { model.exportMarkdown() } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(model.report == nil)
            }
        }
        .onAppear { model.runAudit(url: url) }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedFinding) {
            // Repo info
            Section {
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(url.path)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
                .padding(.vertical, 2)
            } header: {
                sectionHeader("Repository")
            }

            if let report = model.report {
                // Severity summary
                Section {
                    ForEach(Severity.allCases, id: \.self) { sev in
                        let count = report.count(for: sev)
                        SeveritySidebarRow(severity: sev, count: count)
                    }
                } header: {
                    sectionHeader("Summary")
                }

                // Category filters
                Section {
                    categoryFilterRow(nil, label: "All findings", count: model.findings.count)
                    ForEach(FindingCategory.allCases, id: \.self) { cat in
                        let count = model.findings.filter { $0.category == cat }.count
                        if count > 0 {
                            categoryFilterRow(cat, label: cat.rawValue, count: count)
                        }
                    }
                } header: {
                    sectionHeader("Categories")
                }

                // Findings list
                if !visibleFindings.isEmpty {
                    Section {
                        ForEach(visibleFindings) { finding in
                            SidebarFindingRow(finding: finding)
                                .tag(finding.id)
                        }
                    } header: {
                        sectionHeader("Findings (\(visibleFindings.count))")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(displayName)
        .navigationSubtitle(model.isRunning ? "Scanning…" : "\(model.findings.count) findings")
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption2.uppercaseSmallCaps())
            .foregroundStyle(.tertiary)
    }

    private func categoryFilterRow(_ cat: FindingCategory?, label: String, count: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                selectedCategory = cat
                selectedFinding = nil
            }
        } label: {
            HStack {
                Text(label)
                    .font(.callout)
                    .foregroundStyle(selectedCategory == cat ? Color.accentColor : .primary)
                Spacer()
                Text("\(count)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(selectedCategory == cat ? Color.accentColor.opacity(0.7) : Color.secondary.opacity(0.5))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailArea: some View {
        if model.isRunning {
            VStack(spacing: 12) {
                ProgressView()
                Text("Scanning…").font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let msg = model.errorMessage {
            ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(msg))
        } else if let report = model.report {
            if let finding = selectedFinding.flatMap({ id in model.findings.first { $0.id == id } }) {
                findingDetail(finding)
            } else {
                findingsList(report)
            }
        } else {
            ContentUnavailableView("No results", systemImage: "checklist")
        }
    }

    // MARK: - Findings list

    private func findingsList(_ report: AuditReport) -> some View {
        VStack(spacing: 0) {
            // Interactive severity bar — clicking filters
            HStack(spacing: 0) {
                ForEach(Severity.allCases, id: \.self) { sev in
                    SeverityStatTile(
                        severity: sev,
                        count: report.count(for: sev),
                        isSelected: selectedCategory == nil // we use category filter, not severity directly
                    ) {
                        // Filter to findings of this severity
                        withAnimation(.easeInOut(duration: 0.12)) {
                            selectedFinding = nil
                            // Show first finding of that severity
                            if let first = model.findings.first(where: { $0.severity == sev }) {
                                selectedFinding = first.id
                            }
                        }
                    }
                    if sev != .info { Divider().frame(height: 20) }
                }
            }
            .frame(height: 48)
            .background(.regularMaterial)
            Divider()

            if visibleFindings.isEmpty {
                ContentUnavailableView(
                    "No findings",
                    systemImage: "checkmark.seal",
                    description: Text(selectedCategory == nil ? "This repository looks clean." : "Nothing in this category.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(visibleFindings.enumerated()), id: \.element.id) { i, finding in
                            FindingRow(finding: finding) { selectedFinding = finding.id }
                            if i < visibleFindings.count - 1 {
                                Divider().padding(.leading, 34)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Finding detail

    private func findingDetail(_ finding: Finding) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Nav
                HStack {
                    Button { selectedFinding = nil } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.callout).foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(finding.category.rawValue).font(.caption).foregroundStyle(.tertiary)
                }
                .padding(16)
                Divider()

                VStack(alignment: .leading, spacing: 20) {
                    // Severity + title
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 5) {
                            Circle().fill(severityColor(finding.severity)).frame(width: 6, height: 6)
                            Text(finding.severity.displayName.uppercased())
                                .font(.system(.caption2).weight(.semibold))
                                .foregroundStyle(severityColor(finding.severity))
                                .tracking(0.6)
                        }
                        Text(finding.title).font(.title3.weight(.semibold))
                    }

                    // Location
                    if let path = finding.path {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Location").font(.caption2.uppercaseSmallCaps()).foregroundStyle(.tertiary)
                            Text(finding.line != nil ? "\(path):\(finding.line!)" : path)
                                .font(.system(.callout, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.regularMaterial)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    // Detail
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Details").font(.caption2.uppercaseSmallCaps()).foregroundStyle(.tertiary)
                        Text(finding.detail).font(.callout).fixedSize(horizontal: false, vertical: true)
                    }

                    // Remediation
                    if let fix = finding.remediation {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Remediation").font(.caption2.uppercaseSmallCaps()).foregroundStyle(.tertiary)
                            Text(fix)
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.regularMaterial)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    // MARK: - Helpers

    func severityColor(_ severity: Severity) -> Color {
        switch severity {
        case .high:   Color(nsColor: .systemRed)
        case .medium: Color(nsColor: .systemOrange)
        case .low:    Color(nsColor: .systemBlue)
        case .info:   Color(nsColor: .systemGreen)
        }
    }
}

// MARK: - Severity stat tile (clickable)

private struct SeverityStatTile: View {
    let severity: Severity
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(count > 0 ? severityColor : Color.primary.opacity(0.15))
                        .frame(width: 6, height: 6)
                    Text("\(count)")
                        .font(.system(.callout, design: .monospaced).weight(.semibold))
                        .foregroundStyle(count > 0 ? .primary : .tertiary)
                }
                Text(severity.displayName)
                    .font(.caption2)
                    .foregroundStyle(count > 0 ? .secondary : .tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isHovered && count > 0 ? Color.primary.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { v in withAnimation(.easeInOut(duration: 0.08)) { isHovered = v } }
        .disabled(count == 0)
        .help(count > 0 ? "Jump to first \(severity.displayName.lowercased()) finding" : "No \(severity.displayName.lowercased()) findings")
    }

    private var severityColor: Color {
        switch severity {
        case .high:   Color(nsColor: .systemRed)
        case .medium: Color(nsColor: .systemOrange)
        case .low:    Color(nsColor: .systemBlue)
        case .info:   Color(nsColor: .systemGreen)
        }
    }
}

// MARK: - Sidebar finding row

private struct SidebarFindingRow: View {
    let finding: Finding
    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(severityColor(finding.severity))
                .frame(width: 5, height: 5)
            Text(finding.title)
                .font(.callout)
                .lineLimit(1)
        }
    }

    private func severityColor(_ s: Severity) -> Color {
        switch s {
        case .high:   Color(nsColor: .systemRed)
        case .medium: Color(nsColor: .systemOrange)
        case .low:    Color(nsColor: .systemBlue)
        case .info:   Color(nsColor: .systemGreen)
        }
    }
}

// MARK: - Severity sidebar row

private struct SeveritySidebarRow: View {
    let severity: Severity
    let count: Int
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(count > 0 ? severityColor : Color.primary.opacity(0.15))
                .frame(width: 6, height: 6)
            Text(severity.displayName)
                .font(.callout)
                .foregroundStyle(count > 0 ? .primary : .secondary)
            Spacer()
            Text("\(count)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(count > 0 ? .primary : .tertiary)
        }
        .help(count > 0 ? "\(count) \(severity.displayName.lowercased()) finding\(count == 1 ? "" : "s")" : "No \(severity.displayName.lowercased()) findings")
    }

    private var severityColor: Color {
        switch severity {
        case .high:   Color(nsColor: .systemRed)
        case .medium: Color(nsColor: .systemOrange)
        case .low:    Color(nsColor: .systemBlue)
        case .info:   Color(nsColor: .systemGreen)
        }
    }
}

// MARK: - Finding row

private struct FindingRow: View {
    let finding: Finding
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 0) {
                // Severity stripe
                severityColor(finding.severity)
                    .frame(width: 2)
                    .opacity(isHovered ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.1), value: isHovered)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(finding.title).font(.callout.weight(.medium))
                            if let path = finding.path {
                                Text(finding.line != nil ? "\(path):\(finding.line!)" : path)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            Text(finding.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(isHovered ? 6 : 2)
                                .animation(.easeInOut(duration: 0.15), value: isHovered)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .opacity(isHovered ? 1 : 0)
                            .animation(.easeInOut(duration: 0.1), value: isHovered)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)

                    // Hover: remediation hint
                    if isHovered, let fix = finding.remediation {
                        Divider().padding(.leading, 14).opacity(0.5)
                        HStack(spacing: 5) {
                            Text("Fix:")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                            Text(fix)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
            }
            .background(isHovered ? Color.primary.opacity(0.04) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { v in withAnimation(.easeInOut(duration: 0.13)) { isHovered = v } }
    }

    private func severityColor(_ s: Severity) -> Color {
        switch s {
        case .high:   Color(nsColor: .systemRed)
        case .medium: Color(nsColor: .systemOrange)
        case .low:    Color(nsColor: .systemBlue)
        case .info:   Color(nsColor: .systemGreen)
        }
    }
}
