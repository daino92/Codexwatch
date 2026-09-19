import AppKit
import SwiftUI

struct UsagePopoverView: View {
    @ObservedObject var store: UsageStore
    @State private var page: Page = .usage

    private enum Page {
        case usage
        case settings
        case limit(UsageLimit)
    }

    var body: some View {
        Group {
            switch page {
            case .usage:
                usagePage
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        )
                    )

            case .settings:
                SettingsView(store: store) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        page = .usage
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    )
                )

            case .limit(let limit):
                LimitDetailView(limit: limit) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        page = .usage
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    )
                )
            }
        }
        .frame(width: 340)
        .onAppear {
            page = .usage

            if store.refreshOnOpen {
                Task {
                    await store.refresh()
                }
            }
        }
    }

    private var usagePage: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CodexWatch")
                        .font(.headline)

                    Text(headerSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task {
                        await store.refresh()
                    }
                } label: {
                    Image(
                        systemName: store.isLoading
                            ? "hourglass"
                            : "arrow.clockwise"
                    )
                }
                .buttonStyle(.plain)
                .disabled(store.isLoading)
                .help("Refresh")
            }

            if let error = store.errorMessage {
                Label(
                    error,
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            if store.snapshot.limits.isEmpty &&
                store.errorMessage == nil {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(store.snapshot.limits) { limit in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            page = .limit(limit)
                        }
                    } label: {
                        LimitRow(limit: limit)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if let credits = store.snapshot.credits {
                infoRow("Credits", credits)
            }

            if let context = store.snapshot.context {
                infoRow("Context", context)
            }

            Divider()

            HStack {
                Text(updatedText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        page = .settings
                    }
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .help("Settings")

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
            }
        }
        .padding(16)
    }

    private var headerSubtitle: String {
        [store.snapshot.model, store.snapshot.plan]
            .compactMap { $0 }
            .joined(separator: " · ")
            .nonEmpty ?? "Codex CLI usage"
    }

    private var updatedText: String {
        "Updated " +
        store.snapshot.fetchedAt.formatted(
            date: .omitted,
            time: .standard
        )
    }

    private func infoRow(
        _ title: String,
        _ value: String
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .lineLimit(1)
        }
        .font(.caption)
    }
}

private struct LimitRow: View {
    let limit: UsageLimit

    private var statusColor: Color {
        if limit.remainingPercent <= 5 {
            return .red
        }

        if limit.remainingPercent <= 20 {
            return .orange
        }

        return .accentColor
    }

    private var valueColor: Color {
        if limit.remainingPercent <= 5 {
            return .red
        }

        if limit.remainingPercent <= 20 {
            return .orange
        }

        return .primary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(limit.name)
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text("\(Int(limit.remainingPercent))% left")
                    .font(.caption)
                    .foregroundStyle(valueColor)
            }

            ProgressView(
                value: limit.remainingPercent,
                total: 100
            )
            .tint(statusColor)

            if let resetAt = limit.resetAt {
                TimelineView(
                    .periodic(from: .now, by: 60)
                ) { context in
                    HStack(spacing: 5) {
                        Text(
                            "Resets " +
                            resetAt.formatted(
                                .dateTime
                                    .day()
                                    .month(.abbreviated)
                                    .hour()
                                    .minute()
                            )
                        )

                        Text("·")

                        Text(
                            resetCountdown(
                                to: resetAt,
                                now: context.date
                            )
                        )
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            } else if let reset = limit.resetText {
                Text(reset)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func resetCountdown(
        to resetDate: Date,
        now: Date
    ) -> String {
        let seconds = resetDate.timeIntervalSince(now)

        guard seconds > 0 else {
            return "Resetting…"
        }

        let totalMinutes = Int(seconds / 60)
        let days = totalMinutes / 1_440
        let hours = (totalMinutes % 1_440) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return "\(days)d \(hours)h"
        }

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(max(1, minutes))m"
    }
}

private struct LimitDetailView: View {
    let limit: UsageLimit
    let onBack: () -> Void

    private var usedPercent: Double {
        max(0, min(100, 100 - limit.remainingPercent))
    }

    private var statusColor: Color {
        if limit.remainingPercent <= 5 {
            return .red
        }

        if limit.remainingPercent <= 20 {
            return .orange
        }

        return .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")

                        Text(limit.name)
                            .font(.headline)
                    }
                    .frame(height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Back")

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(Int(limit.remainingPercent))%")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(statusColor)

                ProgressView(
                    value: limit.remainingPercent,
                    total: 100
                )
                .tint(statusColor)
            }

            Divider()

            detailRow(
                title: "Used",
                value: "\(Int(usedPercent))%"
            )

            detailRow(
                title: "Remaining",
                value: "\(Int(limit.remainingPercent))%"
            )

            if let resetAt = limit.resetAt {
                detailRow(
                    title: "Resets",
                    value: resetAt.formatted(
                        .dateTime
                            .day()
                            .month(.abbreviated)
                            .hour()
                            .minute()
                    )
                )

                TimelineView(
                    .periodic(from: .now, by: 60)
                ) { context in
                    detailRow(
                        title: "Time remaining",
                        value: resetCountdown(
                            to: resetAt,
                            now: context.date
                        )
                    )
                }
            } else if let reset = limit.resetText {
                detailRow(
                    title: "Reset",
                    value: reset
                )
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private func detailRow(
        title: String,
        value: String
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
        }
        .font(.caption)
    }

    private func resetCountdown(
        to resetDate: Date,
        now: Date
    ) -> String {
        let seconds = resetDate.timeIntervalSince(now)

        guard seconds > 0 else {
            return "Resetting…"
        }

        let totalMinutes = Int(seconds / 60)
        let days = totalMinutes / 1_440
        let hours = (totalMinutes % 1_440) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return "\(days)d \(hours)h"
        }

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(max(1, minutes))m"
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
