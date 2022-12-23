import EsimApiClientDefinition
import Foundation

struct TicketNumbersDTO: Codable {
    let numbers: [Int]
    
    init(numbers: [Int]) {
        self.numbers = numbers
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        let stringValue = try container.decode(String.self)
        
        numbers = stringValue.components(separatedBy: ",").compactMap { Int($0) }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        let stringValue = numbers.map { String($0) }.joined(separator: ",")
        
        try container.encode(stringValue)
    }
}
