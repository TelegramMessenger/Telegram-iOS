import AsyncDisplayKit
import Display
import TelegramPresentationData
import AccountContext
import TextFormat
import UIKit
import AppBundle
import TelegramStringFormatting
import ContextUI
import TelegramCore
import ComponentFlow
import MultilineTextComponent
import BundleIconComponent

private func dayBusinessHoursText(_ day: TelegramBusinessHours.WeekDay) -> String {
    var businessHoursText: String = ""
    switch day {
    case .open:
        businessHoursText += "open 24 hours"
    case .closed:
        businessHoursText += "closed"
    case let .intervals(intervals):
        func clipMinutes(_ value: Int) -> Int {
            return value % (24 * 60)
        }
        
        var resultText: String = ""
        for range in intervals {
            if !resultText.isEmpty {
                resultText.append("\n")
            }
            let startHours = clipMinutes(range.startMinute) / 60
            let startMinutes = clipMinutes(range.startMinute) % 60
            let startText = stringForShortTimestamp(hours: Int32(startHours), minutes: Int32(startMinutes), dateTimeFormat: PresentationDateTimeFormat())
            let endHours = clipMinutes(range.endMinute) / 60
            let endMinutes = clipMinutes(range.endMinute) % 60
            let endText = stringForShortTimestamp(hours: Int32(endHours), minutes: Int32(endMinutes), dateTimeFormat: PresentationDateTimeFormat())
            resultText.append("\(startText) - \(endText)")
        }
        businessHoursText += resultText
    }
    
    return businessHoursText
}

final class PeerInfoScreenBusinessHoursItem: PeerInfoScreenItem {
    let id: AnyHashable
    let label: String
    let businessHours: TelegramBusinessHours
    let requestLayout: () -> Void
    
    init(
        id: AnyHashable,
        label: String,
        businessHours: TelegramBusinessHours,
        requestLayout: @escaping () -> Void
    ) {
        self.id = id
        self.label = label
        self.businessHours = businessHours
        self.requestLayout = requestLayout
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenBusinessHoursItemNode()
    }
}

private final class PeerInfoScreenBusinessHoursItemNode: PeerInfoScreenItemNode {
    private let containerNode: ContextControllerSourceNode
    private let contextSourceNode: ContextExtractedContentContainingNode
    
    private let extractedBackgroundImageNode: ASImageNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    
    private let maskNode: ASImageNode
    private let labelNode: ImmediateTextNode
    private let currentStatusText = ComponentView<Empty>()
    private let currentDayText = ComponentView<Empty>()
    private var dayTitles: [ComponentView<Empty>] = []
    private var dayValues: [ComponentView<Empty>] = []
    private let arrowIcon = ComponentView<Empty>()
    
    private let bottomSeparatorNode: ASDisplayNode
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: PeerInfoScreenBusinessHoursItem?
    private var theme: PresentationTheme?
    
    private var cachedDays: [TelegramBusinessHours.WeekDay] = []
    
    private var isExpanded: Bool = false
    
    override init() {
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.extractedBackgroundImageNode = ASImageNode()
        self.extractedBackgroundImageNode.displaysAsynchronously = false
        self.extractedBackgroundImageNode.alpha = 0.0
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.displaysAsynchronously = false
        self.labelNode.isUserInteractionEnabled = false
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init()
        
        self.addSubnode(self.bottomSeparatorNode)
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.addSubnode(self.maskNode)
        
        self.contextSourceNode.contentNode.clipsToBounds = true
        
        self.contextSourceNode.contentNode.addSubnode(self.extractedBackgroundImageNode)
        self.contextSourceNode.contentNode.addSubnode(self.labelNode)
        
        self.addSubnode(self.activateArea)
        
        self.containerNode.isGestureEnabled = false
        
        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
            guard let strongSelf = self, let theme = strongSelf.theme else {
                return
            }
            
            if isExtracted {
                strongSelf.extractedBackgroundImageNode.image = generateStretchableFilledCircleImage(diameter: 28.0, color: theme.list.plainBackgroundColor)
            }
            
            if let extractedRect = strongSelf.extractedRect, let nonExtractedRect = strongSelf.nonExtractedRect {
                let rect = isExtracted ? extractedRect : nonExtractedRect
                transition.updateFrame(node: strongSelf.extractedBackgroundImageNode, frame: rect)
            }
            
            transition.updateAlpha(node: strongSelf.extractedBackgroundImageNode, alpha: isExtracted ? 1.0 : 0.0, completion: { _ in
                if !isExtracted {
                    self?.extractedBackgroundImageNode.image = nil
                }
            })
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { point in
            return .keepWithSingleTap
        }
        recognizer.highlight = { [weak self] point in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateTouchesAtPoint(point)
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .tap, .longTap:
                    self.isExpanded = !self.isExpanded
                    self.item?.requestLayout()
                default:
                    break
                }
            }
        default:
            break
        }
    }
    
    override func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenBusinessHoursItem else {
            return 10.0
        }
        
        let businessDays: [TelegramBusinessHours.WeekDay]
        if self.item?.businessHours != item.businessHours {
            businessDays = item.businessHours.splitIntoWeekDays()
            self.cachedDays = businessDays
        } else {
            businessDays = self.cachedDays
        }
        
        self.item = item
        self.theme = presentationData.theme
                
        let sideInset: CGFloat = 16.0 + safeInsets.left
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        self.labelNode.attributedText = NSAttributedString(string: item.label, font: Font.regular(14.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
        
        let labelSize = self.labelNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        
        var topOffset = 10.0
        let labelFrame = CGRect(origin: CGPoint(x: sideInset, y: topOffset), size: labelSize)
        if labelSize.height > 0.0 {
            topOffset += labelSize.height
            topOffset += 3.0
        }
        
        let arrowIconSize = self.arrowIcon.update(
            transition: .immediate,
            component: AnyComponent(BundleIconComponent(
                name: "Item List/DownArrow",
                tintColor: presentationData.theme.list.disclosureArrowColor
            )),
            environment: {},
            containerSize: CGSize(width: 100.0, height: 100.0)
        )
        let arrowIconFrame = CGRect(origin: CGPoint(x: width - sideInset + 1.0 - arrowIconSize.width, y: topOffset + 5.0), size: arrowIconSize)
        if let arrowIconView = self.arrowIcon.view {
            if arrowIconView.superview == nil {
                self.contextSourceNode.contentNode.view.addSubview(arrowIconView)
                arrowIconView.frame = arrowIconFrame
            }
            transition.updatePosition(layer: arrowIconView.layer, position: arrowIconFrame.center)
            transition.updateBounds(layer: arrowIconView.layer, bounds: CGRect(origin: CGPoint(), size: arrowIconFrame.size))
            transition.updateTransformRotation(view: arrowIconView, angle: self.isExpanded ? CGFloat.pi * 1.0 : CGFloat.pi * 0.0)
        }
        
        let currentStatusTextSize = self.currentStatusText.update(
            transition: .immediate,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: "Open", font: Font.regular(15.0), textColor: presentationData.theme.list.freeTextSuccessColor))
            )),
            environment: {},
            containerSize: CGSize(width: width - sideInset * 2.0, height: 100.0)
        )
        let currentStatusTextFrame = CGRect(origin: CGPoint(x: sideInset, y: topOffset), size: currentStatusTextSize)
        if let currentStatusTextView = self.currentStatusText.view {
            if currentStatusTextView.superview == nil {
                currentStatusTextView.layer.anchorPoint = CGPoint()
                self.contextSourceNode.contentNode.view.addSubview(currentStatusTextView)
            }
            transition.updatePosition(layer: currentStatusTextView.layer, position: currentStatusTextFrame.origin)
            currentStatusTextView.bounds = CGRect(origin: CGPoint(), size: currentStatusTextFrame.size)
        }
        
        let dayRightInset = sideInset + 17.0
        
        var currentCalendar = Calendar(identifier: .gregorian)
        currentCalendar.timeZone = TimeZone.current
        var currentDayIndex = currentCalendar.component(.weekday, from: Date())
        if currentDayIndex == 1 {
            currentDayIndex = 6
        } else {
            currentDayIndex -= 2
        }
        
        var targetCalendar = Calendar(identifier: .gregorian)
        targetCalendar.timeZone = TimeZone(identifier: item.businessHours.timezoneId) ?? TimeZone.current
        //targetCalendar.component(<#T##component: Calendar.Component##Calendar.Component#>, from: <#T##Date#>)
        
        let currentDayTextSize = self.currentDayText.update(
            transition: .immediate,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: currentDayIndex >= 0 && currentDayIndex < businessDays.count ? dayBusinessHoursText(businessDays[currentDayIndex]) : " ", font: Font.regular(15.0), textColor: presentationData.theme.list.itemSecondaryTextColor)),
                horizontalAlignment: .right,
                maximumNumberOfLines: 0
            )),
            environment: {},
            containerSize: CGSize(width: width - sideInset - dayRightInset, height: 100.0)
        )
        let currentDayTextFrame = CGRect(origin: CGPoint(x: width - dayRightInset - currentDayTextSize.width, y: topOffset), size: currentDayTextSize)
        if let currentDayTextView = self.currentDayText.view {
            if currentDayTextView.superview == nil {
                currentDayTextView.layer.anchorPoint = CGPoint()
                self.contextSourceNode.contentNode.view.addSubview(currentDayTextView)
            }
            transition.updatePosition(layer: currentDayTextView.layer, position: currentDayTextFrame.origin)
            currentDayTextView.bounds = CGRect(origin: CGPoint(), size: currentDayTextFrame.size)
        }
        
        topOffset += max(currentStatusTextSize.height, currentDayTextSize.height)
        
        let daySpacing: CGFloat = 15.0
        
        var dayHeights: CGFloat = 0.0
        
        for i in 0 ..< businessDays.count {
            dayHeights += daySpacing
            
            var dayTransition = transition
            let dayTitle: ComponentView<Empty>
            if self.dayTitles.count > i {
                dayTitle = self.dayTitles[i]
            } else {
                dayTransition = .immediate
                dayTitle = ComponentView()
                self.dayTitles.append(dayTitle)
            }
            
            let dayValue: ComponentView<Empty>
            if self.dayValues.count > i {
                dayValue = self.dayValues[i]
            } else {
                dayValue = ComponentView()
                self.dayValues.append(dayValue)
            }
            
            let dayTitleValue: String
            //TODO:localize
            switch i {
            case 0:
                dayTitleValue = "Monday"
            case 1:
                dayTitleValue = "Tuesday"
            case 2:
                dayTitleValue = "Wednesday"
            case 3:
                dayTitleValue = "Thursday"
            case 4:
                dayTitleValue = "Friday"
            case 5:
                dayTitleValue = "Saturday"
            case 6:
                dayTitleValue = "Sunday"
            default:
                dayTitleValue = " "
            }
            
            let businessHoursText = dayBusinessHoursText(businessDays[i])
            
            let dayTitleSize = dayTitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: dayTitleValue, font: Font.regular(15.0), textColor: presentationData.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: width - sideInset * 2.0, height: 100.0)
            )
            let dayTitleFrame = CGRect(origin: CGPoint(x: sideInset, y: topOffset + dayHeights), size: dayTitleSize)
            if let dayTitleView = dayTitle.view {
                if dayTitleView.superview == nil {
                    dayTitleView.layer.anchorPoint = CGPoint()
                    self.contextSourceNode.contentNode.view.addSubview(dayTitleView)
                    dayTitleView.alpha = 0.0
                }
                dayTransition.updatePosition(layer: dayTitleView.layer, position: dayTitleFrame.origin)
                dayTitleView.bounds = CGRect(origin: CGPoint(), size: dayTitleFrame.size)
                
                transition.updateAlpha(layer: dayTitleView.layer, alpha: self.isExpanded ? 1.0 : 0.0)
            }
            
            let dayValueSize = dayValue.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: businessHoursText, font: Font.regular(15.0), textColor: presentationData.theme.list.itemSecondaryTextColor, paragraphAlignment: .right)),
                    horizontalAlignment: .right,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: width - sideInset - dayRightInset, height: 100.0)
            )
            let dayValueFrame = CGRect(origin: CGPoint(x: width - dayRightInset - dayValueSize.width, y: topOffset + dayHeights), size: dayValueSize)
            if let dayValueView = dayValue.view {
                if dayValueView.superview == nil {
                    dayValueView.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)
                    self.contextSourceNode.contentNode.view.addSubview(dayValueView)
                    dayValueView.alpha = 0.0
                }
                dayTransition.updatePosition(layer: dayValueView.layer, position: CGPoint(x: dayValueFrame.maxX, y: dayValueFrame.minY))
                dayValueView.bounds = CGRect(origin: CGPoint(), size: dayValueFrame.size)
                
                transition.updateAlpha(layer: dayValueView.layer, alpha: self.isExpanded ? 1.0 : 0.0)
            }
            
            dayHeights += max(dayTitleSize.height, dayValueSize.height)
        }
        
        if self.isExpanded {
            topOffset += dayHeights
        }
        
        topOffset += 11.0
        
        transition.updateFrame(node: self.labelNode, frame: labelFrame)
        
        let height = topOffset
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: sideInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        let hasCorners = hasCorners && (topItem == nil || bottomItem == nil)
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        self.bottomSeparatorNode.isHidden = hasBottomCorners
        
        self.activateArea.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: height))
        self.activateArea.accessibilityLabel = item.label
        
        let contentSize = CGSize(width: width, height: height)
        self.containerNode.frame = CGRect(origin: CGPoint(), size: contentSize)
        self.contextSourceNode.frame = CGRect(origin: CGPoint(), size: contentSize)
        transition.updateFrame(node: self.contextSourceNode.contentNode, frame: CGRect(origin: CGPoint(), size: contentSize))
        
        let nonExtractedRect = CGRect(origin: CGPoint(), size: CGSize(width: contentSize.width, height: contentSize.height))
        let extractedRect = nonExtractedRect
        self.extractedRect = extractedRect
        self.nonExtractedRect = nonExtractedRect
        
        if self.contextSourceNode.isExtractedToContextPreview {
            self.extractedBackgroundImageNode.frame = extractedRect
        } else {
            self.extractedBackgroundImageNode.frame = nonExtractedRect
        }
        self.contextSourceNode.contentRect = extractedRect
        
        return height
    }
    
    private func updateTouchesAtPoint(_ point: CGPoint?) {
    }
}
