import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import AccountContext
import GiftItemComponent

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

    private static let sideInset: CGFloat = 16.0
    private static let spacing: CGFloat = 10.0
    private static let columns = 3
    private static let top: CGFloat = 16.0 + 17.0 + 12.0

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

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        let column = index % QrStudioGiftsTabView.columns
        let row = index / QrStudioGiftsTabView.columns
        return CGRect(x: QrStudioGiftsTabView.sideInset + CGFloat(column) * (itemSide + QrStudioGiftsTabView.spacing), y: QrStudioGiftsTabView.top + CGFloat(row) * (itemSide + QrStudioGiftsTabView.spacing), width: itemSide, height: itemSide)
    }

    func update(size: CGSize, context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, gifts: [QrStudioGift], selectedId: Int64?) {
        self.params = Params(size: size, context: context, theme: theme, strings: strings, gifts: gifts, selectedId: selectedId)
        self.scrollView.frame = CGRect(origin: CGPoint(), size: size)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.fadeMask.frame = CGRect(origin: CGPoint(), size: size)
        self.fadeMask.locations = [0.0, NSNumber(value: Double(14.0 / max(size.height, 1.0))), 1.0]
        self.fadeMask.startPoint = CGPoint(x: 0.5, y: 0.0)
        self.fadeMask.endPoint = CGPoint(x: 0.5, y: 1.0)

        let itemSide = self.itemSide(width: size.width)
        CATransaction.commit()

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
        let contentHeight = QrStudioGiftsTabView.top + CGFloat(rows) * itemSide + CGFloat(max(0, rows - 1)) * QrStudioGiftsTabView.spacing + 12.0 + 40.0
        let contentSize = CGSize(width: size.width, height: contentHeight)
        if self.scrollView.contentSize != contentSize {
            self.scrollView.contentSize = contentSize
        }

        self.updateVisibleItems()
    }

    private func updateVisibleItems() {
        guard let params = self.params, params.size.width > 0.0 else {
            return
        }
        let itemSide = self.itemSide(width: params.size.width)
        let itemSize = CGSize(width: itemSide, height: itemSide)
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
                transition: isNew ? .immediate : .easeInOut(duration: 0.2),
                component: AnyComponent(GiftItemComponent(
                    context: params.context,
                    style: .glass,
                    theme: params.theme,
                    strings: params.strings,
                    subject: .uniqueGift(gift: gift.gift, price: nil),
                    ribbon: GiftItemComponent.Ribbon(text: "#\(gift.gift.number)", font: .monospaced, color: ribbonColor),
                    isSelected: gift.id == params.selectedId,
                    mode: .grid,
                    selectionStyle: .trimmedBackground(color: gift.outer.uiColor),
                    action: { [weak self] in
                        self?.selected?(giftId)
                    }
                )),
                environment: {},
                containerSize: itemSize
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
