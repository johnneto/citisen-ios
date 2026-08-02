import SwiftUI

/// Collapsible opening-hours section. The open/closed line is computed live
/// from the place's structured periods in its own timezone, so it never shows
/// a cached answer; the weekly breakdown renders Google's day lines verbatim.
struct POIHoursBlock: View {
    let place: Place
    @Binding var isExpanded: Bool

    private var isBusinessClosed: Bool {
        place.businessStatus == .closedTemporarily || place.businessStatus == .closedPermanently
    }

    private var isCollapsible: Bool {
        !isBusinessClosed && place.weekdayLines != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                guard isCollapsible else { return }
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                header
            }
            .buttonStyle(.plain)
            .disabled(!isCollapsible)

            if isExpanded, let lines = place.weekdayLines {
                weeklyDetail(lines: lines)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .foregroundStyle(AppColor.textSecondary)
            statusLine
                .font(.subheadline15)
            Spacer()
            if isCollapsible {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption12)
                    .foregroundStyle(AppColor.textTertiary)
            }
        }
    }

    @ViewBuilder private var statusLine: some View {
        switch place.businessStatus {
        case .closedTemporarily:
            closedBusinessText("Temporarily closed")
        case .closedPermanently:
            closedBusinessText("Permanently closed")
        default:
            openStatusLine
        }
    }

    private func closedBusinessText(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(AppColor.danger)
            .fontWeight(.semibold)
    }

    @ViewBuilder private var openStatusLine: some View {
        switch place.openStatus() {
        case .open(let closesAt):
            Text("Open now")
                .foregroundStyle(AppColor.success)
                .fontWeight(.semibold)
            if let closesAt {
                Text(" · Closes \(localTime(closesAt))")
                    .foregroundStyle(AppColor.textSecondary)
            } else {
                Text(" · 24 hours")
                    .foregroundStyle(AppColor.textSecondary)
            }
        case .closed(let opensAt):
            Text("Closed")
                .foregroundStyle(AppColor.danger)
                .fontWeight(.semibold)
            if let opensAt {
                Text(" · Opens \(localTime(opensAt))")
                    .foregroundStyle(AppColor.textSecondary)
            }
        case .unknown:
            if place.weekdayLines != nil {
                Text("Opening hours")
                    .foregroundStyle(AppColor.textPrimary)
            } else {
                Text("No opening information available")
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }

    /// Formats a moment as clock time in the place's own timezone, so "Closes
    /// 22:00" means 22:00 at the venue even when browsing from another region.
    private func localTime(_ date: Date) -> String {
        var style = Date.FormatStyle.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute()
        style.timeZone = place.timeZone ?? .current
        return date.formatted(style)
    }

    /// Renders Google's weekday lines verbatim, splitting only for alignment.
    private func weeklyDetail(lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if let separator = line.range(of: ": ") {
                    HStack(alignment: .top) {
                        Text(line[..<separator.lowerBound])
                            .foregroundStyle(AppColor.textSecondary)
                            .frame(width: 84, alignment: .leading)
                        Text(line[separator.upperBound...])
                            .foregroundStyle(AppColor.textPrimary)
                    }
                    .font(.caption12)
                } else {
                    Text(line)
                        .font(.caption12)
                        .foregroundStyle(AppColor.textPrimary)
                }
            }
        }
        .padding(.leading, 22)
    }
}
