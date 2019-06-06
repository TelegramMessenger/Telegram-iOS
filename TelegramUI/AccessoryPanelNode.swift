import Foundation
import UIKit
import AsyncDisplayKit

class AccessoryPanelNode: ASDisplayNode {
    var dismiss: (() -> Void)?
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
    }
    
    func updateState(size: CGSize, interfaceState: ChatPresentationInterfaceState) {
    }
}
