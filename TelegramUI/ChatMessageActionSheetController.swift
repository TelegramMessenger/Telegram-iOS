import Foundation
import Display
import AsyncDisplayKit

final class ChatMessageActionSheetController: ViewController {
    var controllerNode: ChatMessageActionSheetControllerNode {
        return self.displayNode as! ChatMessageActionSheetControllerNode
    }
    
    private let theme: PresentationTheme
    private let actions: [ChatMessageContextMenuSheetAction]
    private let dismissed: () -> Void
    
    init(theme: PresentationTheme, actions: [ChatMessageContextMenuSheetAction], dismissed: @escaping () -> Void) {
        self.theme = theme
        self.actions = actions
        self.dismissed = dismissed
        
        super.init(navigationBarTheme: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = ChatMessageActionSheetControllerNode(theme: self.theme, actions: self.actions, dismissed: self.dismissed)
        self.displayNodeDidLoad()
    }
}
