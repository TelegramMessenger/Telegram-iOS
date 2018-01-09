import Foundation

private func loadCountriesInfo() -> [(Int, String, String)] {
    guard let filePath = Bundle.main.path(forResource: "PhoneCountries", ofType: "txt") else {
        return []
    }
    guard let stringData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
        return []
    }
    guard let data = String(data: stringData, encoding: .utf8) else {
        return []
    }
    
    let delimiter = ";"
    let endOfLine = "\n"

    var array: [(Int, String, String)] = []
    
    var currentLocation = data.startIndex
    while true {
        guard let codeRange = data.range(of: delimiter, options: [], range: currentLocation ..< data.endIndex, locale: nil) else {
            break
        }
        
        guard let countryCode = Int(data[currentLocation ..< codeRange.lowerBound]) else {
            break
        }
        
        guard let idRange = data.range(of: delimiter, options: [], range: codeRange.upperBound ..< data.endIndex) else {
            break
        }
        
        let countryId = String(data[codeRange.upperBound ..< idRange.lowerBound])
        
        let countryName: String
        let nameRange = data.range(of: endOfLine, options: [], range: idRange.upperBound ..< data.endIndex)
        if let nameRange = nameRange {
            countryName = String(data[idRange.upperBound ..< nameRange.lowerBound])
            currentLocation = nameRange.upperBound
        } else {
            countryName = String(data[idRange.upperBound ..< data.index(data.endIndex, offsetBy: -1)])
        }
        
        array.append((countryCode, countryId, countryName))
        
        if nameRange == nil {
            break
        }
    }
    return array
}

let phoneCountriesInfo = loadCountriesInfo()

let countryCodeToIdAndName: [Int: (String, String)] = {
    var dict: [Int: (String, String)] = [:]
    for (code, id, name) in phoneCountriesInfo {
        if dict[code] == nil {
            dict[code] = (id, name)
        }
    }
    return dict
}()
