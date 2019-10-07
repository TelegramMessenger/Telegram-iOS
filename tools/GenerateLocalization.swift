import Foundation

struct Entry {
    let key: String
    let value: String
}

enum ArgumentType: Equatable {
    case any
    case integer(decimalNumbers: Int)
    case float
    
    init(_ control: String, decimalNumbers: Int) {
        switch control {
            case "d":
                self = .integer(decimalNumbers: decimalNumbers)
            case "f":
                self = .float
            case "@":
                self = .any
            default:
                preconditionFailure()
        }
    }
}

struct Argument: Equatable {
    let index: Int
    let type: ArgumentType
}

func escapedIdentifier(_ value: String) -> String {
    return value.replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "#", with: "_").replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "'", with: "_")
}

func functionArguments(_ arguments: [Argument]) -> String {
    var result = ""
    var existingIndices = Set<Int>()
    for argument in arguments.sorted(by: { $0.index < $1.index }) {
        if existingIndices.contains(argument.index) {
            continue
        }
        existingIndices.insert(argument.index)
        if !result.isEmpty {
            result += ", "
        }
        result += "_ _\(argument.index): "
        switch argument.type {
            case .any:
                result += "String"
            case .float:
                result += "Float"
            case .integer:
                result += "Int"
        }
    }
    return result
}

func formatArguments(_ arguments: [Argument]) -> String {
    var result = ""
    for argument in arguments.sorted(by: { $0.index < $1.index }) {
        if !result.isEmpty {
            result += ", "
        }
        switch argument.type {
            case .any:
                result += "_\(argument.index)"
            case .float:
                result += "\"\\(_\(argument.index))\""
            case let .integer(decimalNumbers):
                if decimalNumbers == 0 {
                    result += "\"\\(_\(argument.index))\""
                } else {
                    result += "String(format: \"%.\(decimalNumbers)d\", _\(argument.index))"
                }
        }
    }
    return result
}

let argumentRegex = try! NSRegularExpression(pattern: "%((\\.(\\d+))?)(((\\d+)\\$)?)([@df])", options: [])

func parseArguments(_ value: String) -> [Argument] {
    let string = value as NSString
    
    let matches = argumentRegex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
    
    var arguments: [Argument] = []
    var index = 0
    if value.range(of: ".2d") != nil {
        print(value)
    }
    for match in matches {
        var currentIndex = index
        var decimalNumbers = 0
        if match.range(at: 3).location != NSNotFound {
            decimalNumbers = Int(string.substring(with: match.range(at: 3)))!
        }
        if match.range(at: 6).location != NSNotFound {
            currentIndex = Int(string.substring(with: match.range(at: 6)))!
        }
        arguments.append(Argument(index: currentIndex, type: ArgumentType(string.substring(with: match.range(at: 7)), decimalNumbers: decimalNumbers)))
        index += 1
    }
    
    return arguments
}

func addCode(_ lines: [String]) -> String {
    var result: String = ""
    for line in lines {
        result += line
        result += "\n"
    }
    return result
}

enum PluralizationForm: Int32 {
    case zero = 0
    case one = 1
    case two = 2
    case few = 3
    case many = 4
    case other = 5
    
    static var formCount = Int(PluralizationForm.other.rawValue + 1)
    static var all: [PluralizationForm] = [.zero, .one, .two, .few, .many, .other]
    
    var name: String {
        switch self {
            case .zero:
                return "zero"
            case .one:
                return "one"
            case .two:
                return "two"
            case .few:
                return "few"
            case .many:
                return "many"
            case .other:
                return "other"
        }
    }
}

let pluralizationFormRegex = try! NSRegularExpression(pattern: "(.*?)_(0|zero|1|one|2|two|3_10|few|many|any|other)$", options: [])

func pluralizationForm(_ key: String) -> (String, PluralizationForm)? {
    let string = key as NSString
    let matches = pluralizationFormRegex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
    
    for match in matches {
        if match.range(at: 1).location != NSNotFound && match.range(at: 2).location != NSNotFound {
            let base = string.substring(with: match.range(at: 1))
            let value = string.substring(with: match.range(at: 2))
            let form: PluralizationForm
            switch value {
                case "0", "zero":
                    form = .zero
                case "1", "one":
                    form = .one
                case "2", "two":
                    form = .two
                case "3_10", "few":
                    form = .few
                case "many":
                    form = .many
                case "any", "other":
                    form = .other
                default:
                    return nil
            }
            return (base, form)
        }
    }
    
    return nil
}

final class WriteBuffer {
    var data = Data()
    
    init() {
    }
    
    func append(_ value: Int32) {
        var value = value
        withUnsafePointer(to: &value, { (pointer: UnsafePointer<Int32>) -> Void in
            self.data.append(UnsafeRawPointer(pointer).assumingMemoryBound(to: UInt8.self), count: 4)
        })
    }
    
    func append(_ string: String) {
        let bytes = string.data(using: .utf8)!
        self.append(Int32(bytes.count))
        self.data.append(bytes)
    }
}

if CommandLine.arguments.count < 4 {
    print("Usage: swift GenerateLocalization.swift Localizable.strings Strings.swift Strings.mapping [prefix]")
} else {
    var filterPrefix: String?
    if CommandLine.arguments.count > 4 {
        filterPrefix = CommandLine.arguments[4]
    }
    
    let mappingFileUrl = URL(fileURLWithPath: CommandLine.arguments[3])
    let mappingFileName = mappingFileUrl.lastPathComponent
    let mappingFileBaseName = String(mappingFileName[mappingFileName.startIndex ..< mappingFileName.index(mappingFileName.endIndex, offsetBy: -1 - mappingFileUrl.pathExtension.count)])
    let snakeCaseMappingFileBaseName = mappingFileBaseName.prefix(1).lowercased() + mappingFileBaseName.dropFirst()
    
    if let rawDict = NSDictionary(contentsOfFile: CommandLine.arguments[1]) {
        var result = "import Foundation\nimport AppBundle\nimport StringPluralization\n\n"
        
        result +=
"""
private let fallbackDict: [String: String] = {
    guard let mainPath = getAppBundle().path(forResource: \"en\", ofType: \"lproj\"), let bundle = Bundle(path: mainPath) else {
        return [:]
    }
    guard let path = bundle.path(forResource: \"Localizable\", ofType: \"strings\") else {
        return [:]
    }
    guard let dict = NSDictionary(contentsOf: URL(fileURLWithPath: path)) as? [String: String] else {
        return [:]
    }
    return dict
}()

private extension PluralizationForm {
    var canonicalSuffix: String {
        switch self {
            case .zero:
                return \"_0\"
            case .one:
                return \"_1\"
            case .two:
                return \"_2\"
            case .few:
                return \"_3_10\"
            case .many:
                return \"_many\"
            case .other:
                return \"_any\"
        }
    }
}

public final class \(mappingFileBaseName)Component {
    public let languageCode: String
    public let localizedName: String
    public let pluralizationRulesCode: String?
    public let dict: [String: String]
    
    public init(languageCode: String, localizedName: String, pluralizationRulesCode: String?, dict: [String: String]) {
        self.languageCode = languageCode
        self.localizedName = localizedName
        self.pluralizationRulesCode = pluralizationRulesCode
        self.dict = dict
    }
}
        
private func getValue(_ primaryComponent: \(mappingFileBaseName)Component, _ secondaryComponent: \(mappingFileBaseName)Component?, _ key: String) -> String {
    if let value = primaryComponent.dict[key] {
        return value
    } else if let secondaryComponent = secondaryComponent, let value = secondaryComponent.dict[key] {
        return value
    } else if let value = fallbackDict[key] {
        return value
    } else {
        return key
    }
}

private func getValueWithForm(_ primaryComponent: \(mappingFileBaseName)Component, _ secondaryComponent: \(mappingFileBaseName)Component?, _ key: String, _ form: PluralizationForm) -> String {
    let builtKey = key + form.canonicalSuffix
    if let value = primaryComponent.dict[builtKey] {
        return value
    } else if let secondaryComponent = secondaryComponent, let value = secondaryComponent.dict[builtKey] {
        return value
    } else if let value = fallbackDict[builtKey] {
        return value
    }
    return key
}
        
private let argumentRegex = try! NSRegularExpression(pattern: \"%(((\\\\d+)\\\\$)?)([@df])\", options: [])
private func extractArgumentRanges(_ value: String) -> [(Int, NSRange)] {
    var result: [(Int, NSRange)] = []
    let string = value as NSString
    let matches = argumentRegex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
    var index = 0
    for match in matches {
        var currentIndex = index
        if match.range(at: 3).location != NSNotFound {
            currentIndex = Int(string.substring(with: match.range(at: 3)))! - 1
        }
        result.append((currentIndex, match.range(at: 0)))
        index += 1
    }
    result.sort(by: { $0.1.location < $1.1.location })
    return result
}
    
public func formatWithArgumentRanges(_ value: String, _ ranges: [(Int, NSRange)], _ arguments: [String]) -> (String, [(Int, NSRange)]) {
    let string = value as NSString
    
    var resultingRanges: [(Int, NSRange)] = []

    var currentLocation = 0

    let result = NSMutableString()
    for (index, range) in ranges {
        if currentLocation < range.location {
            result.append(string.substring(with: NSRange(location: currentLocation, length: range.location - currentLocation)))
        }
        resultingRanges.append((index, NSRange(location: result.length, length: (arguments[index] as NSString).length)))
        result.append(arguments[index])
        currentLocation = range.location + range.length
    }
    if currentLocation != string.length {
        result.append(string.substring(with: NSRange(location: currentLocation, length: string.length - currentLocation)))
    }
    return (result as String, resultingRanges)
}
        
private final class DataReader {
    private let data: Data
    private var ptr: Int = 0

    init(_ data: Data) {
        self.data = data
    }

    func readInt32() -> Int32 {
        assert(self.ptr + 4 <= self.data.count)
        let result = self.data.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Int32 in
            var value: Int32 = 0
            memcpy(&value, bytes.advanced(by: self.ptr), 4)
            return value
        }
        self.ptr += 4
        return result
    }

    func readString() -> String {
        let length = Int(self.readInt32())
        assert(self.ptr + length <= self.data.count)
        let value = String(data: self.data.subdata(in: self.ptr ..< self.ptr + length), encoding: .utf8)!
        self.ptr += length
        return value
    }
}
        
private func loadMapping() -> ([Int], [String], [Int], [Int], [String]) {
    guard let filePath = getAppBundle().path(forResource: "\(mappingFileBaseName)", ofType: "mapping") else {
        fatalError()
    }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
        fatalError()
    }

    let reader = DataReader(data)

    let idCount = Int(reader.readInt32())
    var sIdList: [Int] = []
    var sKeyList: [String] = []
    var sArgIdList: [Int] = []
    for _ in 0 ..< idCount {
        let id = Int(reader.readInt32())
        sIdList.append(id)
        sKeyList.append(reader.readString())
        if reader.readInt32() != 0 {
            sArgIdList.append(id)
        }
    }

    let pCount = Int(reader.readInt32())
    var pIdList: [Int] = []
    var pKeyList: [String] = []
    for _ in 0 ..< Int(pCount) {
        pIdList.append(Int(reader.readInt32()))
        pKeyList.append(reader.readString())
    }

    return (sIdList, sKeyList, sArgIdList, pIdList, pKeyList)
}

private let keyMapping: ([Int], [String], [Int], [Int], [String]) = loadMapping()
        
public final class \(mappingFileBaseName): Equatable {
    public let lc: UInt32
    
    public let primaryComponent: \(mappingFileBaseName)Component
    public let secondaryComponent: \(mappingFileBaseName)Component?
    public let baseLanguageCode: String
    public let groupingSeparator: String
        
    private let _s: [Int: String]
    private let _r: [Int: [(Int, NSRange)]]
    private let _ps: [Int: String]

"""
        var rawKeyPairs = rawDict.map({ ($0 as! String, $1 as! String) })
        if let filterPrefix = filterPrefix {
            rawKeyPairs = rawKeyPairs.filter {
                $0.0.hasPrefix(filterPrefix)
            }
        }
        
        let idKeyPairs = zip(rawKeyPairs, 0 ..< rawKeyPairs.count).map({ pair, index in (pair.0, pair.1, index) })
        
        var pluralizationKeys = Set<String>()
        var pluralizationBaseKeys = Set<String>()
        for (key, _, _) in idKeyPairs {
            if let (base, _) = pluralizationForm(key) {
                pluralizationKeys.insert(key)
                pluralizationBaseKeys.insert(base)
            }
        }
        let pluralizationKeyPairs = zip(pluralizationBaseKeys, 0 ..< pluralizationBaseKeys.count).map({ ($0, $1) })
        
        for (key, value, id) in idKeyPairs {
            if pluralizationKeys.contains(key) {
                continue
            }
            
            let arguments = parseArguments(value)
            if !arguments.isEmpty {
                result += "    public func \(escapedIdentifier(key))(\(functionArguments(arguments))) -> (String, [(Int, NSRange)]) {\n"
                result += "        return formatWithArgumentRanges(self._s[\(id)]!, self._r[\(id)]!, [\(formatArguments(arguments))])\n"
                result += "    }\n"
            } else {
                result += "    public var \(escapedIdentifier(key)): String { return self._s[\(id)]! }\n"
            }
        }
        
        for (key, id) in pluralizationKeyPairs {
            var arguments: [Argument]?
            for (otherKey, value, _) in idKeyPairs {
                if let (base, _) = pluralizationForm(otherKey), base == key {
                    let localArguments = parseArguments(value)
                    if !localArguments.isEmpty {
                        let numericCount = localArguments.filter({
                            switch $0.type {
                                case .integer:
                                    return true
                                default:
                                    return false
                            }
                        }).count
                        if numericCount > 1 {
                            preconditionFailure("value for \(key) contains more than 1 numeric argument")
                        }
                        if let argumentsValue = arguments {
                            for i in 0 ..< min(argumentsValue.count, localArguments.count) {
                                if argumentsValue[i] != localArguments[i] {
                                    preconditionFailure("value for \(key) contains incompatible argument lists")
                                }
                            }
                            if argumentsValue.count < localArguments.count {
                                arguments = localArguments
                            }
                        } else {
                            arguments = localArguments
                        }
                    }
                }
            }
            if let arguments = arguments, !arguments.isEmpty {
                if arguments.count > 1 {
                    var argList = ""
                    var argListAccessor = ""
                    for argument in arguments {
                        if !argList.isEmpty {
                            argList.append(", ")
                        }
                        if !argListAccessor.isEmpty {
                            argListAccessor.append(", ")
                        }
                        argList.append("_ _\(argument.index): ")
                        argListAccessor.append("_\(argument.index)")
                        switch argument.type {
                            case .any:
                                argList.append("String")
                            case .integer:
                                argList.append("Int32")
                            case .float:
                                argList.append("Float")
                        }
                    }
                    result +=
"""
    public func \(escapedIdentifier(key))(_ selector: Int32, \(argList)) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[\(id) * \(PluralizationForm.formCount) + Int(form.rawValue)]!, \(argListAccessor))
    }

"""
                } else {
                    result +=
"""
    public func \(escapedIdentifier(key))(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = \(snakeCaseMappingFileBaseName)FormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[\(id) * \(PluralizationForm.formCount) + Int(form.rawValue)]!, stringValue)
    }

"""
                }
            } else {
                preconditionFailure("arguments for \(key) is nil")
            }
        }
        
        result +=
"""
        
    public init(primaryComponent: \(mappingFileBaseName)Component, secondaryComponent: \(mappingFileBaseName)Component?, groupingSeparator: String) {
        self.primaryComponent = primaryComponent
        self.secondaryComponent = secondaryComponent
        self.groupingSeparator = groupingSeparator
        
        self.baseLanguageCode = secondaryComponent?.languageCode ?? primaryComponent.languageCode
        
        let languageCode = primaryComponent.pluralizationRulesCode ?? primaryComponent.languageCode
        var rawCode = languageCode as NSString
        var range = rawCode.range(of: \"_\")
        if range.location != NSNotFound {
            rawCode = rawCode.substring(to: range.location) as NSString
        }
        range = rawCode.range(of: \"-\")
        if range.location != NSNotFound {
            rawCode = rawCode.substring(to: range.location) as NSString
        }
        rawCode = rawCode.lowercased as NSString
        var lc: UInt32 = 0
        for i in 0 ..< rawCode.length {
            lc = (lc << 8) + UInt32(rawCode.character(at: i))
        }
        self.lc = lc

        var _s: [Int: String] = [:]
        var _r: [Int: [(Int, NSRange)]] = [:]
        
        let loadedKeyMapping = keyMapping
        
        let sIdList: [Int] = loadedKeyMapping.0
        let sKeyList: [String] = loadedKeyMapping.1
        let sArgIdList: [Int] = loadedKeyMapping.2

"""
        let mappingResult = WriteBuffer()
        let mappingKeyPairs = idKeyPairs.filter({ !pluralizationKeys.contains($0.0) })
        mappingResult.append(Int32(mappingKeyPairs.count))
        for (key, value, id) in mappingKeyPairs {
            mappingResult.append(Int32(id))
            mappingResult.append(key)
            let arguments = parseArguments(value)
            mappingResult.append(arguments.isEmpty ? 0 : 1)
        }
        
        result +=
"""
        for i in 0 ..< sIdList.count {
            _s[sIdList[i]] = getValue(primaryComponent, secondaryComponent, sKeyList[i])
        }
        for i in 0 ..< sArgIdList.count {
            _r[sArgIdList[i]] = extractArgumentRanges(_s[sArgIdList[i]]!)
        }
        self._s = _s
        self._r = _r

        var _ps: [Int: String] = [:]
        let pIdList: [Int] = loadedKeyMapping.3
        let pKeyList: [String] = loadedKeyMapping.4

"""
        mappingResult.append(Int32(pluralizationKeyPairs.count))
        for (key, id) in pluralizationKeyPairs {
            mappingResult.append(Int32(id))
            mappingResult.append(key)
        }
        result +=
"""
        for i in 0 ..< pIdList.count {
            for form in 0 ..< \(PluralizationForm.formCount) {
                _ps[pIdList[i] * \(PluralizationForm.formCount) + form] = getValueWithForm(primaryComponent, secondaryComponent, pKeyList[i], PluralizationForm(rawValue: Int32(form))!)
            }
        }
        self._ps = _ps

"""
        result += "    }\n"
        result +=
"""
    
    public static func ==(lhs: \(mappingFileBaseName), rhs: \(mappingFileBaseName)) -> Bool {
        return lhs === rhs
    }
"""
        result += "\n}\n\n"
        let _ = try? FileManager.default.removeItem(atPath: CommandLine.arguments[2])
        let _ = try? FileManager.default.removeItem(atPath: CommandLine.arguments[3])
        let _ = try? result.write(toFile: CommandLine.arguments[2], atomically: true, encoding: .utf8)
        let _ = try? mappingResult.data.write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
    } else {
        print("Couldn't read file")
        exit(1)
    }
}
