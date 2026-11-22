import UIKit
import LegacyComponents
import AppBundle
import Lottie
import TelegramPresentationData

final class LockView: UIButton, TGModernConversationInputMicButtonLock {
    private let useDarkTheme: Bool
    private let pause: Bool
    
    private let idleView: AnimationView
    private let lockingView: AnimationView
    
    init(frame: CGRect, theme: PresentationTheme, useDarkTheme: Bool = false, pause: Bool = false, strings: PresentationStrings) {
        self.useDarkTheme = useDarkTheme
        self.pause = pause
        
        if let url = getAppBundle().url(forResource: "LockWait", withExtension: "json"), let animation = Animation.filepath(url.path) {
            let view = AnimationView(animation: animation, configuration: LottieConfiguration(renderingEngine: .mainThread, decodingStrategy: .codable))
            view.loopMode = .autoReverse
            view.backgroundColor = .clear
            view.isOpaque = false
            self.idleView = view
        } else {
            self.idleView = AnimationView()
        }
        
        if let url = getAppBundle().url(forResource: self.pause ? "LockPause" : "Lock", withExtension: "json"), let animation = Animation.filepath(url.path) {
            let view = AnimationView(animation: animation, configuration: LottieConfiguration(renderingEngine: .mainThread, decodingStrategy: .codable))
            view.backgroundColor = .clear
            view.isOpaque = false
            self.lockingView = view
        } else {
            self.lockingView = AnimationView()
        }
        
        super.init(frame: frame)
        
        accessibilityLabel = strings.VoiceOver_Recording_StopAndPreview
        
        addSubview(idleView)
        idleView.frame = bounds
        
        addSubview(lockingView)
        lockingView.frame = bounds
        
        updateTheme(theme)
        updateLockness(0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateLockness(_ lockness: CGFloat) {
        idleView.isHidden = lockness > 0
        if lockness > 0 && idleView.isAnimationPlaying {
            idleView.stop()
        } else if lockness == 0 && !idleView.isAnimationPlaying {
            idleView.play()
        }
        lockingView.isHidden = !idleView.isHidden
        
        lockingView.currentProgress = lockness
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        for keypath in idleView.allKeypaths(predicate: { $0.keys.last == "Color" }) {
            idleView.setValueProvider(ColorValueProvider(theme.chat.inputPanel.panelControlColor.lottieColorValue), keypath: AnimationKeypath(keypath: keypath))
        }
        
        for keypath in lockingView.allKeypaths(predicate: { $0.keys.last == "Color" }) {
            lockingView.setValueProvider(ColorValueProvider(theme.chat.inputPanel.panelControlColor.lottieColorValue), keypath: AnimationKeypath(keypath: keypath))
        }
//        
//        [
//            "Path.Path.Обводка 1": theme.chat.inputPanel.panelControlAccentColor,
//            "Path.Path.Заливка 1": theme.chat.inputPanel.panelBackgroundColor.withAlphaComponent(1.0),
//            "Rectangle.Rectangle.Обводка 1": theme.chat.inputPanel.panelControlAccentColor,
//            "Rectangle.Заливка 1": theme.chat.inputPanel.panelControlAccentColor,
//            "Path 4.Path 4.Обводка 1": theme.chat.inputPanel.panelControlAccentColor
//        ].forEach { key, value in
//            lockingView.setValueProvider(ColorValueProvider(value.lottieColorValue), keypath: AnimationKeypath(keypath: "\(key).Color"))
//        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let superTest = super.hitTest(point, with: event)
        if superTest === lockingView {
            return self
        }
        return superTest
    }
}
