import Foundation
import SwiftSignalKit
import Speech

private var sharedRecognizer: Any?

public func transcribeAudio(path: String) -> Signal<String?, NoError> {
    return Signal { subscriber in
        let disposable = MetaDisposable()
        
        if #available(iOS 13.0, *) {
            SFSpeechRecognizer.requestAuthorization { (status) in
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
                    let speechRecognizer: SFSpeechRecognizer
                    if let sharedRecognizer = sharedRecognizer as? SFSpeechRecognizer {
                        speechRecognizer = sharedRecognizer
                    } else {
                        guard let speechRecognizerValue = SFSpeechRecognizer(locale: Locale(identifier: "ru-RU")), speechRecognizerValue.isAvailable else {
                            subscriber.putNext(nil)
                            subscriber.putCompletion()
                            
                            return
                        }
                        speechRecognizerValue.defaultTaskHint = .unspecified
                        sharedRecognizer = speechRecognizerValue
                        speechRecognizer = speechRecognizerValue
                        
                        speechRecognizer.supportsOnDeviceRecognition = false
                    }
                    
                    let request = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: path))
                    request.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition
                    request.shouldReportPartialResults = false
                    
                    let task = speechRecognizer.recognitionTask(with: request, resultHandler: { result, error in
                        if let result = result {
                            subscriber.putNext(result.bestTranscription.formattedString)
                            subscriber.putCompletion()
                        } else {
                            print("transcribeAudio: \(String(describing: error))")
                            
                            subscriber.putNext(nil)
                            subscriber.putCompletion()
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
        } else {
            subscriber.putNext(nil)
            subscriber.putCompletion()
        }
        
        return disposable
    }
    |> runOn(.mainQueue())
}
