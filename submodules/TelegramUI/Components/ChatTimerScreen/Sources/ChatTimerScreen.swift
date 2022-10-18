import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import SolidRoundedButtonNode
import TelegramPresentationData
import PresentationDataUtils
import TelegramStringFormatting

public enum ChatTimerScreenStyle {
    case `default`
    case media
}

public enum ChatTimerScreenMode {
    case sendTimer
    case autoremove
    case mute
}

public final class ChatTimerScreen: ViewController {
    private var controllerNode: ChatTimerScreenNode {
        return self.displayNode as! ChatTimerScreenNode
    }
    
    private var animatedIn = false
    
    private let context: AccountContext
    private let peerId: PeerId
    private let style: ChatTimerScreenStyle
    private let mode: ChatTimerScreenMode
    private let currentTime: Int32?
    private let dismissByTapOutside: Bool
    private let completion: (Int32) -> Void
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: PeerId, style: ChatTimerScreenStyle, mode: ChatTimerScreenMode = .sendTimer, currentTime: Int32? = nil, dismissByTapOutside: Bool = true, completion: @escaping (Int32) -> Void) {
        self.context = context
        self.peerId = peerId
        self.style = style
        self.mode = mode
        self.currentTime = currentTime
        self.dismissByTapOutside = dismissByTapOutside
        self.completion = completion
        
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.blocksBackgroundWhenInOverlay = true
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatTimerScreenNode(context: self.context, presentationData: presentationData, style: self.style, mode: self.mode, currentTime: self.currentTime, dismissByTapOutside: self.dismissByTapOutside)
        self.controllerNode.completion = { [weak self] time in
            guard let strongSelf = self else {
                return
            }
            strongSelf.completion(time)
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
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

private protocol TimerPickerView: UIView {
    
}

private class TimerCustomPickerView: UIPickerView, TimerPickerView {
    var selectorColor: UIColor? = nil {
        didSet {
            for subview in self.subviews {
                if subview.bounds.height <= 1.0 {
                    subview.backgroundColor = self.selectorColor
                }
            }
        }
    }
    
    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        
        if let selectorColor = self.selectorColor {
            if subview.bounds.height <= 1.0 {
                subview.backgroundColor = selectorColor
            }
        }
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        if let selectorColor = self.selectorColor {
            for subview in self.subviews {
                if subview.bounds.height <= 1.0 {
                    subview.backgroundColor = selectorColor
                }
            }
        }
    }
}

private class TimerDatePickerView: UIDatePicker, TimerPickerView {
    var selectorColor: UIColor? = nil {
        didSet {
            for subview in self.subviews {
                if subview.bounds.height <= 1.0 {
                    subview.backgroundColor = self.selectorColor
                }
            }
        }
    }
    
    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        
        if let selectorColor = self.selectorColor {
            if subview.bounds.height <= 1.0 {
                subview.backgroundColor = selectorColor
            }
        }
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        if let selectorColor = self.selectorColor {
            for subview in self.subviews {
                if subview.bounds.height <= 1.0 {
                    subview.backgroundColor = selectorColor
                }
            }
        }
    }
}

private class TimerPickerItemView: UIView {
    let valueLabel = UILabel()
    let unitLabel = UILabel()
    
    var textColor: UIColor? = nil {
        didSet {
            self.valueLabel.textColor = self.textColor
            self.unitLabel.textColor = self.textColor
        }
    }
    
    var value: (Int32, String)? {
        didSet {
            if let (_, string) = self.value {
                let components = string.components(separatedBy: " ")
                if components.count > 1 {
                    self.valueLabel.text = components[0]
                    self.unitLabel.text = components[1]
                }
            }
            
            self.setNeedsLayout()
        }
    }
    
    override init(frame: CGRect) {
        self.valueLabel.backgroundColor = nil
        self.valueLabel.isOpaque = false
        self.valueLabel.font = Font.regular(24.0)
        
        self.unitLabel.backgroundColor = nil
        self.unitLabel.isOpaque = false
        self.unitLabel.font = Font.medium(16.0)
        
        super.init(frame: frame)
        
        self.addSubview(self.valueLabel)
        self.addSubview(self.unitLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.valueLabel.sizeToFit()
        self.unitLabel.sizeToFit()
        
        self.valueLabel.frame = CGRect(origin: CGPoint(x: self.frame.width / 2.0 - 20.0 - self.valueLabel.frame.size.width, y: floor((self.frame.height - self.valueLabel.frame.height) / 2.0)), size: self.valueLabel.frame.size)
        self.unitLabel.frame = CGRect(origin: CGPoint(x: self.frame.width / 2.0 - 12.0, y: floor((self.frame.height - self.unitLabel.frame.height) / 2.0) + 2.0), size: self.unitLabel.frame.size)
    }
}

private var timerValues: [Int32] = {
    var values: [Int32] = []
    for i in 1 ..< 20 {
        values.append(Int32(i))
    }
    for i in 0 ..< 9 {
        values.append(Int32(20 + i * 5))
    }
    return values
}()

class ChatTimerScreenNode: ViewControllerTracingNode, UIScrollViewDelegate, UIPickerViewDataSource, UIPickerViewDelegate {
    private let context: AccountContext
    private let controllerStyle: ChatTimerScreenStyle
    private var presentationData: PresentationData
    private let dismissByTapOutside: Bool
    private let mode: ChatTimerScreenMode
    
    private let dimNode: ASDisplayNode
    private let wrappingScrollNode: ASScrollNode
    private let contentContainerNode: ASDisplayNode
    private let effectNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let contentBackgroundNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let textNode: ImmediateTextNode
    private let cancelButton: HighlightableButtonNode
    private let doneButton: SolidRoundedButtonNode
    
    private let disableButton: HighlightableButtonNode
    private let disableButtonTitle: ImmediateTextNode
    
    private var initialTime: Int32?
    private var pickerView: TimerPickerView?
    
    private let autoremoveTimerValues: [Int32]
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var completion: ((Int32) -> Void)?
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    
    init(context: AccountContext, presentationData: PresentationData, style: ChatTimerScreenStyle, mode: ChatTimerScreenMode, currentTime: Int32?, dismissByTapOutside: Bool) {
        self.context = context
        self.controllerStyle = style
        self.presentationData = presentationData
        self.dismissByTapOutside = dismissByTapOutside
        self.mode = mode
        self.initialTime = currentTime
        
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
        let blurStyle: UIBlurEffect.Style
        switch style {
            case .default:
                backgroundColor = self.presentationData.theme.actionSheet.itemBackgroundColor
                textColor = self.presentationData.theme.actionSheet.primaryTextColor
                accentColor = self.presentationData.theme.actionSheet.controlAccentColor
                blurStyle = self.presentationData.theme.actionSheet.backgroundType == .light ? .light : .dark
            case .media:
                backgroundColor = UIColor(rgb: 0x1c1c1e)
                textColor = .white
                accentColor = self.presentationData.theme.actionSheet.controlAccentColor
                blurStyle = .dark
        }
        
        self.effectNode = ASDisplayNode(viewBlock: {
            return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        })
        
        self.contentBackgroundNode = ASDisplayNode()
        self.contentBackgroundNode.backgroundColor = backgroundColor
        
        let title: String
        switch self.mode {
        case .sendTimer:
            title = self.presentationData.strings.Conversation_Timer_Title
        case .autoremove:
            title = self.presentationData.strings.Conversation_DeleteTimer_SetupTitle
        case .mute:
            title = self.presentationData.strings.Conversation_Mute_SetupTitle
        }
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(17.0), textColor: textColor)
        
        self.textNode = ImmediateTextNode()
        
        self.cancelButton = HighlightableButtonNode()
        self.cancelButton.setTitle(self.presentationData.strings.Common_Cancel, with: Font.regular(17.0), with: accentColor, for: .normal)
        
        self.doneButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: self.presentationData.theme), height: 52.0, cornerRadius: 11.0, gloss: false)
        self.doneButton.title = self.presentationData.strings.Conversation_Timer_Send
        
        self.disableButton = HighlightableButtonNode()
        self.disableButtonTitle = ImmediateTextNode()
        self.disableButton.addSubnode(self.disableButtonTitle)
        self.disableButtonTitle.attributedText = NSAttributedString(string: self.presentationData.strings.Conversation_DeleteTimer_Disable, font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemAccentColor)
        self.disableButton.isHidden = true
        
        switch self.mode {
        case .autoremove:
            if self.initialTime != nil {
                self.disableButton.isHidden = false
            }
        default:
            break
        }
        
        self.autoremoveTimerValues = [
            1 * 24 * 60 * 60 as Int32,
            2 * 24 * 60 * 60 as Int32,
            3 * 24 * 60 * 60 as Int32,
            4 * 24 * 60 * 60 as Int32,
            5 * 24 * 60 * 60 as Int32,
            6 * 24 * 60 * 60 as Int32,
            1 * 7 * 24 * 60 * 60 as Int32,
            2 * 7 * 24 * 60 * 60 as Int32,
            3 * 7 * 24 * 60 * 60 as Int32,
            1 * 31 * 24 * 60 * 60 as Int32,
            2 * 30 * 24 * 60 * 60 as Int32,
            3 * 31 * 24 * 60 * 60 as Int32,
            4 * 30 * 24 * 60 * 60 as Int32,
            5 * 31 * 24 * 60 * 60 as Int32,
            6 * 30 * 24 * 60 * 60 as Int32,
            365 * 24 * 60 * 60 as Int32
        ]
        
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
        self.contentContainerNode.addSubnode(self.textNode)
        self.contentContainerNode.addSubnode(self.cancelButton)
        self.contentContainerNode.addSubnode(self.doneButton)
        self.contentContainerNode.addSubnode(self.disableButton)
        
        self.cancelButton.addTarget(self, action: #selector(self.cancelButtonPressed), forControlEvents: .touchUpInside)
        self.doneButton.pressed = { [weak self] in
            if let strongSelf = self, let pickerView = strongSelf.pickerView {
                strongSelf.doneButton.isUserInteractionEnabled = false
                if let pickerView = pickerView as? TimerCustomPickerView {
                    switch strongSelf.mode {
                    case .sendTimer:
                        strongSelf.completion?(timerValues[pickerView.selectedRow(inComponent: 0)])
                    case .autoremove:
                        let timeInterval = strongSelf.autoremoveTimerValues[pickerView.selectedRow(inComponent: 0)]
                        strongSelf.completion?(Int32(timeInterval))
                    case .mute:
                        break
                    }
                } else if let pickerView = pickerView as? TimerDatePickerView {
                    switch strongSelf.mode {
                    case .mute:
                        let timeInterval = max(0, Int32(pickerView.date.timeIntervalSince1970) - Int32(Date().timeIntervalSince1970))
                        strongSelf.completion?(timeInterval)
                    default:
                        break
                    }
                }
            }
        }
        
        self.disableButton.addTarget(self, action: #selector(self.disableButtonPressed), forControlEvents: .touchUpInside)
        
        self.setupPickerView(currentTime: currentTime)
    }
    
    @objc private func disableButtonPressed() {
        self.completion?(0)
    }
    
    func setupPickerView(currentTime: Int32? = nil) {
        if let pickerView = self.pickerView {
            pickerView.removeFromSuperview()
        }
        
        switch self.mode {
        case .sendTimer:
            let pickerView = TimerCustomPickerView()
            pickerView.selectorColor = UIColor(rgb: 0xffffff, alpha: 0.18)
            pickerView.dataSource = self
            pickerView.delegate = self
            
            self.contentContainerNode.view.addSubview(pickerView)
            self.pickerView = pickerView
        case .autoremove:
            let pickerView = TimerCustomPickerView()
            pickerView.dataSource = self
            pickerView.delegate = self
            
            pickerView.selectorColor = self.presentationData.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.18)
            
            self.contentContainerNode.view.addSubview(pickerView)
            self.pickerView = pickerView
            
            if let value = self.initialTime {
                var selectedRowIndex = 0
                for i in 0 ..< self.autoremoveTimerValues.count {
                    if self.autoremoveTimerValues[i] <= value {
                        selectedRowIndex = i
                    }
                }
                
                pickerView.selectRow(selectedRowIndex, inComponent: 0, animated: false)
            }
        case .mute:
            let pickerView = TimerDatePickerView()
            pickerView.locale = localeWithStrings(self.presentationData.strings)
            pickerView.datePickerMode = .dateAndTime
            pickerView.minimumDate = Date()
            if #available(iOS 13.4, *) {
                pickerView.preferredDatePickerStyle = .wheels
            }
            pickerView.setValue(self.presentationData.theme.list.itemPrimaryTextColor, forKey: "textColor")
            pickerView.setValue(false, forKey: "highlightsToday")
            pickerView.selectorColor = UIColor(rgb: 0xffffff, alpha: 0.18)
            pickerView.addTarget(self, action: #selector(self.dataPickerChanged), for: .valueChanged)
            
            self.contentContainerNode.view.addSubview(pickerView)
            self.pickerView = pickerView
        }
    }
    
    @objc private func dataPickerChanged() {
        if let (layout, navigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        switch self.mode {
        case .sendTimer:
            return 1
        case .autoremove:
            return 1
        case .mute:
            return 0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch self.mode {
        case .sendTimer:
            return timerValues.count
        case .autoremove:
            return self.autoremoveTimerValues.count
        case .mute:
            return 0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        switch self.mode {
        case .sendTimer:
            let value = timerValues[row]
            let string = timeIntervalString(strings: self.presentationData.strings, value: value)
            if let view = view as? TimerPickerItemView {
                view.value = (value, string)
                return view
            }
            
            let view = TimerPickerItemView()
            view.value = (value, string)
            view.textColor = .white
            return view
        case .autoremove:
            let itemView: TimerPickerItemView
            if let current = view as? TimerPickerItemView {
                itemView = current
            } else {
                itemView = TimerPickerItemView()
                itemView.textColor = self.presentationData.theme.list.itemPrimaryTextColor
            }
            
            let value = self.autoremoveTimerValues[row]
            
            let string: String
            string = timeIntervalString(strings: self.presentationData.strings, value: value)
            
            itemView.value = (value, string)
            
            return itemView
        case .mute:
            preconditionFailure()
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.dataPickerChanged()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        let previousTheme = self.presentationData.theme
        self.presentationData = presentationData
        
        guard case .default = self.controllerStyle else {
            return
        }
        
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
        self.doneButton.updateTheme(SolidRoundedButtonTheme(theme: self.presentationData.theme))
    }
        
    override func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.wrappingScrollNode.view.contentInsetAdjustmentBehavior = .never
        }
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
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
        let targetBounds = self.bounds
        self.bounds = self.bounds.offsetBy(dx: 0.0, dy: -offset)
        self.dimNode.position = CGPoint(x: dimPosition.x, y: dimPosition.y - offset)
        transition.animateView({
            self.bounds = targetBounds
            self.dimNode.position = dimPosition
        })
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
        
        var buttonOffset: CGFloat = 0.0
        let bottomInset: CGFloat = 10.0 + cleanInsets.bottom
        let titleHeight: CGFloat = 54.0
        var contentHeight = titleHeight + bottomInset + 52.0 + 17.0
        let pickerHeight: CGFloat = min(216.0, layout.size.height - contentHeight)
        
        if !self.disableButton.isHidden {
            buttonOffset += 52.0
        }
        
        contentHeight = titleHeight + bottomInset + 52.0 + 17.0 + pickerHeight + buttonOffset
        
        let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: 0.0)
        
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
        
        switch self.mode {
        case .sendTimer:
            break
        case .autoremove:
            self.doneButton.title = self.presentationData.strings.Conversation_DeleteTimer_Apply
        case .mute:
            if let pickerView = self.pickerView as? TimerDatePickerView {
                let timeInterval = max(0, Int32(pickerView.date.timeIntervalSince1970) - Int32(Date().timeIntervalSince1970))
                
                if timeInterval > 0 {
                    let timeString = stringForPreciseRelativeTimestamp(strings: self.presentationData.strings, relativeTimestamp: Int32(pickerView.date.timeIntervalSince1970), relativeTo: Int32(Date().timeIntervalSince1970), dateTimeFormat: self.presentationData.dateTimeFormat)
                    
                    self.doneButton.title = self.presentationData.strings.Conversation_Mute_ApplyMuteUntil(timeString).string
                } else {
                    self.doneButton.title = self.presentationData.strings.Common_Close
                }
            } else {
                self.doneButton.title = self.presentationData.strings.Common_Close
            }
        }
        
        let doneButtonHeight = self.doneButton.updateLayout(width: contentFrame.width - buttonInset * 2.0, transition: transition)
        let doneButtonFrame = CGRect(x: buttonInset, y: contentHeight - doneButtonHeight - insets.bottom - 16.0 - buttonOffset, width: contentFrame.width, height: doneButtonHeight)
        transition.updateFrame(node: self.doneButton, frame: doneButtonFrame)
        
        let disableButtonTitleSize = self.disableButtonTitle.updateLayout(CGSize(width: contentFrame.width, height: doneButtonHeight))
        let disableButtonFrame = CGRect(origin: CGPoint(x: doneButtonFrame.minX, y: doneButtonFrame.maxY), size: CGSize(width: contentFrame.width - buttonInset * 2.0, height: doneButtonHeight))
        transition.updateFrame(node: self.disableButton, frame: disableButtonFrame)
        transition.updateFrame(node: self.disableButtonTitle, frame: CGRect(origin: CGPoint(x: floor((disableButtonFrame.width - disableButtonTitleSize.width) / 2.0), y: floor((disableButtonFrame.height - disableButtonTitleSize.height) / 2.0)), size: disableButtonTitleSize))
        
        self.pickerView?.frame = CGRect(origin: CGPoint(x: 0.0, y: 54.0), size: CGSize(width: contentFrame.width, height: pickerHeight))
        
        transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
    }
}
