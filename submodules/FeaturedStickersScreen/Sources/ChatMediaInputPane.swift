import Foundation
import AsyncDisplayKit
import Display
import ChatPresentationInterfaceState
import TelegramPresentationData

open class ChatMediaInputPane: ASDisplayNode {
    var inputNodeInteraction: ChatMediaInputNodeInteraction?
    var collectionListPanelOffset: CGFloat = 0.0
    var isEmpty: Bool {
        return false
    }
    
    open func updateLayout(size: CGSize, topInset: CGFloat, bottomInset: CGFloat, isExpanded: Bool, isVisible: Bool, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition) {
    }
    
    open func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
    }
}
