import UIKit
import LegacyComponents
import AppBundle
import Lottie
import TelegramPresentationData

final class LockView: UIButton, TGModernConversationInputMicButtonLock {
    
    private var colorCallbacks = [LOTValueDelegate]()
    
    private let idleView: LOTAnimationView = {
        guard let url = getAppBundle().url(forResource: "LockWait", withExtension: "json"),
            let composition = LOTComposition(filePath: url.path)
        else { return LOTAnimationView() }
        
        let view = LOTAnimationView(model: composition, in: getAppBundle())
        view.autoReverseAnimation = true
        view.loopAnimation = true
        view.backgroundColor = .clear
        view.isOpaque = false
        return view
    }()
    
    private let lockingView: LOTAnimationView = {
        guard let url = getAppBundle().url(forResource: "Lock", withExtension: "json"),
            let composition = LOTComposition(filePath: url.path)
        else { return LOTAnimationView() }
        
        let view = LOTAnimationView(model: composition, in: getAppBundle())
        view.backgroundColor = .clear
        view.isOpaque = false
        return view
    }()
    
    init(frame: CGRect, theme: PresentationTheme, strings: PresentationStrings) {
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
        
        lockingView.animationProgress = lockness
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        colorCallbacks.removeAll()
        
        [
            "Rectangle.Заливка 1": theme.chat.inputPanel.panelBackgroundColor,
            "Rectangle.Rectangle.Обводка 1": theme.chat.inputPanel.panelControlAccentColor,
            "Path.Path.Обводка 1": theme.chat.inputPanel.panelControlAccentColor,
            "Path 4.Path 4.Обводка 1": theme.chat.inputPanel.panelControlAccentColor
        ].forEach { key, value in
            let colorCallback = LOTColorValueCallback(color: value.cgColor)
            self.colorCallbacks.append(colorCallback)
            idleView.setValueDelegate(colorCallback, for: LOTKeypath(string: "\(key).Color"))
        }
        
        [
            "Path.Path.Обводка 1": theme.chat.inputPanel.panelControlAccentColor,
            "Path.Path.Заливка 1": theme.chat.inputPanel.panelBackgroundColor,
            "Rectangle.Rectangle.Обводка 1": theme.chat.inputPanel.panelControlAccentColor,
            "Rectangle.Заливка 1": theme.chat.inputPanel.panelControlAccentColor,
            "Path 4.Path 4.Обводка 1": theme.chat.inputPanel.panelControlAccentColor
        ].forEach { key, value in
            let colorCallback = LOTColorValueCallback(color: value.cgColor)
            self.colorCallbacks.append(colorCallback)
            lockingView.setValueDelegate(colorCallback, for: LOTKeypath(string: "\(key).Color"))
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let superTest = super.hitTest(point, with: event)
        if superTest === lockingView {
            return self
        }
        return superTest
    }
}
