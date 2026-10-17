import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import AccountContext
import GiftItemComponent
import LottieAnimationComponent

final class QrStudioGiftsTabView: UIView, UIScrollViewDelegate {
    private struct Params {
        let size: CGSize
        let context: AccountContext
        let theme: PresentationTheme
        let strings: PresentationStrings
        let gifts: [QrStudioGift]
        let selectedId: Int64?
    }

    let scrollView = UIScrollView()
    var selected: ((Int64) -> Void)?
    var loadMore: (() -> Void)?
    var browse: (() -> Void)?

    private let emptyView = UIView()
    private let emptySticker = ComponentView<Empty>()
    private let emptyTitleLabel = UILabel()
    private let emptyTextLabel = UILabel()
    private let browseButton = HighlightTrackingButton()
    private let browseLabel = UILabel()

    private let titleLabel = UILabel()
    private let vibrantHeaders = QrStudioVibrantHeaders()
    var tintMaskContainer: UIView? {
        didSet {
            self.vibrantHeaders.attach(to: self.tintMaskContainer)
        }
    }
    private var items: [Int64: ComponentView<Empty>] = [:]
    private let fadeMask = CAGradientLayer()
    private var params: Params?
    private var isRevealingSelection = false

    private static let sideInset: CGFloat = 16.0
    private static let spacing: CGFloat = 10.0
    private static let columns = 3
    private static let top: CGFloat = 16.0 + 17.0 + 12.0
    private static let bannerHeight: CGFloat = 150.0

    static func compactHeight(count: Int, width: CGFloat, bottomInset: CGFloat) -> CGFloat? {
        switch count {
        case 0:
            return 312.0
        case 1, 2:
            return QrStudioGiftsTabView.top + QrStudioGiftsTabView.bannerHeight + 12.0 + bottomInset
        case 3:
            let side = floor((width - QrStudioGiftsTabView.sideInset * 2.0 - QrStudioGiftsTabView.spacing * 2.0) / 3.0)
            return ceil(QrStudioGiftsTabView.top + side + 12.0 + bottomInset)
        default:
            return nil
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.delegate = self
        self.addSubview(self.scrollView)

        self.titleLabel.textAlignment = .center
        self.scrollView.addSubview(self.titleLabel)

        self.fadeMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor]
        self.layer.mask = self.fadeMask

        self.emptyView.isHidden = true
        self.addSubview(self.emptyView)
        self.emptyTitleLabel.font = Font.semibold(20.0)
        self.emptyTitleLabel.textAlignment = .center
        self.emptyView.addSubview(self.emptyTitleLabel)
        self.emptyTextLabel.font = Font.regular(15.0)
        self.emptyTextLabel.textAlignment = .center
        self.emptyTextLabel.numberOfLines = 0
        self.emptyView.addSubview(self.emptyTextLabel)
        self.browseButton.clipsToBounds = true
        self.browseButton.addSubview(self.browseLabel)
        self.browseLabel.font = Font.semibold(15.0)
        self.browseLabel.textColor = .white
        self.browseButton.addTarget(self, action: #selector(self.browsePressed), for: .touchUpInside)
        self.browseButton.highligthedChanged = { [weak self] highlighted in
            self?.browseButton.alpha = highlighted ? 0.7 : 1.0
        }
        self.emptyView.addSubview(self.browseButton)

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func browsePressed() {
        self.browse?()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.vibrantHeaders.setContentOffset(scrollView.contentOffset)
        self.updateVisibleItems()
        if scrollView.contentOffset.y + scrollView.bounds.height > scrollView.contentSize.height - 200.0 {
            self.loadMore?()
        }
    }

    private func itemSide(width: CGFloat) -> CGFloat {
        let columns = CGFloat(QrStudioGiftsTabView.columns)
        return floor((width - QrStudioGiftsTabView.sideInset * 2.0 - QrStudioGiftsTabView.spacing * (columns - 1.0)) / columns)
    }

    private func itemFrame(index: Int, itemSide: CGFloat) -> CGRect {
        if let params = self.params, params.gifts.count <= 2 {
            let count = CGFloat(params.gifts.count)
            let width = floor((params.size.width - QrStudioGiftsTabView.sideInset * 2.0 - QrStudioGiftsTabView.spacing * (count - 1.0)) / count)
            return CGRect(x: QrStudioGiftsTabView.sideInset + CGFloat(index) * (width + QrStudioGiftsTabView.spacing), y: QrStudioGiftsTabView.top, width: width, height: QrStudioGiftsTabView.bannerHeight)
        }
        let column = index % QrStudioGiftsTabView.columns
        let row = index / QrStudioGiftsTabView.columns
        return CGRect(x: QrStudioGiftsTabView.sideInset + CGFloat(column) * (itemSide + QrStudioGiftsTabView.spacing), y: QrStudioGiftsTabView.top + CGFloat(row) * (itemSide + QrStudioGiftsTabView.spacing), width: itemSide, height: itemSide)
    }

    func update(size: CGSize, context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, gifts: [QrStudioGift], isLoaded: Bool, selectedId: Int64?, revealSelection: Bool, scrollsToSelection: Bool) {
        self.params = Params(size: size, context: context, theme: theme, strings: strings, gifts: gifts, selectedId: selectedId)
        self.scrollView.frame = CGRect(origin: CGPoint(), size: size)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.fadeMask.frame = CGRect(origin: CGPoint(), size: size)
        self.fadeMask.locations = [0.0, NSNumber(value: Double(14.0 / max(size.height, 1.0))), 1.0]
        self.fadeMask.startPoint = CGPoint(x: 0.5, y: 0.0)
        self.fadeMask.endPoint = CGPoint(x: 0.5, y: 1.0)
        CATransaction.commit()

        let isEmpty = gifts.isEmpty
        self.scrollView.isHidden = isEmpty
        self.emptyView.isHidden = !(isEmpty && isLoaded)
        if isEmpty {
            self.vibrantHeaders.update(size: size, headers: [], isEnabled: false)
            if isLoaded {
                self.updateEmptyState(size: size, theme: theme, strings: strings)
            }
            return
        }

        let itemSide = self.itemSide(width: size.width)

        self.titleLabel.attributedText = NSAttributedString(string: strings.QrStudio_Gifts_Title.uppercased(), attributes: [
            .font: Font.semibold(13.0),
            .foregroundColor: theme.overallDarkAppearance ? theme.chat.inputMediaPanel.stickersSectionTextColor : theme.chat.inputMediaPanel.panelContentVibrantOverlayColor,
            .kern: -0.078
        ])
        self.titleLabel.frame = CGRect(x: 2.0, y: 16.0, width: size.width - 4.0, height: 17.0)
        if let text = self.titleLabel.attributedText {
            self.vibrantHeaders.update(size: size, headers: [(text, self.titleLabel.frame)], isEnabled: !theme.overallDarkAppearance)
            self.vibrantHeaders.setContentOffset(self.scrollView.contentOffset)
        }

        let rows = (gifts.count + QrStudioGiftsTabView.columns - 1) / QrStudioGiftsTabView.columns
        let rowsHeight = gifts.count <= 2 ? QrStudioGiftsTabView.bannerHeight : CGFloat(rows) * itemSide + CGFloat(max(0, rows - 1)) * QrStudioGiftsTabView.spacing
        let contentHeight = QrStudioGiftsTabView.top + rowsHeight + 12.0 + (gifts.count <= 3 ? 0.0 : 40.0)
        let contentSize = CGSize(width: size.width, height: contentHeight)
        if self.scrollView.contentSize != contentSize {
            self.scrollView.contentSize = contentSize
        }

        self.isRevealingSelection = revealSelection
        defer {
            self.isRevealingSelection = false
        }
        if revealSelection, scrollsToSelection, size.height > 0.0, !self.scrollView.isTracking, let selectedId, let index = gifts.firstIndex(where: { $0.id == selectedId }) {
            let frame = self.itemFrame(index: index, itemSide: itemSide)
            let offset = self.scrollView.contentOffset.y
            if frame.minY < offset + 14.0 || frame.maxY > offset + size.height - 40.0 {
                let maxOffset = max(0.0, contentHeight - size.height)
                self.scrollView.setContentOffset(CGPoint(x: 0.0, y: min(maxOffset, max(0.0, frame.midY - size.height * 0.5))), animated: false)
            }
        }

        self.updateVisibleItems()
    }

    private func updateEmptyState(size: CGSize, theme: PresentationTheme, strings: PresentationStrings) {
        self.emptyView.frame = CGRect(origin: CGPoint(), size: size)
        let stickerSide: CGFloat = 100.0
        let _ = self.emptySticker.update(
            transition: .immediate,
            component: AnyComponent(LottieAnimationComponent(animation: LottieAnimationComponent.AnimationItem(name: "QrStudioNoGifts", mode: .animating(loop: true)), colors: [:], size: CGSize(width: stickerSide, height: stickerSide))),
            environment: {},
            containerSize: CGSize(width: stickerSide, height: stickerSide)
        )
        var y: CGFloat = 28.0
        if let stickerView = self.emptySticker.view {
            if stickerView.superview == nil {
                self.emptyView.addSubview(stickerView)
            }
            stickerView.frame = CGRect(x: floor((size.width - stickerSide) * 0.5), y: y, width: stickerSide, height: stickerSide)
        }
        y += stickerSide + 12.0

        self.emptyTitleLabel.text = strings.QrStudio_Gifts_EmptyTitle
        self.emptyTitleLabel.textColor = theme.list.itemPrimaryTextColor
        let titleSize = self.emptyTitleLabel.sizeThatFits(CGSize(width: size.width - 32.0, height: 100.0))
        self.emptyTitleLabel.frame = CGRect(x: 16.0, y: y, width: size.width - 32.0, height: ceil(titleSize.height))
        y += ceil(titleSize.height) + 6.0

        self.emptyTextLabel.text = strings.QrStudio_Gifts_EmptyText
        self.emptyTextLabel.textColor = theme.list.itemSecondaryTextColor
        let textSize = self.emptyTextLabel.sizeThatFits(CGSize(width: size.width - 32.0, height: 200.0))
        self.emptyTextLabel.frame = CGRect(x: 16.0, y: y, width: size.width - 32.0, height: ceil(textSize.height))
        y += ceil(textSize.height) + 18.0

        self.browseLabel.text = strings.QrStudio_Gifts_Browse
        let labelSize = self.browseLabel.sizeThatFits(CGSize(width: size.width, height: 40.0))
        let buttonWidth = ceil(labelSize.width) + 44.0
        self.browseButton.backgroundColor = theme.list.itemCheckColors.fillColor
        self.browseButton.layer.cornerRadius = 20.0
        self.browseButton.frame = CGRect(x: floor((size.width - buttonWidth) * 0.5), y: y, width: buttonWidth, height: 40.0)
        self.browseLabel.frame = CGRect(x: 22.0, y: floor((40.0 - ceil(labelSize.height)) * 0.5), width: ceil(labelSize.width), height: ceil(labelSize.height))
    }

    private func updateVisibleItems() {
        guard let params = self.params, params.size.width > 0.0 else {
            return
        }
        let itemSide = self.itemSide(width: params.size.width)
        let isWide = params.gifts.count <= 2
        let visibleRect = self.scrollView.bounds.insetBy(dx: 0.0, dy: -itemSide)

        var validIds = Set<Int64>()
        for (index, gift) in params.gifts.enumerated() {
            let frame = self.itemFrame(index: index, itemSide: itemSide)
            guard frame.intersects(visibleRect) else {
                continue
            }
            validIds.insert(gift.id)
            let item: ComponentView<Empty>
            var isNew = false
            if let current = self.items[gift.id] {
                item = current
            } else {
                item = ComponentView()
                self.items[gift.id] = item
                isNew = true
            }
            let giftId = gift.id
            var ribbonColor: GiftItemComponent.Ribbon.Color = .blue
            for attribute in gift.gift.attributes {
                if case let .backdrop(_, _, innerColor, outerColor, _, _, _) = attribute {
                    ribbonColor = .custom(outerColor, innerColor)
                    break
                }
            }
            let _ = item.update(
                transition: isNew || self.isRevealingSelection ? .immediate : .easeInOut(duration: 0.2),
                component: AnyComponent(GiftItemComponent(
                    context: params.context,
                    style: .glass,
                    theme: params.theme,
                    strings: params.strings,
                    subject: .uniqueGift(gift: gift.gift, price: nil),
                    ribbon: GiftItemComponent.Ribbon(text: "#\(gift.gift.number)", font: .monospaced, color: ribbonColor),
                    isSelected: gift.id == params.selectedId,
                    mode: isWide ? .profile : .grid,
                    selectionStyle: .trimmedBackground(color: gift.outer.uiColor),
                    action: { [weak self] in
                        self?.selected?(giftId)
                    }
                )),
                environment: {},
                containerSize: frame.size
            )
            if let itemView = item.view {
                if itemView.superview == nil {
                    self.scrollView.addSubview(itemView)
                }
                itemView.frame = frame
            }
        }
        for (id, item) in self.items where !validIds.contains(id) {
            item.view?.removeFromSuperview()
            self.items.removeValue(forKey: id)
        }
    }
}
