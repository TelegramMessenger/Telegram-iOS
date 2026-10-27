import Foundation
import UIKit
import Display
import CheckNode
import GridMessageSelectionNode
import InvisibleInkDustNode
import MediaGrid

struct MediaGridPaneCellState {
    var duration: Int32?
    var isLivePhoto: Bool
    var hasSpoiler: Bool
    var spoilerImage: UIImage?
    var isSelected: Bool?
    var isHidden: Bool
}

struct MediaGridPaneShimmerColors: Equatable {
    var background: UIColor
    var foreground: UIColor
}

protocol MediaGridPaneCellProvider: AnyObject {
    var checkTheme: CheckNodeTheme { get }
    var shimmerColors: MediaGridPaneShimmerColors { get }
    var shimmerViewport: (offset: CGFloat, height: CGFloat) { get }
    func cellState(at index: Int) -> MediaGridPaneCellState?
}

private final class MediaGridPaneShimmerImage {
    static let shared = MediaGridPaneShimmerImage()

    private var colors: MediaGridPaneShimmerColors?
    private var image: CGImage?

    func image(colors: MediaGridPaneShimmerColors) -> CGImage? {
        if self.colors == colors, let image = self.image {
            return image
        }
        self.colors = colors
        self.image = generateImage(CGSize(width: 1.0, height: 320.0), opaque: false, scale: 1.0, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(colors.background.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
            let transparentColor = colors.foreground.withAlphaComponent(0.0).cgColor
            let peakColor = colors.foreground.cgColor
            var locations: [CGFloat] = [0.0, 0.5, 1.0]
            let gradientColors: [CGColor] = [transparentColor, peakColor, transparentColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors as CFArray, locations: &locations)!
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        })?.cgImage
        return self.image
    }
}

final class MediaGridPaneCellLayer: MediaGridCellLayer {
    weak var provider: MediaGridPaneCellProvider?

    private static let minDurationWidth: CGFloat = 80.0

    private var detail: MediaGridCellDetail = .full
    private var shimmerLayer: SimpleLayer?
    private var durationLayer: VisualMediaDurationLayer?
    private var livePhotoLayer: SimpleLayer?
    private var rightShadowLayer: SimpleLayer?
    private var selectionLayer: GridMessageSelectionLayer?
    private var dustLayer: MediaDustLayer?
    private var currentDuration: (Int32, Bool)?

    override init() {
        super.init()
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var hasVisibleImage: Bool {
        return self.isShowingThumbnail || self.displayedImage != nil
    }

    override func bind(index: Int, detail: MediaGridCellDetail) {
        super.bind(index: index, detail: detail)
        self.detail = detail
        self.refresh(animated: false)
    }

    override func setSelected(_ selected: Bool) {
    }

    override func setImage(_ image: UIImage?) {
        super.setImage(image)
        self.updateShimmer()
    }

    override func setThumbnail(_ thumbnail: MediaGridThumbnail, cellAspect: CGFloat) {
        super.setThumbnail(thumbnail, cellAspect: cellAspect)
        self.updateShimmer()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.isHidden = false
        self.removeAllAnimations()
    }

    func refresh(animated: Bool) {
        let state = self.index >= 0 ? self.provider?.cellState(at: self.index) : nil
        let isFull = self.detail == .full
        self.isHidden = state?.isHidden ?? false
        self.updateDuration(isFull ? state?.duration : nil, isLivePhoto: isFull && (state?.isLivePhoto ?? false))
        self.updateSpoiler(state?.hasSpoiler ?? false, image: state?.spoilerImage)
        self.updateSelection(isFull ? state?.isSelected : nil, animated: animated)
        self.updateShimmer()
        self.setNeedsLayout()
    }

    func updateShimmer() {
        if self.hasVisibleImage {
            if let shimmerLayer = self.shimmerLayer {
                self.shimmerLayer = nil
                shimmerLayer.removeFromSuperlayer()
            }
            return
        }
        guard let provider = self.provider else {
            return
        }
        let shimmerLayer: SimpleLayer
        if let current = self.shimmerLayer {
            shimmerLayer = current
        } else {
            shimmerLayer = SimpleLayer()
            self.insertSublayer(shimmerLayer, at: 0)
            self.shimmerLayer = shimmerLayer
        }
        shimmerLayer.frame = self.bounds
        shimmerLayer.contents = MediaGridPaneShimmerImage.shared.image(colors: provider.shimmerColors)
        let viewport = provider.shimmerViewport
        if viewport.height > 0.0 {
            shimmerLayer.contentsRect = CGRect(x: 0.0, y: (self.frame.minY - viewport.offset) / viewport.height, width: 1.0, height: self.bounds.height / viewport.height)
        }
        if shimmerLayer.animation(forKey: "shimmer") == nil {
            let animation = CABasicAnimation(keyPath: "contentsRect.origin.y")
            animation.fromValue = 1.0 as NSNumber
            animation.toValue = -1.0 as NSNumber
            animation.isAdditive = true
            animation.repeatCount = .infinity
            animation.duration = 0.8
            animation.beginTime = shimmerLayer.convertTime(1.0, from: nil)
            shimmerLayer.add(animation, forKey: "shimmer")
        }
    }

    private func updateDuration(_ duration: Int32?, isLivePhoto: Bool) {
        let size = self.bounds.size
        let minFactor = min(1.0, size.height / 74.0)
        if isLivePhoto {
            if self.livePhotoLayer == nil {
                let livePhotoLayer = SimpleLayer()
                livePhotoLayer.contentsGravity = .topLeft
                livePhotoLayer.contentsScale = UIScreenScale
                livePhotoLayer.contents = visualMediaLivePhotoImage.cgImage
                self.addSublayer(livePhotoLayer)
                self.livePhotoLayer = livePhotoLayer
            }
        } else if let livePhotoLayer = self.livePhotoLayer {
            self.livePhotoLayer = nil
            livePhotoLayer.removeFromSuperlayer()
        }
        self.livePhotoLayer?.transform = CATransform3DMakeScale(minFactor, minFactor, 1.0)

        if let duration {
            let isMin = size.width < MediaGridPaneCellLayer.minDurationWidth
            let durationLayer: VisualMediaDurationLayer
            if let current = self.durationLayer {
                durationLayer = current
            } else {
                durationLayer = VisualMediaDurationLayer()
                self.addSublayer(durationLayer)
                self.durationLayer = durationLayer
            }
            if self.currentDuration?.0 != duration || self.currentDuration?.1 != isMin {
                self.currentDuration = (duration, isMin)
                durationLayer.update(duration: duration, isMin: isMin)
            }
            durationLayer.transform = CATransform3DMakeScale(minFactor, minFactor, 1.0)
            if self.rightShadowLayer == nil {
                let rightShadowLayer = SimpleLayer()
                rightShadowLayer.contents = visualMediaRightShadowImage.cgImage
                self.insertSublayer(rightShadowLayer, below: durationLayer)
                self.rightShadowLayer = rightShadowLayer
            }
        } else {
            self.currentDuration = nil
            if let durationLayer = self.durationLayer {
                self.durationLayer = nil
                durationLayer.removeFromSuperlayer()
            }
            if let rightShadowLayer = self.rightShadowLayer {
                self.rightShadowLayer = nil
                rightShadowLayer.removeFromSuperlayer()
            }
        }
    }

    private func updateSpoiler(_ hasSpoiler: Bool, image: UIImage?) {
        if hasSpoiler {
            let dustLayer: MediaDustLayer
            if let current = self.dustLayer {
                dustLayer = current
            } else {
                dustLayer = MediaDustLayer()
                self.addSublayer(dustLayer)
                self.dustLayer = dustLayer
            }
            dustLayer.contents = image?.cgImage
        } else if let dustLayer = self.dustLayer {
            self.dustLayer = nil
            dustLayer.removeFromSuperlayer()
        }
    }

    private func updateSelection(_ isSelected: Bool?, animated: Bool) {
        if let isSelected, let provider = self.provider {
            if let selectionLayer = self.selectionLayer {
                selectionLayer.updateSelected(isSelected, animated: animated)
            } else {
                let selectionLayer = GridMessageSelectionLayer(theme: provider.checkTheme)
                selectionLayer.updateSelected(isSelected, animated: false)
                self.selectionLayer = selectionLayer
                self.addSublayer(selectionLayer)
                if !self.bounds.isEmpty {
                    selectionLayer.frame = self.bounds
                    selectionLayer.updateLayout(size: self.bounds.size)
                    if animated {
                        selectionLayer.animateIn()
                    }
                }
            }
        } else if let selectionLayer = self.selectionLayer {
            self.selectionLayer = nil
            if animated {
                selectionLayer.animateOut { [weak selectionLayer] in
                    selectionLayer?.removeFromSuperlayer()
                }
            } else {
                selectionLayer.removeFromSuperlayer()
            }
        }
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        let size = self.bounds.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.shimmerLayer?.frame = self.bounds
        if let livePhotoLayer = self.livePhotoLayer {
            let minFactor = min(1.0, size.height / 74.0)
            livePhotoLayer.transform = CATransform3DIdentity
            livePhotoLayer.frame = CGRect(origin: CGPoint(x: 3.0, y: 3.0), size: visualMediaLivePhotoImage.size)
            livePhotoLayer.transform = CATransform3DMakeScale(minFactor, minFactor, 1.0)
        }
        if let durationLayer = self.durationLayer, let (duration, isMin) = self.currentDuration {
            let updatedIsMin = size.width < MediaGridPaneCellLayer.minDurationWidth
            if updatedIsMin != isMin {
                self.currentDuration = (duration, updatedIsMin)
                durationLayer.update(duration: duration, isMin: updatedIsMin)
            }
            let minFactor = min(1.0, size.height / 74.0)
            durationLayer.transform = CATransform3DIdentity
            durationLayer.frame = CGRect(origin: CGPoint(x: size.width - 3.0, y: size.height - 3.0), size: CGSize())
            durationLayer.transform = CATransform3DMakeScale(minFactor, minFactor, 1.0)
        }
        if let rightShadowLayer = self.rightShadowLayer {
            let shadowSize = CGSize(width: min(size.width, visualMediaRightShadowImage.size.width), height: min(size.height, visualMediaRightShadowImage.size.height))
            rightShadowLayer.frame = CGRect(origin: CGPoint(x: size.width - shadowSize.width, y: size.height - shadowSize.height), size: shadowSize)
        }
        if let dustLayer = self.dustLayer {
            dustLayer.frame = self.bounds
            dustLayer.updateLayout(size: size)
        }
        if let selectionLayer = self.selectionLayer {
            selectionLayer.frame = self.bounds
            selectionLayer.updateLayout(size: size)
        }
        CATransaction.commit()
    }
}
