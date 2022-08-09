//import Foundation
//import UIKit
//import AsyncDisplayKit
//import TelegramCore
//import Postbox
//import SwiftSignalKit
//import Display
//import TelegramPresentationData
//import TelegramUIPreferences
//import AccountContext
//import AppBundle
//import InstantPageUI
//
//final class BrowserInstantPageContent: ASDisplayNode, BrowserContent {
//    private let instantPageNode: InstantPageContentNode
//    
//    private var _state: BrowserContentState
//    private let statePromise: Promise<BrowserContentState>
//    
//    private let webPage: TelegramMediaWebpage
//    private var initialized = false
//    
//    var state: Signal<BrowserContentState, NoError> {
//        return self.statePromise.get()
//    }
//    
//    init(context: AccountContext, webPage: TelegramMediaWebpage, url: String) {
//        self.webPage = webPage
//        
//        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
//        self.instantPageNode = InstantPageContentNode(context: context, webPage: webPage, settings: nil, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, sourcePeerType: .contact, getNavigationController: { return nil }, present: { _, _ in }, pushController: { _ in }, openPeer: { _ in }, navigateBack: {})
//
//        let title: String
//        if case let .Loaded(content) = webPage.content {
//            title = content.title ?? ""
//        } else {
//            title = ""
//        }
//        
//        self._state = BrowserContentState(title: title, url: url, estimatedProgress: 0.0, isInstant: false)
//        self.statePromise = Promise<BrowserContentState>(self._state)
//        
//        super.init()
//        
//        self.addSubnode(self.instantPageNode)
//    }
//    
//    func navigateBack() {
//        
//    }
//    
//    func navigateForward() {
//        
//    }
//    
//    func setFontSize(_ fontSize: CGFloat) {
//        
//    }
//    
//    func setForceSerif(_ force: Bool) {
//        
//    }
//    
//    func setSearch(_ query: String?, completion: ((Int) -> Void)?) {
//        
//    }
//    
//    func scrollToPreviousSearchResult(completion: ((Int, Int) -> Void)?) {
//        
//    }
//    
//    func scrollToNextSearchResult(completion: ((Int, Int) -> Void)?) {
//        
//    }
//    
//    func scrollToTop() {
//        
//    }
//    
//    func updateLayout(size: CGSize, insets: UIEdgeInsets, transition: ContainedViewLayoutTransition) {
//        let layout = ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: insets.bottom, right: 0.0), safeInsets: UIEdgeInsets(top: 0.0, left: insets.left, bottom: 0.0, right: insets.right), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false)
//        self.instantPageNode.containerLayoutUpdated(layout, navigationBarHeight: 0.0, transition: transition)
//        self.instantPageNode.frame = CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height)
//        //transition.updateFrame(view: self.webView, frame: CGRect(origin: CGPoint(x: 0.0, y: 56.0), size: CGSize(width: size.width, height: size.height - 56.0)))
//        
//        if !self.initialized {
//            self.initialized = true
//            self.instantPageNode.updateWebPage(self.webPage, anchor: nil)
//        }
//    }
//}
