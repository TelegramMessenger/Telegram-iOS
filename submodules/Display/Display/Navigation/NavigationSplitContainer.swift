import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

final class NavigationSplitContainer: ASDisplayNode {
    private var theme: NavigationControllerTheme
    
    private let masterContainer: NavigationContainer
    private let detailContainer: NavigationContainer
    private let separator: ASDisplayNode
    
    private var masterControllers: [ViewController] = []
    private var detailControllers: [ViewController] = []
    
    init(theme: NavigationControllerTheme, controllerRemoved: @escaping (ViewController) -> Void) {
        self.theme = theme
        
        self.masterContainer = NavigationContainer(controllerRemoved: controllerRemoved)
        self.masterContainer.clipsToBounds = true
        
        self.detailContainer = NavigationContainer(controllerRemoved: controllerRemoved)
        self.detailContainer.clipsToBounds = true
        
        self.separator = ASDisplayNode()
        self.separator.backgroundColor = theme.navigationBar.separatorColor
        
        super.init()
        
        self.addSubnode(self.masterContainer)
        self.addSubnode(self.detailContainer)
        self.addSubnode(self.separator)
    }
    
    func updateTheme(theme: NavigationControllerTheme) {
        self.separator.backgroundColor = theme.navigationBar.separatorColor
    }
    
    func update(layout: ContainerViewLayout, masterControllers: [ViewController], detailControllers: [ViewController], transition: ContainedViewLayoutTransition) {
        let masterWidth = min(max(320.0, floor(layout.size.width / 3.0)), floor(layout.size.width / 2.0))
        let detailWidth = layout.size.width - masterWidth
        
        transition.updateFrame(node: self.masterContainer, frame: CGRect(origin: CGPoint(), size: CGSize(width: masterWidth, height: layout.size.height)))
        transition.updateFrame(node: self.detailContainer, frame: CGRect(origin: CGPoint(x: masterWidth, y: 0.0), size: CGSize(width: detailWidth, height: layout.size.height)))
        transition.updateFrame(node: self.separator, frame: CGRect(origin: CGPoint(x: masterWidth, y: 0.0), size: CGSize(width: UIScreenPixel, height: layout.size.height)))
        
        self.masterContainer.update(layout: ContainerViewLayout(size: CGSize(width: masterWidth, height: layout.size.height), metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: layout.intrinsicInsets, safeInsets: layout.safeInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), canBeClosed: false, controllers: masterControllers, transition: transition)
        self.detailContainer.update(layout: ContainerViewLayout(size: CGSize(width: detailWidth, height: layout.size.height), metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: layout.intrinsicInsets, safeInsets: layout.safeInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), canBeClosed: true, controllers: detailControllers, transition: transition)
        
        var controllersUpdated = false
        if self.detailControllers.last !== detailControllers.last {
            controllersUpdated = true
        } else if self.masterControllers.count != masterControllers.count {
            controllersUpdated = true
        } else {
            for i in 0 ..< masterControllers.count {
                if masterControllers[i] !== self.masterControllers[i] {
                    controllersUpdated = true
                    break
                }
            }
        }
        
        self.masterControllers = masterControllers
        self.detailControllers = detailControllers
        
        if controllersUpdated {
            let data = self.detailControllers.last?.customData
            for controller in self.masterControllers {
                controller.updateNavigationCustomData(data, progress: 1.0, transition: transition)
            }
        }
    }
}
