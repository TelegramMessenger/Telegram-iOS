import XCTest
@testable import TelegramPresentationData

final class DataSizeStringTests: XCTestCase {
    private let formatting = DataSizeStringFormatting(
        decimalSeparator: ",",
        byte: { PresentationStrings.FormattedString(string: "\($0) Б", ranges: []) },
        kilobyte: { PresentationStrings.FormattedString(string: "\($0) КБ", ranges: []) },
        megabyte: { PresentationStrings.FormattedString(string: "\($0) МБ", ranges: []) },
        gigabyte: { PresentationStrings.FormattedString(string: "\($0) ГБ", ranges: []) }
    )

    private func kb(_ value: Double) -> Int64 {
        return Int64(value * 1024.0)
    }

    private func mb(_ value: Double) -> Int64 {
        return Int64(value * 1024.0 * 1024.0)
    }

    private func gb(_ value: Double) -> Int64 {
        return Int64(value * 1024.0 * 1024.0 * 1024.0)
    }

    private func compact(_ size: Int64) -> String {
        return dataSizeString(size, compact: true, formatting: self.formatting)
    }

    func testDefaultFormatUnchanged() {
        XCTAssertEqual(dataSizeString(self.mb(131.5), formatting: self.formatting), "131,5 МБ")
        XCTAssertEqual(dataSizeString(self.mb(48.85), formatting: self.formatting), "48,8 МБ")
        XCTAssertEqual(dataSizeString(self.mb(1000.0), formatting: self.formatting), "1000 МБ")
        XCTAssertEqual(dataSizeString(self.gb(27.25), formatting: self.formatting), "27,2 ГБ")
    }

    // Data and Storage's usage rows: KB and MB keep a decimal only below 10.
    func testCompactKilobytesAndMegabytes() {
        XCTAssertEqual(self.compact(self.mb(9.95)), "9,9 МБ")
        XCTAssertEqual(self.compact(self.mb(10.0)), "10 МБ")
        XCTAssertEqual(self.compact(self.mb(48.85)), "48 МБ")
        XCTAssertEqual(self.compact(self.mb(131.5)), "131 МБ")
        XCTAssertEqual(self.compact(self.mb(999.9)), "999 МБ")
        XCTAssertEqual(self.compact(self.mb(5.0)), "5 МБ")
        XCTAssertEqual(self.compact(self.kb(512.5)), "512 КБ")
        XCTAssertEqual(self.compact(self.kb(1.5)), "1,5 КБ")
        XCTAssertEqual(self.compact(999), "999 Б")
        XCTAssertEqual(self.compact(0), "0 Б")
    }

    // GB keeps its decimal below 100.
    func testCompactGigabytes() {
        XCTAssertEqual(self.compact(self.gb(1.0)), "1 ГБ")
        XCTAssertEqual(self.compact(self.gb(27.25)), "27,2 ГБ")
        XCTAssertEqual(self.compact(self.gb(99.95)), "99,9 ГБ")
        XCTAssertEqual(self.compact(self.gb(100.0)), "100 ГБ")
        XCTAssertEqual(self.compact(self.gb(131.5)), "131 ГБ")
    }

    // From 1000 units up a size shows in the next unit, rounded to one decimal: "1000 МБ" would not fit.
    func testCompactThousandShowsInNextUnit() {
        XCTAssertEqual(self.compact(self.mb(1000.0)), "1 ГБ")
        XCTAssertEqual(self.compact(self.mb(1023.9)), "1 ГБ")
        XCTAssertEqual(self.compact(self.mb(1024.0)), "1 ГБ")
        XCTAssertEqual(self.compact(self.kb(1000.0)), "1 МБ")
        XCTAssertEqual(self.compact(1000), "1 КБ")
    }

    func testForceDecimalWins() {
        XCTAssertEqual(dataSizeString(self.mb(131.0), forceDecimal: true, compact: true, formatting: self.formatting), "131,0 МБ")
    }
}
