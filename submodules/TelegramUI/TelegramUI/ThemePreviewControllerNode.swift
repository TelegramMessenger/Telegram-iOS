import Foundation
import UIKit
import Display
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences

class ThemePreviewControllerNode: ASDisplayNode {
    private let context: AccountContext
    private let previewTheme: PresentationTheme
    
    private var messageNodes: [ListViewItemNode]?
    private let toolbarNode: WallpaperGalleryToolbarNode
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    init(context: AccountContext, previewTheme: PresentationTheme, dismiss: @escaping () -> Void, apply: @escaping () -> Void) {
        self.context = context
        self.previewTheme = previewTheme
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        
        self.toolbarNode = WallpaperGalleryToolbarNode(theme: presentationData.theme, strings: presentationData.strings)
        
        super.init()
        
        self.addSubnode(self.toolbarNode)
        
        self.toolbarNode.cancel = { [weak self] in
            dismiss()
        }
        self.toolbarNode.done = { [weak self] in
            apply()
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let hadLayout = self.validLayout != nil
        
        transition.updateFrame(node: self.toolbarNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - 49.0 - layout.intrinsicInsets.bottom), size: CGSize(width: layout.size.width, height: 49.0 + layout.intrinsicInsets.bottom)))
        self.toolbarNode.updateLayout(size: CGSize(width: layout.size.width, height: 49.0), layout: layout, transition: transition)
    }
}
