import Foundation
import SwiftSignalKit
import Speech

public func transcribeAudio(path: String, locale: String) -> Signal<LocallyTranscribedAudio?, Error> {
    return Signal { subscriber in
        let disposable = MetaDisposable()
        
        if #available(iOS 10.0, *) {
            SFSpeechRecognizer.requestAuthorization { status in
                Queue.mainQueue().async {
                    switch status {
                    case .notDetermined:
                        subscriber.putNext(nil)
                        subscriber.putCompletion()
                    case .restricted:
                        subscriber.putNext(nil)
                        subscriber.putCompletion()
                    case .denied:
                        subscriber.putNext(nil)
                        subscriber.putCompletion()
                    case .authorized:
                        guard let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)), speechRecognizer.isAvailable else {
                            subscriber.putNext(nil)
                            subscriber.putCompletion()
                            
                            return
                        }
                        
                        speechRecognizer.defaultTaskHint = .unspecified
                        
                        let tempFilePath = NSTemporaryDirectory() + "\(UInt64.random(in: 0 ... UInt64.max)).m4a"
                        let _ = try? FileManager.default.copyItem(atPath: path, toPath: tempFilePath)
                        
                        let request = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: tempFilePath))
                        request.shouldReportPartialResults = true
                        
                        let task = speechRecognizer.recognitionTask(with: request, resultHandler: { result, error in
                            if let result = result {
                                subscriber.putNext(LocallyTranscribedAudio(text: result.bestTranscription.formattedString, isFinal: result.isFinal))
                                
                                if result.isFinal {
                                    subscriber.putCompletion()
                                    
                                    let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
                                }
                            } else {
                                print("transcribeAudio: locale: \(locale), error: \(String(describing: error))")
                                
                                subscriber.putError(error!)
                                
                                let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
                            }
                        })
                        
                        disposable.set(ActionDisposable {
                            task.cancel()
                        })
                    @unknown default:
                        subscriber.putNext(nil)
                        subscriber.putCompletion()
                    }
                }
            }
        } else {
            subscriber.putNext(nil)
            subscriber.putCompletion()
        }
        
        return disposable
    }
    |> runOn(.mainQueue())
}

public struct LocallyTranscribedAudio {
    public var text: String
    public var isFinal: Bool
}

public func speechRecognitionSupported(languageCode: String) -> Bool {
    if #available(iOS 10.0, *) {
        return SFSpeechRecognizer.supportedLocales().contains(where: { $0.languageCode == languageCode })
    } else {
        return false
    }
}
