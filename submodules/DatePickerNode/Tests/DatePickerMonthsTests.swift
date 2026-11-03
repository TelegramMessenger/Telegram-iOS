import Foundation
import XCTest
@testable import DatePickerNode

/// The month pages of `DatePickerNode` and the page it shows (bugs.telegram.org/c/63155).
///
/// The message-search calendar and Format Date allow any date from 1970, so their month list
/// crosses every historical clock change of the user's time zone. In the Soviet zones clocks
/// jumped from 00:00 to 01:00 on 1 April 1981, so that month has no local midnight. Pages are
/// found by comparing `Date`s, which only works while every month the node holds is exactly
/// `monthForDate` of that month: a month shifted by an hour matches no page, and the picker opened
/// on January 1970 under a header naming the current month.
///
/// These are the free functions the node pages with. The node itself cannot be built here: it
/// needs a `PresentationStrings`, which asserts without the app bundle's strings data.
final class DatePickerMonthsTests: XCTestCase {
    private static let searchMinDate = Date(timeIntervalSince1970: 0.0)
    private static let searchMaxDate = Date(timeIntervalSince1970: Double(Int32.max - 1))

    // One zone from each region with a first-of-month midnight gap after 1970, plus UTC as a control.
    private static let timeZoneIds = ["Europe/Moscow", "Europe/Kyiv", "Asia/Almaty", "America/Argentina/Buenos_Aires", "Africa/Cairo", "America/Havana", "UTC"]

    private func calendar(_ timeZoneId: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneId)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func yearMonth(_ date: Date, calendar: Calendar) -> DateComponents {
        let components = calendar.dateComponents([.year, .month], from: date)
        return DateComponents(year: components.year, month: components.month)
    }

    // Counted arithmetically: turning `{year, month}` back into a date lands inside the very gap under test.
    private func monthNumber(_ date: Date, calendar: Calendar) -> Int {
        let components = self.yearMonth(date, calendar: calendar)
        return components.year! * 12 + components.month!
    }

    private func searchMonths(calendar: Calendar) -> [Date] {
        return datePickerMonths(minDate: DatePickerMonthsTests.searchMinDate, maxDate: DatePickerMonthsTests.searchMaxDate, calendar: calendar)
    }

    func testSearchCalendarOpensOnTheSelectedMonth() {
        for timeZoneId in DatePickerMonthsTests.timeZoneIds {
            let calendar = self.calendar(timeZoneId)
            let months = self.searchMonths(calendar: calendar)
            for selected in [self.date(2026, 6, 26, calendar: calendar), self.date(1990, 3, 8, calendar: calendar)] {
                let currentIndex = datePickerMonthIndex(of: selected, in: months, calendar: calendar)
                XCTAssertEqual(self.yearMonth(months[currentIndex], calendar: calendar), self.yearMonth(selected, calendar: calendar), "\(timeZoneId): opened on \(months[currentIndex]) for \(selected)")
            }
        }
    }

    func testEveryPageIsTheStartOfItsMonth() {
        for timeZoneId in DatePickerMonthsTests.timeZoneIds {
            let calendar = self.calendar(timeZoneId)
            let months = self.searchMonths(calendar: calendar)
            XCTAssertEqual(self.yearMonth(months.last!, calendar: calendar), DateComponents(year: 2038, month: 1), timeZoneId)
            for i in 0 ..< months.count {
                XCTAssertEqual(monthForDate(months[i], calendar: calendar), months[i], "\(timeZoneId): page \(i) is \(months[i])")
                if i > 0 {
                    XCTAssertEqual(self.monthNumber(months[i], calendar: calendar) - self.monthNumber(months[i - 1], calendar: calendar), 1, "\(timeZoneId): page \(i)")
                }
            }
        }
    }

    /// One lookup serves both opening the picker and every later page change, so it must find each
    /// page exactly, from the page itself and from any date inside its month.
    func testEveryDateFindsItsOwnPage() {
        for timeZoneId in DatePickerMonthsTests.timeZoneIds {
            let calendar = self.calendar(timeZoneId)
            let months = self.searchMonths(calendar: calendar)
            for i in 0 ..< months.count {
                XCTAssertEqual(datePickerMonthIndex(of: months[i], in: months, calendar: calendar), i, "\(timeZoneId): page \(months[i])")
                let midMonth = calendar.date(byAdding: .day, value: 14, to: months[i])!
                XCTAssertEqual(datePickerMonthIndex(of: midMonth, in: months, calendar: calendar), i, "\(timeZoneId): \(midMonth)")
            }
        }
    }

    /// A month outside the range has no page, so it must show the nearest one. The month right
    /// after the range used to produce an index one past the last page (a blank grid, and a crash
    /// on the next tap or undirected swipe), and every other month outside it the first page.
    func testSelectedMonthOutsideTheRangeShowsTheNearestPage() {
        for timeZoneId in DatePickerMonthsTests.timeZoneIds {
            let calendar = self.calendar(timeZoneId)
            let months = datePickerMonths(minDate: self.date(2026, 1, 5, calendar: calendar), maxDate: self.date(2026, 9, 20, calendar: calendar), calendar: calendar)
            XCTAssertEqual(months.count, 9, timeZoneId)
            for (selected, expected) in [
                (self.date(2026, 10, 15, calendar: calendar), DateComponents(year: 2026, month: 9)),
                (self.date(2026, 12, 15, calendar: calendar), DateComponents(year: 2026, month: 9)),
                (self.date(2025, 11, 10, calendar: calendar), DateComponents(year: 2026, month: 1)),
                (self.date(2026, 1, 1, calendar: calendar), DateComponents(year: 2026, month: 1)),
                (self.date(2026, 9, 30, calendar: calendar), DateComponents(year: 2026, month: 9))
            ] {
                let currentIndex = datePickerMonthIndex(of: selected, in: months, calendar: calendar)
                guard currentIndex >= 0 && currentIndex < months.count else {
                    XCTFail("\(timeZoneId): index \(currentIndex) is outside \(months.count) pages for \(selected)")
                    continue
                }
                XCTAssertEqual(self.yearMonth(months[currentIndex], calendar: calendar), expected, "\(timeZoneId): \(selected)")
            }
        }
    }

    /// A range whose maximum precedes its minimum still has a page, so there is always one to show.
    func testInvertedRangeStillHasAPage() {
        let calendar = self.calendar("UTC")
        let months = datePickerMonths(minDate: self.date(2026, 5, 1, calendar: calendar), maxDate: self.date(2026, 2, 1, calendar: calendar), calendar: calendar)
        XCTAssertEqual(months.count, 1)
        XCTAssertEqual(datePickerMonthIndex(of: self.date(2026, 3, 1, calendar: calendar), in: months, calendar: calendar), 0)
    }

    /// The previous/next buttons step `selectedMonth` and look the page up again, so a step must
    /// land exactly on a page, including across the gap and in the months after it.
    func testMonthButtonsStepOntoPages() {
        for timeZoneId in DatePickerMonthsTests.timeZoneIds {
            let calendar = self.calendar(timeZoneId)
            let months = self.searchMonths(calendar: calendar)
            let pages = Set(months)
            for i in 1 ..< months.count - 1 {
                XCTAssertEqual(monthByAdding(1, to: months[i], calendar: calendar), months[i + 1], "\(timeZoneId): next from \(months[i])")
                XCTAssertEqual(monthByAdding(-1, to: months[i], calendar: calendar), months[i - 1], "\(timeZoneId): previous from \(months[i])")
            }
            var month = monthForDate(self.date(1981, 2, 15, calendar: calendar), calendar: calendar)
            for _ in 0 ..< 4 {
                month = monthByAdding(1, to: month, calendar: calendar)!
                XCTAssertTrue(pages.contains(month), "\(timeZoneId): stepped to \(month), which is not a page")
            }
        }
    }
}
