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
import TelegramStringFormatting
import PresentationDataUtils
import CoreLocation

enum LocationDistancePickerScreenStyle {
    case `default`
    case media
}

final class LocationDistancePickerScreen: ViewController {
    private var controllerNode: LocationDistancePickerScreenNode {
        return self.displayNode as! LocationDistancePickerScreenNode
    }
    
    private var animatedIn = false
    
    private let context: AccountContext
    private let style: LocationDistancePickerScreenStyle
    private let distances: Signal<[Double], NoError>
    private let compactDisplayTitle: String?
    private let updated: (Int32?) -> Void
    private let completion: (Int32, @escaping () -> Void) -> Void
    private let willDismiss: () -> Void
    
    private var presentationDataDisposable: Disposable?
    
    init(context: AccountContext, style: LocationDistancePickerScreenStyle, compactDisplayTitle: String?, distances: Signal<[Double], NoError>, updated: @escaping (Int32?) -> Void, completion: @escaping (Int32, @escaping () -> Void) -> Void, willDismiss: @escaping () -> Void) {
        self.context = context
        self.style = style
        self.distances = distances
        self.compactDisplayTitle = compactDisplayTitle
        self.updated = updated
        self.completion = completion
        self.willDismiss = willDismiss
        
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
        self.displayNode = LocationDistancePickerScreenNode(context: self.context, style: self.style, compactDisplayTitle: self.compactDisplayTitle, distances: self.distances)
        self.controllerNode.updated = { [weak self] distance in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updated(distance)
        }
        self.controllerNode.completion = { [weak self] distance in
            guard let strongSelf = self else {
                return
            }
            strongSelf.completion(distance, {
                strongSelf.dismiss()
            })
        }
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
        
        let _ = self.controllerNode.update()
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
        self.willDismiss()
        self.controllerNode.animateOut(completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

private class TimerPickerView: UIPickerView {
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

private var unitValues: [Int32] = {
    var values: [Int32] = []
    for i in 0 ..< 99 {
        values.append(Int32(i))
    }
    return values
}()

private var smallUnitValues: [Int32] = {
    var values: [Int32] = []
    values.append(0)
    values.append(5)
    for i in 1 ..< 10 {
        values.append(Int32(i * 10))
    }
    return values
}()

class LocationDistancePickerScreenNode: ViewControllerTracingNode, UIScrollViewDelegate, UIPickerViewDataSource, UIPickerViewDelegate {
    private let context: AccountContext
    private let controllerStyle: LocationDistancePickerScreenStyle
    private var presentationData: PresentationData
    private var compactDisplayTitle: String?
    private var distances: [Double] = []
    
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
    
    private let measureButtonTitleNode: ImmediateTextNode
    
    private var pickerView: TimerPickerView?
    private let unitLabelNode: ImmediateTextNode
    private let smallUnitLabelNode: ImmediateTextNode
    
    private var pickerTimer: SwiftSignalKit.Timer?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private var distancesDisposable: Disposable?
    
    var updated: ((Int32) -> Void)?
    var completion: ((Int32) -> Void)?
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    
    init(context: AccountContext, style: LocationDistancePickerScreenStyle, compactDisplayTitle: String?, distances: Signal<[Double], NoError>) {
        self.context = context
        self.controllerStyle = style
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.compactDisplayTitle = compactDisplayTitle
        
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
        
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: self.presentationData.strings.Location_ProximityNotification_Title, font: Font.bold(17.0), textColor: textColor)
        
        self.textNode = ImmediateTextNode()
        self.textNode.alpha = 0.0
        
        self.cancelButton = HighlightableButtonNode()
        self.cancelButton.setTitle(self.presentationData.strings.Common_Cancel, with: Font.regular(17.0), with: accentColor, for: .normal)
        
        self.doneButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: self.presentationData.theme), height: 52.0, cornerRadius: 11.0, gloss: false)
        self.doneButton.title = self.presentationData.strings.Conversation_Timer_Send
        
        self.unitLabelNode = ImmediateTextNode()
        self.smallUnitLabelNode = ImmediateTextNode()
        
        self.measureButtonTitleNode = ImmediateTextNode()
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.unitLabelNode.attributedText = NSAttributedString(string: self.usesMetricSystem ? self.presentationData.strings.Location_ProximityNotification_DistanceKM : self.presentationData.strings.Location_ProximityNotification_DistanceMI, font: Font.regular(15.0), textColor: textColor)
        self.smallUnitLabelNode.attributedText = NSAttributedString(string: self.usesMetricSystem ? self.presentationData.strings.Location_ProximityNotification_DistanceM : "", font: Font.regular(15.0), textColor: textColor)
        
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
        
        self.contentContainerNode.addSubnode(self.unitLabelNode)
        self.contentContainerNode.addSubnode(self.smallUnitLabelNode)
        
        self.cancelButton.addTarget(self, action: #selector(self.cancelButtonPressed), forControlEvents: .touchUpInside)
        self.doneButton.pressed = { [weak self] in
            if let strongSelf = self, let pickerView = strongSelf.pickerView {
                strongSelf.doneButton.isUserInteractionEnabled = false
                
                let largeValue = unitValues[pickerView.selectedRow(inComponent: 0)]
                let smallValue = smallUnitValues[pickerView.selectedRow(inComponent: 1)]
                var value = largeValue * 1000 + smallValue * 10
                if !strongSelf.usesMetricSystem {
                    value = Int32(Double(value) * 1.60934)
                }
                strongSelf.completion?(value)
            }
        }
        
        self.setupPickerView()
    
        self.distancesDisposable = (distances
        |> deliverOnMainQueue).start(next: { [weak self] distances in
            if let strongSelf = self {
                strongSelf.distances = distances
                strongSelf.updateDoneButtonTitle()
            }
        })
    }
    
    deinit {
        self.distancesDisposable?.dispose()
        
        self.pickerTimer?.invalidate()
    }
    
    func setupPickerView() {
        if let pickerView = self.pickerView {
            pickerView.removeFromSuperview()
        }
        
        let pickerView = TimerPickerView()
        pickerView.selectorColor = UIColor(rgb: 0xffffff, alpha: 0.18)
        pickerView.dataSource = self
        pickerView.delegate = self
        pickerView.selectRow(0, inComponent: 0, animated: false)
        
        if self.usesMetricSystem {
            pickerView.selectRow(6, inComponent: 1, animated: false)
        } else {
            pickerView.selectRow(4, inComponent: 1, animated: false)
        }
        self.contentContainerNode.view.addSubview(pickerView)
        self.pickerView = pickerView
        
        self.contentContainerNode.addSubnode(self.unitLabelNode)
        self.contentContainerNode.addSubnode(self.smallUnitLabelNode)
        
        self.pickerTimer?.invalidate()
        
        let pickerTimer = SwiftSignalKit.Timer(timeout: 0.4, repeat: true, completion: { [weak self] in
            if let strongSelf = self {
                if strongSelf.update() {
                    strongSelf.updateDoneButtonTitle()
                }
            }
        }, queue: Queue.mainQueue())
        self.pickerTimer = pickerTimer
        pickerTimer.start()
        
        self.updateDoneButtonTitle()
    }
    
    private var usesMetricSystem: Bool {
        let locale = localeWithStrings(self.presentationData.strings)
        if locale.identifier.hasSuffix("GB") {
            return false
        }
        return locale.usesMetricSystem
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }
    
    private func updateDoneButtonTitle() {
        if let pickerView = self.pickerView {
            let selectedLargeRow = pickerView.selectedRow(inComponent: 0)
            var selectedSmallRow = pickerView.selectedRow(inComponent: 1)
            if selectedLargeRow == 0 && selectedSmallRow == 0 {
                selectedSmallRow = 1
            }
            
            let largeValue = unitValues[selectedLargeRow]
            let smallValue = smallUnitValues[selectedSmallRow]
            
            let value = largeValue * 1000 + smallValue * 10
            var formattedValue = String(format: "%0.1f", CGFloat(value) / 1000.0)
            if smallValue == 5 {
                formattedValue = formattedValue.replacingOccurrences(of: ".1", with: ".05").replacingOccurrences(of: ",1", with: ",05")
            }
            let distance = self.usesMetricSystem ? "\(formattedValue) \(self.presentationData.strings.Location_ProximityNotification_DistanceKM)" : "\(formattedValue) \(self.presentationData.strings.Location_ProximityNotification_DistanceMI)"
            
            let shortTitle = self.presentationData.strings.Location_ProximityNotification_Notify(distance).string
            var longTitle: String?
            if let displayTitle = self.compactDisplayTitle, let (layout, _) = self.containerLayout {
                let title = self.presentationData.strings.Location_ProximityNotification_NotifyLong(displayTitle, distance).string
                let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: 0.0)
                
                self.measureButtonTitleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(17.0), textColor: .black)
                let titleSize = self.measureButtonTitleNode.updateLayout(CGSize(width: width * 2.0, height: 50.0))
                if titleSize.width < width - 70.0 {
                    longTitle = title
                }
            }
            self.doneButton.title = longTitle ?? shortTitle
    
            self.textNode.attributedText = NSAttributedString(string: self.presentationData.strings.Location_ProximityNotification_AlreadyClose(distance).string, font: Font.regular(14.0), textColor: self.presentationData.theme.actionSheet.secondaryTextColor)
            if let (layout, navigationBarHeight) = self.containerLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
            
            var convertedValue = Double(value)
            if !self.usesMetricSystem {
                convertedValue = Double(convertedValue) * 1.60934
            }
            
            if let distance = self.distances.last, convertedValue > distance {
                self.doneButton.alpha = 0.0
                self.doneButton.isUserInteractionEnabled = false
                self.textNode.alpha = 1.0
            } else {
                self.doneButton.alpha = 1.0
                self.doneButton.isUserInteractionEnabled = true
                self.textNode.alpha = 0.0
            }
        }
    }
    
    var previousReportedValue: Int32?
    fileprivate func update() -> Bool {
        if let pickerView = self.pickerView {
            let selectedLargeRow = pickerView.selectedRow(inComponent: 0)
            var selectedSmallRow = pickerView.selectedRow(inComponent: 1)
            if selectedLargeRow == 0 && selectedSmallRow == 0 {
                selectedSmallRow = 1
            }
            
            let largeValue = unitValues[selectedLargeRow]
            let smallValue = smallUnitValues[selectedSmallRow]
            
            var value = largeValue * 1000 + smallValue * 10
            if !self.usesMetricSystem {
                value = Int32(Double(value) * 1.60934)
            }
            
            if let previousReportedValue = self.previousReportedValue, value == previousReportedValue {
                return false
            } else {
                self.updated?(value)
                self.previousReportedValue = value
                return true
            }
        } else {
            return false
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView.selectedRow(inComponent: 0) == 0 && pickerView.selectedRow(inComponent: 1) == 0 {
            pickerView.selectRow(1, inComponent: 1, animated: true)
        }
        self.updateDoneButtonTitle()
        let _ = self.update()
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if component == 0 {
            return unitValues.count
        } else if component == 1 {
            return smallUnitValues.count
        } else {
            return 1
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let font = Font.regular(17.0)
        let string: String
        if component == 0 {
            let value = unitValues[row]
            string = "\(value)"
        } else {
            if self.usesMetricSystem {
                let value = String(format: "%d", smallUnitValues[row] * 10)
                string = "\(value)"
            } else {
                let value = smallUnitValues[row]
                if value == 0 {
                    string = ".0"
                } else if value == 5 {
                    string = ".05"
                } else {
                    string = ".\(value / 10)"
                }
            }
        }
        return NSAttributedString(string: string, font: font, textColor: self.presentationData.theme.actionSheet.primaryTextColor)
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
        
        self.updateDoneButtonTitle()
        
        self.unitLabelNode.attributedText = NSAttributedString(string: self.usesMetricSystem ? self.presentationData.strings.Location_ProximityNotification_DistanceKM : self.presentationData.strings.Location_ProximityNotification_DistanceMI, font: Font.regular(15.0), textColor: self.presentationData.theme.actionSheet.primaryTextColor)
        self.smallUnitLabelNode.attributedText = NSAttributedString(string: self.usesMetricSystem ? self.presentationData.strings.Location_ProximityNotification_DistanceM : "", font: Font.regular(15.0), textColor: self.presentationData.theme.actionSheet.primaryTextColor)
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
        if case .ended = recognizer.state {
            self.cancelButtonPressed()
        }
    }
    
    func animateIn() {
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        
        let offset = self.contentContainerNode.frame.height
        let position = self.wrappingScrollNode.position
        let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
        self.wrappingScrollNode.position = CGPoint(x: position.x, y: position.y + offset)
        transition.animateView({
            self.wrappingScrollNode.position = position
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
        
        let offset = self.contentContainerNode.frame.height
        self.wrappingScrollNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { _ in
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
        let hadValidLayout = self.containerLayout != nil
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.statusBar, .input])
        let cleanInsets = layout.insets(options: [.statusBar])
        insets.top = max(10.0, insets.top)
        
        let buttonOffset: CGFloat = 0.0
        let bottomInset: CGFloat = 10.0 + cleanInsets.bottom
        let titleHeight: CGFloat = 54.0
        var contentHeight = titleHeight + bottomInset + 52.0 + 17.0
        let pickerHeight: CGFloat = min(216.0, layout.size.height - contentHeight)
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
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: insets.top + 66.0 + UIScreenPixel)))
        
        let titleSize = self.titleNode.measure(CGSize(width: width, height: titleHeight))
        let titleFrame = CGRect(origin: CGPoint(x: floor((contentFrame.width - titleSize.width) / 2.0), y: 16.0), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        let cancelSize = self.cancelButton.measure(CGSize(width: width, height: titleHeight))
        let cancelFrame = CGRect(origin: CGPoint(x: 16.0, y: 16.0), size: cancelSize)
        transition.updateFrame(node: self.cancelButton, frame: cancelFrame)
        
        let buttonInset: CGFloat = 16.0
        let doneButtonHeight = self.doneButton.updateLayout(width: contentFrame.width - buttonInset * 2.0, transition: transition)
        let doneButtonFrame = CGRect(x: buttonInset, y: contentHeight - doneButtonHeight - insets.bottom - 16.0 - buttonOffset, width: contentFrame.width, height: doneButtonHeight)
        transition.updateFrame(node: self.doneButton, frame: doneButtonFrame)
        
        let textSize = self.textNode.updateLayout(CGSize(width: width, height: titleHeight))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floor((width - textSize.width) / 2.0), y: floor(doneButtonFrame.center.y - textSize.height / 2.0)), size: textSize))
                
        let pickerFrame = CGRect(origin: CGPoint(x: 0.0, y: 54.0), size: CGSize(width: contentFrame.width, height: pickerHeight))
        self.pickerView?.frame = pickerFrame
        
        let unitLabelSize = self.unitLabelNode.updateLayout(CGSize(width: width, height: titleHeight))
        transition.updateFrame(node: self.unitLabelNode, frame: CGRect(origin: CGPoint(x: floor(pickerFrame.width / 4.0) + 50.0, y: floor(pickerFrame.center.y - unitLabelSize.height / 2.0)), size: unitLabelSize))
        
        let smallUnitLabelSize = self.smallUnitLabelNode.updateLayout(CGSize(width: width, height: titleHeight))
        transition.updateFrame(node: self.smallUnitLabelNode, frame: CGRect(origin: CGPoint(x: floor(pickerFrame.width / 4.0 * 3.0) + 50.0, y: floor(pickerFrame.center.y - smallUnitLabelSize.height / 2.0)), size: smallUnitLabelSize))
        
        transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
        
        if !hadValidLayout {
            self.updateDoneButtonTitle()
        }
    }
}
