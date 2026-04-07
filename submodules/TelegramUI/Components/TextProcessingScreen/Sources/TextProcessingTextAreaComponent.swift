import Foundation
import UIKit
import SwiftSignalKit
import Display
import TelegramPresentationData
import ComponentFlow
import AccountContext
import MultilineTextComponent
import BundleIconComponent
import TelegramCore
import TextFormat
import PlainButtonComponent
import CheckComponent
import ShimmerEffect
import TextSelectionNode
import Pasteboard
import Speak
import InteractiveTextComponent

final class TextProcessingTextAreaComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let titleFormat: String
    let title: String
    let titleAction: ((UIView) -> Void)?
    let isExpanded: (value: Bool, toggle: () -> Void)?
    let copyAction: (() -> Void)?
    let emojify: (value: Bool, toggle: () -> Void)?
    let text: TextWithEntities?
    let loadingStateMeasuringText: String?
    let textCorrectionRanges: [Range<Int>]
    let present: (ViewController, Any?) -> Void
    let rootViewForTextSelection: () -> UIView?

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        titleFormat: String,
        title: String,
        titleAction: ((UIView) -> Void)?,
        isExpanded: (value: Bool, toggle: () -> Void)?,
        copyAction: (() -> Void)?,
        emojify: (value: Bool, toggle: () -> Void)?,
        text: TextWithEntities?,
        loadingStateMeasuringText: String?,
        textCorrectionRanges: [Range<Int>],
        present: @escaping (ViewController, Any?) -> Void,
        rootViewForTextSelection: @escaping () -> UIView?
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.titleFormat = titleFormat
        self.isExpanded = isExpanded
        self.copyAction = copyAction
        self.title = title
        self.titleAction = titleAction
        self.emojify = emojify
        self.text = text
        self.loadingStateMeasuringText = loadingStateMeasuringText
        self.textCorrectionRanges = textCorrectionRanges
        self.present = present
        self.rootViewForTextSelection = rootViewForTextSelection
    }

    static func ==(lhs: TextProcessingTextAreaComponent, rhs: TextProcessingTextAreaComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.titleFormat != rhs.titleFormat {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if (lhs.titleAction == nil) != (rhs.titleAction == nil) {
            return false
        }
        if lhs.isExpanded?.value != rhs.isExpanded?.value {
            return false
        }
        if (lhs.copyAction == nil) != (rhs.copyAction == nil) {
            return false
        }
        if lhs.emojify?.value != rhs.emojify?.value {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.loadingStateMeasuringText != rhs.loadingStateMeasuringText {
            return false
        }
        if lhs.textCorrectionRanges != rhs.textCorrectionRanges {
            return false
        }
        return true
    }

    final class View: UIView {
        private var component: TextProcessingTextAreaComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private let title = ComponentView<Empty>()
        private var titleArrow: ComponentView<Empty>?
        private var emojify: ComponentView<Empty>?
        private let titleButton: HighlightTrackingButton
        
        private let textState = InteractiveTextComponent.External()
        private let textContainer: UIView
        private let text = ComponentView<Empty>()
        private var expandShadow: UIImageView?
        private var expandButton: ComponentView<Empty>?
        
        private let copyButton = ComponentView<Empty>()
        
        private var previousText: TextWithEntities?
        private var previousTextLineCount: Int?
        private let measureLoadingTextState = InteractiveTextComponent.External()
        private let measureLoadingText = ComponentView<Empty>()
        private var shimmerEffectNode: ShimmerEffectNode?
        
        private var textSelectionNode: TextSelectionNode?
        private let textSelectionContainer: UIView
        private let textSelectionKnobContainer: UIView
        private let textSelectionKnobSurface: UIView
        
        private var expandedBlockIds: Set<Int> = Set()
        private var appliedExpandedBlockIds: Set<Int>?
        private var displayContentsUnderSpoilers: (value: Bool, location: CGPoint?) = (false, nil)
        
        private var currentSpeechHolder: SpeechSynthesizerHolder?
        
        override init(frame: CGRect) {
            self.textContainer = UIView()
            self.textContainer.clipsToBounds = true
            
            self.textSelectionContainer = UIView()
            self.textSelectionContainer.isUserInteractionEnabled = false
            self.textSelectionKnobContainer = UIView()
            self.textSelectionKnobSurface = UIView()
            self.textSelectionKnobContainer.addSubview(self.textSelectionKnobSurface)
            
            self.titleButton = HighlightTrackingButton()
            
            super.init(frame: frame)
            
            self.addSubview(self.textContainer)
            self.addSubview(self.textSelectionContainer)
            self.addSubview(self.titleButton)
            
            self.titleButton.highligthedChanged = { [weak self] highighed in
                guard let self, let titleView = self.title.view, let titleArrowView = self.titleArrow?.view else {
                    return
                }
                if highighed {
                    titleView.alpha = 0.6
                    titleArrowView.alpha = 0.6
                } else {
                    let transition: ComponentTransition = .easeInOut(duration: 0.25)
                    transition.setAlpha(view: titleView, alpha: 1.0)
                    transition.setAlpha(view: titleArrowView, alpha: 1.0)
                }
            }
            self.titleButton.addTarget(self, action: #selector(self.titleButtonPressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func titleButtonPressed() {
            guard let component = self.component, let titleView = self.title.view else {
                return
            }
            component.titleAction?(titleView)
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            if result == self.textSelectionNode?.view {
                if let textView = self.text.view as? InteractiveTextComponent.View {
                    let textPoint = self.convert(point, to: textView.textNode.view)
                    if let attributes = textView.textNode.attributesAtPoint(textPoint, orNearest: false)?.1 {
                        if attributes[NSAttributedString.Key(rawValue: "TelegramSpoiler")] != nil || attributes[NSAttributedString.Key(rawValue: "Attribute__Spoiler")] != nil {
                            if !self.displayContentsUnderSpoilers.value {
                                if let value = textView.textNode.view.hitTest(textPoint, with: event) {
                                    return value
                                }
                            }
                        }
                        if attributes[NSAttributedString.Key(rawValue: "TelegramBlockQuote")] != nil || attributes[NSAttributedString.Key(rawValue: "Attribute__Blockquote")] != nil {
                            if let value = textView.textNode.view.hitTest(textPoint, with: event) {
                                return value
                            }
                        }
                    }
                }
            }
            return result
        }

        func update(component: TextProcessingTextAreaComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            
            self.component = component
            self.state = state
            
            self.titleButton.isUserInteractionEnabled = component.titleAction != nil
            
            let topInset: CGFloat = 0.0
            let bottomInset: CGFloat = 0.0
            let sideInset: CGFloat = 0.0
            
            var contentHeight: CGFloat = 0.0
            contentHeight += topInset
            
            let titleString = NSMutableAttributedString()
            if let range = component.titleFormat.range(of: "{}") {
                if range.lowerBound != component.titleFormat.startIndex {
                    titleString.append(NSAttributedString(string: String(component.titleFormat[component.titleFormat.startIndex ..< range.lowerBound]), font: Font.semibold(13.0), textColor: component.theme.list.itemSecondaryTextColor))
                }
                titleString.append(NSAttributedString(string: component.title, font: Font.semibold(13.0), textColor: component.theme.list.itemAccentColor))
                if range.upperBound != component.titleFormat.endIndex {
                    titleString.append(NSAttributedString(string: String(component.titleFormat[range.upperBound...]), font: Font.semibold(13.0), textColor: component.theme.list.itemSecondaryTextColor))
                }
            } else {
                titleString.append(NSAttributedString(string: component.titleFormat, font: Font.semibold(13.0), textColor: component.theme.list.itemSecondaryTextColor))
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(titleString)
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 10.0, height: 100.0)
            )
            
            let titleFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: titleSize)
            
            transition.setFrame(view: self.titleButton, frame: titleFrame.insetBy(dx: -10.0, dy: -10.0))
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.layer.anchorPoint = CGPoint()
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                transition.setPosition(view: titleView, position: titleFrame.origin)
            }
            
            if component.titleAction != nil {
                let titleArrow: ComponentView<Empty>
                var titleArrowTransition = transition
                if let current = self.titleArrow {
                    titleArrow = current
                } else {
                    titleArrowTransition = titleArrowTransition.withAnimation(.none)
                    titleArrow = ComponentView()
                    self.titleArrow = titleArrow
                }
                let titleArrowSize = titleArrow.update(
                    transition: titleArrowTransition,
                    component: AnyComponent(BundleIconComponent(
                        name: "Item List/ContextDisclosureArrow",
                        tintColor: component.theme.list.itemAccentColor.withMultipliedAlpha(0.8),
                        maxSize: CGSize(width: 8.0, height: 11.0)
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let titleArrowFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + 2.0, y: titleFrame.minY + 1.0 + floorToScreenPixels((titleFrame.height - titleArrowSize.height) * 0.5)), size: titleArrowSize)
                if let titleArrowView = titleArrow.view {
                    if titleArrowView.superview == nil {
                        titleArrowView.isUserInteractionEnabled = false
                        self.addSubview(titleArrowView)
                    }
                    transition.setFrame(view: titleArrowView, frame: titleArrowFrame)
                }
            } else {
                if let titleArrow = self.titleArrow {
                    self.titleArrow = nil
                    titleArrow.view?.removeFromSuperview()
                }
            }
            
            if let emojifyValue = component.emojify {
                let emojify: ComponentView<Empty>
                var emojifyTransition = transition
                if let current = self.emojify {
                    emojify = current
                } else {
                    emojify = ComponentView()
                    self.emojify = emojify
                    emojifyTransition = emojifyTransition.withAnimation(.none)
                }
                let checkTheme = CheckComponent.Theme(
                    backgroundColor: component.theme.list.itemCheckColors.fillColor,
                    strokeColor: component.theme.list.itemCheckColors.foregroundColor,
                    borderColor: component.theme.list.itemCheckColors.strokeColor,
                    overlayBorder: false,
                    hasInset: false,
                    hasShadow: false
                )
                let emojifySize = emojify.update(
                    transition: emojifyTransition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(HStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(CheckComponent(
                                theme: checkTheme,
                                size: CGSize(width: 16.0, height: 16.0),
                                selected: emojifyValue.value
                            ))),
                            AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(string: component.strings.TextProcessing_Emojify, font: Font.semibold(13.0), textColor: component.theme.list.itemSecondaryTextColor))
                            )))
                        ], spacing: 7.0)),
                        effectAlignment: .center,
                        action: {
                            emojifyValue.toggle()
                        },
                        animateAlpha: false,
                        animateScale: false
                    )),
                    environment: {
                    },
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                )
                let emojifyFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - emojifySize.width, y: contentHeight), size: emojifySize)
                if let emojifyView = emojify.view {
                    if emojifyView.superview == nil {
                        self.addSubview(emojifyView)
                    }
                    emojifyTransition.setFrame(view: emojifyView, frame: emojifyFrame)
                }
            } else {
                if let emojify = self.emojify {
                    self.emojify = nil
                    emojify.view?.removeFromSuperview()
                }
            }
            
            contentHeight += 25.0
            
            let fontSize: CGFloat = 17.0
            let textValue = NSMutableAttributedString(attributedString: stringWithAppliedEntities(
                component.text?.text ?? self.previousText?.text ?? "",
                entities: component.text?.entities ?? self.previousText?.entities ?? [],
                baseColor: component.theme.list.itemPrimaryTextColor,
                linkColor: component.theme.list.itemAccentColor,
                baseQuoteTintColor: component.theme.list.itemAccentColor,
                baseFont: Font.regular(fontSize),
                linkFont: Font.regular(fontSize),
                boldFont: Font.semibold(fontSize),
                italicFont: Font.italic(fontSize),
                boldItalicFont: Font.semiboldItalic(fontSize),
                fixedFont: Font.monospace(fontSize),
                blockQuoteFont: Font.monospace(fontSize),
                message: nil
            ))
            for range in component.textCorrectionRanges {
                if range.lowerBound >= 0 && range.upperBound < textValue.length {
                    textValue.addAttributes([
                        .underlineColor: component.theme.list.itemAccentColor,
                        .underlineStyle: NSUnderlineStyle.patternDot.rawValue
                    ], range: NSRange(location: range.lowerBound, length: range.upperBound - range.lowerBound))
                }
            }
            
            let textOrigin = CGPoint(x: sideInset, y: contentHeight)
            
            var spoilerExpandPoint: CGPoint?
            if let location = self.displayContentsUnderSpoilers.location {
                self.displayContentsUnderSpoilers.location = nil
                
                spoilerExpandPoint = CGPoint(x: location.x - textOrigin.x, y: location.y - textOrigin.y)
            }
            
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(InteractiveTextComponent(
                    external: self.textState,
                    attributedString: textValue,
                    backgroundColor: nil,
                    minimumNumberOfLines: 1,
                    maximumNumberOfLines: 0,
                    truncationType: .end,
                    alignment: .left,
                    verticalAlignment: .top,
                    lineSpacing: 0.12,
                    cutout: nil,
                    insets: UIEdgeInsets(),
                    lineColor: nil,
                    textShadowColor: nil,
                    textShadowBlur: nil,
                    textStroke: nil,
                    displayContentsUnderSpoilers: self.displayContentsUnderSpoilers.value,
                    customTruncationToken: nil,
                    expandedBlocks: self.expandedBlockIds,
                    context: component.context,
                    cache: component.context.animationCache,
                    renderer: component.context.animationRenderer,
                    placeholderColor: component.theme.list.mediaPlaceholderColor,
                    attemptSynchronous: true,
                    textColor: component.theme.list.itemPrimaryTextColor,
                    spoilerEffectColor: component.theme.list.itemPrimaryTextColor,
                    spoilerTextColor: component.theme.list.itemPrimaryTextColor,
                    areContentAnimationsEnabled: true,
                    spoilerExpandPoint: spoilerExpandPoint,
                    canHandleTapAtPoint: { _ in
                        return true
                    },
                    requestToggleBlockCollapsed: { [weak self] blockId in
                        guard let self else {
                            return
                        }
                        if self.expandedBlockIds.contains(blockId) {
                            self.expandedBlockIds.remove(blockId)
                        } else {
                            self.expandedBlockIds.insert(blockId)
                        }
                        self.state?.updated(transition: .spring(duration: 0.4))
                    },
                    requestDisplayContentsUnderSpoilers: { [weak self] location in
                        guard let self, let textView = self.text.view as? InteractiveTextComponent.View else {
                            return
                        }
                        
                        cancelParentGestures(view: self)
                        
                        var mappedLocation: CGPoint?
                        if let location {
                            mappedLocation = textView.textNode.layer.convert(location, to: self.layer)
                        }
                        self.displayContentsUnderSpoilers = (true, mappedLocation)
                        self.state?.updated(transition: .spring(duration: 0.4))
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
            )
            let textFrame = CGRect(origin: textOrigin, size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    textView.layer.anchorPoint = CGPoint()
                    self.textContainer.addSubview(textView)
                    textView.alpha = 0.0
                }
                textView.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
                alphaTransition.setAlpha(view: textView, alpha: component.text != nil ? 1.0 : 0.0)
            }
            if component.text != nil, let layout = self.textState.layout {
                self.previousText = component.text
                self.previousTextLineCount = layout.numberOfLines
            }
            
            var textContainerFrame = textFrame
            if let isExpanded = component.isExpanded, let textLayout = self.textState.layout, textLayout.numberOfLines > 1 {
                if !isExpanded.value, let firstLineRect = textLayout.linesRects().first {
                    textContainerFrame.size.height = ceil(firstLineRect.maxY)
                }
                
                let expandButton: ComponentView<Empty>
                var expandButtonTransition = transition
                if let current = self.expandButton {
                    expandButton = current
                } else {
                    expandButtonTransition = expandButtonTransition.withAnimation(.none)
                    expandButton = ComponentView()
                    self.expandButton = expandButton
                }
                let expandShadow: UIImageView
                if let current = self.expandShadow {
                    expandShadow = current
                } else {
                    expandShadow = UIImageView()
                    self.expandShadow = expandShadow
                    self.addSubview(expandShadow)
                }
                let expandShadowExtent: CGFloat = 20.0
                if expandShadow.image == nil {
                    let baseSize: CGFloat = 20.0
                    expandShadow.image = generateImage(CGSize(width: baseSize + expandShadowExtent * 2.0, height: baseSize + expandShadowExtent * 2.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        
                        let colors: [CGColor] = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.0).cgColor]
                        let locations: [CGFloat] = [0.0, 1.0]
                        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) {
                            let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
                            context.drawRadialGradient(gradient, startCenter: center, startRadius: baseSize / 2.0, endCenter: center, endRadius: size.width / 2.0, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                        }
                    })?.withRenderingMode(.alwaysTemplate).stretchableImage(withLeftCapWidth: Int(baseSize / 2.0 + expandShadowExtent), topCapHeight: Int(baseSize / 2.0 + expandShadowExtent))
                }
                expandShadow.tintColor = component.theme.list.itemBlocksBackgroundColor
                
                let expandButtonSize = expandButton.update(
                    transition: expandButtonTransition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: isExpanded.value ? component.strings.TextProcessing_TextCollapse : component.strings.TextProcessing_TextExpand, font: Font.regular(17.0), textColor: component.theme.list.itemAccentColor))
                        )),
                        effectAlignment: .right,
                        action: {
                            isExpanded.toggle()
                        },
                        animateAlpha: true,
                        animateScale: false,
                        animateContents: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 100.0)
                )
                
                if isExpanded.value && textLayout.trailingLineWidth >= availableSize.width - sideInset - expandButtonSize.width - 8.0 {
                    textContainerFrame.size.height += 22.0
                }
                
                let expandButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - expandButtonSize.width, y: textContainerFrame.maxY - expandButtonSize.height - 2.0), size: expandButtonSize)
                if let expandButtonView = expandButton.view {
                    if expandButtonView.superview == nil {
                        expandButtonView.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)
                        self.addSubview(expandButtonView)
                    }
                    expandButtonTransition.setPosition(view: expandButtonView, position: CGPoint(x: expandButtonFrame.maxX, y: expandButtonFrame.minY))
                    expandButtonTransition.setBounds(view: expandButtonView, bounds: CGRect(origin: CGPoint(), size: expandButtonFrame.size))
                    
                    expandButtonTransition.setFrame(view: expandShadow, frame: expandButtonFrame.insetBy(dx: -expandShadowExtent, dy: -expandShadowExtent))
                    expandButtonTransition.setAlpha(view: expandShadow, alpha: isExpanded.value ? 0.0 : 1.0)
                }
                
            } else {
                if let expandButton = self.expandButton {
                    self.expandButton = nil
                    expandButton.view?.removeFromSuperview()
                }
                if let expandShadow = self.expandShadow {
                    self.expandShadow = nil
                    expandShadow.removeFromSuperview()
                }
                
                if component.copyAction != nil, let textLayout = self.textState.layout {
                    if textLayout.trailingLineWidth >= availableSize.width - sideInset - 32.0 || textLayout.trailingLineIsRTL || textLayout.trailingLineIsBlock {
                        textContainerFrame.size.height += 28.0
                    }
                }
            }
            
            if component.text != nil, component.isExpanded?.value ?? true, let textView = self.text.view as? InteractiveTextComponent.View {
                let textSelectionNode: TextSelectionNode
                if let current = self.textSelectionNode {
                    textSelectionNode = current
                } else {
                    textSelectionNode = TextSelectionNode(theme: TextSelectionTheme(selection: component.theme.list.itemAccentColor.withMultipliedAlpha(0.5), knob: component.theme.list.itemAccentColor, isDark: component.theme.overallDarkAppearance), strings: component.strings, textNodeOrView: .node(textView.textNode), updateIsActive: { [weak self] value in
                        guard let self else {
                            return
                        }
                        let _ = self
                    }, present: { [weak self] c, a in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.present(c, a)
                    }, rootView: { [weak self] in
                        guard let self, let component = self.component else {
                            return nil
                        }
                        return component.rootViewForTextSelection()
                    }, externalKnobSurface: self.textSelectionKnobSurface, performAction: { [weak self] text, action in
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        switch action {
                        case .copy:
                            storeAttributedTextInPasteboard(text)
                        case .share:
                            let shareController = component.context.sharedContext.makeShareController(context: component.context, params: ShareControllerParams(subject: .text(text.string)))
                            component.present(shareController, nil)
                        case .lookup:
                            let controller = UIReferenceLibraryViewController(term: text.string)
                            if let window = self.window {
                                controller.popoverPresentationController?.sourceView = window
                                controller.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
                                window.rootViewController?.present(controller, animated: true)
                            }
                        case .speak:
                            if let speechHolder = speakText(context: component.context, text: text.string) {
                                speechHolder.completion = { [weak self, weak speechHolder] in
                                    guard let self else {
                                        return
                                    }
                                    if self.currentSpeechHolder === speechHolder {
                                        self.currentSpeechHolder = nil
                                    }
                                }
                                self.currentSpeechHolder = speechHolder
                            }
                        case .translate:
                            break
                        case .quote:
                            break
                        }
                    })
                    
                    textSelectionNode.enableLookup = true
                    textSelectionNode.enableTranslate = false
                    textSelectionNode.menuSkipCoordnateConversion = false
                    textSelectionNode.canBeginSelection = { _ in
                        return true
                    }
                    self.textSelectionNode = textSelectionNode
                    
                    self.textSelectionContainer.insertSubview(self.textSelectionKnobContainer, at: 0)
                    self.textContainer.insertSubview(textSelectionNode.highlightAreaNode.view, belowSubview: textView)
                    self.textContainer.insertSubview(textSelectionNode.view, aboveSubview: textView)
                }
                
                textSelectionNode.frame = textView.frame
                textSelectionNode.highlightAreaNode.frame = textView.frame
                self.textSelectionKnobSurface.frame = textView.frame
            } else {
                for subview in Array(self.textSelectionContainer.subviews) {
                    subview.removeFromSuperview()
                }
                if self.textSelectionKnobContainer.superview != nil {
                    self.textSelectionKnobContainer.removeFromSuperview()
                }
                if let textSelectionNode = self.textSelectionNode {
                    self.textSelectionNode = nil
                    textSelectionNode.view.removeFromSuperview()
                    
                    if textSelectionNode.highlightAreaNode.view.superview != nil {
                        textSelectionNode.highlightAreaNode.view.removeFromSuperview()
                    }
                }
            }
            
            if component.text == nil {
                let shimmerEffectNode: ShimmerEffectNode
                if let current = self.shimmerEffectNode {
                    shimmerEffectNode = current
                } else {
                    shimmerEffectNode = ShimmerEffectNode()
                    shimmerEffectNode.layer.allowsGroupOpacity = true
                    shimmerEffectNode.alpha = 0.0
                    self.shimmerEffectNode = shimmerEffectNode
                    self.addSubview(shimmerEffectNode.view)
                }
                
                var fakeLines = ""
                if let previousTextLineCount = self.previousTextLineCount {
                    for _ in 0 ..< min(20, previousTextLineCount) {
                        if !fakeLines.isEmpty {
                            fakeLines.append("\n")
                        }
                        fakeLines.append("a")
                    }
                } else if let loadingStateMeasuringText = component.loadingStateMeasuringText {
                    fakeLines = loadingStateMeasuringText
                } else {
                    for _ in 0 ..< 4 {
                        if !fakeLines.isEmpty {
                            fakeLines.append("\n")
                        }
                        fakeLines.append("a")
                    }
                }
                
                let measureLoadingTextSize = self.measureLoadingText.update(
                    transition: .immediate,
                    component: AnyComponent(InteractiveTextComponent(
                        external: self.measureLoadingTextState,
                        attributedString: NSAttributedString(string: fakeLines, font: Font.regular(fontSize), textColor: .black),
                        backgroundColor: nil,
                        minimumNumberOfLines: 1,
                        maximumNumberOfLines: 0,
                        truncationType: .end,
                        alignment: .left,
                        verticalAlignment: .top,
                        lineSpacing: 0.12,
                        cutout: nil,
                        insets: UIEdgeInsets(),
                        lineColor: nil,
                        textShadowColor: nil,
                        textShadowBlur: nil,
                        textStroke: nil,
                        displayContentsUnderSpoilers: true,
                        customTruncationToken: nil,
                        expandedBlocks: self.expandedBlockIds,
                        context: component.context,
                        cache: component.context.animationCache,
                        renderer: component.context.animationRenderer,
                        placeholderColor: component.theme.list.mediaPlaceholderColor,
                        attemptSynchronous: true,
                        textColor: component.theme.list.itemPrimaryTextColor,
                        spoilerEffectColor: component.theme.list.itemPrimaryTextColor,
                        spoilerTextColor: component.theme.list.itemPrimaryTextColor,
                        areContentAnimationsEnabled: true,
                        spoilerExpandPoint: nil
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
                )
                textContainerFrame.size = CGSize(width: availableSize.width, height: measureLoadingTextSize.height)
                
                shimmerEffectNode.frame = textContainerFrame
                
                var shapes: [ShimmerEffectNode.Shape] = []
                if let textLayout = self.measureLoadingTextState.layout {
                    var seed: UInt32 = 0x9E3779B9
                    for (index, lineRect) in textLayout.linesRects().enumerated() {
                        seed = seed &* 1664525 &+ UInt32(index) &+ 1013904223
                        let normalized = CGFloat(seed >> 16) / CGFloat(0xFFFF)
                        let width = 0.7 + normalized * 0.3
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: 0.0, y: lineRect.midY - 18.0), width: floor(textContainerFrame.width * width), diameter: 6.0))
                    }
                }
                shimmerEffectNode.updateAbsoluteRect(shimmerEffectNode.bounds, within: shimmerEffectNode.bounds.size)
                shimmerEffectNode.update(backgroundColor: component.theme.list.itemBlocksBackgroundColor, foregroundColor: component.theme.list.mediaPlaceholderColor, shimmeringColor: component.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, size: shimmerEffectNode.bounds.size)
                alphaTransition.setAlpha(view: shimmerEffectNode.view, alpha: 1.0)
            } else {
                if let shimmerEffectNode = self.shimmerEffectNode {
                    self.shimmerEffectNode = nil
                    alphaTransition.setAlpha(view: shimmerEffectNode.view, alpha: 0.0, completion: { [weak shimmerEffectNode] _ in
                        shimmerEffectNode?.view.removeFromSuperview()
                    })
                }
            }
            
            if let copyAction = component.copyAction {
                let copyButtonSize = self.copyButton.update(
                    transition: transition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(BundleIconComponent(
                            name: "Chat/Context Menu/Copy",
                            tintColor: component.theme.list.itemAccentColor
                        )),
                        effectAlignment: .right,
                        action: {
                            copyAction()
                        },
                        animateAlpha: true,
                        animateScale: false,
                        animateContents: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 100.0)
                )
                let copyButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - copyButtonSize.width, y: textContainerFrame.maxY - copyButtonSize.height - 2.0), size: copyButtonSize)
                if let copyButtonView = self.copyButton.view {
                    if copyButtonView.superview == nil {
                        copyButtonView.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)
                        self.addSubview(copyButtonView)
                    }
                    transition.setPosition(view: copyButtonView, position: CGPoint(x: copyButtonFrame.maxX, y: copyButtonFrame.minY))
                    transition.setBounds(view: copyButtonView, bounds: CGRect(origin: CGPoint(), size: copyButtonFrame.size))
                    alphaTransition.setAlpha(view: copyButtonView, alpha: component.text != nil ? 1.0 : 0.0)
                }
            }
            
            transition.setFrame(view: self.textContainer, frame: textContainerFrame)
            transition.setFrame(view: self.textSelectionContainer, frame: textContainerFrame)
            contentHeight += textContainerFrame.height

            contentHeight += bottomInset

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

