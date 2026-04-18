import SwiftUI
import Charts
import KeyLensCore

// MARK: - Apps sub-tab enum (Issue #274)

enum AppsSubTab: String, CaseIterable {
    case apps
    case devices
}

extension ChartsView {

    var appsTabAppsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection(L10n.shared.appsAllTime, helpText: L10n.shared.helpApps, showSort: true) { topAppsChart }
                chartSection(L10n.shared.appsToday, helpText: L10n.shared.helpAppsToday, showSort: true) { todayTopAppsChart }
                if !model.appErgScores.isEmpty {
                    chartSection(L10n.shared.appErgScoreSection, helpText: L10n.shared.helpAppErgScore) {
                        appErgScoreTable
                    }
                }
            }
            .padding(24)
        }
    }

    var appsTabDevicesContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection(L10n.shared.devicesAllTime, helpText: L10n.shared.helpDevices, showSort: true) { topDevicesChart }
                chartSection(L10n.shared.devicesToday, helpText: L10n.shared.helpDevicesToday, showSort: true) { todayTopDevicesChart }
                if !model.deviceErgScores.isEmpty {
                    chartSection(L10n.shared.deviceErgScoreSection, helpText: L10n.shared.helpDeviceErgScore) {
                        deviceErgScoreTable
                    }
                }
            }
            .padding(24)
        }
    }

    var appErgScoreTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack {
                Text(L10n.shared.appErgScoreAppHeader)
                    .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                Text(L10n.shared.appErgScoreKeysHeader)
                    .font(.footnote).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                Text(L10n.shared.appErgScoreScoreHeader)
                    .font(.footnote).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(6)

            ForEach(model.appErgScores) { entry in
                HStack {
                    Text(entry.app)
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                    Text(entry.keystrokes.formatted())
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    HStack(spacing: 4) {
                        // Score bar (fills proportionally from 0–100)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(scoreColor(entry.score).opacity(0.25))
                                .frame(width: geo.size.width)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(scoreColor(entry.score))
                                        .frame(width: geo.size.width * entry.score / 100)
                                }
                        }
                        .frame(width: 44, height: 8)
                        Text(String(format: "%.0f", entry.score))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(scoreColor(entry.score))
                            .frame(width: 28, alignment: .trailing)
                    }
                    .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                Divider().padding(.horizontal, 12)
            }
        }
    }

    var deviceErgScoreTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.shared.deviceErgScoreDeviceHeader)
                    .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                Text(L10n.shared.deviceErgScoreKeysHeader)
                    .font(.footnote).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                Text(L10n.shared.deviceErgScoreScoreHeader)
                    .font(.footnote).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(6)

            ForEach(model.deviceErgScores) { entry in
                HStack {
                    Text(entry.device)
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                    Text(entry.keystrokes.formatted())
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    HStack(spacing: 4) {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(scoreColor(entry.score).opacity(0.25))
                                .frame(width: geo.size.width)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(scoreColor(entry.score))
                                        .frame(width: geo.size.width * entry.score / 100)
                                }
                        }
                        .frame(width: 44, height: 8)
                        Text(String(format: "%.0f", entry.score))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(scoreColor(entry.score))
                            .frame(width: 28, alignment: .trailing)
                    }
                    .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                Divider().padding(.horizontal, 12)
            }
        }
    }

    func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }

    @ViewBuilder
    var topAppsChart: some View {
        if model.topApps.isEmpty {
            emptyState
        } else {
            let appOrder = model.topApps.map(\.app)
            let domain = sortDescending ? Array(appOrder.reversed()) : appOrder

            Chart(model.topApps) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("App", item.app)
                )
                .foregroundStyle(theme.accentColor.gradient)
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: domain)
            .chartLegend(.hidden)
            .chartXAxisLabel(L10n.shared.axisLabelKeys, alignment: .trailing)
            .frame(height: CGFloat(model.topApps.count * 28 + 24))
        }
    }

    @ViewBuilder
    var todayTopAppsChart: some View {
        if model.todayTopApps.isEmpty {
            emptyState
        } else {
            let appOrder = model.todayTopApps.map(\.app)
            let domain = sortDescending ? Array(appOrder.reversed()) : appOrder

            Chart(model.todayTopApps) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("App", item.app)
                )
                .foregroundStyle(Color.teal.gradient)
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: domain)
            .chartLegend(.hidden)
            .chartXAxisLabel(L10n.shared.axisLabelKeys, alignment: .trailing)
            .frame(height: CGFloat(model.todayTopApps.count * 28 + 24))
        }
    }

    @ViewBuilder
    var topDevicesChart: some View {
        if model.topDevices.isEmpty {
            emptyState
        } else {
            let entries = sortDescending ? model.topDevices : model.topDevices.reversed()
            let maxCount = CGFloat(entries.map(\.count).max() ?? 1)
            VStack(spacing: 0) {
                ForEach(entries) { item in
                    HStack(spacing: 8) {
                        Text(item.device)
                            .font(.system(size: 11))
                            .frame(width: 160, alignment: .trailing)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        GeometryReader { geo in
                            let barWidth = max(geo.size.width * CGFloat(item.count) / maxCount, 4)
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.indigo.gradient)
                                    .frame(width: barWidth, height: 14)
                                Text(item.count.formatted())
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 0)
                            }
                            .frame(maxHeight: .infinity, alignment: .center)
                        }
                        Button {
                            devicePendingDelete = item.device
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .help(L10n.shared.deleteDeviceTitle)
                    }
                    .frame(height: 26)
                }
            }
            .alert(
                L10n.shared.deleteDeviceTitle,
                isPresented: Binding(
                    get: { devicePendingDelete != nil },
                    set: { if !$0 { devicePendingDelete = nil } }
                ),
                presenting: devicePendingDelete
            ) { device in
                Button(L10n.shared.deleteDeviceConfirm, role: .destructive) {
                    KeyCountStore.shared.deleteDevice(device)
                    if accumSelectedDevice == device { accumSelectedDevice = nil }
                    model.reload()
                }
                Button(L10n.shared.cancel, role: .cancel) {}
            } message: { device in
                Text("\"\(device)\"\n\(L10n.shared.deleteDeviceMessage)")
            }
        }
    }

    @ViewBuilder
    var todayTopDevicesChart: some View {
        if model.todayTopDevices.isEmpty {
            emptyState
        } else {
            let deviceOrder = model.todayTopDevices.map(\.device)
            let domain = sortDescending ? Array(deviceOrder.reversed()) : deviceOrder

            Chart(model.todayTopDevices) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Device", item.device)
                )
                .foregroundStyle(Color.purple.gradient)
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: domain)
            .chartLegend(.hidden)
            .chartXAxisLabel(L10n.shared.axisLabelKeys, alignment: .trailing)
            .frame(height: CGFloat(model.todayTopDevices.count * 28 + 24))
        }
    }
}
