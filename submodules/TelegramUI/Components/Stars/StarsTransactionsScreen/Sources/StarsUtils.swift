import Foundation

func formatStarsUsdValue(_ value: Int64, rate: Double) -> String {
    let formattedValue = String(format: "%0.2f", (Double(value)) * rate)
    return "$\(formattedValue)"
}
