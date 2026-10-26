import UIKit
import TelegramCore
import GiftItemComponent
import Display
import AccountContext
import TelegramPresentationData
import ComponentFlow
import WalletContext
import WalletCollectibleHeaderComponent
import WalletGiftStickerMediaComponent

final class WalletCollectiblesGridView: UIView {
    private final class ItemView: UIControl {
        let media = WalletCollectibleMediaView(frame: .zero)
        let giftTile = UIView()
        private let modelSilhouette = UIImageView()
        private var silhouetteSource: UIImage?
        private let giftContent = ComponentView<Empty>()
        private var decorationStyle: WalletContext.CardGiftStyle?
        private var decorationModel: Data?
        private var decorationAttributes: [StarGift.UniqueGift.Attribute] = []
        private(set) var stickerReady = false
        var action: (() -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.media)
            self.giftTile.isUserInteractionEnabled = false
            self.addSubview(self.giftTile)
            self.isAccessibilityElement = true
            self.accessibilityTraits = .button
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }

        func setModelWiggle(angle: CGFloat, scale: CGFloat) {
            var transform = CATransform3DMakeRotation(angle, 0, 0, 1)
            transform = CATransform3DScale(transform, scale, scale, 1)
            (self.giftContent.view as? GiftItemComponent.View)?.setModelTransform(transform)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func updateGiftTile(context: AccountContext, theme: PresentationTheme, item: WalletContext.Collectible, media: WalletGiftStickerMedia?, side: CGFloat) {
            self.giftTile.frame = CGRect(x: 0, y: 0, width: side, height: side)
            let uniqueGift = item.nft?.gift ?? media?.uniqueGift
            var style = media?.style
            if style == nil, let gift = uniqueGift {
                for case let .backdrop(_, _, inner, outer, pattern, _, _) in gift.attributes {
                    style = WalletContext.CardGiftStyle(innerColor: inner, outerColor: outer, patternColor: pattern, patternFile: nil)
                    break
                }
            }
            if self.decorationStyle != style || self.decorationModel != media?.modelFile {
                self.decorationStyle = style
                self.decorationModel = media?.modelFile
                self.decorationAttributes = []
                if let data = media?.modelFile,
                   let file = EnginePostboxDecoder(buffer: EngineMemoryBuffer(data: data)).decodeRootObject() as? TelegramMediaFile {
                    self.decorationAttributes.append(.model(name: "", file: file, rarity: .permille(0), crafted: false))
                }
                if let style {
                    self.decorationAttributes.append(.backdrop(name: "", id: 0, innerColor: style.innerColor,
                        outerColor: style.outerColor, patternColor: style.patternColor, textColor: 0, rarity: .permille(0)))
                    if let data = style.patternFile,
                       let file = EnginePostboxDecoder(buffer: EngineMemoryBuffer(data: data)).decodeRootObject() as? TelegramMediaFile {
                        self.decorationAttributes.append(.pattern(name: "", file: file, rarity: .permille(0)))
                    }
                }
            }
            let suffix = item.name.split(separator: "#").last.map(String.init)
            let slugNumber = item.giftSlug?.split(separator: "-").last.map(String.init)
            let number = [item.nft?.gift.map { String($0.number) }, item.name.contains("#") ? suffix : nil, slugNumber]
                .compactMap { $0 }.first { !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }
            let ribbon = number.map { GiftItemComponent.Ribbon(text: "#\($0)", font: .monospaced,
                color: style.map { .custom($0.outerColor, $0.innerColor) } ?? .blue) }
            self.stickerReady = uniqueGift != nil || self.decorationModel != nil
            let subject: GiftItemComponent.Subject = uniqueGift.map { .uniqueGift(gift: $0, price: nil) }
                ?? .preview(attributes: self.decorationAttributes, rarity: nil)
            let _ = self.giftContent.update(
                transition: .immediate,
                component: AnyComponent(GiftItemComponent(
                    context: context, theme: theme,
                    strings: context.sharedContext.currentPresentationData.with { $0 }.strings,
                    subject: subject,
                    ribbon: ribbon, mode: .grid, cornerRadius: 16, allowAnimations: true
                )),
                environment: {},
                containerSize: CGSize(width: side, height: side)
            )
            if let content = self.giftContent.view {
                if content.superview == nil { self.giftTile.addSubview(content) }
                content.frame = self.giftTile.bounds
            }
        }

        func setModelSilhouette(_ visible: Bool, image: UIImage?, frame: CGRect) {
            let showSilhouette = visible && image != nil && self.decorationStyle != nil
            (self.giftContent.view as? GiftItemComponent.View)?.setModelHidden(showSilhouette)
            if self.silhouetteSource !== image {
                self.silhouetteSource = image
                self.modelSilhouette.image = image?.withRenderingMode(.alwaysTemplate)
            }
            if showSilhouette, self.modelSilhouette.superview == nil {
                self.modelSilhouette.isUserInteractionEnabled = false
                self.giftTile.addSubview(self.modelSilhouette)
            }
            if let style = self.decorationStyle {
                self.modelSilhouette.tintColor = UIColor(rgb: UInt32(bitPattern: style.outerColor))
                    .withMultiplied(hue: 1.0, saturation: 1.1, brightness: 0.86)
            }
            self.modelSilhouette.frame = frame
            self.modelSilhouette.isHidden = !showSilhouette
        }

        override var isHighlighted: Bool {
            didSet {
                self.alpha = self.isHighlighted ? 0.7 : 1.0
            }
        }

        @objc private func pressed() {
            self.action?()
        }
    }

    var visibleGiftsChanged: (([WalletContext.Collectible]) -> Void)?
    private var occupied = Set<String>()
    private var lifted = Set<String>()
    private var giftMedia: [String: WalletGiftStickerMedia] = [:]
    private var giftStyles: [String: WalletContext.CardGiftStyle] = [:]
    private static let cornerRadius: CGFloat = 16
    private var viewport = CGRect.zero
    var visibleGifts: [WalletContext.Collectible] {
        self.items.filter { $0.kind == .gift && self.itemViews[$0.address] != nil }
    }

    func setStickers(occupied: Set<String>, lifted: Set<String> = [], styles: [String: WalletContext.CardGiftStyle], media: [String: WalletGiftStickerMedia]) {
        self.occupied = occupied
        self.lifted = lifted
        self.giftStyles = styles
        self.giftMedia = media
        for (id, view) in self.itemViews {
            let lifted = self.lifted.contains(id)
            if let item = self.items.first(where: { $0.address == id }), item.kind == .gift,
               let context = self.context, let theme = self.theme {
                view.updateGiftTile(context: context, theme: theme, item: item, media: media[id], side: self.itemSide)
                view.setModelSilhouette(occupied.contains(id) || lifted, image: media[id]?.first?.art,
                    frame: self.stickerModelFrame(address: id, side: self.itemSide))
            }
            view.media.setAnimationVisible(!lifted && view.frame.intersects(self.viewport))
        }
    }

    func stickerCandidate(at point: CGPoint, in host: UIView) -> (WalletContext.Collectible, CGRect)? {
        guard self.superview != nil, !self.isHidden, self.alpha > 0.01 else { return nil }
        let local = self.convert(point, from: host)
        guard self.viewport.contains(local) else { return nil }
        for item in self.items where item.kind == .gift {
            if let view = self.itemViews[item.address], view.frame.contains(local) {
                return (item, self.convert(view.layer.presentation()?.frame ?? view.frame, to: host))
            }
        }
        return nil
    }

    func isStickerReady(address: String) -> Bool { self.itemViews[address]?.stickerReady == true }

    func stickerModelFrame(address: String, side: CGFloat) -> CGRect {
        let iconSide = floor(side * 0.7)
        let origin = floorToScreenPixels((side - iconSide) / 2)
        let hasUniqueGift = self.items.first(where: { $0.address == address })?.nft?.gift != nil || self.giftMedia[address]?.uniqueGift != nil
        let artSide = iconSide / WalletGiftStickerMedia.contentFraction
        return CGRect(x: origin + (iconSide - artSide) / 2,
            y: origin + (hasUniqueGift ? 0 : -4) + (iconSide - artSide) / 2,
            width: artSide, height: artSide)
    }

    func stickerSourceView(address: String) -> UIView? { self.itemViews[address] }

    var isShown: Bool { self.superview != nil && !self.isHidden && self.alpha > 0.5 && self.isUserInteractionEnabled }

    func setStickerWiggle(address: String, angle: CGFloat, scale: CGFloat) {
        self.itemViews[address]?.setModelWiggle(angle: angle, scale: scale)
    }

    func setStickerReturnScale(address: String, scale: CGFloat) {
        self.itemViews[address]?.transform = CGAffineTransform(scaleX: scale, y: scale)
    }

    func pressSticker(address: String, pressed: Bool) {
        guard let view = self.itemViews[address] else { return }
        UIView.animate(withDuration: pressed ? 0.32 : 0.25, delay: 0,
            usingSpringWithDamping: 0.78, initialSpringVelocity: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            view.transform = pressed ? CGAffineTransform(scaleX: 1.15, y: 1.15) : .identity
        }
    }

    func stickerFrame(address: String, in host: UIView) -> CGRect? {
        guard self.superview != nil, let view = self.itemViews[address], view.frame.intersects(self.viewport) else { return nil }
        return self.convert(view.layer.presentation()?.frame ?? view.frame, to: host)
    }

    private var items: [WalletContext.Collectible] = []
    private var itemViews: [String: ItemView] = [:]
    private var context: AccountContext?
    private var theme: PresentationTheme?
    private var openCollectible: ((WalletContext.Collectible) -> Void)?
    private var itemSide: CGFloat = 0.0
    private let spacing: CGFloat = 10.0

    func update(context: AccountContext, theme: PresentationTheme, items: [WalletContext.Collectible], width: CGFloat, visibleBounds: CGRect, transition: ComponentTransition, openCollectible: @escaping (WalletContext.Collectible) -> Void) -> CGSize {
        self.context = context
        self.theme = theme
        self.items = items
        self.openCollectible = openCollectible
        self.itemSide = floorToScreenPixels(max(0.0, width - self.spacing * 2.0) / 3.0)
        self.updateVisibleBounds(visibleBounds, transition: transition)
        let rowCount = (items.count + 2) / 3
        return CGSize(width: width, height: CGFloat(rowCount) * self.itemSide + CGFloat(max(0, rowCount - 1)) * self.spacing)
    }

    func updateVisibleBounds(_ visibleBounds: CGRect, transition: ComponentTransition) {
        guard let context = self.context, let theme = self.theme, self.itemSide > 0.0 else { return }
        self.viewport = visibleBounds
        // Preload nearby cells, but only play animations inside the actual viewport.
        let preloadBounds = visibleBounds.insetBy(dx: 0.0, dy: -100.0)
        let stride = self.itemSide + self.spacing
        let firstRow = max(0, Int(floor(preloadBounds.minY / stride)))
        let lastRow = max(firstRow, Int(ceil(preloadBounds.maxY / stride)))
        let firstIndex = min(self.items.count, firstRow * 3)
        let lastIndex = min(self.items.count, lastRow * 3)
        var validIds = Set<String>()
        for index in firstIndex ..< lastIndex {
            let item = self.items[index]
            let frame = CGRect(x: CGFloat(index % 3) * stride, y: CGFloat(index / 3) * stride, width: self.itemSide, height: self.itemSide)
            validIds.insert(item.address)
            let view: ItemView
            let itemTransition: ComponentTransition
            if let current = self.itemViews[item.address] {
                view = current
                itemTransition = transition
            } else {
                view = ItemView(frame: .zero)
                self.itemViews[item.address] = view
                self.addSubview(view)
                itemTransition = .immediate
            }
            view.accessibilityLabel = item.name
            view.accessibilityValue = item.subtitle
            view.action = { [weak self] in self?.openCollectible?(item) }
            view.media.isHidden = item.kind == .gift
            view.giftTile.isHidden = item.kind != .gift
            if item.kind != .gift {
                view.media.update(context: context, theme: theme, image: item.image ?? item.thumbnail, lottie: nil,
                    size: frame.size, cornerRadius: Self.cornerRadius, transition: itemTransition)
            }
            itemTransition.setFrame(view: view.media, frame: CGRect(origin: .zero, size: frame.size))
            itemTransition.setPosition(view: view, position: CGPoint(x: frame.midX, y: frame.midY))
            itemTransition.setBounds(view: view, bounds: CGRect(origin: .zero, size: frame.size))
            view.media.setAnimationVisible(!self.occupied.contains(item.address) && frame.intersects(visibleBounds))
        }
        for id in Array(self.itemViews.keys) where !validIds.contains(id) {
            if let view = self.itemViews.removeValue(forKey: id) {
                view.media.setAnimationVisible(false)
                view.removeFromSuperview()
            }
        }
        self.setStickers(occupied: self.occupied, lifted: self.lifted, styles: self.giftStyles, media: self.giftMedia)
        self.visibleGiftsChanged?(self.visibleGifts)
    }

    func clearVisibleItems() {
        for view in self.itemViews.values {
            view.media.setAnimationVisible(false)
            view.removeFromSuperview()
        }
        self.itemViews.removeAll()
    }
}
