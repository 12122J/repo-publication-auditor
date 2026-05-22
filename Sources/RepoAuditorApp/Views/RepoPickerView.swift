import SwiftUI

struct RepoPickerView: View {
    @EnvironmentObject var appVM: AppViewModel
    @EnvironmentObject var github: GitHubService
    @State private var search = ""
    @State private var cloningID: Int?
    @State private var cloneError: String?

    private var filtered: [GitHubRepo] {
        guard !search.isEmpty else { return github.repos }
        return github.repos.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            ($0.description ?? "").localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            Divider()

            if let err = cloneError {
                HStack(spacing: 8) {
                    Text(err).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss") { cloneError = nil }
                        .font(.caption).buttonStyle(.plain).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.red.opacity(0.07))
                Divider()
            }

            if github.isLoading && github.repos.isEmpty {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Loading repositories…").font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filtered.isEmpty {
                ContentUnavailableView(
                    "No Results", systemImage: "tray",
                    description: Text(search.isEmpty ? "No repositories found." : "No match for \"\(search)\"")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, repo in
                            RepoRow(repo: repo, isCloning: cloningID == repo.id) { startClone(repo) }
                            if i < filtered.count - 1 { Divider().padding(.leading, 14) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { appVM.phase = .welcome } label: {
                    Label("Back", systemImage: "chevron.left").labelStyle(.iconOnly)
                }
            }
            ToolbarItem(placement: .navigation) {
                if let user = github.user {
                    Text(user.login).font(.callout.weight(.medium)).foregroundStyle(.secondary)
                }
            }
            ToolbarItemGroup {
                if github.isLoading { ProgressView().scaleEffect(0.7).frame(width: 16) }
                Button {
                    github.signOut(); appVM.phase = .welcome
                } label: { Text("Sign out").font(.callout) }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.callout).foregroundStyle(.tertiary)
            TextField("Filter \(github.repos.count) repositories…", text: $search)
                .textFieldStyle(.plain).font(.callout)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(.regularMaterial)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func startClone(_ repo: GitHubRepo) {
        cloningID = repo.id; cloneError = nil
        Task {
            do {
                let url = try await RepoCloner().clone(repo: repo, token: github.token)
                cloningID = nil
                appVM.startAudit(url: url, repoName: repo.fullName)
            } catch {
                cloningID = nil
                cloneError = error.localizedDescription
            }
        }
    }
}

// MARK: - RepoRow

private struct RepoRow: View {
    let repo: GitHubRepo
    let isCloning: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                // Language color stripe
                languageColor(repo.language)
                    .frame(width: 3)
                    .opacity(isHovered ? 1 : 0.4)
                    .animation(.easeInOut(duration: 0.12), value: isHovered)

                VStack(alignment: .leading, spacing: 0) {
                    // Main info row
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(repo.name).font(.callout.weight(.medium))
                                if repo.isPrivate {
                                    Text("private")
                                        .font(.caption2)
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(Color.primary.opacity(0.08))
                                        .foregroundStyle(.secondary)
                                        .clipShape(Capsule())
                                }
                            }
                            if let desc = repo.description {
                                Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        Spacer()
                        if isCloning {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.65)
                                Text("Cloning…").font(.caption).foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Audit")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.accentColor)
                                .opacity(isHovered ? 1 : 0)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)

                    // Hover detail strip
                    if isHovered {
                        Divider().padding(.leading, 14).opacity(0.5)
                        HStack(spacing: 16) {
                            if let lang = repo.language {
                                HStack(spacing: 4) {
                                    Circle().fill(languageColor(lang)).frame(width: 8, height: 8)
                                    Text(lang).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            if repo.stargazersCount > 0 {
                                Text("★ \(repo.stargazersCount)").font(.caption2).foregroundStyle(.tertiary)
                            }
                            Text(relativeDate(repo.updatedAt))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Spacer()
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
        .onHover { v in withAnimation(.easeInOut(duration: 0.12)) { isHovered = v } }
        .disabled(isCloning)
    }

    private func relativeDate(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        guard let date = fmt.date(from: iso) else { return "" }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .abbreviated
        return "Updated " + rel.localizedString(for: date, relativeTo: Date())
    }

    private func languageColor(_ lang: String?) -> Color {
        switch (lang ?? "").lowercased() {
        case "swift":       return Color(red: 0.99, green: 0.44, blue: 0.21)
        case "typescript":  return Color(red: 0.20, green: 0.47, blue: 0.73)
        case "javascript":  return Color(red: 0.97, green: 0.82, blue: 0.17)
        case "python":      return Color(red: 0.24, green: 0.48, blue: 0.69)
        case "go":          return Color(red: 0.00, green: 0.68, blue: 0.81)
        case "rust":        return Color(red: 0.85, green: 0.37, blue: 0.19)
        case "ruby":        return Color(red: 0.70, green: 0.12, blue: 0.13)
        case "kotlin":      return Color(red: 0.50, green: 0.31, blue: 0.89)
        case "java":        return Color(red: 0.72, green: 0.28, blue: 0.20)
        case "c#":          return Color(red: 0.36, green: 0.18, blue: 0.71)
        case "c++":         return Color(red: 0.37, green: 0.59, blue: 0.84)
        default:            return Color.primary.opacity(0.3)
        }
    }
}
