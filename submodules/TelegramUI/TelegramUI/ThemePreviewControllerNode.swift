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
    private var presentationData: PresentationData
    
    private var messageNodes: [ListViewItemNode]?
    private let toolbarNode: WallpaperGalleryToolbarNode
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    init(context: AccountContext, previewTheme: PresentationTheme, dismiss: @escaping () -> Void, apply: @escaping () -> Void) {
        self.context = context
        self.previewTheme = previewTheme
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.toolbarNode = WallpaperGalleryToolbarNode(theme: self.previewTheme, strings: self.presentationData.strings)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        if case let .color(value) = self.previewTheme.chat.defaultWallpaper {
            self.backgroundColor = UIColor(rgb: UInt32(bitPattern: value))
        } else {
            self.backgroundColor = self.previewTheme.list.plainBackgroundColor
        }
        
        self.addSubnode(self.toolbarNode)
        
        self.toolbarNode.cancel = {
            dismiss()
        }
        self.toolbarNode.done = {
            apply()
        }
    }
    
    func animateIn(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.toolbarNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - 49.0 - layout.intrinsicInsets.bottom), size: CGSize(width: layout.size.width, height: 49.0 + layout.intrinsicInsets.bottom)))
        self.toolbarNode.updateLayout(size: CGSize(width: layout.size.width, height: 49.0), layout: layout, transition: transition)
    }
}
