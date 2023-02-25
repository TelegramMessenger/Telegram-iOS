import Foundation
import SwiftSignalKit
import Speech

private weak var previousTask: SFSpeechRecognitionTask?

public func transcribeAudio(path: String, locale: String, audioDuration: Int32) -> Signal<LocallyTranscribedAudio?, Error> {
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
                        // only one simultaneous task allowed
                        previousTask?.cancel()
                        
                        guard let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)), speechRecognizer.isAvailable else {
                            subscriber.putNext(nil)
                            subscriber.putCompletion()
                            
                            return
                        }
                        
                        speechRecognizer.defaultTaskHint = .unspecified
                        
                        let tempFilePath = NSTemporaryDirectory() + "\(UInt64.random(in: 0 ... UInt64.max)).m4a"
                        let _ = try? FileManager.default.copyItem(atPath: path, toPath: tempFilePath)
                        
                        let request = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: tempFilePath))
                        if #available(iOS 16.0, *) {
                            request.addsPunctuation = true
                        }
                        if #available(iOS 13.0, *) {
                            // on-device recognition allows full recognition of audio > 1 min
                            request.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition
                        }
                        request.shouldReportPartialResults = true
                        
                        // during on-device recognition the result text is delivered in multiple parts
                        var accumulatedString = ""
                        var lastResultString = ""
                        var lastEndingTimestamp = 0.0
                        
                        let task = speechRecognizer.recognitionTask(with: request, resultHandler: { result, error in
                            if let result = result {
                                if let lastSegment = result.bestTranscription.segments.last {
                                    if lastSegment.timestamp + lastSegment.duration < lastEndingTimestamp {
                                        accumulatedString += lastResultString + " "
                                    }
                                    lastEndingTimestamp = lastSegment.timestamp + lastSegment.duration
                                }
                                lastResultString = result.bestTranscription.formattedString
                                
                                var maybeCutMark = ""
                                if result.isFinal {
                                    if #available(iOS 13.0, *), request.requiresOnDeviceRecognition {
                                    } else if lastEndingTimestamp <= 60.0 && audioDuration > 60 {
                                        maybeCutMark = " ✂"
                                    }
                                }
                                
                                subscriber.putNext(LocallyTranscribedAudio(text: accumulatedString + result.bestTranscription.formattedString + maybeCutMark, isFinal: result.isFinal))
                                
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
                        
                        previousTask = task
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
