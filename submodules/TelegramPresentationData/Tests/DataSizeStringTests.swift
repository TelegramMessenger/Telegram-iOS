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

    private func mb(_ value: Double) -> Int64 {
        return Int64(value * 1024.0 * 1024.0)
    }

    func testDefaultKeepsDecimal() {
        XCTAssertEqual(dataSizeString(self.mb(131.5), formatting: self.formatting), "131,5 МБ")
        XCTAssertEqual(dataSizeString(self.mb(27.25 * 1024.0), formatting: self.formatting), "27,2 ГБ")
    }

    // Data and Storage's usage rows: no decimal from 100 units up, so the value fits beside a long Russian title.
    func testOmitDecimalFrom100() {
        XCTAssertEqual(dataSizeString(self.mb(131.5), omitDecimalFrom100: true, formatting: self.formatting), "131 МБ")
        XCTAssertEqual(dataSizeString(self.mb(100.9), omitDecimalFrom100: true, formatting: self.formatting), "100 МБ")
        XCTAssertEqual(dataSizeString(self.mb(150.0 * 1024.0 + 512.0), omitDecimalFrom100: true, formatting: self.formatting), "150 ГБ")
        XCTAssertEqual(dataSizeString(Int64(512.5 * 1024.0), omitDecimalFrom100: true, formatting: self.formatting), "512 КБ")
    }

    func testOmitDecimalFrom100KeepsSmallerValues() {
        XCTAssertEqual(dataSizeString(self.mb(99.95), omitDecimalFrom100: true, formatting: self.formatting), "99,9 МБ")
        XCTAssertEqual(dataSizeString(self.mb(27.25 * 1024.0), omitDecimalFrom100: true, formatting: self.formatting), "27,2 ГБ")
        XCTAssertEqual(dataSizeString(self.mb(1.5), omitDecimalFrom100: true, formatting: self.formatting), "1,5 МБ")
    }

    func testForceDecimalWins() {
        XCTAssertEqual(dataSizeString(self.mb(131.0), forceDecimal: true, omitDecimalFrom100: true, formatting: self.formatting), "131,0 МБ")
    }
}
