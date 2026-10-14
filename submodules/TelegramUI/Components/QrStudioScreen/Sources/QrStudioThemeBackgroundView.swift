import Foundation
import UIKit
import Display
import AccountContext
import WallpaperBackgroundNode

final class QrStudioThemeBackgroundView: UIView, QrStudioBackgroundContent {
    private let wallpaperNode: WallpaperBackgroundNode
    private var size = CGSize()

    let theme: QrStudioTheme
    let wantsFullFrameRate: Bool = false

    init(context: AccountContext, theme: QrStudioTheme) {
        self.theme = theme
        self.wallpaperNode = createWallpaperBackgroundNode(context: context, forChatDisplay: false)

        super.init(frame: CGRect())

        self.clipsToBounds = true
        self.backgroundColor = self.theme.colors.first?.uiColor ?? .white
        self.addSubview(self.wallpaperNode.view)
        self.wallpaperNode.update(wallpaper: theme.wallpaper, animated: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(size: CGSize, revealCenter: CGPoint) {
        guard self.size != size, size.width > 0.0, size.height > 0.0 else {
            return
        }
        self.size = size
        self.wallpaperNode.frame = CGRect(origin: CGPoint(), size: size)
        self.wallpaperNode.updateLayout(size: size, displayMode: .aspectFill, transition: .immediate)
    }

    func tick(time: Double, pan: QrStudioPan, drift: QrStudioDrift, tilt: SIMD2<Double>) {
    }

    func beginReveal(at time: Double) {
    }

    func setVisible(_ isVisible: Bool) {
    }

    func makeCodeFill() -> (owner: AnyObject, view: UIView)? {
        guard let node = self.wallpaperNode.makeDimmedNode() else {
            return nil
        }
        return (node, node.view)
    }

    func snapshotImage(scale: CGFloat) -> CGImage? {
        guard self.size.width > 0.0, self.size.height > 0.0 else {
            return nil
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: self.size, format: format).image { _ in
            self.drawHierarchy(in: CGRect(origin: CGPoint(), size: self.size), afterScreenUpdates: false)
        }.cgImage
    }
}
