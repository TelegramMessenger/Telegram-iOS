import Foundation
import NGExtensions
import NGModels

struct GoogleRecognitionConfig: Encodable {
    let encoding: String
    let sampleRateHertz: Int
    let languageCode: String
    let alternativeLanguageCodes: [String]
    let enableAutomaticPunctuation: Bool
}

struct GoogleRecognitionResult {
    let parts: [Translate]
    
    struct Translate {
        let text: String
        let confidence: Double
    }
}

class GoogleSpeechToTextProcessor {
    
    //  MARK: - Dependencies
    
    private let urlSession: URLSession
    
    //  MARK: - Logic
    
    private let apiKey: String
    
    private let url = URL(string: "https://speech.googleapis.com/v1p1beta1/speech:recognize")
    
    //  MARK: - Lifecycle
    
    init(apiKey: String, urlSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.urlSession = urlSession
    }
    
    //  MARK: - Public Functions

    func recognize(audioData: Data, config: GoogleRecognitionConfig, completion: ((Result<GoogleRecognitionResult, Error>) -> ())?) {
        guard var url = url else {
            completion?(.failure(MessageError.unknown))
            return
        }
        url = url.appending("key", value: apiKey)
        
        let body = makeBody(audioData: audioData, config: config)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        urlSession.dataTask(with: request) { data, response, error in
            let result = self.mapApiResponse(data: data, response: response, error: error)
            completion?(result)
        }.resume()
    }
}

//  MARK: - Private Functions

private extension GoogleSpeechToTextProcessor {
    func makeBody(audioData: Data, config: GoogleRecognitionConfig) -> BodyDTO {
        return BodyDTO(config: config, audio: .init(content: audioData.base64EncodedString()))
    }
    
    func mapApiResponse(data: Data?, response: URLResponse?, error: Error?) -> Result<GoogleRecognitionResult, Error> {
        if let error = error {
            return .failure(error)
        }
        
        guard let code = (response as? HTTPURLResponse)?.statusCode else {
            return .failure(MessageError.unknown)
        }
        
        switch code {
        case 200:
            do {
                guard let data = data else {
                    return .failure(MessageError.unknown)
                }

                let dto = try JSONDecoder().decode(ResponseDTO.self, from: data)
                let recognitionResult = mapResponseDto(dto)
                return .success(recognitionResult)
            } catch {
                return .failure(error)
            }
        default:
            return .failure(MessageError.unknown)
        }
    }
    
    func mapResponseDto(_ dto: ResponseDTO) -> GoogleRecognitionResult {
        let results = dto.results ?? []
        let parts: [GoogleRecognitionResult.Translate] = results
            .reduce([], { $0 + [$1.alternatives?.first].compactMap({$0}) })
            .map({ .init(text: $0.transcript, confidence: $0.confidence) })
        return GoogleRecognitionResult(parts: parts)
    }
}

//  MARK: - DTO

private struct BodyDTO: Encodable {
    let config: GoogleRecognitionConfig
    let audio: Audio
    
    struct Audio: Encodable {
        let content: String
    }
}

private struct ResponseDTO: Decodable {
    let results: [Result]?
    
    struct Result: Decodable {
        let alternatives: [Alternative]?
        
        struct Alternative: Decodable {
            let transcript: String
            let confidence: Double
        }
    }
}
