import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData

final class ChatMessageActionSheetController: ViewController {
    var controllerNode: ChatMessageActionSheetControllerNode {
        return self.displayNode as! ChatMessageActionSheetControllerNode
    }
    
    private let theme: PresentationTheme
    private let actions: [ChatMessageContextMenuSheetAction]
    private let dismissed: () -> Void
    private weak var associatedController: ViewController?
    
    init(theme: PresentationTheme, actions: [ChatMessageContextMenuSheetAction], dismissed: @escaping () -> Void, associatedController: ViewController?) {
        self.theme = theme
        self.actions = actions
        self.dismissed = dismissed
        self.associatedController = associatedController
        
        super.init(navigationBarPresentationData: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = ChatMessageActionSheetControllerNode(theme: self.theme, actions: self.actions, dismissed: self.dismissed, associatedController: self.associatedController)
        self.displayNodeDidLoad()
    }
    
    override func dismiss(completion: (() -> Void)? = nil) {
        self.presentingViewController?.dismiss(animated: false, completion: nil)
    }
}
