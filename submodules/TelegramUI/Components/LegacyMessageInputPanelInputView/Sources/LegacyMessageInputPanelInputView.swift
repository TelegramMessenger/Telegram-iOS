import Foundation
import UIKit
import AsyncDisplayKit
import Display

public protocol LegacyMessageInputPanelInputView: UIView {
    var insertText: ((NSAttributedString) -> Void)? { get set }
    var deleteBackwards: (() -> Void)? { get set }
    var switchToKeyboard: (() -> Void)? { get set }
    var presentController: ((ViewController) -> Void)? { get set }
}
