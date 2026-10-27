import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import MessageWidget
import ChatMessageWidgetBubbleContentNode

/// How the results panels draw a widget result (widget-sandbox v0.2, sdk-v1 §2.16; v0.2 W3): the chat's outgoing
/// bubble's widget theme and its corner radius.
struct ChatContextResultWidgetAppearance: Equatable {
    let theme: MessageWidgetInstance.Theme
    let cornerRadius: CGFloat

    init(theme: PresentationTheme, wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, cornerRadius: CGFloat) {
        self.theme = messageWidgetPreviewTheme(theme: theme, wallpaper: wallpaper, fontSize: fontSize)
        self.cornerRadius = cornerRadius
    }
}

private let titleFont = Font.medium(16.0)

/// The accessibility label of a widget result: its title, else its text, else "Widget".
private func widgetResultAccessibilityLabel(_ result: ChatContextResult, strings: PresentationStrings) -> String {
    if let title = result.title, !title.isEmpty {
        return title
    }
    if case let .widget(_, caption, _, _) = result.message, !caption.isEmpty {
        return caption
    }
    return strings.Message_Widget
}

/// A widget result in the vertical results list (v0.2 W3; the user, 2026-10-27, "Its own height"): its title, then the
/// live widget at its sent bubble's width and its own height, at most `MessageWidgetPreviewLayout.maximumListHeight`
/// (a taller one is scaled down). The row is laid out from the anchors and the height the panel last heard the widget
/// report; the widget boots in the apply, on main.
final class VerticalListContextResultsChatInputPanelWidgetItem: ListViewItem {
    var neighborDescriptor: AnyEquatable {
        return AnyEquatable.noNeighborInfluence
    }

    fileprivate let theme: PresentationTheme
    fileprivate let strings: PresentationStrings
    fileprivate let result: ChatContextResult
    fileprivate let widget: TelegramMediaWidget
    fileprivate let appearance: ChatContextResultWidgetAppearance
    fileprivate let reportedHeight: CGFloat?
    fileprivate let resultSelected: (ChatContextResult, ASDisplayNode, CGRect) -> Bool
    fileprivate let heightReported: (String, CGFloat) -> Void

    let selectable: Bool = true

    init(theme: PresentationTheme, strings: PresentationStrings, result: ChatContextResult, widget: TelegramMediaWidget, appearance: ChatContextResultWidgetAppearance, reportedHeight: CGFloat?, resultSelected: @escaping (ChatContextResult, ASDisplayNode, CGRect) -> Bool, heightReported: @escaping (String, CGFloat) -> Void) {
        self.theme = theme
        self.strings = strings
        self.result = result
        self.widget = widget
        self.appearance = appearance
        self.reportedHeight = reportedHeight
        self.resultSelected = resultSelected
        self.heightReported = heightReported
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let configure = { () -> Void in
            let node = VerticalListContextResultsChatInputPanelWidgetItemNode()

            let nodeLayout = node.asyncLayout()
            let (layout, apply) = nodeLayout(self, params, neighbors.next != nil)

            node.contentSize = layout.contentSize
            node.insets = layout.insets

            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(.None) })
                })
            }
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? VerticalListContextResultsChatInputPanelWidgetItemNode {
                let nodeLayout = nodeValue.asyncLayout()

                async {
                    let (layout, apply) = nodeLayout(self, params, neighbors.next != nil)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation)
                        })
                    }
                }
            } else {
                assertionFailure()
            }
        }
    }
}

final class VerticalListContextResultsChatInputPanelWidgetItemNode: ListViewItemNode {
    private let titleNode: TextNode
    private let previewNode: MessageWidgetPreviewNode
    private let separatorNode: ASDisplayNode

    private var item: VerticalListContextResultsChatInputPanelWidgetItem?

    override var visibility: ListViewItemNodeVisibility {
        didSet {
            self.previewNode.setVisible(self.visibility != .none)
        }
    }

    init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false

        self.previewNode = MessageWidgetPreviewNode()

        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true

        super.init(layerBacked: false)

        self.isAccessibilityElement = true
        self.accessibilityTraits = .button

        self.addSubnode(self.separatorNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.previewNode)
    }

    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, neighbors: ListViewItemNeighbors) {
        if let item = item as? VerticalListContextResultsChatInputPanelWidgetItem {
            let doLayout = self.asyncLayout()
            let (layout, apply) = doLayout(item, params, neighbors.next != nil)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }

    func asyncLayout() -> (_ item: VerticalListContextResultsChatInputPanelWidgetItem, _ params: ListViewItemLayoutParams, _ mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)

        return { [weak self] item, params, mergedBottom in
            let leftInset: CGFloat = 12.0 + params.leftInset
            let rightInset: CGFloat = 12.0 + params.rightInset
            let availableWidth = max(1.0, params.width - leftInset - rightInset)

            let titleString: NSAttributedString? = item.result.title.flatMap { title in
                title.isEmpty ? nil : NSAttributedString(string: title, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor)
            }
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: availableWidth, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let titleFrame: CGRect? = titleString == nil ? nil : CGRect(origin: CGPoint(x: leftInset, y: 9.0), size: titleLayout.size)

            let content = MessageWidgetPreviewLayout.contentSize(anchors: MessageWidgetAnchors(width: item.widget.width, height: item.widget.height), availableWidth: availableWidth, reportedHeight: item.reportedHeight)
            let fitted = MessageWidgetPreviewLayout.fitted(content, in: CGSize(width: availableWidth, height: MessageWidgetPreviewLayout.maximumListHeight))
            let displaySize = CGSize(width: floorToScreenPixels(fitted.size.width), height: floorToScreenPixels(fitted.size.height))
            let widgetFrame = CGRect(origin: CGPoint(x: leftInset, y: titleFrame.flatMap { $0.maxY + 6.0 } ?? 9.0), size: displaySize)

            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: widgetFrame.maxY + 9.0), insets: UIEdgeInsets())

            return (nodeLayout, { animation in
                guard let self else {
                    return
                }
                self.item = item

                let _ = titleApply()
                if let titleFrame {
                    self.titleNode.frame = titleFrame
                }
                self.titleNode.isHidden = titleFrame == nil

                self.previewNode.frame = widgetFrame
                let resultId = item.result.id
                self.previewNode.onContentHeightChange = { [weak self] height in
                    guard let self, let item = self.item, item.result.id == resultId else {
                        return
                    }
                    item.heightReported(resultId, height)
                }
                self.previewNode.setVisible(self.visibility != .none)
                self.previewNode.update(widget: item.widget, ownerId: "\(item.result.queryId):\(resultId)", theme: item.appearance.theme, locale: item.strings.baseLanguageCode, stoppedLabel: item.strings.Message_WidgetStopped, contentWidth: content.width, displaySize: displaySize, cornerRadius: item.appearance.cornerRadius)

                self.accessibilityLabel = widgetResultAccessibilityLabel(item.result, strings: item.strings)

                self.separatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                self.separatorNode.isHidden = !mergedBottom
                animation.animator.updateFrame(layer: self.separatorNode.layer, frame: CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - UIScreenPixel), size: CGSize(width: params.width - leftInset, height: UIScreenPixel)), completion: nil)
            })
        }
    }

    override func selected() {
        guard let item = self.item else {
            return
        }
        let _ = item.resultSelected(item.result, self, self.bounds)
    }
}

/// A widget result in the gallery strip (v0.2 W3): the live widget, laid out at its sent bubble's width and fitted into
/// the box an image result's widest crop takes. A new reported height re-fits it inside the cell; the strip's cells do
/// not change size for it.
final class HorizontalListContextResultsChatInputPanelWidgetItem: ListViewItem {
    var neighborDescriptor: AnyEquatable {
        return AnyEquatable.noNeighborInfluence
    }

    fileprivate let strings: PresentationStrings
    fileprivate let result: ChatContextResult
    fileprivate let widget: TelegramMediaWidget
    fileprivate let appearance: ChatContextResultWidgetAppearance
    fileprivate let chatWidth: CGFloat
    fileprivate let resultSelected: (ChatContextResult, ASDisplayNode, CGRect) -> Bool

    let selectable: Bool = true

    init(strings: PresentationStrings, result: ChatContextResult, widget: TelegramMediaWidget, appearance: ChatContextResultWidgetAppearance, chatWidth: CGFloat, resultSelected: @escaping (ChatContextResult, ASDisplayNode, CGRect) -> Bool) {
        self.strings = strings
        self.result = result
        self.widget = widget
        self.appearance = appearance
        self.chatWidth = chatWidth
        self.resultSelected = resultSelected
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let configure = { () -> Void in
            let node = HorizontalListContextResultsChatInputPanelWidgetItemNode()

            let nodeLayout = node.asyncLayout()
            let (layout, apply) = nodeLayout(self, params)

            node.contentSize = layout.contentSize
            node.insets = layout.insets

            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? HorizontalListContextResultsChatInputPanelWidgetItemNode {
                let nodeLayout = nodeValue.asyncLayout()

                async {
                    let (layout, apply) = nodeLayout(self, params)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            } else {
                assertionFailure()
            }
        }
    }
}

final class HorizontalListContextResultsChatInputPanelWidgetItemNode: ListViewItemNode {
    /// Upright in the strip's rotated list, as an image result's `imageNode` is.
    private let containerNode: ASDisplayNode
    private let previewNode: MessageWidgetPreviewNode

    private var item: HorizontalListContextResultsChatInputPanelWidgetItem?
    /// The box the widget is fitted into (the container's bounds), and the width it is laid out at.
    private var box = CGSize()
    /// The height the widget last reported, kept until the cell shows another result.
    private var reportedHeight: CGFloat?

    override var visibility: ListViewItemNodeVisibility {
        didSet {
            self.previewNode.setVisible(self.visibility != .none)
        }
    }

    init() {
        self.containerNode = ASDisplayNode()
        self.containerNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)

        self.previewNode = MessageWidgetPreviewNode()

        super.init(layerBacked: false)

        self.isAccessibilityElement = true
        self.accessibilityTraits = .button

        self.containerNode.addSubnode(self.previewNode)
        self.addSubnode(self.containerNode)
    }

    func asyncLayout() -> (_ item: HorizontalListContextResultsChatInputPanelWidgetItem, _ params: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, () -> Void) {
        return { [weak self] item, params in
            // The list is rotated: `params.width` is the strip's thickness, and a cell's height its length.
            let height = params.width
            let sideInset: CGFloat = 4.0
            let box = CGSize(width: floor(height * 4.0 / 3.0), height: max(1.0, height - sideInset * 2.0))
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: height, height: box.width + sideInset), insets: UIEdgeInsets())

            return (nodeLayout, {
                guard let self else {
                    return
                }
                if let previous = self.item, previous.result.queryId != item.result.queryId || previous.result.id != item.result.id {
                    self.reportedHeight = nil
                }
                self.item = item
                self.box = box
                self.containerNode.bounds = CGRect(origin: CGPoint(), size: box)
                self.containerNode.position = CGPoint(x: height / 2.0, y: (nodeLayout.contentSize.height - sideInset) / 2.0 + sideInset)
                self.accessibilityLabel = widgetResultAccessibilityLabel(item.result, strings: item.strings)

                let resultId = item.result.id
                self.previewNode.onContentHeightChange = { [weak self] height in
                    guard let self, let item = self.item, item.result.id == resultId else {
                        return
                    }
                    self.reportedHeight = height
                    self.updatePreview(item: item)
                }
                self.previewNode.setVisible(self.visibility != .none)
                self.updatePreview(item: item)
            })
        }
    }

    /// Lays the widget out at its sent bubble's width and fits it into the box, centred (main thread).
    private func updatePreview(item: HorizontalListContextResultsChatInputPanelWidgetItem) {
        let content = MessageWidgetPreviewLayout.contentSize(anchors: MessageWidgetAnchors(width: item.widget.width, height: item.widget.height), availableWidth: max(1.0, item.chatWidth - 24.0), reportedHeight: self.reportedHeight)
        let fitted = MessageWidgetPreviewLayout.fitted(content, in: self.box)
        let displaySize = CGSize(width: floorToScreenPixels(fitted.size.width), height: floorToScreenPixels(fitted.size.height))
        self.previewNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((self.box.width - displaySize.width) / 2.0), y: floorToScreenPixels((self.box.height - displaySize.height) / 2.0)), size: displaySize)
        self.previewNode.update(widget: item.widget, ownerId: "\(item.result.queryId):\(item.result.id)", theme: item.appearance.theme, locale: item.strings.baseLanguageCode, stoppedLabel: item.strings.Message_WidgetStopped, contentWidth: content.width, displaySize: displaySize, cornerRadius: item.appearance.cornerRadius)
    }

    override func selected() {
        guard let item = self.item else {
            return
        }
        let _ = item.resultSelected(item.result, self, self.bounds)
    }
}
