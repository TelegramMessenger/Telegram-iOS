import UIKit

/// `PhysicsScrollEngine`'s content host: its layer repeats on the layers registered as mirrors every model write of its
/// `bounds.origin.y` and every `bounds.origin.y` animation added to or removed from it, which is all of the content's
/// motion: a drag's writes, a `.keyframe` flight and its brake on the render server, a pass's viewport track. A view
/// outside the list then rides the content exactly (`CoreVirtualListView.addContentMotionMirror`), where a follower
/// placed from per-frame callbacks trails a render-server flight by the commit's frame or two.
final class ContentMotionHostView: UIView {
    override class var layerClass: AnyClass {
        return ContentMotionMirroringLayer.self
    }

    var mirroringLayer: ContentMotionMirroringLayer? {
        return self.layer as? ContentMotionMirroringLayer
    }
}

final class ContentMotionMirroringLayer: CALayer {
    private static let mirroredKeyPath = "bounds.origin.y"

    private let mirrors = NSHashTable<CALayer>.weakObjects()
    /// The keys of the mirrored animations this layer holds, for a removal that names none (`removeAllAnimations`).
    private var mirroredKeys = Set<String>()

    /// Starts `mirror` where the content is, with the animations it has now; a flight's explicit `beginTime` keeps the
    /// copy in phase.
    func addMirror(_ mirror: CALayer) {
        self.mirrors.add(mirror)
        Self.write(self.bounds.origin.y, to: mirror)
        for key in self.animationKeys() ?? [] {
            if let animation = self.animation(forKey: key), Self.isMirrored(animation) {
                mirror.add(Self.mirrorCopy(of: animation), forKey: key)
            }
        }
    }

    func removeMirror(_ mirror: CALayer) {
        self.mirrors.remove(mirror)
        for key in self.mirroredKeys {
            mirror.removeAnimation(forKey: key)
        }
    }

    override var bounds: CGRect {
        didSet {
            guard self.bounds.origin.y != oldValue.origin.y else {
                return
            }
            for mirror in self.mirrors.allObjects {
                Self.write(self.bounds.origin.y, to: mirror)
            }
        }
    }

    override func add(_ animation: CAAnimation, forKey key: String?) {
        super.add(animation, forKey: key)
        guard let key, Self.isMirrored(animation) else {
            return
        }
        self.mirroredKeys.insert(key)
        let copy = Self.mirrorCopy(of: animation)
        for mirror in self.mirrors.allObjects {
            mirror.add(copy, forKey: key)
        }
    }

    override func removeAnimation(forKey key: String) {
        super.removeAnimation(forKey: key)
        guard self.mirroredKeys.remove(key) != nil else {
            return
        }
        for mirror in self.mirrors.allObjects {
            mirror.removeAnimation(forKey: key)
        }
    }

    override func removeAllAnimations() {
        super.removeAllAnimations()
        for key in self.mirroredKeys {
            for mirror in self.mirrors.allObjects {
                mirror.removeAnimation(forKey: key)
            }
        }
        self.mirroredKeys.removeAll()
    }

    /// The animation without its completion: CoreList's completions are one-shot delegates, and a copy stopping before
    /// the host's (a mirror removed mid-flight) would spend the host's, finalizing the flight early.
    private static func mirrorCopy(of animation: CAAnimation) -> CAAnimation {
        guard let copy = animation.copy() as? CAAnimation else {
            return animation
        }
        copy.delegate = nil
        return copy
    }

    private static func isMirrored(_ animation: CAAnimation) -> Bool {
        return (animation as? CAPropertyAnimation)?.keyPath == Self.mirroredKeyPath
    }

    /// The origin alone: the mirror keeps its own size. A view-backed mirror takes no implicit animation for it.
    private static func write(_ originY: CGFloat, to mirror: CALayer) {
        var bounds = mirror.bounds
        bounds.origin.y = originY
        mirror.bounds = bounds
    }
}
