import Foundation
import UIKit
import Display
import TelegramPresentationData
import CheckNode
import MediaGrid

struct MediaPickerGridCellState {
    var identifier: String
    var decorations: MediaPickerGridCellDecorations
    var isHidden: Bool
}

protocol MediaPickerGridCellStateProvider: AnyObject {
    var cellTheme: PresentationTheme { get }
    func cellState(at index: Int, isCompact: Bool) -> MediaPickerGridCellState?
}

private let gridCellLeftShadowImage: UIImage? = {
    guard let baseImage = UIImage(bundleImageName: "Peer Info/MediaGridShadow") else {
        return nil
    }
    return generateImage(baseImage.size, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: -1.0, y: -1.0)
        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
        UIGraphicsPushContext(context)
        baseImage.draw(in: CGRect(origin: CGPoint(), size: size))
        UIGraphicsPopContext()
    })
}()

private let gridCellRightShadowImage: UIImage? = {
    guard let baseImage = UIImage(bundleImageName: "Peer Info/MediaGridShadow") else {
        return nil
    }
    return generateImage(baseImage.size, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        UIGraphicsPushContext(context)
        baseImage.draw(in: CGRect(origin: CGPoint(), size: size))
        UIGraphicsPopContext()
    })
}()

private let gridCellFavoriteImage: UIImage? = generateTintedImage(image: UIImage(bundleImageName: "Media Grid/Favorite"), color: .white)

private func gridCellTypeIconImage(_ icon: MediaPickerGridCellTypeIcon) -> UIImage? {
    switch icon {
    case .video:
        return UIImage(bundleImageName: "Media Editor/MediaVideo")
    case .slomo:
        return UIImage(bundleImageName: "Media Editor/MediaSlomo")
    case .timelapse:
        return UIImage(bundleImageName: "Media Editor/MediaTimelapse")
    case .favorite:
        return gridCellFavoriteImage
    case .livePhoto:
        return UIImage(bundleImageName: "Chat/Message/LivePhoto")
    case .livePhotoOff:
        return UIImage(bundleImageName: "Chat/Message/LivePhotoOff")
    }
}

private final class GridCellDurationImageCache {
    static let shared = GridCellDurationImageCache()

    private var images: [String: UIImage] = [:]

    func image(for text: String) -> UIImage? {
        if let image = self.images[text] {
            return image
        }
        let string = NSAttributedString(string: text, font: Font.semibold(11.0), textColor: .white)
        let textSize = string.boundingRect(with: CGSize(width: 200.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil).size
        let padding: CGFloat = 4.0
        let size = CGSize(width: ceil(textSize.width) + padding * 2.0, height: ceil(textSize.height) + padding * 2.0)
        let image = generateImage(size, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setShadow(offset: CGSize(), blur: 4.0, color: UIColor(white: 0.0, alpha: 0.4).cgColor)
            UIGraphicsPushContext(context)
            string.draw(at: CGPoint(x: padding, y: padding))
            UIGraphicsPopContext()
        })
        if self.images.count > 512 {
            self.images.removeAll()
        }
        if let image {
            self.images[text] = image
        }
        return image
    }
}

private func gridCellImage(of contents: Any?) -> CGImage? {
    guard let contents else {
        return nil
    }
    let object = contents as CFTypeRef
    guard CFGetTypeID(object) == CGImage.typeID else {
        return nil
    }
    return (object as! CGImage)
}

private func gridCellVisibleImage(contents: Any?, contentsRect: CGRect) -> UIImage? {
    guard let image = gridCellImage(of: contents) else {
        return nil
    }
    if contentsRect == CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0) {
        return UIImage(cgImage: image)
    }
    let cropRect = CGRect(x: contentsRect.minX * CGFloat(image.width), y: contentsRect.minY * CGFloat(image.height), width: contentsRect.width * CGFloat(image.width), height: contentsRect.height * CGFloat(image.height)).integral
    return image.cropping(to: cropRect).flatMap { UIImage(cgImage: $0) }
}

final class MediaPickerGridCellLayer: MediaGridCellLayer {
    static let checkSize = CGSize(width: 29.0, height: 29.0)
    static let durationPadding: CGFloat = 4.0

    weak var provider: MediaPickerGridCellStateProvider?

    private(set) var identifier: String?
    private(set) var decorations: MediaPickerGridCellDecorations = .none
    private var spoilerLayer: CALayer?
    private var leftShadowLayer: CALayer?
    private var rightShadowLayer: CALayer?
    private var typeIconLayer: CALayer?
    private var durationLayer: CALayer?
    private var checkLayer: CheckLayer?
    private var checkTheme: CheckNodeTheme?

    override init() {
        super.init()
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func checkFrame(in bounds: CGRect) -> CGRect {
        return CGRect(origin: CGPoint(x: bounds.width - MediaPickerGridCellLayer.checkSize.width - 3.0, y: 3.0), size: MediaPickerGridCellLayer.checkSize)
    }

    override func bind(index: Int, detail: MediaGridCellDetail) {
        super.bind(index: index, detail: detail)
        let state = self.provider?.cellState(at: index, isCompact: detail == .compact)
        self.apply(state, animated: false)
    }

    override func setSelected(_ selected: Bool) {
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.identifier = nil
        self.isHidden = false
        self.opacity = 1.0
        self.applyDecorations(.none, animated: false)
    }

    func refresh(isCompact: Bool, animated: Bool) {
        guard self.index >= 0 else {
            return
        }
        let state = self.provider?.cellState(at: self.index, isCompact: isCompact)
        self.apply(state, animated: animated)
    }

    func apply(_ state: MediaPickerGridCellState?, animated: Bool) {
        guard let state else {
            self.identifier = nil
            self.isHidden = false
            self.applyDecorations(.none, animated: false)
            return
        }
        let isSameItem = self.identifier == state.identifier
        self.identifier = state.identifier
        self.isHidden = state.isHidden
        self.applyDecorations(state.decorations, animated: animated && isSameItem)
    }

    private func makeImageLayer(_ image: UIImage?) -> CALayer {
        let layer = CALayer()
        layer.actions = ["contents": NSNull(), "position": NSNull(), "bounds": NSNull(), "opacity": NSNull(), "hidden": NSNull()]
        layer.contents = image?.cgImage
        layer.contentsGravity = .center
        layer.contentsScale = image?.scale ?? UIScreenScale
        return layer
    }

    private func applyDecorations(_ decorations: MediaPickerGridCellDecorations, animated: Bool) {
        let previous = self.decorations
        self.decorations = decorations

        if decorations.showsSpoilerBlur {
            if self.spoilerLayer == nil {
                let spoilerLayer = self.makeImageLayer(nil)
                spoilerLayer.contentsGravity = .resizeAspectFill
                spoilerLayer.masksToBounds = true
                self.insertSublayer(spoilerLayer, at: 0)
                self.spoilerLayer = spoilerLayer
            }
            if !previous.showsSpoilerBlur || self.spoilerLayer?.contents == nil {
                self.updateSpoilerContents()
            }
        } else if let spoilerLayer = self.spoilerLayer {
            self.spoilerLayer = nil
            spoilerLayer.removeFromSuperlayer()
        }

        if decorations.showsLeftShadow {
            if self.leftShadowLayer == nil {
                let layer = self.makeImageLayer(gridCellLeftShadowImage)
                layer.contentsGravity = .resize
                self.addSublayer(layer)
                self.leftShadowLayer = layer
            }
        } else if let layer = self.leftShadowLayer {
            self.leftShadowLayer = nil
            layer.removeFromSuperlayer()
        }

        if decorations.showsRightShadow {
            if self.rightShadowLayer == nil {
                let layer = self.makeImageLayer(gridCellRightShadowImage)
                layer.contentsGravity = .resize
                self.addSublayer(layer)
                self.rightShadowLayer = layer
            }
        } else if let layer = self.rightShadowLayer {
            self.rightShadowLayer = nil
            layer.removeFromSuperlayer()
        }

        if let typeIcon = decorations.typeIcon {
            let image = gridCellTypeIconImage(typeIcon)
            if let layer = self.typeIconLayer {
                if previous.typeIcon != typeIcon {
                    layer.contents = image?.cgImage
                    layer.contentsScale = image?.scale ?? UIScreenScale
                }
            } else {
                let layer = self.makeImageLayer(image)
                self.addSublayer(layer)
                self.typeIconLayer = layer
            }
        } else if let layer = self.typeIconLayer {
            self.typeIconLayer = nil
            layer.removeFromSuperlayer()
        }

        if let durationText = decorations.durationText {
            let image = GridCellDurationImageCache.shared.image(for: durationText)
            if let layer = self.durationLayer {
                if previous.durationText != durationText {
                    layer.contents = image?.cgImage
                    layer.contentsScale = image?.scale ?? UIScreenScale
                    layer.bounds = CGRect(origin: CGPoint(), size: image?.size ?? CGSize())
                }
            } else {
                let layer = self.makeImageLayer(image)
                layer.bounds = CGRect(origin: CGPoint(), size: image?.size ?? CGSize())
                self.addSublayer(layer)
                self.durationLayer = layer
            }
        } else if let layer = self.durationLayer {
            self.durationLayer = nil
            layer.removeFromSuperlayer()
        }

        if let check = decorations.check, let theme = self.provider?.cellTheme {
            let checkTheme = CheckNodeTheme(theme: theme, style: .overlay)
            let checkLayer: CheckLayer
            var isNew = false
            if let current = self.checkLayer {
                checkLayer = current
                if self.checkTheme != checkTheme {
                    checkLayer.theme = checkTheme
                }
            } else {
                checkLayer = CheckLayer(theme: checkTheme)
                checkLayer.actions = ["position": NSNull(), "bounds": NSNull(), "opacity": NSNull(), "contents": NSNull(), "hidden": NSNull()]
                checkLayer.frame = MediaPickerGridCellLayer.checkFrame(in: self.bounds)
                self.addSublayer(checkLayer)
                self.checkLayer = checkLayer
                isNew = true
            }
            self.checkTheme = checkTheme
            if let number = check.number {
                checkLayer.content = .counter(number)
            }
            checkLayer.setSelected(check.isSelected, animated: animated && !isNew)
            if isNew {
                checkLayer.setNeedsDisplay()
            }
        } else if let layer = self.checkLayer {
            self.checkLayer = nil
            self.checkTheme = nil
            layer.removeFromSuperlayer()
        }

        if let checkLayer = self.checkLayer, checkLayer.superlayer === self, self.sublayers?.last !== checkLayer {
            checkLayer.removeFromSuperlayer()
            self.addSublayer(checkLayer)
        }

        self.setNeedsLayout()
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        let bounds = self.bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.spoilerLayer?.frame = bounds
        if let layer = self.leftShadowLayer, let image = gridCellLeftShadowImage {
            layer.frame = CGRect(x: 0.0, y: 0.0, width: min(image.size.width, bounds.width), height: image.size.height)
        }
        if let layer = self.rightShadowLayer, let image = gridCellRightShadowImage {
            let width = min(image.size.width, bounds.width)
            layer.frame = CGRect(x: bounds.width - width, y: bounds.height - image.size.height, width: width, height: image.size.height)
        }
        self.typeIconLayer?.frame = CGRect(x: 0.0, y: 1.0, width: 19.0, height: 19.0)
        if let layer = self.durationLayer {
            let size = layer.bounds.size
            let padding = MediaPickerGridCellLayer.durationPadding
            layer.frame = CGRect(origin: CGPoint(x: bounds.width - size.width + padding - 6.0, y: bounds.height - size.height + padding - 6.0), size: size)
        }
        if let checkLayer = self.checkLayer {
            let frame = MediaPickerGridCellLayer.checkFrame(in: bounds)
            if checkLayer.frame != frame {
                checkLayer.frame = frame
                checkLayer.setNeedsDisplay()
            }
        }
        CATransaction.commit()
    }

    override func setImage(_ image: UIImage?) {
        super.setImage(image)
        if self.spoilerLayer != nil {
            self.updateSpoilerContents()
        }
    }

    override func setThumbnail(_ thumbnail: MediaGridThumbnail, cellAspect: CGFloat) {
        super.setThumbnail(thumbnail, cellAspect: cellAspect)
        if self.spoilerLayer != nil {
            self.updateSpoilerContents()
        }
    }

    private func updateSpoilerContents() {
        guard let spoilerLayer = self.spoilerLayer else {
            return
        }
        let source = self.transitionImage
        let blurred = source.flatMap { blurredImage($0) }
        spoilerLayer.contents = blurred?.cgImage
    }

    func animateFadeIn(animateCheck: Bool) {
        if animateCheck {
            self.checkLayer?.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
        self.leftShadowLayer?.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.rightShadowLayer?.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.typeIconLayer?.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.durationLayer?.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
    }

    func makeSnapshotView(frame: CGRect) -> UIView {
        let view = UIView(frame: frame)
        view.clipsToBounds = true
        view.layer.contents = self.contents
        view.layer.contentsRect = self.contentsRect
        view.layer.contentsGravity = self.contentsGravity
        view.layer.contentsScale = self.contentsScale
        if let spoilerLayer = self.spoilerLayer, let contents = spoilerLayer.contents {
            let blurView = UIView(frame: view.bounds)
            blurView.layer.contents = contents
            blurView.layer.contentsGravity = .resizeAspectFill
            blurView.clipsToBounds = true
            blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(blurView)
        }
        return view
    }

    var transitionImage: UIImage? {
        if let image = self.displayedImage {
            return image
        }
        return gridCellVisibleImage(contents: self.contents, contentsRect: self.contentsRect)
    }
}
