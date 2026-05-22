import SwiftUI

struct GitHubAuthView: View {
    @EnvironmentObject var appVM: AppViewModel
    @EnvironmentObject var github: GitHubService

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 28) // traffic light clearance

            Spacer()

            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Connect GitHub")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Sign in to browse and audit your repositories")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 14) {
                    if github.isPolling, let code = github.deviceCode {
                        // Waiting state
                        VStack(spacing: 14) {
                            HStack(spacing: 10) {
                                ProgressView().scaleEffect(0.75)
                                Text("Waiting for authorization in browser…")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(spacing: 4) {
                                Text("Your code").font(.caption).foregroundStyle(.tertiary)
                                Text(code.userCode)
                                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                                    .tracking(4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                            Button {
                                if let url = URL(string: code.verificationUriComplete) {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                Label("Open GitHub in browser", systemImage: "arrow.up.right.square")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)

                            Button {
                                github.cancelDeviceFlow()
                            } label: {
                                Text("Cancel")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        // Initial state
                        Button {
                            Task { await github.startDeviceFlow() }
                        } label: {
                            HStack(spacing: 8) {
                                if github.isLoading {
                                    ProgressView().scaleEffect(0.7).frame(width: 14, height: 14)
                                }
                                Text(github.isLoading ? "Starting…" : "Sign in with GitHub")
                                    .font(.callout.weight(.medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.regularMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                        .disabled(github.isLoading)

                        if let err = github.error {
                            Label(err, systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Divider()

                        // gh CLI fallback
                        Button {
                            Task {
                                let ok = await github.tryGhCLI()
                                if ok {
                                    await github.fetchRepos()
                                    appVM.phase = .repoPicker
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text("Use GitHub CLI (gh) if already logged in")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(.thickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.14), Color.white.opacity(0.04)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: 320)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { appVM.phase = .welcome } label: {
                    Label("Back", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                }
            }
            ToolbarItem(placement: .navigation) {
                Text("Connect GitHub").font(.callout.weight(.medium)).foregroundStyle(.secondary)
            }
        }
    }
}
