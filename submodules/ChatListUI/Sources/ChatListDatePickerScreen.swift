import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramStringFormatting
import SolidRoundedButtonNode
import PresentationDataUtils

final class ChatListDatePickerScreen: ViewController {
    private var controllerNode: ChatListDatePickerScreenNode {
        return self.displayNode as! ChatListDatePickerScreenNode
    }
    
    private var animatedIn = false
    
    private let context: AccountContext
    private let dismissByTapOutside: Bool
    private let completion: (Int32?, Bool) -> Void
    
    private var presentationDataDisposable: Disposable?
    
    init(context: AccountContext, dismissByTapOutside: Bool = true, completion: @escaping (Int32?, Bool) -> Void) {
        self.context = context
        self.dismissByTapOutside = dismissByTapOutside
        self.completion = completion
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.blocksBackgroundWhenInOverlay = true
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatListDatePickerScreenNode(context: self.context, dismissByTapOutside: self.dismissByTapOutside)
        self.controllerNode.completion = { [weak self] date, after in
            guard let strongSelf = self else {
                return
            }
            strongSelf.completion(date, after)
            strongSelf.dismiss()
        }
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
    }
    
    override public func loadView() {
        super.loadView()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}

class ChatListDatePickerScreenNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let dismissByTapOutside: Bool
    
    private let dimNode: ASDisplayNode
    private let wrappingScrollNode: ASScrollNode
    private let contentContainerNode: ASDisplayNode
    private let effectNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let contentBackgroundNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let cancelButton: HighlightableButtonNode
    private let beforeButton: SolidRoundedButtonNode
    private let afterButton: SolidRoundedButtonNode
    
    private var pickerView: UIDatePicker?
    private let dateFormatter: DateFormatter
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var completion: ((Int32?, Bool) -> Void)?
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    
    init(context: AccountContext, dismissByTapOutside: Bool) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.dismissByTapOutside = dismissByTapOutside
        
        self.wrappingScrollNode = ASScrollNode()
        self.wrappingScrollNode.view.alwaysBounceVertical = true
        self.wrappingScrollNode.view.delaysContentTouches = false
        self.wrappingScrollNode.view.canCancelContentTouches = true
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.isOpaque = false

        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.clipsToBounds = true
        self.backgroundNode.cornerRadius = 16.0
        
        let backgroundColor: UIColor
        let textColor: UIColor
        let accentColor: UIColor
        let buttonColor: UIColor
        let buttonTextColor: UIColor
        let blurStyle: UIBlurEffect.Style

        backgroundColor = self.presentationData.theme.actionSheet.itemBackgroundColor
        textColor = self.presentationData.theme.actionSheet.primaryTextColor
        accentColor = self.presentationData.theme.actionSheet.controlAccentColor
        buttonColor = self.presentationData.theme.actionSheet.opaqueItemBackgroundColor
        buttonTextColor = accentColor
        blurStyle = self.presentationData.theme.actionSheet.backgroundType == .light ? .light : .dark
        
        self.effectNode = ASDisplayNode(viewBlock: {
            return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        })
        
        self.contentBackgroundNode = ASDisplayNode()
        self.contentBackgroundNode.backgroundColor = backgroundColor
        
        let title: String = "Set Date"
        
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(17.0), textColor: textColor)
        
        self.cancelButton = HighlightableButtonNode()
        self.cancelButton.setTitle(self.presentationData.strings.Common_Cancel, with: Font.regular(17.0), with: accentColor, for: .normal)
        
        self.beforeButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: self.presentationData.theme), height: 52.0, cornerRadius: 11.0, gloss: false)
        
        self.afterButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: buttonColor, foregroundColor: buttonTextColor), font: .regular, height: 52.0, cornerRadius: 11.0, gloss: false)
        self.afterButton.title = self.presentationData.strings.Conversation_ScheduleMessage_SendWhenOnline

        self.dateFormatter = DateFormatter()
        self.dateFormatter.timeStyle = .none
        self.dateFormatter.dateStyle = .short
        self.dateFormatter.timeZone = TimeZone.current
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        self.addSubnode(self.dimNode)
        
        self.wrappingScrollNode.view.delegate = self
        self.addSubnode(self.wrappingScrollNode)
        
        self.wrappingScrollNode.addSubnode(self.backgroundNode)
        self.wrappingScrollNode.addSubnode(self.contentContainerNode)
        
        self.backgroundNode.addSubnode(self.effectNode)
        self.backgroundNode.addSubnode(self.contentBackgroundNode)
        self.contentContainerNode.addSubnode(self.titleNode)
        self.contentContainerNode.addSubnode(self.cancelButton)
        self.contentContainerNode.addSubnode(self.beforeButton)
        self.contentContainerNode.addSubnode(self.afterButton)
        
        self.cancelButton.addTarget(self, action: #selector(self.cancelButtonPressed), forControlEvents: .touchUpInside)
        self.beforeButton.pressed = { [weak self] in
            if let strongSelf = self, let pickerView = strongSelf.pickerView {
                strongSelf.beforeButton.isUserInteractionEnabled = false
                strongSelf.completion?(Int32(pickerView.date.timeIntervalSince1970), false)
            }
        }
        self.afterButton.pressed = { [weak self] in
            if let strongSelf = self, let pickerView = strongSelf.pickerView {
                strongSelf.afterButton.isUserInteractionEnabled = false
                strongSelf.completion?(Int32(pickerView.date.timeIntervalSince1970), true)
            }
        }
        
        self.setupPickerView(currentTime: nil)
        self.updateButtonTitle()
    }
    
    func setupPickerView(currentTime: Int32? = nil) {
        var currentDate: Date?
        if let pickerView = self.pickerView {
            currentDate = pickerView.date
            pickerView.removeFromSuperview()
        }
        
        let textColor: UIColor = self.presentationData.theme.actionSheet.primaryTextColor
        
        let pickerView = UIDatePicker()
        pickerView.timeZone = TimeZone(secondsFromGMT: 0)
        pickerView.setValue(textColor, forKey: "textColor")
        pickerView.datePickerMode = .countDownTimer
        pickerView.datePickerMode = .date
        pickerView.locale = Locale.current
        pickerView.timeZone = TimeZone.current
        pickerView.minuteInterval = 1
        self.contentContainerNode.view.addSubview(pickerView)
        pickerView.addTarget(self, action: #selector(self.datePickerUpdated), for: .valueChanged)
        self.pickerView = pickerView
        
        self.updateMinimumDate(currentTime: currentTime)
        if let currentDate = currentDate {
            pickerView.date = currentDate
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        let previousTheme = self.presentationData.theme
        self.presentationData = presentationData
        
        if let effectView = self.effectNode.view as? UIVisualEffectView {
            effectView.effect = UIBlurEffect(style: presentationData.theme.actionSheet.backgroundType == .light ? .light : .dark)
        }
        
        self.contentBackgroundNode.backgroundColor = self.presentationData.theme.actionSheet.itemBackgroundColor
        self.titleNode.attributedText = NSAttributedString(string: self.titleNode.attributedText?.string ?? "", font: Font.bold(17.0), textColor: self.presentationData.theme.actionSheet.primaryTextColor)
        
        if previousTheme !== presentationData.theme, let (layout, navigationBarHeight) = self.containerLayout {
            self.setupPickerView()
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
        
        self.cancelButton.setTitle(self.presentationData.strings.Common_Cancel, with: Font.regular(17.0), with: self.presentationData.theme.actionSheet.controlAccentColor, for: .normal)
        self.beforeButton.updateTheme(SolidRoundedButtonTheme(theme: self.presentationData.theme))
        self.afterButton.updateTheme(SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.actionSheet.opaqueItemBackgroundColor, foregroundColor: self.presentationData.theme.actionSheet.controlAccentColor))
    }
    
    private func updateMinimumDate(currentTime: Int32? = nil) {
//        let timeZone = TimeZone(secondsFromGMT: 0)!
//        var calendar = Calendar(identifier: .gregorian)
//        calendar.timeZone = timeZone
//        let currentDate = Date()
//        var components = calendar.dateComponents(Set([.era, .year, .month, .day, .hour, .minute, .second]), from: currentDate)
//        components.second = 0
//        let minute = (components.minute ?? 0) % 5
        
        self.pickerView?.minimumDate = Date(timeIntervalSince1970: 1376438400.0)
        self.pickerView?.maximumDate = Date(timeIntervalSinceNow: 2.0)
        self.pickerView?.date = Date()
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.wrappingScrollNode.view.contentInsetAdjustmentBehavior = .never
        }
    }
    
    private func updateButtonTitle() {
        guard let date = self.pickerView?.date else {
            return
        }
                
        self.beforeButton.title = self.presentationData.strings.ChatList_Search_SearchBeforeDate(self.dateFormatter.string(from: date)).0
        self.afterButton.title = self.presentationData.strings.ChatList_Search_SearchAfterDate(self.dateFormatter.string(from: date)).0
    }
    
    @objc private func datePickerUpdated() {
        self.updateButtonTitle()
//        if let date = self.pickerView?.date, date < Date() {
//            self.beforeButton.alpha = 0.4
//            self.beforeButton.isUserInteractionEnabled = false
//        } else {
//            self.beforeButton.alpha = 1.0
//            self.beforeButton.isUserInteractionEnabled = true
//        }
    }
    
    @objc func cancelButtonPressed() {
        self.cancel?()
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if self.dismissByTapOutside, case .ended = recognizer.state {
            self.cancelButtonPressed()
        }
    }
    
    func animateIn() {
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        
        let dimPosition = self.dimNode.layer.position
        self.dimNode.layer.animatePosition(from: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), to: dimPosition, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.layer.animateBoundsOriginYAdditive(from: -offset, to: 0.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        var dimCompleted = false
        var offsetCompleted = false
        
        let internalCompletion: () -> Void = { [weak self] in
            if let strongSelf = self, dimCompleted && offsetCompleted {
                strongSelf.dismiss?()
            }
            completion?()
        }
        
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
            dimCompleted = true
            internalCompletion()
        })
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        let dimPosition = self.dimNode.layer.position
        self.dimNode.layer.animatePosition(from: dimPosition, to: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.layer.animateBoundsOriginYAdditive(from: 0.0, to: -offset, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            offsetCompleted = true
            internalCompletion()
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            if !self.contentBackgroundNode.bounds.contains(self.convert(point, to: self.contentBackgroundNode)) {
                return self.dimNode.view
            }
        }
        return super.hitTest(point, with: event)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let contentOffset = scrollView.contentOffset
        let additionalTopHeight = max(0.0, -contentOffset.y)
        
        if additionalTopHeight >= 30.0 {
            self.cancelButtonPressed()
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.statusBar, .input])
        let cleanInsets = layout.insets(options: [.statusBar])
        insets.top = max(10.0, insets.top)
        
        var buttonOffset: CGFloat = 64.0
        
        let bottomInset: CGFloat = 10.0 + cleanInsets.bottom
        let titleHeight: CGFloat = 54.0
        var contentHeight = titleHeight + bottomInset + 52.0 + 17.0
        let pickerHeight: CGFloat = min(216.0, layout.size.height - contentHeight)
        contentHeight = titleHeight + bottomInset + 52.0 + 17.0 + pickerHeight + buttonOffset
        
        let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: layout.safeInsets.left)
        
        let sideInset = floor((layout.size.width - width) / 2.0)
        let contentContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - contentHeight), size: CGSize(width: width, height: contentHeight))
        let contentFrame = contentContainerFrame
        
        var backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY), size: CGSize(width: contentFrame.width, height: contentFrame.height + 2000.0))
        if backgroundFrame.minY < contentFrame.minY {
            backgroundFrame.origin.y = contentFrame.minY
        }
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        transition.updateFrame(node: self.effectNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.contentBackgroundNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let titleSize = self.titleNode.measure(CGSize(width: width, height: titleHeight))
        let titleFrame = CGRect(origin: CGPoint(x: floor((contentFrame.width - titleSize.width) / 2.0), y: 16.0), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        let cancelSize = self.cancelButton.measure(CGSize(width: width, height: titleHeight))
        let cancelFrame = CGRect(origin: CGPoint(x: 16.0, y: 16.0), size: cancelSize)
        transition.updateFrame(node: self.cancelButton, frame: cancelFrame)
        
        let buttonInset: CGFloat = 16.0
        let doneButtonHeight = self.beforeButton.updateLayout(width: contentFrame.width - buttonInset * 2.0, transition: transition)
        transition.updateFrame(node: self.beforeButton, frame: CGRect(x: buttonInset, y: contentHeight - doneButtonHeight - insets.bottom - 16.0 - buttonOffset, width: contentFrame.width, height: doneButtonHeight))
        
        let onlineButtonHeight = self.afterButton.updateLayout(width: contentFrame.width - buttonInset * 2.0, transition: transition)
        transition.updateFrame(node: self.afterButton, frame: CGRect(x: buttonInset, y: contentHeight - onlineButtonHeight - insets.bottom - 16.0, width: contentFrame.width, height: onlineButtonHeight))
        
        self.pickerView?.frame = CGRect(origin: CGPoint(x: 0.0, y: 54.0), size: CGSize(width: contentFrame.width, height: pickerHeight))
        
        transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
    }
}
