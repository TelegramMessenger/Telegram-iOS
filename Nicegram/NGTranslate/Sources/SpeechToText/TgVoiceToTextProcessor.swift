import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore
import NGData
import NGEnv
import NGLocalization
import NGModels
import NGStrings

public enum TgVoiceToTextError: Error {
    case needPremium
    case lowAccuracy
    case underlying(Error)
}

extension TgVoiceToTextError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .needPremium, .lowAccuracy:
            return nil
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

public class TgVoiceToTextProcessor {
    
    //  MARK: - Dependencies
    
    private let mediaBox: MediaBox
    private let googleProcessor: GoogleSpeechToTextProcessor
    
    //  MARK: - Logic
    
    private let additionalLanguageCodes: [String]
    
    private let encodingFormat = "OGG-OPUS"
    private let sampleRateHertz = 48000
    private let thresholdAccuracy = 0.7
    
    //  MARK: - Lifecycle
    
    init(mediaBox: MediaBox, googleProcessor: GoogleSpeechToTextProcessor, additionalLanguageCodes: [String]) {
        self.mediaBox = mediaBox
        self.googleProcessor = googleProcessor
        self.additionalLanguageCodes = additionalLanguageCodes
    }
    
    //  MARK: - Public Functions

    public func recognize(mediaFile: TelegramMediaFile, completion: ((Result<String, TgVoiceToTextError>) -> ())?) {
        guard isPremium() else {
            completion?(.failure(.needPremium))
            return
        }
        
        let _ = (mediaBox.resourceData(mediaFile.resource)
        |> take(1)).start { data in
            do {
                let audioData = try self.extractAudioData(data)
                let config = self.makeRecognitionConfig()
                
                self.googleProcessor.recognize(audioData: audioData, config: config) { result in
                    let result = self.mapGoogleRecognitionResponse(result)
                    DispatchQueue.main.async {
                        completion?(result)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion?(.failure(.underlying(error)))
                }
            }
        }
    }
}

//  MARK: - Convenience init

public extension TgVoiceToTextProcessor {
    convenience init(mediaBox: MediaBox, additionalLanguageCodes: [String]) {
        let googleProcessor = GoogleSpeechToTextProcessor(apiKey: NGENV.google_cloud_api_key)
        self.init(mediaBox: mediaBox, googleProcessor: googleProcessor, additionalLanguageCodes: additionalLanguageCodes)
    }
}

//  MARK: - Private Functions

private extension TgVoiceToTextProcessor {
    func extractAudioData(_ data: MediaResourceData) throws -> Data {
        let path = data.path
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        return data
    }
    
    func makeRecognitionConfig() -> GoogleRecognitionConfig {
        let mainCode = Locale.currentAppLocale.langCode
        var additionalCodes = Set(
            additionalLanguageCodes + [
                Locale.current.langCode,
                "en"
            ]
        )
        additionalCodes.remove(mainCode)
        
        return GoogleRecognitionConfig(
            encoding: encodingFormat,
            sampleRateHertz: sampleRateHertz,
            languageCode: mainCode,
            alternativeLanguageCodes: Array(additionalCodes),
            enableAutomaticPunctuation: true
        )
    }
    
    func mapGoogleRecognitionResponse(_ result: Result<GoogleRecognitionResult, Error>) -> Result<String, TgVoiceToTextError> {
        switch result {
        case .success(let result):
            return mapGoogleRecognitionResult(result)
        case .failure(let error):
            return .failure(.underlying(error))
        }
    }
    
    func mapGoogleRecognitionResult(_ result: GoogleRecognitionResult) -> Result<String, TgVoiceToTextError> {
        let accuracy = measureAccuracy(result)
        guard accuracy > thresholdAccuracy else {
            return .failure(.lowAccuracy)
        }
        
        return .success(result.parts.map(\.text).joined())
    }
    
    func measureAccuracy(_ result: GoogleRecognitionResult) -> Double {
        let sum = result.parts.reduce(0, { $0 + $1.confidence })
        
        let averageAccuracy: Double
        if result.parts.isEmpty {
            averageAccuracy = 0
        } else {
            averageAccuracy = sum / Double(result.parts.count)
        }
        
        return averageAccuracy
    }
}
