import Foundation

func formatUsdValue(_ value: Int64, rate: Double) -> String {
    let formattedValue = String(format: "%0.2f", (Double(value) / 1000000000) * rate)
    return "$\(formattedValue)"
}
