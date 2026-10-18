import Foundation
import CoreGraphics

let passMaxStringLength = 256
let passMaxFieldsPerGroup = 8

public struct PassColor: Equatable {
    public var red: CGFloat
    public var green: CGFloat
    public var blue: CGFloat

    public init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public enum PassTransitType: String {
    case air = "PKTransitTypeAir"
    case boat = "PKTransitTypeBoat"
    case bus = "PKTransitTypeBus"
    case train = "PKTransitTypeTrain"
    case generic = "PKTransitTypeGeneric"
}

public enum PassStyle: Equatable {
    case boardingPass(PassTransitType)
    case coupon
    case eventTicket
    case generic
    case storeCard
}

public enum PassTextAlignment {
    case left
    case center
    case right
    case natural
}

public enum PassFieldValue: Equatable {
    case string(String)
    case number(Double)
}

public struct PassField: Equatable {
    public var key: String
    public var label: String?
    public var value: PassFieldValue
    public var textAlignment: PassTextAlignment
    public var dateStyle: String?
    public var timeStyle: String?
    public var ignoresTimeZone: Bool
    public var currencyCode: String?
    public var numberStyle: String?

    public init(key: String, label: String?, value: PassFieldValue, textAlignment: PassTextAlignment, dateStyle: String?, timeStyle: String?, ignoresTimeZone: Bool, currencyCode: String?, numberStyle: String?) {
        self.key = key
        self.label = label
        self.value = value
        self.textAlignment = textAlignment
        self.dateStyle = dateStyle
        self.timeStyle = timeStyle
        self.ignoresTimeZone = ignoresTimeZone
        self.currencyCode = currencyCode
        self.numberStyle = numberStyle
    }
}

public struct Pass: Equatable {
    public var style: PassStyle
    public var backgroundColor: PassColor
    public var foregroundColor: PassColor
    public var labelColor: PassColor
    public var logoText: String?
    public var headerFields: [PassField]
    public var primaryFields: [PassField]
    public var secondaryFields: [PassField]
    public var auxiliaryFields: [PassField]

    public init(style: PassStyle, backgroundColor: PassColor, foregroundColor: PassColor, labelColor: PassColor, logoText: String?, headerFields: [PassField], primaryFields: [PassField], secondaryFields: [PassField], auxiliaryFields: [PassField]) {
        self.style = style
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.labelColor = labelColor
        self.logoText = logoText
        self.headerFields = headerFields
        self.primaryFields = primaryFields
        self.secondaryFields = secondaryFields
        self.auxiliaryFields = auxiliaryFields
    }
}

private func parseColor(_ value: Any?) -> PassColor? {
    guard let string = (value as? String)?.trimmingCharacters(in: .whitespaces).lowercased() else {
        return nil
    }
    if string.hasPrefix("rgb"), let open = string.firstIndex(of: "("), let close = string.lastIndex(of: ")"), open < close {
        let parts = string[string.index(after: open) ..< close].split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count >= 3 else {
            return nil
        }
        return PassColor(red: CGFloat(min(255.0, max(0.0, parts[0])) / 255.0), green: CGFloat(min(255.0, max(0.0, parts[1])) / 255.0), blue: CGFloat(min(255.0, max(0.0, parts[2])) / 255.0))
    }
    if string.hasPrefix("#"), string.count == 7, let rgb = UInt32(string.dropFirst(), radix: 16) {
        return PassColor(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0)
    }
    return nil
}

func passCappedString(_ string: String) -> String {
    let scalars = string.unicodeScalars
    guard let end = scalars.index(scalars.startIndex, offsetBy: passMaxStringLength, limitedBy: scalars.endIndex), end != scalars.endIndex else {
        return string
    }
    return String(scalars[scalars.startIndex ..< end])
}

private func parseFields(_ value: Any?) -> [PassField] {
    guard let list = value as? [[String: Any]] else {
        return []
    }
    return list.prefix(passMaxFieldsPerGroup).compactMap { item -> PassField? in
        guard let key = item["key"] as? String else {
            return nil
        }
        let fieldValue: PassFieldValue
        if let string = item["value"] as? String {
            fieldValue = .string(passCappedString(string))
        } else if let number = item["value"] as? NSNumber {
            fieldValue = .number(number.doubleValue)
        } else {
            return nil
        }
        let alignment: PassTextAlignment
        switch item["textAlignment"] as? String {
        case "PKTextAlignmentLeft":
            alignment = .left
        case "PKTextAlignmentCenter":
            alignment = .center
        case "PKTextAlignmentRight":
            alignment = .right
        default:
            alignment = .natural
        }
        return PassField(key: key, label: (item["label"] as? String).flatMap(passCappedString), value: fieldValue, textAlignment: alignment, dateStyle: item["dateStyle"] as? String, timeStyle: item["timeStyle"] as? String, ignoresTimeZone: (item["ignoresTimeZone"] as? Bool) ?? false, currencyCode: item["currencyCode"] as? String, numberStyle: item["numberStyle"] as? String)
    }
}

extension Pass {
    public static func parse(jsonData: Data) -> Pass? {
        var data = jsonData
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            data = data.subdata(in: 3 ..< data.count)
        }
        var options: JSONSerialization.ReadingOptions = []
        if #available(iOS 15.0, macOS 12.0, *) {
            options.insert(.json5Allowed)
        }
        guard let root = (try? JSONSerialization.jsonObject(with: data, options: options)) as? [String: Any] else {
            return nil
        }
        let style: PassStyle
        let body: [String: Any]
        if let value = root["boardingPass"] as? [String: Any] {
            style = .boardingPass((value["transitType"] as? String).flatMap(PassTransitType.init(rawValue:)) ?? .generic)
            body = value
        } else if let value = root["eventTicket"] as? [String: Any] {
            style = .eventTicket
            body = value
        } else if let value = root["storeCard"] as? [String: Any] {
            style = .storeCard
            body = value
        } else if let value = root["coupon"] as? [String: Any] {
            style = .coupon
            body = value
        } else if let value = root["generic"] as? [String: Any] {
            style = .generic
            body = value
        } else {
            return nil
        }
        let foreground = parseColor(root["foregroundColor"]) ?? PassColor(red: 0.0, green: 0.0, blue: 0.0)
        return Pass(style: style, backgroundColor: parseColor(root["backgroundColor"]) ?? PassColor(red: 1.0, green: 1.0, blue: 1.0), foregroundColor: foreground, labelColor: parseColor(root["labelColor"]) ?? foreground, logoText: (root["logoText"] as? String).flatMap(passCappedString), headerFields: parseFields(body["headerFields"]), primaryFields: parseFields(body["primaryFields"]), secondaryFields: parseFields(body["secondaryFields"]), auxiliaryFields: parseFields(body["auxiliaryFields"]))
    }
}
