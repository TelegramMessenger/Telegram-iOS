import Foundation
import UIKit
import Display

func cameraBatchThumbnailSide(screenSize: CGSize) -> CGFloat {
    let longSide = max(screenSize.width, screenSize.height)
    let pixel = UIScreenPixel
    if longSide >= 956.0 {
        return 145.0 + pixel
    } else if longSide >= 926.0 {
        return 141.0 + pixel
    } else if longSide >= 896.0 {
        return 137.0 - pixel
    } else if longSide >= 874.0 {
        return 133.0 - pixel
    } else if longSide >= 844.0 {
        return 129.0 - pixel
    } else if longSide >= 812.0 {
        return 124.0 - pixel
    } else if longSide >= 736.0 {
        return 137.0 - pixel
    } else if longSide >= 667.0 {
        return 124.0 - pixel
    } else {
        return 106.0 - pixel
    }
}

private func cameraBatchDurationString(_ duration: Double) -> String {
    let seconds = Int(ceil(duration))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
}

private let counterBackgroundImage: UIImage = {
    return generateImage(CGSize(width: 38.0, height: 38.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        context.setFillColor(UIColor(white: 0.0, alpha: 0.5).cgColor)
        context.fillEllipse(in: CGRect(x: 3.5, y: 1.0, width: 31.0, height: 31.0))
        context.setLineWidth(UIScreenScale >= 3.0 ? 5.0 / 3.0 : 1.5)
        context.setStrokeColor(UIColor.white.cgColor)
        context.strokeEllipse(in: CGRect(x: 3.0, y: 1.0, width: 31.0, height: 31.0))
    })!
}()

private let counterCrossImage: UIImage = {
    return generateImage(CGSize(width: 11.0, height: 11.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.move(to: CGPoint(x: 1.0, y: 1.0))
        context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - 1.0))
        context.move(to: CGPoint(x: size.width - 1.0, y: 1.0))
        context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
        context.strokePath()
    })!
}()

private let deleteButtonImage: UIImage = {
    return generateImage(CGSize(width: 32.0, height: 32.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        let circleRect = CGRect(origin: .zero, size: size).insetBy(dx: 4.5, dy: 4.5)
        context.setFillColor(UIColor(white: 0.0, alpha: 0.7).cgColor)
        context.fillEllipse(in: circleRect)
        context.setShadow(offset: .zero, blur: 2.5, color: UIColor(white: 0.0, alpha: 0.22).cgColor)
        context.setLineWidth(1.5)
        context.setStrokeColor(UIColor.white.cgColor)
        context.strokeEllipse(in: circleRect)
        context.setShadow(offset: .zero, blur: 0.0, color: nil)
        context.setLineWidth(1.5)
        context.setLineCap(.round)
        let crossInset: CGFloat = 12.0
        context.move(to: CGPoint(x: crossInset, y: crossInset))
        context.addLine(to: CGPoint(x: size.width - crossInset, y: size.height - crossInset))
        context.move(to: CGPoint(x: size.width - crossInset, y: crossInset))
        context.addLine(to: CGPoint(x: crossInset, y: size.height - crossInset))
        context.strokePath()
    })!
}()

private let cellGradientImage: UIImage = {
    return generateImage(CGSize(width: 1.0, height: 20.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        let colors = [UIColor(white: 0.0, alpha: 0.0).cgColor, UIColor(white: 0.0, alpha: 0.8).cgColor] as CFArray
        var locations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: size.height), end: CGPoint(x: 0.0, y: 0.0), options: [])
    })!
}()

final class CameraBatchCounterView: UIControl {
    static let size = CGSize(width: 38.0, height: 38.0)

    private let wrapperView = UIView()
    private let backgroundView = UIImageView(image: counterBackgroundImage)
    private let countLabel = UILabel()
    private let crossView = UIImageView(image: counterCrossImage)

    private(set) var count = 0
    private(set) var isShown = false
    private(set) var isToggled = false

    var tapped: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.isExclusiveTouch = true

        self.wrapperView.isUserInteractionEnabled = false
        self.wrapperView.alpha = 0.0
        self.wrapperView.isHidden = true
        self.addSubview(self.wrapperView)

        self.wrapperView.addSubview(self.backgroundView)

        self.countLabel.font = Font.with(size: 18.0, design: .round)
        self.countLabel.textColor = .white
        self.countLabel.textAlignment = .center
        self.wrapperView.addSubview(self.countLabel)

        self.crossView.alpha = 0.0
        self.wrapperView.addSubview(self.crossView)

        self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            if self.isHighlighted {
                self.wrapperView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            } else {
                UIView.animate(withDuration: 0.2, animations: {
                    self.wrapperView.transform = .identity
                })
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let transform = self.wrapperView.transform
        self.wrapperView.transform = .identity
        self.wrapperView.frame = self.bounds
        self.wrapperView.transform = transform
        self.backgroundView.frame = CGRect(origin: CGPoint(x: floor((self.bounds.width - 38.0) / 2.0), y: floor((self.bounds.height - 38.0) / 2.0) + 2.0), size: CGSize(width: 38.0, height: 38.0))
        let circleCenter = CGPoint(x: self.backgroundView.frame.minX + 19.0, y: self.backgroundView.frame.minY + 16.5)
        self.countLabel.frame = CGRect(x: circleCenter.x - 19.0, y: circleCenter.y - 12.0 + UIScreenPixel, width: 38.0, height: 24.0)
        self.crossView.frame = CGRect(origin: CGPoint(x: circleCenter.x - 5.5, y: circleCenter.y - 5.5), size: CGSize(width: 11.0, height: 11.0))
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard self.isShown, self.bounds.insetBy(dx: -4.0, dy: -4.0).contains(point) else {
            return nil
        }
        return self
    }

    @objc private func pressed() {
        self.tapped?()
    }

    func setToggled(_ toggled: Bool, animated: Bool) {
        guard self.isToggled != toggled else {
            return
        }
        self.isToggled = toggled
        let changes = {
            self.countLabel.alpha = toggled ? 0.0 : 1.0
            self.crossView.alpha = toggled ? 1.0 : 0.0
        }
        if animated {
            UIView.animate(withDuration: 0.2, animations: changes)
        } else {
            changes()
        }
    }

    func setCount(_ count: Int, animated: Bool) {
        let increasing = count > self.count
        self.count = count
        self.countLabel.text = "\(count)"
        guard animated, self.isShown, !self.isToggled else {
            return
        }
        UIView.animate(withDuration: 0.12, delay: 0.0, options: [.curveEaseOut], animations: {
            self.wrapperView.transform = increasing ? CGAffineTransform(scaleX: 1.2, y: 1.2) : CGAffineTransform(scaleX: 0.8, y: 0.8)
        }, completion: { finished in
            if finished {
                UIView.animate(withDuration: 0.08, delay: 0.0, options: [.curveEaseIn], animations: {
                    self.wrapperView.transform = .identity
                })
            }
        })
    }

    func setShown(_ shown: Bool, animated: Bool) {
        guard self.isShown != shown else {
            return
        }
        self.isShown = shown
        if animated {
            self.wrapperView.isHidden = false
            if shown {
                UIView.animate(withDuration: 0.12, delay: 0.0, options: [.curveEaseOut], animations: {
                    self.wrapperView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                }, completion: { finished in
                    if finished {
                        UIView.animate(withDuration: 0.08, delay: 0.0, options: [.curveEaseIn], animations: {
                            self.wrapperView.transform = .identity
                        })
                    }
                })
                UIView.animate(withDuration: 0.2, animations: {
                    self.wrapperView.alpha = 1.0
                })
            } else {
                UIView.animate(withDuration: 0.12, delay: 0.0, options: [.curveEaseIn], animations: {
                    self.wrapperView.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                }, completion: { finished in
                    if finished, !self.isShown {
                        self.wrapperView.transform = .identity
                        self.wrapperView.isHidden = true
                    }
                })
                UIView.animate(withDuration: 0.1, animations: {
                    self.wrapperView.alpha = 0.0
                })
            }
        } else {
            self.wrapperView.layer.removeAllAnimations()
            self.wrapperView.transform = .identity
            self.wrapperView.alpha = shown ? 1.0 : 0.0
            self.wrapperView.isHidden = !shown
        }
    }
}

private final class CameraBatchStripCell: UIView {
    let uniqueId: String
    private let imageView = UIImageView()
    private let gradientView = UIImageView(image: cellGradientImage)
    private let durationLabel = UILabel()
    private let deleteButton = HighlightableButton()

    var selected: ((String) -> Void)?
    var removed: ((String) -> Void)?

    init(item: CameraBatch.Item) {
        self.uniqueId = item.uniqueId
        super.init(frame: .zero)

        self.clipsToBounds = true
        self.layer.cornerRadius = 4.0

        self.imageView.contentMode = .scaleAspectFill
        self.imageView.clipsToBounds = true
        self.imageView.image = item.thumbnail
        self.imageView.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        self.addSubview(self.imageView)

        if case let .video(_, _, duration, _, _) = item.content {
            self.addSubview(self.gradientView)
            self.durationLabel.font = Font.regular(12.0)
            self.durationLabel.textColor = .white
            self.durationLabel.textAlignment = .right
            self.durationLabel.text = cameraBatchDurationString(duration)
            self.addSubview(self.durationLabel)
        }

        self.deleteButton.setImage(deleteButtonImage, for: .normal)
        self.deleteButton.addTarget(self, action: #selector(self.deletePressed), for: .touchUpInside)
        self.addSubview(self.deleteButton)

        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.imageView.frame = self.bounds
        self.deleteButton.frame = CGRect(x: self.bounds.width - 32.0, y: 0.0, width: 32.0, height: 32.0)
        self.gradientView.frame = CGRect(x: 0.0, y: self.bounds.height - 20.0, width: self.bounds.width, height: 20.0)
        self.durationLabel.sizeToFit()
        let labelSize = CGSize(width: ceil(self.durationLabel.bounds.width), height: ceil(self.durationLabel.bounds.height))
        self.durationLabel.frame = CGRect(x: self.bounds.width - labelSize.width - 4.0, y: self.bounds.height - labelSize.height - 2.0, width: labelSize.width, height: labelSize.height)
    }

    @objc private func deletePressed() {
        self.removed?(self.uniqueId)
    }

    @objc private func tapped() {
        self.selected?(self.uniqueId)
    }
}

final class CameraBatchStripView: UIView {
    private let wrapperView = UIView()
    private let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let maskContainerView = UIView()
    private let scrollView = UIScrollView()
    private var cells: [CameraBatchStripCell] = []

    private(set) var isShown = false
    private var itemSide: CGFloat = 106.0

    var itemSelected: ((String) -> Void)?
    var itemRemoved: ((String) -> Void)?

    static func height(itemSide: CGFloat) -> CGFloat {
        return itemSide + 4.0 * 2.0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.isHidden = true
        self.wrapperView.alpha = 0.0
        self.addSubview(self.wrapperView)

        self.effectView.clipsToBounds = true
        self.effectView.layer.cornerRadius = 8.0
        self.wrapperView.addSubview(self.effectView)

        self.maskContainerView.clipsToBounds = true
        self.wrapperView.addSubview(self.maskContainerView)

        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.alwaysBounceHorizontal = false
        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.scrollView.clipsToBounds = false
        self.maskContainerView.addSubview(self.scrollView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard self.isShown else {
            return nil
        }
        let result = super.hitTest(point, with: event)
        if let result, result.isDescendant(of: self.scrollView) {
            return result
        }
        return nil
    }

    func update(items: [CameraBatch.Item], itemSide: CGFloat, animated: Bool) {
        self.itemSide = itemSide
        let previousIds = self.cells.map { $0.uniqueId }
        var updatedCells: [CameraBatchStripCell] = []
        for item in items {
            if let cell = self.cells.first(where: { $0.uniqueId == item.uniqueId }) {
                updatedCells.append(cell)
            } else {
                let cell = CameraBatchStripCell(item: item)
                cell.selected = { [weak self] id in
                    self?.itemSelected?(id)
                }
                cell.removed = { [weak self] id in
                    self?.itemRemoved?(id)
                }
                self.scrollView.addSubview(cell)
                updatedCells.append(cell)
            }
        }
        for cell in self.cells where !updatedCells.contains(where: { $0 === cell }) {
            if animated {
                UIView.animate(withDuration: 0.2, animations: {
                    cell.alpha = 0.0
                    cell.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                }, completion: { _ in
                    cell.removeFromSuperview()
                })
            } else {
                cell.removeFromSuperview()
            }
        }
        self.cells = updatedCells
        let inserted = items.count > previousIds.count && !(items.last.flatMap { last in previousIds.contains(last.uniqueId) } ?? true)

        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                self.layoutStrip()
            })
        } else {
            self.layoutStrip()
        }
        if inserted {
            let offset = max(-self.scrollView.contentInset.left, self.scrollView.contentSize.width - self.scrollView.bounds.width + self.scrollView.contentInset.right)
            self.scrollView.setContentOffset(CGPoint(x: offset, y: 0.0), animated: animated)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        UIView.performWithoutAnimation {
            self.layoutStrip()
        }
    }

    private func layoutStrip() {
        let spacing: CGFloat = 4.0
        let count = max(1, self.cells.count)
        let contentWidth = CGFloat(count) * (self.itemSide + spacing) - spacing
        let backgroundWidth = max(0.0, min(self.bounds.width, contentWidth + 8.0))

        if self.wrapperView.layer.animation(forKey: "position") == nil {
            self.wrapperView.bounds = CGRect(origin: .zero, size: self.bounds.size)
            if self.isShown {
                self.wrapperView.center = CGPoint(x: self.bounds.width / 2.0, y: self.bounds.height / 2.0)
            }
        }

        let backgroundFrame = CGRect(x: self.bounds.width - backgroundWidth, y: 0.0, width: backgroundWidth, height: self.bounds.height)
        self.effectView.frame = backgroundFrame
        self.maskContainerView.frame = CGRect(x: backgroundFrame.minX, y: backgroundFrame.minY + 4.0, width: backgroundFrame.width, height: backgroundFrame.height - 8.0)
        self.scrollView.frame = self.maskContainerView.bounds
        self.scrollView.contentInset = UIEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0)
        for (index, cell) in self.cells.enumerated() {
            cell.alpha = 1.0
            cell.transform = .identity
            cell.frame = CGRect(x: CGFloat(index) * (self.itemSide + spacing), y: 0.0, width: self.itemSide, height: self.itemSide)
        }
        self.scrollView.contentSize = CGSize(width: max(0.0, contentWidth), height: self.itemSide)
    }

    func setShown(_ shown: Bool, animated: Bool) {
        guard self.isShown != shown else {
            return
        }
        self.isShown = shown
        let shownCenter = CGPoint(x: self.bounds.width / 2.0, y: self.bounds.height / 2.0)
        let hiddenCenter = CGPoint(x: self.bounds.width / 2.0, y: self.bounds.height / 2.0 + self.bounds.height / 3.0)
        if animated {
            if shown {
                self.isHidden = false
                if self.wrapperView.alpha.isZero {
                    self.wrapperView.center = hiddenCenter
                }
                UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 0.72, initialSpringVelocity: 0.0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                    self.wrapperView.alpha = 1.0
                    self.wrapperView.center = shownCenter
                })
            } else {
                UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 0.72, initialSpringVelocity: 0.0, options: [.beginFromCurrentState], animations: {
                    self.wrapperView.alpha = 0.0
                    self.wrapperView.center = hiddenCenter
                }, completion: { _ in
                    if !self.isShown {
                        self.isHidden = true
                    }
                })
            }
        } else {
            self.wrapperView.layer.removeAllAnimations()
            self.wrapperView.alpha = shown ? 1.0 : 0.0
            self.wrapperView.center = shown ? shownCenter : hiddenCenter
            self.isHidden = !shown
        }
    }
}
