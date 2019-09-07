import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

struct ChatMediaInputPaneScrollState {
    let absoluteOffset: CGFloat?
    let relativeChange: CGFloat
}

class ChatMediaInputPane: ASDisplayNode {
    var inputNodeInteraction: ChatMediaInputNodeInteraction?
    var collectionListPanelOffset: CGFloat = 0.0
    var isEmpty: Bool {
        return false
    }
    
    func updateLayout(size: CGSize, topInset: CGFloat, bottomInset: CGFloat, isExpanded: Bool, isVisible: Bool, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition) {
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
    }
}
