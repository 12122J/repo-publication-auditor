import SwiftUI

private let localChecks  = ["Secrets & tokens", "Git history", "Large files", "Infra exposure", "CI / CD setup", "Risky files"]
private let githubChecks = ["Browse all repos", "Clone & scan privately", "Private repo support", "Auth via gh CLI or OAuth"]

struct WelcomeView: View {
    @EnvironmentObject var appVM: AppViewModel
    @EnvironmentObject var github: GitHubService

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

            VStack(spacing: 0) {
                Color.clear.frame(height: 28) // toolbar clearance
                Spacer(minLength: 0)

                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 5) {
                        Text("Repo Auditor")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Audit before you make a repository public")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    // Tiles
                    HStack(alignment: .top, spacing: 10) {
                        OptionTile(
                            title: "Local Repository",
                            subtitle: "Choose a folder on your Mac",
                            checks: localChecks,
                            action: { appVM.chooseLocalFolder() }
                        )
                        OptionTile(
                            title: "GitHub",
                            subtitle: github.user.map { "Signed in as \($0.login)" } ?? "Sign in to browse repos",
                            checks: githubChecks,
                            action: {
                                if github.user != nil {
                                    Task { await github.fetchRepos() }
                                    appVM.phase = .repoPicker
                                } else {
                                    appVM.phase = .githubAuth
                                }
                            }
                        )
                    }
                    .frame(maxWidth: 500)

                    // Keyboard hint
                    HStack(spacing: 16) {
                        ShortcutHint(key: "⌘O", label: "Local folder")
                        ShortcutHint(key: "⌘G", label: "GitHub")
                    }
                    .opacity(0.45)
                }
                .padding(.horizontal, 40)

                Spacer(minLength: 0)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text("Repo Auditor")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .background {
            // Hidden buttons to capture keyboard shortcuts
            Group {
                Button("") { appVM.chooseLocalFolder() }
                    .keyboardShortcut("o", modifiers: .command).opacity(0)
                Button("") {
                    if github.user != nil { Task { await github.fetchRepos() }; appVM.phase = .repoPicker }
                    else { appVM.phase = .githubAuth }
                }
                .keyboardShortcut("g", modifiers: .command).opacity(0)
            }
        }
    }
}

// MARK: - Tile

private struct OptionTile: View {
    let title: String
    let subtitle: String
    let checks: [String]
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Main row
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.callout.weight(.semibold))
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .opacity(isHovered ? 1 : 0)
                        .offset(x: isHovered ? 0 : -4)
                }
                .padding(16)

                // Hover expansion — what will be scanned
                if isHovered {
                    Divider().opacity(0.5)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                        ForEach(checks, id: \.self) { check in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.primary.opacity(0.25))
                                    .frame(width: 4, height: 4)
                                Text(check)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.2 : 0.12),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { v in withAnimation(.easeInOut(duration: 0.16)) { isHovered = v } }
    }
}

// MARK: - Shortcut hint

private struct ShortcutHint: View {
    let key: String
    let label: String
    var body: some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(.caption2, design: .monospaced).weight(.medium))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Color.primary.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(label).font(.caption2)
        }
    }
}
