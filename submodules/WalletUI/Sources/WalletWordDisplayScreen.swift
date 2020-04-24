import Foundation
import UIKit
import AppBundle
import SwiftSignalKit
import AsyncDisplayKit
import Display
import SolidRoundedButtonNode
import AlertUI
import AnimatedStickerNode
import WalletCore

public enum WalletWordDisplayScreenMode {
    case check
    case export
}

public final class WalletWordDisplayScreen: ViewController {
    private let context: WalletContext
    private var presentationData: WalletPresentationData
    private let walletInfo: WalletInfo
    private let wordList: [String]
    private let mode: WalletWordDisplayScreenMode
    
    private let startTime: Double
    private let idleTimerExtensionDisposable: Disposable
    
    private let walletCreatedPreloadState: Promise<WalletCreatedPreloadState?>?
    
    public init(context: WalletContext, walletInfo: WalletInfo, wordList: [String], mode: WalletWordDisplayScreenMode, walletCreatedPreloadState: Promise<WalletCreatedPreloadState?>?) {
        self.context = context
        self.walletInfo = walletInfo
        self.wordList = wordList
        self.mode = mode
        self.walletCreatedPreloadState = walletCreatedPreloadState
        
        self.presentationData = context.presentationData
        
        let defaultTheme = self.presentationData.theme.navigationBar
        let navigationBarTheme = NavigationBarTheme(buttonColor: defaultTheme.buttonColor, disabledButtonColor: defaultTheme.disabledButtonColor, primaryTextColor: defaultTheme.primaryTextColor, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: defaultTheme.badgeBackgroundColor, badgeStrokeColor: defaultTheme.badgeStrokeColor, badgeTextColor: defaultTheme.badgeTextColor)
        
        self.startTime = Date().timeIntervalSince1970
        self.idleTimerExtensionDisposable = context.idleTimerExtension()
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: NavigationBarStrings(back: self.presentationData.strings.Wallet_Navigation_Back, close: self.presentationData.strings.Wallet_Navigation_Close)))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.statusBarStyle
        self.navigationPresentation = .modalInLargeLayout
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.navigationBar?.intrinsicCanTransitionInline = false
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Wallet_Navigation_Back, style: .plain, target: nil, action: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.idleTimerExtensionDisposable.dispose()
    }
    
    @objc private func backPressed() {
        self.dismiss()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = WalletWordDisplayScreenNode(presentationData: self.presentationData, wordList: self.wordList, action: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            if case .export = strongSelf.mode {
                strongSelf.dismiss()
                return
            }
            
            let deltaTime = Date().timeIntervalSince1970 - strongSelf.startTime
            let minimalTimeout: Double
            #if DEBUG
            minimalTimeout = 5.0
            #else
            minimalTimeout = 30.0
            #endif
            if deltaTime < minimalTimeout {
                strongSelf.present(standardTextAlertController(theme: strongSelf.presentationData.theme.alert, title: strongSelf.presentationData.strings.Wallet_Words_NotDoneTitle, text: strongSelf.presentationData.strings.Wallet_Words_NotDoneText, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Wallet_Words_NotDoneOk, action: {
                    guard let strongSelf = self else {
                        return
                    }
                    (strongSelf.displayNode as! WalletWordDisplayScreenNode).displayToast()
                })]), in: .window(.root))
            } else {
                var wordIndices: [Int] = []
                while wordIndices.count < 3 {
                    let index = Int(arc4random_uniform(UInt32(strongSelf.wordList.count)))
                    if !wordIndices.contains(index) {
                        wordIndices.append(index)
                    }
                }
                wordIndices.sort()
                strongSelf.push(WalletWordCheckScreen(context: strongSelf.context, mode: .verify(strongSelf.walletInfo, strongSelf.wordList, wordIndices), walletCreatedPreloadState: strongSelf.walletCreatedPreloadState))
            }
        })
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! WalletWordDisplayScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
    }
}

private final class WalletWordDisplayScreenNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private var presentationData: WalletPresentationData
    private let wordList: [String]
    private let action: () -> Void
    
    private let navigationBackgroundNode: ASDisplayNode
    private let navigationSeparatorNode: ASDisplayNode
    private let scrollNode: ASScrollNode
    private let animationNode: AnimatedStickerNode
    private let titleNodeContainer: ASDisplayNode
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let wordNodes: [(ImmediateTextNode, ImmediateTextNode, ImmediateTextNode)]
    private let buttonNode: SolidRoundedButtonNode
    
    private var toastNode: ToastNode?
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    private var navigationHeight: CGFloat?
    
    init(presentationData: WalletPresentationData, wordList: [String], action: @escaping () -> Void) {
        self.presentationData = presentationData
        self.wordList = wordList
        self.action = action
        
        self.navigationBackgroundNode = ASDisplayNode()
        self.navigationBackgroundNode.backgroundColor = self.presentationData.theme.navigationBar.backgroundColor
        self.navigationBackgroundNode.alpha = 0.0
        self.navigationSeparatorNode = ASDisplayNode()
        self.navigationSeparatorNode.backgroundColor = self.presentationData.theme.navigationBar.separatorColor
        
        self.scrollNode = ASScrollNode()
        
        self.animationNode = AnimatedStickerNode()
        if let path = getAppBundle().path(forResource: "WalletWordList", ofType: "tgs") {
            self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 264, height: 264, playbackMode: .once, mode: .direct)
            self.animationNode.visibility = true
        }
        
        let title: String = self.presentationData.strings.Wallet_Words_Title
        let text: String = self.presentationData.strings.Wallet_Words_Text
        let buttonText: String = self.presentationData.strings.Wallet_Words_Done
        
        self.titleNodeContainer = ASDisplayNode()
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(32.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.textNode.maximumNumberOfLines = 0
        self.textNode.lineSpacing = 0.1
        self.textNode.textAlignment = .center
        
        var wordNodes: [(ImmediateTextNode, ImmediateTextNode, ImmediateTextNode)] = []
        
        for i in 0 ..< wordList.count {
            let indexNode = ImmediateTextNode()
            indexNode.displaysAsynchronously = false
            indexNode.attributedText = NSAttributedString(string: "\(i + 1)", font: Font.regular(18.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor)
            indexNode.maximumNumberOfLines = 1
            indexNode.textAlignment = .left
            
            let indexDotNode = ImmediateTextNode()
            indexDotNode.displaysAsynchronously = false
            indexDotNode.attributedText = NSAttributedString(string: ".", font: Font.regular(18.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor)
            indexDotNode.maximumNumberOfLines = 1
            indexDotNode.textAlignment = .left
            
            let wordNode = ImmediateTextNode()
            wordNode.displaysAsynchronously = false
            wordNode.attributedText = NSAttributedString(string: wordList[i], font: Font.semibold(18.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
            wordNode.maximumNumberOfLines = 1
            wordNode.textAlignment = .left
            
            wordNodes.append((indexNode, indexDotNode, wordNode))
        }
        
        self.wordNodes = wordNodes
        
        self.buttonNode = SolidRoundedButtonNode(title: buttonText, theme: SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.setup.buttonFillColor, foregroundColor: self.presentationData.theme.setup.buttonForegroundColor), height: 50.0, cornerRadius: 10.0, gloss: false)
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.scrollNode)
        
        self.scrollNode.addSubnode(self.animationNode)
        self.scrollNode.addSubnode(self.textNode)
        self.scrollNode.addSubnode(self.buttonNode)
        
        for (indexNode, indexDotNode, wordNode) in self.wordNodes {
            self.scrollNode.addSubnode(indexNode)
            self.scrollNode.addSubnode(indexDotNode)
            self.scrollNode.addSubnode(wordNode)
        }
        
        self.navigationBackgroundNode.addSubnode(self.navigationSeparatorNode)
        self.addSubnode(self.navigationBackgroundNode)
        
        self.titleNodeContainer.addSubnode(self.titleNode)
        self.addSubnode(self.titleNodeContainer)
        
        self.buttonNode.pressed = {
            action()
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.alwaysBounceVertical = false
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        self.scrollNode.view.delegate = self
        
       
        #if DEBUG
        self.textNode.view.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(self.textLongPressGesture(_:))))
        #endif
    }
    
    @objc func textLongPressGesture(_ recognizer: UILongPressGestureRecognizer) {
        if case .began = recognizer.state {
            UIPasteboard.general.string = self.wordList.joined(separator: "\n")
        }
    }
    
    private var listTitleFrame: CGRect?
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateTitle()
    }
    
    private func updateTitle() {
        guard let layout = self.validLayout, let listTitleFrame = self.listTitleFrame else {
            return
        }
        let scrollView = self.scrollNode.view
        
        let navigationHeight = self.navigationHeight ?? 0.0
        let nominalNavigationHeight = navigationHeight - (layout.0.statusBarHeight ?? 0.0)
        
        let minY = navigationHeight - nominalNavigationHeight + floor(nominalNavigationHeight / 2.0)
        let maxY = minY + nominalNavigationHeight
        let y = max(minY, -scrollView.contentOffset.y + listTitleFrame.midY)
        var t = (y - minY) / (maxY - minY)
        t = max(0.0, min(1.0, t))
        
        let minScale: CGFloat = 0.5
        let maxScale: CGFloat = 1.0
        let scale = t * maxScale + (1.0 - t) * minScale
        
        self.titleNodeContainer.frame = CGRect(origin: CGPoint(x: scrollView.bounds.width / 2.0, y: y), size: CGSize())
        self.titleNodeContainer.subnodeTransform = CATransform3DMakeScale(scale, scale, 1.0)
        
        let alpha: CGFloat = (t <= 0.0 + CGFloat.ulpOfOne) ? 1.0 : 0.0
        if self.navigationBackgroundNode.alpha != alpha {
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
            transition.updateAlpha(node: self.navigationBackgroundNode, alpha: alpha, beginWithCurrentState: true)
        }
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationHeight)
        self.navigationHeight = navigationHeight
        
        let sideInset: CGFloat = 32.0
        let buttonSideInset: CGFloat = 48.0
        let iconSpacing: CGFloat = 18.0
        let titleSpacing: CGFloat = 19.0
        let textSpacing: CGFloat = 37.0
        let buttonHeight: CGFloat = 50.0
        let buttonSpacing: CGFloat = 45.0
        let wordSpacing: CGFloat = 12.0
        let indexSpacing: CGFloat = 4.0
        
        transition.updateFrame(node: self.navigationBackgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: navigationHeight)))
        transition.updateFrame(node: self.navigationSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationHeight), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let iconSize = CGSize(width: 132.0, height: 132.0)
        self.animationNode.updateLayout(size: iconSize)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        let textSize = self.textNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        
        var contentHeight: CGFloat = 0.0
        
        let contentVerticalOrigin = navigationHeight + 10.0
        
        let iconFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0) + 12.0, y: contentVerticalOrigin), size: iconSize)
        transition.updateFrameAdditive(node: self.animationNode, frame: iconFrame)
        let titleFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: iconFrame.maxY + iconSpacing), size: titleSize)
        self.listTitleFrame = titleFrame
        transition.updateFrameAdditive(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((-titleFrame.width) / 2.0), y: floor((-titleFrame.height) / 2.0)), size: titleFrame.size))
        let textFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - textSize.width) / 2.0), y: titleFrame.maxY + titleSpacing), size: textSize)
        transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
        
        contentHeight = textFrame.maxY + textSpacing
        
        let rowCount = self.wordNodes.count / 2
        
        var wordSizes: [(CGSize, CGSize)] = []
        var columnIndexWidth: [CGFloat] = [0.0, 0.0]
        var columnWordWidth: [CGFloat] = [0.0, 0.0]
        var dotSize: CGSize = CGSize()
        
        for i in 0 ..< self.wordNodes.count {
            let indexSize = self.wordNodes[i].0.updateLayout(CGSize(width: 200.0, height: 100.0))
            dotSize = self.wordNodes[i].1.updateLayout(CGSize(width: 200.0, height: 100.0))
            let wordSize = self.wordNodes[i].2.updateLayout(CGSize(width: 200.0, height: 100.0))
            wordSizes.append((indexSize, wordSize))
            let column = i / rowCount
            columnIndexWidth[column] = max(columnIndexWidth[column], indexSize.width)
            columnWordWidth[column] = max(columnWordWidth[column], wordSize.width)
        }
        
        for column in 0 ..< 2 {
            var columnHeight: CGFloat = 0.0
            for i in 0 ..< self.wordNodes.count {
                if !columnHeight.isZero {
                    columnHeight += wordSpacing
                }
                if i / rowCount != column {
                    continue
                }
                
                let horizontalOrigin: CGFloat
                let verticalOrigin: CGFloat = contentHeight + columnHeight
                if column == 0 {
                    horizontalOrigin = buttonSideInset + columnIndexWidth[column]
                } else {
                    horizontalOrigin = layout.size.width - buttonSideInset - columnWordWidth[column] - indexSpacing
                }
                let indexSize = self.wordNodes[i].0.updateLayout(CGSize(width: 200.0, height: 100.0))
                let wordSize = self.wordNodes[i].2.updateLayout(CGSize(width: 200.0, height: 100.0))
                transition.updateFrameAdditive(node: self.wordNodes[i].0, frame: CGRect(origin: CGPoint(x: horizontalOrigin - indexSize.width - dotSize.width, y: verticalOrigin), size: indexSize))
                transition.updateFrameAdditive(node: self.wordNodes[i].1, frame: CGRect(origin: CGPoint(x: horizontalOrigin - dotSize.width, y: verticalOrigin), size: indexSize))
                transition.updateFrameAdditive(node: self.wordNodes[i].2, frame: CGRect(origin: CGPoint(x: horizontalOrigin + indexSpacing, y: verticalOrigin), size: wordSize))
                columnHeight += wordSize.height
            }
            
            if column == 1 {
                contentHeight += columnHeight
            }
        }
        
        let minimalScrollBottomInset: CGFloat = 30.0
        let scrollBottomInset = layout.intrinsicInsets.bottom + minimalScrollBottomInset
        
        let buttonWidth = layout.size.width - buttonSideInset * 2.0
        
        let buttonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonWidth) / 2.0), y: max(contentHeight + buttonSpacing, layout.size.height - scrollBottomInset - buttonHeight)), size: CGSize(width: buttonWidth, height: buttonHeight))
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        let _ = self.buttonNode.updateLayout(width: buttonFrame.width, transition: transition)
        
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: max(layout.size.height, buttonFrame.maxY + scrollBottomInset))
        
        self.updateTitle()
    }
    
    func displayToast() {
        if self.toastNode != nil {
            return
        }
        
        if let path = getAppBundle().path(forResource: "WalletApologiesAccepted", ofType: "tgs") {
            let toastNode = ToastNode(theme: self.presentationData.theme, animationPath: path, text: self.presentationData.strings.Wallet_Words_NotDoneResponse)
            self.toastNode = toastNode
            if let (layout, _) = self.validLayout {
                toastNode.update(layout: layout, transition: .immediate)
            }
            self.addSubnode(toastNode)
            toastNode.show(removed: { [weak self, weak toastNode] in
                guard let strongSelf = self, let toastNode = toastNode else {
                    return
                }
                toastNode.removeFromSupernode()
                if toastNode === strongSelf.toastNode {
                    strongSelf.toastNode = nil
                }
            })
        }
    }
}
