import XCTest
@testable import TDShim

final class EncodeParityTests: XCTestCase {

    func test_dto_injectsTypeExtra_andSnakeCases() throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let dto = DTO(GetChatHistory(chatId: 42, fromMessageId: 0, limit: 30, offset: 0, onlyLocal: false),
                      encoder: encoder)
        let data = try dto.make(with: "extra-123")
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["@type"] as? String, "getChatHistory")
        XCTAssertEqual(obj["@extra"] as? String, "extra-123")
        XCTAssertEqual(obj["chat_id"] as? Int, 42)
        XCTAssertNotNil(obj["from_message_id"])
    }

    func test_errorEnvelope_decodes() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let data = Data(#"{"@type":"error","code":404,"message":"Not Found"}"#.utf8)
        let dto = try decoder.decode(DTO<TDError>.self, from: data)
        XCTAssertEqual(dto.payload.code, 404)
        XCTAssertEqual(dto.payload.message, "Not Found")
    }
}
