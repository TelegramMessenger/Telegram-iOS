import Foundation
import AVFoundation

// Incuding at least one Objective-C class in a swift file ensures that it doesn't get stripped by the linker
private final class LinkHelperClass: NSObject {
}

public func speakText(_ text: String) {
    guard !text.isEmpty else {
        return
    }
    let speechSynthesizer = AVSpeechSynthesizer()
    let utterance = AVSpeechUtterance(string: text)
    if #available(iOS 11.0, *), let language = NSLinguisticTagger.dominantLanguage(for: text) {
        utterance.voice = AVSpeechSynthesisVoice(language: language)
    }
    speechSynthesizer.speak(utterance)
}
