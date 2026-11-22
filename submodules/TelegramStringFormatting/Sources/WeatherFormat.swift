import Foundation

private enum TemperatureUnit {
    case celsius
    case fahrenheit
    
    var suffix: String {
        switch self {
        case .celsius:
            return "°C"
        case .fahrenheit:
            return "°F"
        }
    }
}

private var cachedTemperatureUnit: TemperatureUnit?
private func currentTemperatureUnit() -> TemperatureUnit {
    if let cachedTemperatureUnit {
        return cachedTemperatureUnit
    }
    let temperatureFormatter = MeasurementFormatter()
    temperatureFormatter.locale = Locale.current
   
    let fahrenheitMeasurement = Measurement(value: 0, unit: UnitTemperature.fahrenheit)
    let fahrenheitString = temperatureFormatter.string(from: fahrenheitMeasurement)
    
    var temperatureUnit: TemperatureUnit = .celsius
    if fahrenheitString.contains("F") || fahrenheitString.contains("Fahrenheit") {
        temperatureUnit = .fahrenheit
    }
    cachedTemperatureUnit = temperatureUnit
    return temperatureUnit
}

private var formatter: MeasurementFormatter = {
    let formatter = MeasurementFormatter()
    formatter.locale = Locale.current
    formatter.unitStyle = .short
    formatter.numberFormatter.maximumFractionDigits = 0
    return formatter
}()

public func stringForTemperature(_ value: Double) -> String {
    let valueString = formatter.string(from: Measurement(value: value, unit: UnitTemperature.celsius)).trimmingCharacters(in: CharacterSet(charactersIn: "0123456789-,.").inverted)
    return valueString + currentTemperatureUnit().suffix
}
