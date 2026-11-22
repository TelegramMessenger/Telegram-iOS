import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import AccountContext
import TextFormat
import InteractiveTextComponent
import InstantPageUI

/// Renders the text of a `TextProcessingTextAreaComponent`.
///
/// Hosts two backends: `.plain`/`.empty`/`nil` render through `InteractiveTextComponent`;
/// `.rich` renders its `InstantPage` natively via `TextProcessingRichContentView`. Parents
/// therefore only talk to it through `ComposedRichMessage` and the semantic accessors on `View`
/// (`textLayoutInfo`, `textNodeForSelection`, `hitTestTextInteraction`).
final class TextProcessingTextComponent: Component {
    static let fontSize: CGFloat = 17.0

    struct TextLayoutInfo {
        private enum Backing {
            case interactiveText(InteractiveTextNodeLayout)
            case instantPage(InstantPageV2TextLineMetrics)
        }

        private let backing: Backing

        init(interactiveTextLayout: InteractiveTextNodeLayout) {
            self.backing = .interactiveText(interactiveTextLayout)
        }

        init(instantPageMetrics: InstantPageV2TextLineMetrics) {
            self.backing = .instantPage(instantPageMetrics)
        }

        var numberOfLines: Int {
            switch self.backing {
            case let .interactiveText(layout):
                return layout.numberOfLines
            case let .instantPage(metrics):
                return metrics.numberOfLines
            }
        }

        var trailingLineWidth: CGFloat {
            switch self.backing {
            case let .interactiveText(layout):
                return layout.trailingLineWidth
            case let .instantPage(metrics):
                return metrics.trailingLineWidth
            }
        }

        var trailingLineIsRTL: Bool {
            switch self.backing {
            case let .interactiveText(layout):
                return layout.trailingLineIsRTL
            case let .instantPage(metrics):
                return metrics.trailingLineIsRTL
            }
        }

        var trailingLineIsBlock: Bool {
            switch self.backing {
            case let .interactiveText(layout):
                return layout.trailingLineIsBlock
            case let .instantPage(metrics):
                return metrics.trailingIsBlock
            }
        }

        func linesRects() -> [CGRect] {
            switch self.backing {
            case let .interactiveText(layout):
                return layout.linesRects()
            case let .instantPage(metrics):
                return metrics.lineRects
            }
        }
    }

    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let text: ComposedRichMessage?
    let textCorrectionRanges: [Range<Int>]

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        text: ComposedRichMessage?,
        textCorrectionRanges: [Range<Int>]
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.text = text
        self.textCorrectionRanges = textCorrectionRanges
    }

    static func ==(lhs: TextProcessingTextComponent, rhs: TextProcessingTextComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.textCorrectionRanges != rhs.textCorrectionRanges {
            return false
        }
        return true
    }

    final class View: UIView {
        private var component: TextProcessingTextComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false

        private let interactiveTextState = InteractiveTextComponent.External()
        private let interactiveText = ComponentView<Empty>()

        private var richContentView: TextProcessingRichContentView?
        private var richContentInstantPage: InstantPage?

        private var expandedBlockIds: Set<Int> = Set()
        private var displayContentsUnderSpoilers: (value: Bool, location: CGPoint?) = (false, nil)

        var textLayoutInfo: TextLayoutInfo? {
            if let richContentView = self.richContentView {
                return richContentView.currentTextLineMetrics.flatMap { TextLayoutInfo(instantPageMetrics: $0) }
            }
            return self.interactiveTextState.layout.flatMap { TextLayoutInfo(interactiveTextLayout: $0) }
        }

        var textNodeForSelection: TextNodeProtocol? {
            if self.richContentView != nil {
                return nil
            }
            return (self.interactiveText.view as? InteractiveTextComponent.View)?.textNode
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            preconditionFailure()
        }

        /// If the tap at `point` (in this view's coordinates) lands on interactive text content
        /// that must win over surrounding gesture handling (an unrevealed spoiler, or a
        /// collapsible blockquote), returns the view that should receive the touch.
        func hitTestTextInteraction(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if self.richContentView != nil {
                return nil
            }
            guard let textView = self.interactiveText.view as? InteractiveTextComponent.View else {
                return nil
            }
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
            return nil
        }

        func update(component: TextProcessingTextComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            self.component = component
            self.state = state

            switch component.text {
            case let .rich(instantPage):
                if let interactiveTextView = self.interactiveText.view, interactiveTextView.superview != nil {
                    interactiveTextView.removeFromSuperview()
                }

                let richContentView: TextProcessingRichContentView
                if let current = self.richContentView, self.richContentInstantPage == instantPage {
                    richContentView = current
                } else {
                    self.richContentView?.removeFromSuperview()
                    richContentView = TextProcessingRichContentView(context: component.context, instantPage: instantPage)
                    richContentView.requestUpdate = { [weak self] in
                        guard let self else {
                            return
                        }
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    }
                    self.richContentView = richContentView
                    self.richContentInstantPage = instantPage
                    self.addSubview(richContentView)
                }

                let richSize = richContentView.update(boundingWidth: availableSize.width, theme: component.theme, strings: component.strings, transition: transition)
                richContentView.frame = CGRect(origin: CGPoint(), size: richSize)
                return richSize
            case .plain, .empty, nil:
                if let richContentView = self.richContentView {
                    self.richContentView = nil
                    self.richContentInstantPage = nil
                    richContentView.removeFromSuperview()
                }
            }

            let text: String
            let entities: [MessageTextEntity]
            switch component.text {
            case .rich:
                // Handled above; unreachable here.
                text = ""
                entities = []
            case let .plain(plainText, plainEntities):
                text = plainText
                entities = plainEntities
            case .empty, nil:
                text = ""
                entities = []
            }

            let fontSize = TextProcessingTextComponent.fontSize
            let textValue = NSMutableAttributedString(attributedString: stringWithAppliedEntities(
                text,
                entities: entities,
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

            var spoilerExpandPoint: CGPoint?
            if let location = self.displayContentsUnderSpoilers.location {
                self.displayContentsUnderSpoilers.location = nil
                spoilerExpandPoint = location
            }

            let textSize = self.interactiveText.update(
                transition: transition,
                component: AnyComponent(InteractiveTextComponent(
                    external: self.interactiveTextState,
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
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    },
                    requestDisplayContentsUnderSpoilers: { [weak self] location in
                        guard let self else {
                            return
                        }

                        cancelParentGestures(view: self)

                        var mappedLocation: CGPoint?
                        if let location, let textView = self.interactiveText.view as? InteractiveTextComponent.View {
                            mappedLocation = textView.textNode.layer.convert(location, to: self.layer)
                        }
                        self.displayContentsUnderSpoilers = (true, mappedLocation)
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    }
                )),
                environment: {},
                containerSize: availableSize
            )

            if let textView = self.interactiveText.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                textView.frame = CGRect(origin: CGPoint(), size: textSize)
            }

            return textSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
