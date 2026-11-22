import Foundation
import UIKit
import Display
import SwiftSignalKit
import LegacyComponents
import MediaCropComponent

private let chatMediaEditorSelectionShadowColor = UIColor(white: 0.0, alpha: 0.22)

private func chatMediaEditorSelectionRingLineWidth() -> CGFloat {
    return UIScreen.main.scale == 3.0 ? 5.0 / 3.0 : 1.5
}

private let chatMediaEditorSelectionPopSpring = mediaCropPopSpring(speed: 12.0, bounciness: 7.0)

let chatMediaEditorSelectionPopTransition: ContainedViewLayoutTransition = mediaCropSpringTransition(chatMediaEditorSelectionPopSpring)

private func chatMediaEditorAnimatePopRotation(view: UIView, from: CGFloat, to: CGFloat) {
    view.layer.removeAnimation(forKey: "popRotation")
    view.transform = CGAffineTransform(rotationAngle: to)
    let animation = CASpringAnimation(keyPath: "transform.rotation.z")
    animation.mass = chatMediaEditorSelectionPopSpring.mass
    animation.stiffness = chatMediaEditorSelectionPopSpring.stiffness
    animation.damping = chatMediaEditorSelectionPopSpring.damping
    animation.fromValue = from as NSNumber
    animation.toValue = to as NSNumber
    animation.duration = animation.settlingDuration
    animation.isRemovedOnCompletion = true
    view.layer.add(animation, forKey: "popRotation")
}

private func chatMediaEditorCurrentRotation(_ view: UIView) -> CGFloat {
    let layer = view.layer.presentation() ?? view.layer
    return (layer.value(forKeyPath: "transform.rotation.z") as? NSNumber).flatMap { CGFloat($0.doubleValue) } ?? 0.0
}

final class ChatMediaEditorCheckButton: UIControl {
    enum Style {
        case gallery
        case media
    }

    private let style: Style
    private let wrapperView: UIView
    private let backgroundLayer: CALayer
    private let fillView: UIImageView
    private let checkView: UIView
    private let shortFragment: UIView
    private let longFragment: UIView
    private let numberLabel: UILabel
    private(set) var isChecked = false
    private var number = 0

    private static let checkDefaultTransform = CGAffineTransform(rotationAngle: -CGFloat.pi / 4.0)

    init(style: Style, fillColor: UIColor, foregroundColor: UIColor) {
        self.style = style
        let size: CGSize
        let insideInset: CGFloat
        let lineWidth: CGFloat
        switch style {
        case .gallery:
            size = chatMediaEditorCheckButtonSize
            insideInset = 3.5
            lineWidth = chatMediaEditorSelectionRingLineWidth()
        case .media:
            size = CGSize(width: 32.0, height: 32.0)
            insideInset = 4.0
            lineWidth = 1.5
        }
        let bounds = CGRect(origin: .zero, size: size)

        self.wrapperView = UIView(frame: bounds)
        self.wrapperView.isUserInteractionEnabled = false

        self.backgroundLayer = CALayer()
        self.backgroundLayer.frame = bounds
        self.backgroundLayer.contents = generateImage(size, rotatedContext: { size, context in
            context.clear(CGRect(origin: .zero, size: size))
            context.setShadow(offset: .zero, blur: 2.5, color: chatMediaEditorSelectionShadowColor.cgColor)
            context.setLineWidth(lineWidth)
            context.setStrokeColor(UIColor.white.cgColor)
            context.strokeEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: insideInset + 0.5, dy: insideInset + 0.5))
        })?.cgImage

        self.fillView = UIImageView(frame: bounds)
        self.fillView.image = generateImage(size, rotatedContext: { size, context in
            context.clear(CGRect(origin: .zero, size: size))
            context.setFillColor(fillColor.cgColor)
            context.fillEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: insideInset + 1.2, dy: insideInset + 1.2))
        })
        self.fillView.alpha = 0.0
        self.fillView.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)

        self.checkView = UIView(frame: bounds.insetBy(dx: 4.0, dy: 4.0))
        self.checkView.alpha = 0.0
        self.checkView.isUserInteractionEnabled = false
        self.checkView.transform = ChatMediaEditorCheckButton.checkDefaultTransform

        let shortFrame: CGRect
        let longFrame: CGRect
        switch style {
        case .gallery:
            shortFrame = CGRect(x: 9.0, y: 10.5, width: 2.0, height: 8.0)
            longFrame = CGRect(x: 9.5, y: 16.5, width: 14.5, height: 2.0)
        case .media:
            shortFrame = CGRect(x: 6.5, y: 8.5, width: 1.5, height: 6.0)
            longFrame = CGRect(x: 7.5, y: 13.0, width: 11.0, height: 1.5)
        }
        self.shortFragment = UIView()
        self.shortFragment.backgroundColor = foregroundColor
        self.shortFragment.layer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        self.shortFragment.frame = shortFrame
        self.shortFragment.transform = CGAffineTransform(scaleX: 1.0, y: 0.0001)
        self.longFragment = UIView()
        self.longFragment.backgroundColor = foregroundColor
        self.longFragment.layer.anchorPoint = CGPoint(x: 0.0, y: 0.5)
        self.longFragment.frame = longFrame
        self.longFragment.transform = CGAffineTransform(scaleX: 0.0001, y: 1.0)

        self.numberLabel = UILabel(frame: CGRect(x: 0.0, y: -UIScreenPixel, width: size.width, height: size.height))
        self.numberLabel.backgroundColor = .clear
        self.numberLabel.textColor = foregroundColor
        self.numberLabel.textAlignment = .center
        self.numberLabel.isUserInteractionEnabled = false
        self.numberLabel.font = TGFont.roundedFont(ofSize: style == .gallery ? 18.0 : 16.0)
        self.numberLabel.alpha = 0.0

        super.init(frame: bounds)

        self.addSubview(self.wrapperView)
        self.wrapperView.layer.addSublayer(self.backgroundLayer)
        self.wrapperView.addSubview(self.fillView)
        self.wrapperView.addSubview(self.checkView)
        self.checkView.addSubview(self.shortFragment)
        self.checkView.addSubview(self.longFragment)
        self.fillView.addSubview(self.numberLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setNumber(_ number: Int?, animated: Bool) {
        let number = number ?? 0
        self.number = number
        if number > 0 {
            self.checkView.alpha = 0.0
            self.numberLabel.alpha = 1.0
            self.numberLabel.text = "\(number)"
            if self.style != .gallery {
                self.numberLabel.font = TGFont.roundedFont(ofSize: number < 10 ? 16.0 : 15.0)
            }
        } else if animated {
            UIView.animate(withDuration: 0.2, animations: {
                self.numberLabel.alpha = 0.0
            })
        } else {
            self.numberLabel.alpha = 0.0
        }
    }

    func setChecked(_ checked: Bool, animated: Bool) {
        if animated {
            if self.isChecked == checked {
                return
            }
            self.isChecked = checked
            self.fillView.transform = checked ? CGAffineTransform(scaleX: 0.01, y: 0.01) : .identity
            UIView.animate(withDuration: 0.19, animations: {
                self.fillView.alpha = checked ? 1.0 : 0.0
                self.fillView.transform = checked ? .identity : CGAffineTransform(scaleX: 0.01, y: 0.01)
            })
            if checked {
                UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 0.35, initialSpringVelocity: 0.8, options: [.beginFromCurrentState], animations: {
                    self.wrapperView.transform = .identity
                })
                if self.number == 0 {
                    self.checkView.alpha = 1.0
                    self.shortFragment.transform = CGAffineTransform(scaleX: 1.0, y: 0.0001)
                    self.longFragment.transform = CGAffineTransform(scaleX: 0.0001, y: 1.0)
                    UIView.animateKeyframes(withDuration: 0.21, delay: 0.0, options: [], animations: {
                        UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.333, animations: {
                            self.shortFragment.transform = .identity
                        })
                        UIView.addKeyframe(withRelativeStartTime: 0.333, relativeDuration: 0.666, animations: {
                            self.longFragment.transform = .identity
                        })
                    })
                }
            } else {
                let number = self.number
                UIView.animate(withDuration: 0.17, animations: {
                    if number == 0 {
                        self.checkView.transform = self.checkView.transform.scaledBy(x: 0.01, y: 0.01)
                        self.checkView.alpha = 0.0
                    }
                }, completion: { _ in
                    self.checkView.transform = ChatMediaEditorCheckButton.checkDefaultTransform
                })
            }
        } else {
            self.isChecked = checked
            self.fillView.alpha = checked ? 1.0 : 0.0
            self.fillView.transform = checked ? .identity : CGAffineTransform(scaleX: 0.1, y: 0.1)
            if self.number > 0 {
                self.checkView.alpha = 0.0
            } else {
                self.checkView.alpha = checked ? 1.0 : 0.0
                self.checkView.transform = ChatMediaEditorCheckButton.checkDefaultTransform
                self.shortFragment.transform = .identity
                self.longFragment.transform = .identity
            }
        }
    }

    private func setWrapperScale(_ scale: CGFloat) {
        UIView.animate(withDuration: 0.12, delay: 0.0, options: [.allowAnimatedContent], animations: {
            self.wrapperView.transform = CGAffineTransform(scaleX: scale, y: scale)
        })
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.setWrapperScale(0.85)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        self.setWrapperScale(1.0)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        self.setWrapperScale(1.0)
    }
}

private let chatMediaEditorCounterBackgroundImage: UIImage? = generateImage(CGSize(width: 38.0, height: 38.0), rotatedContext: { size, context in
    context.clear(CGRect(origin: .zero, size: size))
    context.setFillColor(UIColor(white: 0.0, alpha: 0.5).cgColor)
    context.fillEllipse(in: CGRect(x: 3.5, y: 1.0, width: 31.0, height: 31.0))
    context.setLineWidth(chatMediaEditorSelectionRingLineWidth())
    context.setStrokeColor(UIColor.white.cgColor)
    context.strokeEllipse(in: CGRect(x: chatMediaEditorCounterCircleFrame.minX - 13.0, y: chatMediaEditorCounterCircleFrame.minY, width: chatMediaEditorCounterCircleFrame.width, height: chatMediaEditorCounterCircleFrame.height))
})

final class ChatMediaEditorCounterButton: UIControl {
    private let wrapperView: UIView
    private let backgroundView: UIImageView
    private let countLabel: UILabel
    private let crossIconView: UIImageView
    private(set) var isInternalHidden = true
    private(set) var isOpen = false
    private var count = 0

    override init(frame: CGRect) {
        let bounds = CGRect(origin: .zero, size: chatMediaEditorCounterButtonSize)
        self.wrapperView = UIView(frame: bounds)
        self.wrapperView.alpha = 0.0
        self.wrapperView.isHidden = true
        self.wrapperView.isUserInteractionEnabled = false

        self.backgroundView = UIImageView(frame: CGRect(x: 13.0, y: 0.0, width: 38.0, height: 38.0))
        self.backgroundView.image = chatMediaEditorCounterBackgroundImage

        self.countLabel = UILabel(frame: CGRect(x: 0.0, y: -0.5, width: bounds.width + 1.0, height: bounds.height))
        self.countLabel.backgroundColor = .clear
        self.countLabel.font = TGFont.roundedFont(ofSize: 18.0)
        self.countLabel.textColor = .white
        self.countLabel.text = "0"

        self.crossIconView = UIImageView(frame: CGRect(x: 0.0, y: 0.0, width: bounds.width - 1.0, height: bounds.height - 5.0))
        self.crossIconView.alpha = 0.0
        self.crossIconView.contentMode = .center
        self.crossIconView.isHidden = true
        self.crossIconView.image = TGComponentsImageNamed("ImagePickerPhotoCounter_Close")

        super.init(frame: bounds)

        self.isExclusiveTouch = true
        self.addSubview(self.wrapperView)
        self.wrapperView.addSubview(self.backgroundView)
        self.wrapperView.addSubview(self.countLabel)
        self.wrapperView.addSubview(self.crossIconView)
        self.layoutCountLabel(sizeToFit: true)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.isInternalHidden {
            return nil
        }
        return super.hitTest(point, with: event)
    }

    override var isHighlighted: Bool {
        didSet {
            if self.isHighlighted {
                self.wrapperView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            }
        }
    }

    private func layoutCountLabel(sizeToFit: Bool) {
        let transform = self.countLabel.transform
        self.countLabel.transform = .identity
        if sizeToFit {
            self.countLabel.sizeToFit()
        }
        let labelWidth = ceil(self.countLabel.frame.width)
        let labelOrigin = 12.0 + UIScreenPixel + (38.0 - labelWidth) / 2.0
        self.countLabel.frame = CGRect(x: labelOrigin, y: 5.0 + UIScreenPixel, width: labelWidth, height: self.countLabel.frame.height)
        self.countLabel.transform = transform
    }

    func setInternalHidden(_ hidden: Bool, animated: Bool, completion: (() -> Void)? = nil) {
        guard self.isInternalHidden != hidden else {
            return
        }
        self.isInternalHidden = hidden
        if animated {
            self.wrapperView.isHidden = false
            if !hidden {
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
                }, completion: { finished in
                    if finished {
                        self.wrapperView.isHidden = self.isInternalHidden
                        completion?()
                    }
                })
            } else {
                self.countLabel.transform = .identity
                self.crossIconView.transform = .identity
                UIView.animate(withDuration: 0.12, delay: 0.0, options: [.curveEaseIn], animations: {
                    self.wrapperView.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                }, completion: { finished in
                    if finished {
                        self.wrapperView.transform = .identity
                        self.wrapperView.isHidden = self.isInternalHidden
                        completion?()
                    }
                })
                UIView.animate(withDuration: 0.1, animations: {
                    self.wrapperView.alpha = 0.0
                })
            }
        } else {
            self.wrapperView.alpha = hidden ? 0.0 : 1.0
            self.wrapperView.isHidden = hidden
            completion?()
        }
    }

    func setCount(_ count: Int, animated: Bool) {
        let increasing = count > self.count
        self.count = count
        self.countLabel.text = "\(count)"
        self.layoutCountLabel(sizeToFit: true)
        if self.isOpen || !animated {
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

    func setOpen(_ open: Bool, animated: Bool) {
        if animated {
            self.crossIconView.isHidden = false
            self.countLabel.isHidden = false
            var crossStart = chatMediaEditorCurrentRotation(self.crossIconView)
            var labelStart = chatMediaEditorCurrentRotation(self.countLabel)
            if self.isOpen != open {
                crossStart = open ? CGFloat.pi / 4.0 : 0.0
                labelStart = open ? 0.0 : -CGFloat.pi / 4.0
            }
            chatMediaEditorAnimatePopRotation(view: self.crossIconView, from: crossStart, to: open ? 0.0 : CGFloat.pi / 4.0)
            chatMediaEditorAnimatePopRotation(view: self.countLabel, from: labelStart, to: open ? -CGFloat.pi / 4.0 : 0.0)
            UIView.animate(withDuration: 0.2, animations: {
                self.wrapperView.transform = .identity
                self.crossIconView.alpha = open ? 1.0 : 0.0
                self.countLabel.alpha = open ? 0.0 : 1.0
            }, completion: { finished in
                if finished {
                    self.crossIconView.isHidden = !self.isOpen
                    self.countLabel.isHidden = self.isOpen
                }
            })
        } else {
            self.crossIconView.layer.removeAnimation(forKey: "popRotation")
            self.countLabel.layer.removeAnimation(forKey: "popRotation")
            self.crossIconView.alpha = open ? 1.0 : 0.0
            self.countLabel.alpha = open ? 0.0 : 1.0
            self.crossIconView.isHidden = !open
            self.countLabel.isHidden = open
        }
        self.isOpen = open
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.wrapperView.transform = .identity
        super.touchesCancelled(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.updatePressedScale(touches)
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.updatePressedScale(touches)
        super.touchesEnded(touches, with: event)
    }

    private func updatePressedScale(_ touches: Set<UITouch>) {
        if let touch = touches.first, self.bounds.contains(touch.location(in: self)) {
            self.wrapperView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        } else {
            self.wrapperView.transform = .identity
        }
    }
}

private let chatMediaEditorStripGradientImage: UIImage? = generateImage(CGSize(width: 1.0, height: 20.0), rotatedContext: { size, context in
    context.clear(CGRect(origin: .zero, size: size))
    let colors = [UIColor(white: 0.0, alpha: 0.0).cgColor, UIColor(white: 0.0, alpha: 0.8).cgColor] as CFArray
    var locations: [CGFloat] = [0.0, 1.0]
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: &locations) {
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: [])
    }
})

struct ChatMediaEditorStripItemInfo {
    var thumbnail: Signal<UIImage?, NoError>
    var videoDuration: Double?
}

final class ChatMediaEditorStripCell: UICollectionViewCell {
    let imageView: UIImageView
    private let gradientView: UIImageView
    private let iconView: UIImageView
    private let durationLabel: UILabel
    private(set) var checkButton: ChatMediaEditorCheckButton?
    private let thumbnailDisposable = MetaDisposable()
    private(set) var uniqueId: String?
    var checkPressed: ((ChatMediaEditorStripCell) -> Void)?

    override init(frame: CGRect) {
        self.imageView = UIImageView()
        self.imageView.contentMode = .scaleAspectFill
        self.imageView.clipsToBounds = true
        self.gradientView = UIImageView(image: chatMediaEditorStripGradientImage)
        self.gradientView.isHidden = true
        self.iconView = UIImageView()
        self.iconView.contentMode = .center
        self.durationLabel = UILabel()
        self.durationLabel.textColor = .white
        self.durationLabel.backgroundColor = .clear
        self.durationLabel.textAlignment = .right
        self.durationLabel.font = TGFont.systemFont(ofSize: 12.0)

        super.init(frame: frame)

        self.clipsToBounds = true
        self.layer.cornerRadius = 4.0
        self.contentView.addSubview(self.imageView)
        self.contentView.addSubview(self.gradientView)
        self.contentView.addSubview(self.iconView)
        self.contentView.addSubview(self.durationLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.thumbnailDisposable.dispose()
    }

    func setup(uniqueId: String, info: ChatMediaEditorStripItemInfo?, isChecked: Bool, fillColor: UIColor, foregroundColor: UIColor) {
        self.uniqueId = uniqueId
        if self.checkButton == nil {
            let checkButton = ChatMediaEditorCheckButton(style: .media, fillColor: fillColor, foregroundColor: foregroundColor)
            checkButton.addTarget(self, action: #selector(self.checkButtonPressed), for: .touchUpInside)
            self.contentView.addSubview(checkButton)
            self.checkButton = checkButton
        }
        self.checkButton?.setChecked(isChecked, animated: false)

        self.imageView.image = nil
        if let info {
            self.thumbnailDisposable.set((info.thumbnail
            |> deliverOnMainQueue).startStrict(next: { [weak self] image in
                self?.imageView.image = image
            }))
        } else {
            self.thumbnailDisposable.set(nil)
        }
        if let duration = info?.videoDuration {
            self.gradientView.isHidden = false
            let seconds = Int(ceil(duration))
            self.durationLabel.text = String(format: "%d:%02d", seconds / 60, seconds % 60)
            self.iconView.image = TGComponentsImageNamed("ModernMediaItemVideoIcon")
        } else {
            self.gradientView.isHidden = true
            self.durationLabel.text = nil
            self.iconView.image = nil
        }
        self.setNeedsLayout()
    }

    func setChecked(_ checked: Bool, animated: Bool) {
        self.checkButton?.setChecked(checked, animated: animated)
    }

    @objc private func checkButtonPressed() {
        self.checkPressed?(self)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.thumbnailDisposable.set(nil)
        self.imageView.image = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = self.bounds.size
        self.imageView.frame = CGRect(origin: .zero, size: size)
        if let checkButton = self.checkButton {
            checkButton.frame = CGRect(x: size.width - checkButton.bounds.width, y: 0.0, width: checkButton.bounds.width, height: checkButton.bounds.height)
        }
        self.gradientView.frame = CGRect(x: 0.0, y: size.height - 20.0, width: size.width, height: 20.0)
        self.iconView.frame = CGRect(x: 0.0, y: size.height - 19.0, width: 19.0, height: 19.0)
        self.durationLabel.sizeToFit()
        let durationSize = CGSize(width: ceil(self.durationLabel.bounds.width), height: ceil(self.durationLabel.bounds.height))
        self.durationLabel.frame = CGRect(x: size.width - durationSize.width - 4.0, y: size.height - durationSize.height - 2.0, width: durationSize.width, height: durationSize.height)
    }
}

final class ChatMediaEditorStripView: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    private let wrapperView: UIView
    private let effectView: UIVisualEffectView
    private let maskContainerView: UIView
    private let collectionViewLayout: UICollectionViewFlowLayout
    let collectionView: UICollectionView
    private let fillColor: UIColor
    private let foregroundColor: UIColor
    let cellSize: CGSize

    private(set) var items: [String] = []
    private(set) var isInternalHidden = true
    private(set) var toolbarSide: ChatMediaEditorToolbarSide?
    var isVertical: Bool {
        return self.toolbarSide != nil
    }
    var itemInfo: ((String) -> ChatMediaEditorStripItemInfo?)?
    var isItemChecked: ((String) -> Bool)?
    var itemTapped: ((String) -> Void)?
    var itemCheckPressed: ((String, ChatMediaEditorStripCell) -> Void)?

    init(fillColor: UIColor, foregroundColor: UIColor) {
        self.fillColor = fillColor
        self.foregroundColor = foregroundColor
        self.cellSize = TGPhotoThumbnailSizeForCurrentScreen()

        self.wrapperView = UIView()
        self.effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        self.effectView.clipsToBounds = true
        self.effectView.layer.cornerRadius = 8.0
        self.maskContainerView = UIView()
        self.maskContainerView.clipsToBounds = true

        self.collectionViewLayout = UICollectionViewFlowLayout()
        self.collectionViewLayout.scrollDirection = .horizontal
        self.collectionViewLayout.itemSize = self.cellSize
        self.collectionViewLayout.minimumInteritemSpacing = 4.0
        self.collectionViewLayout.minimumLineSpacing = 4.0
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.collectionViewLayout)
        self.collectionView.contentInsetAdjustmentBehavior = .never
        self.collectionView.alwaysBounceHorizontal = false
        self.collectionView.alwaysBounceVertical = false
        self.collectionView.backgroundColor = .clear
        self.collectionView.contentInset = UIEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0)
        self.collectionView.showsHorizontalScrollIndicator = false
        self.collectionView.showsVerticalScrollIndicator = false
        self.collectionView.register(ChatMediaEditorStripCell.self, forCellWithReuseIdentifier: "cell")

        super.init(frame: .zero)

        self.isHidden = true
        self.addSubview(self.wrapperView)
        self.wrapperView.addSubview(self.effectView)
        self.wrapperView.addSubview(self.maskContainerView)
        self.maskContainerView.addSubview(self.collectionView)
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if let result, result.isDescendant(of: self.collectionView) {
            return result
        }
        return nil
    }

    func reload(items: [String]) {
        self.items = items
        self.collectionView.reloadData()
        self.layoutBackground()
    }

    func apply(update: ChatMediaEditorStripUpdate, items: [String], animated: Bool) {
        let previousCount = self.items.count
        self.items = items
        let isValid = previousCount - update.removed.count + update.inserted.count == items.count
        if !animated || !isValid || self.isHidden || self.bounds.width <= 0.0 {
            self.collectionView.reloadData()
            self.collectionView.layoutIfNeeded()
            self.layoutBackground()
            if !update.inserted.isEmpty {
                self.scrollToEnd(animated: false)
            }
            return
        }
        UIView.performWithoutAnimation {
            self.collectionView.performBatchUpdates({
                if !update.removed.isEmpty {
                    self.collectionView.deleteItems(at: update.removed.map { IndexPath(item: $0, section: 0) })
                }
                if !update.inserted.isEmpty {
                    self.collectionView.insertItems(at: update.inserted.map { IndexPath(item: $0, section: 0) })
                }
            })
        }
        UIView.animate(withDuration: 0.3, animations: {
            self.layoutBackground()
        })
        if !update.inserted.isEmpty {
            self.scrollToEnd(animated: true)
        }
    }

    func updateToolbarSide(_ toolbarSide: ChatMediaEditorToolbarSide?) {
        guard self.toolbarSide != toolbarSide else {
            return
        }
        let wasVertical = self.isVertical
        self.toolbarSide = toolbarSide
        if wasVertical != self.isVertical {
            if self.isVertical {
                self.collectionViewLayout.scrollDirection = .vertical
                self.collectionView.contentInset = UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0)
                self.collectionView.contentOffset = CGPoint(x: 0.0, y: -4.0)
            } else {
                self.collectionViewLayout.scrollDirection = .horizontal
                self.collectionView.contentInset = UIEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0)
                self.collectionView.contentOffset = CGPoint(x: -4.0, y: 0.0)
            }
            self.collectionViewLayout.invalidateLayout()
        }
        self.setNeedsLayout()
    }

    private func scrollToEnd(animated: Bool) {
        self.collectionView.layoutIfNeeded()
        if self.isVertical {
            let offsetY = max(-self.collectionView.contentInset.top, self.collectionView.contentSize.height - self.collectionView.bounds.height + self.collectionView.contentInset.bottom)
            self.collectionView.setContentOffset(CGPoint(x: 0.0, y: offsetY), animated: animated)
        } else {
            let offsetX = max(-self.collectionView.contentInset.left, self.collectionView.contentSize.width - self.collectionView.bounds.width + self.collectionView.contentInset.right)
            self.collectionView.setContentOffset(CGPoint(x: offsetX, y: 0.0), animated: animated)
        }
    }

    func updateCheckedStates(animated: Bool) {
        for cell in self.collectionView.visibleCells {
            if let cell = cell as? ChatMediaEditorStripCell, let uniqueId = cell.uniqueId {
                cell.setChecked(self.isItemChecked?(uniqueId) ?? false, animated: animated)
            }
        }
    }

    private func hiddenCenter() -> CGPoint {
        return chatMediaEditorStripHiddenCenter(size: self.bounds.size, toolbarSide: self.toolbarSide)
    }

    func setInternalHidden(_ hidden: Bool, animated: Bool) {
        guard self.isInternalHidden != hidden else {
            return
        }
        self.isInternalHidden = hidden
        let size = self.bounds.size
        let visibleCenter = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        if animated {
            if !hidden {
                self.isHidden = false
            }
            let transition = chatMediaEditorSelectionPopTransition
            transition.updateAlpha(layer: self.wrapperView.layer, alpha: hidden ? 0.0 : 1.0, beginWithCurrentState: true, completion: { [weak self] finished in
                guard let self, finished, self.isInternalHidden else {
                    return
                }
                self.isHidden = true
            })
            transition.updatePosition(layer: self.wrapperView.layer, position: hidden ? self.hiddenCenter() : visibleCenter, beginFromCurrentState: true)
        } else {
            self.isHidden = hidden
            self.wrapperView.alpha = hidden ? 0.0 : 1.0
            self.wrapperView.center = hidden ? self.hiddenCenter() : visibleCenter
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = self.bounds.size
        self.wrapperView.bounds = CGRect(origin: .zero, size: size)
        if self.wrapperView.layer.animation(forKey: "position") == nil {
            self.wrapperView.center = self.isInternalHidden ? self.hiddenCenter() : CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        }
        UIView.performWithoutAnimation {
            self.layoutBackground()
        }
    }

    private func layoutBackground() {
        let size = self.bounds.size
        self.effectView.frame = chatMediaEditorStripBackgroundFrame(size: size, count: self.items.count, cellSize: self.cellSize, isVertical: self.isVertical)
        let maskFrame = chatMediaEditorStripMaskFrame(size: size, count: self.items.count, cellSize: self.cellSize, isVertical: self.isVertical)
        if self.maskContainerView.frame != maskFrame {
            self.maskContainerView.frame = maskFrame
            self.collectionView.frame = CGRect(origin: .zero, size: maskFrame.size)
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! ChatMediaEditorStripCell
        if indexPath.item < self.items.count {
            let uniqueId = self.items[indexPath.item]
            cell.setup(uniqueId: uniqueId, info: self.itemInfo?(uniqueId), isChecked: self.isItemChecked?(uniqueId) ?? false, fillColor: self.fillColor, foregroundColor: self.foregroundColor)
            cell.checkPressed = { [weak self] cell in
                guard let self, let uniqueId = cell.uniqueId else {
                    return
                }
                self.itemCheckPressed?(uniqueId, cell)
            }
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < self.items.count else {
            return
        }
        self.itemTapped?(self.items[indexPath.item])
        guard let cell = collectionView.cellForItem(at: indexPath), let superview = collectionView.superview else {
            return
        }
        let frame = collectionView.convert(cell.frame, to: superview)
        if self.isVertical {
            if frame.minY < 0.0 {
                collectionView.setContentOffset(CGPoint(x: collectionView.contentOffset.x, y: collectionView.contentOffset.y + frame.minY), animated: true)
            } else if frame.maxY > superview.bounds.height {
                collectionView.setContentOffset(CGPoint(x: collectionView.contentOffset.x, y: collectionView.contentOffset.y + frame.maxY - superview.bounds.height), animated: true)
            }
        } else if frame.minX < 0.0 {
            collectionView.setContentOffset(CGPoint(x: collectionView.contentOffset.x + frame.minX, y: collectionView.contentOffset.y), animated: true)
        } else if frame.maxX > superview.bounds.width {
            collectionView.setContentOffset(CGPoint(x: collectionView.contentOffset.x + frame.maxX - superview.bounds.width, y: collectionView.contentOffset.y), animated: true)
        }
    }
}
