import Foundation
import TelegramLegacyComponents
import Display

final class LegacyEmptyController: TGViewController {
    override func viewDidLoad() {
        self.view.backgroundColor = nil
        self.view.isOpaque = false
    }
}

final class LegacyOverlayWindowHost: TGOverlayControllerWindow {
    private let presentInWindow: (ViewController) -> Void
    private let content: LegacyController
    
    init(presentInWindow: @escaping (ViewController) -> Void, parentController: TGViewController!, contentController: TGOverlayController!, keepKeyboard: Bool) {
        self.content = LegacyController(legacyController: contentController, presentation: .custom)
        self.presentInWindow = presentInWindow
        
        super.init(parentController: parentController, contentController: contentController, keepKeyboard: keepKeyboard)
        
        self.rootViewController = nil
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if !self._isHidden {
            self.content.dismiss()
        }
    }
    
    private var _isHidden = true
    override var isHidden: Bool {
        get {
            return self._isHidden
        } set(value) {
            if value != self._isHidden {
                self._isHidden = value
                if !value {
                    self.presentInWindow(self.content)
                } else {
                    self.content.dismiss()
                }
            }
        }
    }
    
    override func dismiss() {
        self.isHidden = true
    }
}
