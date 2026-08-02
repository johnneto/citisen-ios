import Foundation

/// Computes live open/closed state from Google's structured opening periods,
/// evaluated in the place's own timezone (from `utcOffsetMinutes`) rather than
/// the device's. Being a pure function of `at:` makes it fully testable and
/// means cached places never carry a stale open/closed boolean.
enum OpeningHoursCalculator {
    private static let minutesPerWeek = 7 * 24 * 60

    static func status(
        periods: [OpeningPeriod]?,
        utcOffsetMinutes: Int?,
        at date: Date
    ) -> OpenStatus {
        guard let periods, !periods.isEmpty,
              let offset = utcOffsetMinutes,
              let timeZone = TimeZone(secondsFromGMT: offset * 60) else {
            return .unknown
        }

        // Google's 24/7 sentinel: a single period with an open point and no close.
        if periods.count == 1, periods[0].closeDay == nil {
            return .open(closesAt: nil)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = components.weekday,
              let hour = components.hour,
              let minute = components.minute else {
            return .unknown
        }
        // Calendar weekday is 1 = Sunday; Google's day is 0 = Sunday.
        let nowMinutes = ((weekday - 1) * 24 + hour) * 60 + minute

        var nextOpenDelta = Int.max
        for period in periods {
            guard let closeDay = period.closeDay,
                  let closeHour = period.closeHour,
                  let closeMinute = period.closeMinute else {
                continue
            }
            let start = (period.openDay * 24 + period.openHour) * 60 + period.openMinute
            var end = (closeDay * 24 + closeHour) * 60 + closeMinute
            if end <= start { end += minutesPerWeek }   // overnight / Sat→Sun wrap

            for now in [nowMinutes, nowMinutes + minutesPerWeek] where now >= start && now < end {
                let closesAt = date.addingTimeInterval(TimeInterval((end - now) * 60))
                return .open(closesAt: closesAt)
            }

            let delta = (start - nowMinutes % minutesPerWeek + minutesPerWeek) % minutesPerWeek
            nextOpenDelta = min(nextOpenDelta, delta)
        }

        let opensAt = nextOpenDelta == .max
            ? nil
            : date.addingTimeInterval(TimeInterval(nextOpenDelta * 60))
        return .closed(opensAt: opensAt)
    }
}
