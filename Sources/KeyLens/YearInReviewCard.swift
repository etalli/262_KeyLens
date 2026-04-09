import SwiftUI

// MARK: - AnnualSummaryCardView

/// A self-contained card view that summarizes one year of typing activity.
/// Rendered off-screen via ImageRenderer and saved as PNG.
struct AnnualSummaryCardView: View {
    let data: AnnualSummaryData
    /// When true, renders without card background/border — for embedding inside existing windows.
    var embedded: Bool = false
    @ObservedObject private var theme = ThemeStore.shared

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider().padding(.vertical, 12)
            statsRow
            Divider().padding(.vertical, 12)
            monthlyChartSection
            Divider().padding(.vertical, 12)
            topKeysSection
            if !embedded {
                Divider().padding(.vertical, 12)
            }
        }
        .padding(embedded ? 0 : 24)
        .frame(width: embedded ? nil : 560)

        if embedded {
            content
        } else {
            content
                .background(Color(NSColor.windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "calendar")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.accentColor)
            Text(L10n.shared.yearInReviewTitle)
                .font(.system(size: 20, weight: .bold))
            Text(data.year)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(
                icon: "character.cursor.ibeam",
                label: L10n.shared.weeklySummaryCardTotalKeys,
                value: data.totalKeystrokes.formatted()
            )
            Divider().frame(height: 48)
            statCell(
                icon: "chart.bar",
                label: L10n.shared.yearInReviewDailyAvg,
                value: data.dailyAverage.formatted()
            )
            Divider().frame(height: 48)
            statCell(
                icon: "calendar.badge.checkmark",
                label: L10n.shared.yearInReviewActiveDays,
                value: "\(data.activeDays)"
            )
            Divider().frame(height: 48)
            statCell(
                icon: "trophy",
                label: L10n.shared.yearInReviewBestMonth,
                value: data.bestMonthLabel
            )
        }
    }

    private func statCell(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(theme.accentColor)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Monthly chart

    private var monthlyChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.shared.yearInReviewMonthlyChart)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            let maxTotal = data.monthlyTotals.map(\.total).max() ?? 1
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(data.monthlyTotals, id: \.month) { entry in
                    VStack(spacing: 3) {
                        let barHeight = max(4, CGFloat(entry.total) / CGFloat(maxTotal) * 80)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.accentColor.opacity(0.75))
                            .frame(height: barHeight)
                        Text(entry.shortLabel)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)
        }
    }

    // MARK: - Top keys

    private var topKeysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.shared.weeklySummaryCardTopKeys)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                ForEach(data.topKeys, id: \.key) { entry in
                    VStack(spacing: 2) {
                        Text(entry.key)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .frame(width: 36, height: 36)
                            .background(theme.accentColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text(entry.count.formatted())
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - AnnualSummaryData

struct AnnualSummaryData {
    let year: String
    let totalKeystrokes: Int
    let dailyAverage: Int
    let activeDays: Int
    let bestMonthLabel: String
    let monthlyTotals: [MonthEntry]
    let topKeys: [(key: String, count: Int)]

    struct MonthEntry {
        let month: String   // "yyyy-MM"
        let total: Int

        /// Short display label, e.g. "Jan"
        var shortLabel: String {
            guard month.count >= 7 else { return month }
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM"
            if let date = fmt.date(from: month) {
                let out = DateFormatter()
                out.dateFormat = "MMM"
                return out.string(from: date)
            }
            return String(month.suffix(2))
        }
    }

    /// Build data for the given calendar year. Defaults to the previous year.
    static func forYear(_ year: Int) -> AnnualSummaryData {
        let store = KeyCountStore.shared
        let yearStr = String(format: "%04d", year)

        // Monthly totals filtered to this year
        let allMonths = store.monthlyTotals()
        let yearMonths = allMonths.filter { $0.month.hasPrefix(yearStr) }
        let total = yearMonths.reduce(0) { $0 + $1.total }

        // Fill all 12 months (so chart always shows Jan–Dec, even with zero months)
        let monthEntries: [MonthEntry] = (1...12).map { m in
            let key = String(format: "%04d-%02d", year, m)
            let found = yearMonths.first { $0.month == key }
            return MonthEntry(month: key, total: found?.total ?? 0)
        }

        // Active days: count days with data in this year
        let allDays = store.dailyTotals()
        let activeDays = allDays.filter { $0.date.hasPrefix(yearStr) && $0.total > 0 }.count

        // Daily average (over active days only, to avoid dilution by gaps)
        let dailyAvg = activeDays > 0 ? total / activeDays : 0

        // Best month label (e.g. "Mar")
        let bestMonth = yearMonths.max(by: { $0.total < $1.total })
        let bestMonthLabel: String = {
            guard let best = bestMonth else { return "—" }
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM"
            if let date = fmt.date(from: best.month) {
                let out = DateFormatter()
                out.dateFormat = "MMM"
                return out.string(from: date)
            }
            return best.month
        }()

        return AnnualSummaryData(
            year: yearStr,
            totalKeystrokes: total,
            dailyAverage: dailyAvg,
            activeDays: activeDays,
            bestMonthLabel: bestMonthLabel,
            monthlyTotals: monthEntries,
            topKeys: store.topKeys(limit: 5)
        )
    }

    /// Convenience: use previous calendar year.
    static func previousYear() -> AnnualSummaryData {
        let year = Calendar.current.component(.year, from: Date()) - 1
        return forYear(year)
    }
}

// MARK: - YearInReviewGenerator

enum YearInReviewGenerator {

    private static let reportsDir: URL = {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyLens/reports")
    }()

    /// Renders the card for the given year and saves it as PNG.
    /// Returns the saved URL, or nil on failure.
    @MainActor
    @discardableResult
    static func generate(year: Int, to url: URL? = nil) -> URL? {
        let data = AnnualSummaryData.forYear(year)
        let view = AnnualSummaryCardView(data: data)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0  // retina quality

        guard let cgImage = renderer.cgImage else { return nil }

        let destURL: URL
        if let provided = url {
            destURL = provided
        } else {
            let yearStr = String(format: "%04d", year)
            try? FileManager.default.createDirectory(at: reportsDir, withIntermediateDirectories: true)
            destURL = reportsDir.appendingPathComponent("KeyLens_year_\(yearStr).png")
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return nil }

        do {
            try pngData.write(to: destURL)
            return destURL
        } catch {
            return nil
        }
    }
}
