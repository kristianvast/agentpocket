import SwiftUI

struct ProjectListView: View {
    @Environment(AppState.self) private var appState
    @State private var hasAnimated = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if appState.isLoadingProjects {
                    loadingState
                } else if appState.projectStore.sortedProjects.isEmpty {
                    emptyState
                } else {
                    projectGrid
                }
            }
            .background(Theme.background)
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        appState.disconnect()
                    } label: {
                        HStack(spacing: Theme.spacingXS) {
                            Image(systemName: "chevron.left")
                                .font(.caption.bold())
                            Text("Servers")
                                .font(Theme.captionFont)
                        }
                        .foregroundStyle(Theme.cyanAccent)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await appState.loadProjects() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Theme.cyanAccent)
                    }
                }
            }
            .refreshable {
                await appState.loadProjects()
            }
        }
        .onAppear {
            guard !hasAnimated else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeOut(duration: 0.5)) {
                    hasAnimated = true
                }
            }
        }
    }

    // MARK: - Project Grid

    private var projectGrid: some View {
        LazyVStack(spacing: Theme.spacingMD) {
            ForEach(Array(appState.projectStore.sortedProjects.enumerated()), id: \.element.id) { index, project in
                ProjectCard(project: project) {
                    HapticManager.impact(.medium)
                    Task {
                        await appState.selectProject(project)
                    }
                }
                .opacity(hasAnimated ? 1 : 0)
                .offset(y: hasAnimated ? 0 : 20)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.8)
                        .delay(Double(index) * 0.08),
                    value: hasAnimated
                )
            }
        }
        .padding(.horizontal, Theme.spacingMD)
        .padding(.top, Theme.spacingSM)
        .padding(.bottom, Theme.spacingXL)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: Theme.spacingMD) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonProjectCard()
            }
        }
        .padding(.horizontal, Theme.spacingMD)
        .padding(.top, Theme.spacingSM)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Projects", systemImage: "folder")
                .foregroundStyle(Theme.textMuted)
        } description: {
            Text("Open a project with OpenCode on your machine to see it here.")
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.top, 80)
    }
}

// MARK: - Project Card

struct ProjectCard: View {
    let project: Project
    let action: () -> Void

    @State private var isPressed = false

    private var accentColor: Color {
        if let hex = project.icon?.color, !hex.isEmpty {
            return Color(hex: hex)
        }
        // Generate a stable color from the project name
        let colors: [Color] = [
            Theme.cyanAccent, Theme.emerald, Theme.orange,
            Color(hex: "#A78BFA"), Color(hex: "#F472B6"), Color(hex: "#60A5FA")
        ]
        let hash = abs(project.displayName.hashValue)
        return colors[hash % colors.count]
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Top section: icon + name
                HStack(spacing: Theme.spacingMD) {
                    // Project icon
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.radiusMD)
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 52, height: 52)

                        Image(systemName: "folder.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(accentColor)
                    }

                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text(project.displayName)
                            .font(.system(.title3, design: .default, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)

                        Text(project.shortPath)
                            .font(Theme.monoFont)
                            .foregroundStyle(Theme.textMuted)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.textMuted.opacity(0.5))
                }

                // Bottom section: metadata
                HStack(spacing: Theme.spacingMD) {
                    // Time since last activity
                    Label {
                        Text(project.time.updated, style: .relative)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textMuted)
                    } icon: {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textMuted)
                    }

                    Spacer()

                    // Accent bar
                    RoundedRectangle(cornerRadius: 1)
                        .fill(accentColor.opacity(0.4))
                        .frame(width: 24, height: 3)
                }
                .padding(.top, Theme.spacingMD)
            }
            .padding(Theme.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusLG)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLG)
                    .stroke(
                        LinearGradient(
                            colors: [accentColor.opacity(0.2), accentColor.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(ProjectCardButtonStyle())
    }
}

struct ProjectCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Skeleton Loading

struct SkeletonProjectCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.spacingMD) {
                SkeletonView(width: 52, height: 52)

                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    SkeletonView(width: 160, height: 20)
                    SkeletonView(width: 220, height: 14)
                }

                Spacer()
            }

            HStack {
                SkeletonView(width: 100, height: 12)
                Spacer()
            }
            .padding(.top, Theme.spacingMD)
        }
        .padding(Theme.spacingMD)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLG))
    }
}
