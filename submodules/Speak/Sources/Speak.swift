import Foundation
import AVFoundation
import AccountContext

// Incuding at least one Objective-C class in a swift file ensures that it doesn't get stripped by the linker
private final class LinkHelperClass: NSObject {
}

public class SpeechSynthesizerHolder: NSObject, AVSpeechSynthesizerDelegate {
    private var speechSynthesizer: AVSpeechSynthesizer
    
    public var completion: () -> Void = {}
    
    init(speechSynthesizer: AVSpeechSynthesizer) {
        self.speechSynthesizer = speechSynthesizer
        
        super.init()
        
        self.speechSynthesizer.delegate = self
    }
    
    public func stop() {
        self.speechSynthesizer.stopSpeaking(at: .immediate)
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        self.completion()
    }
}

public func supportedSpeakLanguages() -> Set<String> {
    var languages: [String] = []
    for voice in AVSpeechSynthesisVoice.speechVoices() {
        let components = voice.language.components(separatedBy: "-")
        if let language = components.first {
            languages.append(language)
        }
    }
    return Set(languages)
}

public func speakText(context: AccountContext, text: String) -> SpeechSynthesizerHolder? {
    guard !text.isEmpty else {
        return nil
    }
    
    let speechSynthesizer = AVSpeechSynthesizer()
    let utterance = AVSpeechUtterance(string: text)
    if #available(iOS 11.0, *), let language = NSLinguisticTagger.dominantLanguage(for: text) {
        utterance.voice = AVSpeechSynthesisVoice(language: language)
    }
    speechSynthesizer.speak(utterance)
    
    return SpeechSynthesizerHolder(speechSynthesizer: speechSynthesizer)
}
