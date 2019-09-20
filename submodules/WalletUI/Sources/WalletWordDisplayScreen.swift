import Foundation
import UIKit
import AppBundle
import AccountContext
import TelegramPresentationData
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SolidRoundedButtonNode
import UndoUI
import AlertUI

public final class WalletWordDisplayScreen: ViewController {
    private let context: AccountContext
    private let tonContext: TonContext
    private var presentationData: PresentationData
    private let walletInfo: WalletInfo
    private let wordList: [String]
    
    private let startTime: Double
    
    public init(context: AccountContext, tonContext: TonContext, walletInfo: WalletInfo, wordList: [String]) {
        self.context = context
        self.tonContext = tonContext
        self.walletInfo = walletInfo
        self.wordList = wordList
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let defaultNavigationPresentationData = NavigationBarPresentationData(presentationTheme: self.presentationData.theme, presentationStrings: self.presentationData.strings)
        let navigationBarTheme = NavigationBarTheme(buttonColor: defaultNavigationPresentationData.theme.buttonColor, disabledButtonColor: defaultNavigationPresentationData.theme.disabledButtonColor, primaryTextColor: defaultNavigationPresentationData.theme.primaryTextColor, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: defaultNavigationPresentationData.theme.badgeBackgroundColor, badgeStrokeColor: defaultNavigationPresentationData.theme.badgeStrokeColor, badgeTextColor: defaultNavigationPresentationData.theme.badgeTextColor)
        
        self.startTime = Date().timeIntervalSince1970
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: defaultNavigationPresentationData.strings))
        
        self.navigationPresentation = .modalInLargeLayout
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.navigationBar?.intrinsicCanTransitionInline = false
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func backPressed() {
        self.dismiss()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = WalletWordDisplayScreenNode(presentationData: self.presentationData, wordList: self.wordList, action: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let deltaTime = Date().timeIntervalSince1970 - strongSelf.startTime
            let minimalTimeout: Double
            #if DEBUG
            minimalTimeout = 1.0
            #else
            minimalTimeout = 60.0
            #endif
            if deltaTime < minimalTimeout {
                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: "Sure Done?", text: "You didn't have enough time to write those words down.", actions: [TextAlertAction(type: .defaultAction, title: "OK, Sorry", action: {
                    guard let strongSelf = self else {
                        return
                    }
                    if let path = getAppBundle().path(forResource: "thumbsup", ofType: "tgs") {
                        strongSelf.present(UndoOverlayController(context: strongSelf.context, content: UndoOverlayContent.emoji(account: strongSelf.context.account, path: path, text: "Apologies Accepted"), elevatedLayout: false, animateInAsReplacement: false, action: { _ in }), in: .current)
                    }
                })]), in: .window(.root))
            } else {
                strongSelf.push(WalletWordCheckScreen(context: strongSelf.context, tonContext: strongSelf.tonContext, mode: .verify(strongSelf.walletInfo, strongSelf.wordList)))
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
    private var presentationData: PresentationData
    private let wordList: [String]
    private let action: () -> Void
    
    private let navigationBackgroundNode: ASDisplayNode
    private let navigationSeparatorNode: ASDisplayNode
    private let navigationTitleNode: ImmediateTextNode
    private let scrollNode: ASScrollNode
    private let iconNode: ASImageNode
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let wordNodes: [(ImmediateTextNode, ImmediateTextNode, ImmediateTextNode)]
    private let buttonNode: SolidRoundedButtonNode
    
    private var navigationHeight: CGFloat?
    
    init(presentationData: PresentationData, wordList: [String], action: @escaping () -> Void) {
        self.presentationData = presentationData
        self.wordList = wordList
        self.action = action
        
        self.navigationBackgroundNode = ASDisplayNode()
        self.navigationBackgroundNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.backgroundColor
        self.navigationBackgroundNode.alpha = 0.0
        self.navigationSeparatorNode = ASDisplayNode()
        self.navigationSeparatorNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        
        self.scrollNode = ASScrollNode()
        
        self.iconNode = ASImageNode()
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        
        let title: String = "24 Secret Words"
        let text: String = "Write down these 24 words in the correct order and store them in a secret place.\n\nUse these secret words to restore access to your wallet if you lose your passcode or Telegram account."
        let buttonText: String = "Done"
        
        self.iconNode.image = UIImage(bundleImageName: "Settings/Wallet/WordsDisplayIcon")
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(32.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        
        self.navigationTitleNode = ImmediateTextNode()
        self.navigationTitleNode.displaysAsynchronously = false
        self.navigationTitleNode.attributedText = NSAttributedString(string: title, font: Font.bold(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.navigationTitleNode.maximumNumberOfLines = 0
        self.navigationTitleNode.textAlignment = .center
        
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
        
        self.buttonNode = SolidRoundedButtonNode(title: buttonText, theme: SolidRoundedButtonTheme(theme: self.presentationData.theme), height: 50.0, cornerRadius: 10.0, gloss: false)
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.scrollNode)
        
        self.scrollNode.addSubnode(self.iconNode)
        self.scrollNode.addSubnode(self.titleNode)
        self.scrollNode.addSubnode(self.textNode)
        self.scrollNode.addSubnode(self.buttonNode)
        
        for (indexNode, indexDotNode, wordNode) in self.wordNodes {
            self.scrollNode.addSubnode(indexNode)
            self.scrollNode.addSubnode(indexDotNode)
            self.scrollNode.addSubnode(wordNode)
        }
        
        self.navigationBackgroundNode.addSubnode(self.navigationSeparatorNode)
        self.navigationBackgroundNode.addSubnode(self.navigationTitleNode)
        self.addSubnode(self.navigationBackgroundNode)
        
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
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let navigationHeight = self.navigationHeight ?? 0.0
        let alpha: CGFloat = scrollView.contentOffset.y >= (self.titleNode.frame.maxY - navigationHeight) ? 1.0 : 0.0
        if self.navigationBackgroundNode.alpha != alpha {
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.12, curve: .easeInOut)
            transition.updateAlpha(node: self.navigationBackgroundNode, alpha: alpha, beginWithCurrentState: true)
        }
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.navigationHeight = navigationHeight
        
        let sideInset: CGFloat = 32.0
        let buttonSideInset: CGFloat = 48.0
        let iconSpacing: CGFloat = 5.0
        let titleSpacing: CGFloat = 19.0
        let textSpacing: CGFloat = 37.0
        let buttonHeight: CGFloat = 50.0
        let buttonSpacing: CGFloat = 45.0
        let wordSpacing: CGFloat = 12.0
        let indexSpacing: CGFloat = 4.0
        
        transition.updateFrame(node: self.navigationBackgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: navigationHeight)))
        transition.updateFrame(node: self.navigationSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationHeight), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let iconSize = self.iconNode.image?.size ?? CGSize(width: 50.0, height: 50.0)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        let navigationTitleSize = self.navigationTitleNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        let textSize = self.textNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        
        var contentHeight: CGFloat = 0.0
        
        let contentVerticalOrigin = navigationHeight + 10.0
        
        let iconFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: contentVerticalOrigin), size: iconSize)
        transition.updateFrameAdditive(node: self.iconNode, frame: iconFrame)
        let titleFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: iconFrame.maxY + iconSpacing), size: titleSize)
        transition.updateFrameAdditive(node: self.titleNode, frame: titleFrame)
        let textFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - textSize.width) / 2.0), y: titleFrame.maxY + titleSpacing), size: textSize)
        transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
        
        transition.updateFrameAdditive(node: self.navigationTitleNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - navigationTitleSize.width) / 2.0), y: navigationHeight - 44.0 + floor((44.0 - navigationTitleSize.height) / 2.0)), size: navigationTitleSize))
        
        contentHeight = textFrame.maxY + textSpacing
        
        let rowWidth = layout.size.width - buttonSideInset * 2.0
        let rowCount = self.wordNodes.count / 2
        
        let indexWidth: CGFloat = 16.0
        
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
        
        let minimalFullscreenBottomInset: CGFloat = 74.0
        let minimalScrollBottomInset: CGFloat = 30.0
        let fullscreenBottomInset = layout.intrinsicInsets.bottom + minimalFullscreenBottomInset
        let scrollBottomInset = layout.intrinsicInsets.bottom + minimalScrollBottomInset
        
        let buttonWidth = layout.size.width - buttonSideInset * 2.0
        
        let buttonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonWidth) / 2.0), y: max(contentHeight + buttonSpacing, layout.size.height - scrollBottomInset - buttonHeight)), size: CGSize(width: buttonWidth, height: buttonHeight))
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        self.buttonNode.updateLayout(width: buttonFrame.width, transition: transition)
        
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: max(layout.size.height, buttonFrame.maxY + scrollBottomInset))
    }
}
