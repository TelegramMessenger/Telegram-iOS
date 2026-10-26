import XCTest
import UIKit
import ContextMenuMorph
@preconcurrency import LensTransitionRuntime

@MainActor final class LiquidMorphTests: XCTestCase {
    func testReturnPreviewUsesCurrentUnpressedContent() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let root = window.rootViewController!.view!
        root.backgroundColor = .black
        let button = UIView(frame: CGRect(x: 30, y: 100, width: 80, height: 50))
        button.alpha = 0.4
        root.addSubview(button)
        let source = UIView(frame: button.bounds)
        button.addSubview(source)
        let foreground = UIView(frame: source.bounds)
        foreground.backgroundColor = .red
        source.addSubview(foreground)
        window.layoutIfNeeded()
        let background = UIView(frame: source.bounds)
        background.backgroundColor = .blue
        var lease: ContextMenuSourceLease? = ContextMenuSourceLease(source: source, decorations: [], makeContent: {
            ContextMenuSourceContent(source: source, foreground: foreground, background: background, container: root)
        })
        let preview = lease!.content!.view
        XCTAssertTrue(foreground.superview === preview)
        foreground.backgroundColor = .green // The button changes while its menu is open.
        let image = UIGraphicsImageRenderer(bounds: preview.bounds).image { _ in
            preview.drawHierarchy(in: preview.bounds, afterScreenUpdates: true)
        }
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        XCTAssertGreaterThan(pixel[1], 240, "Return preview must show current, full-brightness foreground")
        XCTAssertLessThan(pixel[0], 10, "Return preview must not preserve the old pressed red pixels")
        var second: ContextMenuSourceLease? = ContextMenuSourceLease(source: source, decorations: [], makeContent: {
            XCTFail("Overlapping menus must share the extracted content")
            return nil
        })
        XCTAssertTrue(second?.content?.view === preview)
        lease = nil
        XCTAssertTrue(foreground.superview === preview, "Old completion must not restore the live contents")
        second = nil
        XCTAssertTrue(foreground.superview === source)
        XCTAssertNil(preview.superview)
    }

    func testReopeningDoesNotLeavePreviousReturnVisible() {
        checkOverlappingReturn(useComposite: false)
    }

    func testReopeningCompositeSourceDoesNotLeavePreviousReturnVisible() {
        checkOverlappingReturn(useComposite: true)
    }

    private func checkOverlappingReturn(useComposite: Bool) {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let root = window.rootViewController!.view!
        root.backgroundColor = .white
        let source = UIView(frame: CGRect(x: 30, y: 100, width: 80, height: 50))
        source.backgroundColor = .red
        source.layer.cornerRadius = 16
        root.addSubview(source)
        let oldHost = UIView(frame: root.bounds)
        let newHost = UIView(frame: root.bounds)
        root.addSubview(oldHost)
        root.addSubview(newHost)
        let oldMenu = UIView(frame: CGRect(x: 30, y: 190, width: 250, height: 200))
        oldMenu.backgroundColor = .blue
        oldHost.addSubview(oldMenu)
        let newMenu = UIView(frame: oldMenu.frame)
        newMenu.backgroundColor = .blue
        newHost.addSubview(newMenu)
        newMenu.alpha = 0
        let foreground = UIView(frame: source.bounds)
        foreground.backgroundColor = .red
        if useComposite {
            source.backgroundColor = .clear
            source.addSubview(foreground)
        }
        var oldLease: ContextMenuSourceLease?
        var nextLease: ContextMenuSourceLease?
        if useComposite {
            oldLease = ContextMenuSourceLease(source: source, decorations: [], makeContent: {
                let backdrop = UIView(frame: source.bounds)
                backdrop.backgroundColor = .red
                backdrop.layer.cornerRadius = 16
                return ContextMenuSourceContent(source: source, foreground: foreground, background: backdrop, container: root)
            })
        }
        let transitionSource = oldLease?.content?.view ?? source
        let old = LiquidMorphTransition()
        let next = LiquidMorphTransition()
        var oldAssertion: AnyObject?
        var nextAssertion: AnyObject?
        let finished = expectation(description: "Both overlapping transitions finish")
        let nextFinished = expectation(description: "Replacement completes and restores its hierarchy")
        let sampled = expectation(description: "Source pixels during second opening")
        let first = UITargetedPreview(view: transitionSource)
        let menu = UITargetedPreview(view: oldMenu)
        XCTAssertTrue(old.animate(from: first, to: menu, attachment: source.center, in: oldHost, sourceIdentity: source, alongsideAnimations: {
            oldAssertion = LiquidMorphTransition.sourceVisibilityAssertion(for: transitionSource)
        }) {
            let closingTarget = first
            XCTAssertTrue(old.animate(from: menu, to: closingTarget, attachment: source.center, in: oldHost, sourceIdentity: source) {
                oldAssertion = nil
                oldHost.removeFromSuperview()
                oldLease = nil
                finished.fulfill()
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if useComposite {
                    nextLease = ContextMenuSourceLease(source: source, decorations: [], makeContent: {
                        XCTFail("Native handoff must reuse the existing foreground")
                        return nil
                    })
                }
                newMenu.alpha = 1
                XCTAssertTrue(next.animate(from: first, to: UITargetedPreview(view: newMenu), attachment: source.center, in: newHost, sourceIdentity: source, alongsideAnimations: {
                    nextAssertion = LiquidMorphTransition.sourceVisibilityAssertion(for: transitionSource)
                }) {
                    XCTAssertTrue(newMenu.superview === newHost)
                    XCTAssertTrue(source.superview === root)
                    XCTAssertFalse(next.isAnimating)
                    nextFinished.fulfill()
                })
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                    }
                    let roi = source.frame.insetBy(dx: 20, dy: 15)
                    let scale = image.scale
                    let crop = image.cgImage!.cropping(to: CGRect(x: roi.minX * scale, y: roi.minY * scale, width: roi.width * scale, height: roi.height * scale))!
                    var pixel = [UInt8](repeating: 0, count: 4)
                    let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                    context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                    print("OVERLAP source RGB \(pixel)")
                    XCTAssertGreaterThan(pixel[1], 220, "The old red return must not remain at the source during the second opening")
                    sampled.fulfill()
                }
            }
        })
        wait(for: [sampled, finished, nextFinished], timeout: 10)
        withExtendedLifetime((oldAssertion, nextAssertion, nextLease)) {}
        nextAssertion = nil
        nextLease = nil
        if useComposite { XCTAssertTrue(foreground.superview === source) }
    }

    func testOverlappingProfileMenusKeepBackgroundHidden() {
        let source = UIView()
        let mask = UIView()
        mask.alpha = 0.65
        let initiallyHidden = UIView()
        initiallyHidden.isHidden = true
        var first: ContextMenuSourceLease? = ContextMenuSourceLease(source: source, decorations: [mask, initiallyHidden])
        XCTAssertNotNil(first)
        XCTAssertTrue(mask.isHidden)
        var second: ContextMenuSourceLease? = ContextMenuSourceLease(source: source, decorations: [mask, initiallyHidden])
        XCTAssertNotNil(second)
        first = nil
        XCTAssertTrue(mask.isHidden, "Older menu must not reveal the new menu's source backdrop")
        second = nil
        XCTAssertFalse(mask.isHidden)
        XCTAssertTrue(initiallyHidden.isHidden)
        XCTAssertEqual(mask.alpha, 0.65, accuracy: 0.001)
    }

    func testSharedDecorationSurvivesReverseCompletionOrder() {
        let firstSource = UIView()
        let secondSource = UIView()
        let mask = UIView()
        var first: ContextMenuSourceLease? = ContextMenuSourceLease(source: firstSource, decorations: [mask, mask])
        var second: ContextMenuSourceLease? = ContextMenuSourceLease(source: secondSource, decorations: [mask])
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        second = nil
        XCTAssertTrue(mask.isHidden)
        first = nil
        XCTAssertFalse(mask.isHidden)
    }

    func testDisabledAnimationsCompleteAndReleaseNativeCoordinator() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let host = window.rootViewController!.view!
        let source = UIView(frame: CGRect(x: 20, y: 80, width: 40, height: 40))
        let destination = UIView(frame: CGRect(x: 20, y: 140, width: 260, height: 200))
        host.addSubview(source)
        host.addSubview(destination)
        let pivot = UITargetedPreview(view: UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10)), parameters: UIPreviewParameters(), target: UIPreviewTarget(container: host, center: source.center))
        var driver: LTTransitionDriver? = LTTransitionDriver(source: UITargetedPreview(view: source), destination: UITargetedPreview(view: destination), pivot: pivot, container: host, sourceIdentity: nil, alongside: nil)
        XCTAssertNotNil(driver)
        weak let native = driver?.value(forKey: "_native") as AnyObject?
        weak let context = driver?.value(forKey: "_context") as AnyObject?
        XCTAssertNotNil(native)
        let done = expectation(description: "Completion and native ownership without UIView animations")
        let enabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        driver?.start {
            DispatchQueue.main.async {
                driver = nil
                DispatchQueue.main.async {
                    XCTAssertNil(native, "Dynamic initializer must transfer its +1 ownership")
                    XCTAssertNil(context, "Adapter state must not form a retain cycle")
                    XCTAssertTrue(source.superview === host)
                    XCTAssertTrue(destination.superview === host)
                    done.fulfill()
                }
            }
        }
        UIView.setAnimationsEnabled(enabled)
        wait(for: [done], timeout: 10)
    }

    func testLiveSourceIncludesBackdropAndTracksMovedTransformedSource() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let root = window.rootViewController!.view!
        let source = UIView(frame: CGRect(x: 30, y: 100, width: 80, height: 50))
        root.addSubview(source)
        let foreground = UIView(frame: source.bounds)
        source.addSubview(foreground)
        let backdrop = UIView(frame: source.bounds)
        backdrop.backgroundColor = .blue
        var lease: ContextMenuSourceLease? = ContextMenuSourceLease(source: source, decorations: [], makeContent: {
            ContextMenuSourceContent(source: source, foreground: foreground, background: backdrop, container: root)
        })
        let preview = lease!.content!.view
        let image = UIGraphicsImageRenderer(bounds: preview.bounds).image { _ in preview.drawHierarchy(in: preview.bounds, afterScreenUpdates: true) }
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        XCTAssertGreaterThan(pixel[2], 240, "The return view must include its live backdrop")
        source.center = CGPoint(x: 150, y: 200)
        source.transform = CGAffineTransform(rotationAngle: 0.2).scaledBy(x: 0.8, y: 0.9)
        lease?.content?.updateGeometry()
        XCTAssertEqual(preview.center.x, 150, accuracy: 0.001)
        XCTAssertEqual(preview.center.y, 200, accuracy: 0.001)
        XCTAssertEqual(preview.transform.a, source.transform.a, accuracy: 0.001)
        XCTAssertEqual(preview.transform.b, source.transform.b, accuracy: 0.001)
        source.removeFromSuperview()
        lease = nil
        XCTAssertNil(preview.superview, "Removing a source must not leave an extracted foreground behind")
        XCTAssertTrue(foreground.superview === source)
    }

    func testSourceVisibilityAssertionsOutliveMorphAndOverlap() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let container = window.rootViewController!.view!
        container.backgroundColor = .white
        let source = UIView(frame: CGRect(x: 20, y: 100, width: 60, height: 40))
        source.backgroundColor = .red
        source.alpha = 0.8
        container.addSubview(source)
        let menu = UIView(frame: CGRect(x: 120, y: 200, width: 200, height: 180))
        menu.backgroundColor = .blue
        container.addSubview(menu)
        var first: AnyObject?
        var second: AnyObject?
        let engine = LiquidMorphTransition()
        let done = expectation(description: "Source visibility lease survives native cleanup")
        XCTAssertTrue(engine.animate(from: UITargetedPreview(view: source), to: UITargetedPreview(view: menu), attachment: source.center, in: container, alongsideAnimations: {
            first = LiquidMorphTransition.sourceVisibilityAssertion(for: source)
            XCTAssertNotNil(first)
        }) {
            XCTAssertNotNil(first)
            second = LiquidMorphTransition.sourceVisibilityAssertion(for: source)
            XCTAssertNotNil(second)
            first = nil
            // Releasing the older menu must not invalidate the newer menu's claim.
            XCTAssertEqual((second as? NSObject)?.value(forKey: "alpha") as? CGFloat, 0)
            XCTAssertEqual(source.alpha, 0.8, accuracy: 0.001)
            XCTAssertFalse(source.isHidden)
            second = nil
            XCTAssertEqual(source.alpha, 0.8, accuracy: 0.001)
            done.fulfill()
        })
        wait(for: [done], timeout: 10)
    }

    func testCroppedTransformedSourceTargetsItsVisibleShape() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let container = window.rootViewController!.view!
        let source = UIView(frame: CGRect(x: 20, y: 80, width: 180, height: 64))
        source.transform = CGAffineTransform(rotationAngle: 0.15).scaledBy(x: 0.85, y: 0.9)
        container.addSubview(source)
        let parameters = UIPreviewParameters()
        parameters.visiblePath = UIBezierPath(roundedRect: CGRect(x: 90, y: 8, width: 72, height: 48), cornerRadius: 24)
        let preview = LiquidMorphTransition.sourcePreview(for: source, parameters: parameters)!
        let visibleCenter = source.convert(CGPoint(x: 126, y: 32), to: container)
        XCTAssertEqual(preview.target.center.x, visibleCenter.x, accuracy: 0.001)
        XCTAssertEqual(preview.target.center.y, visibleCenter.y, accuracy: 0.001)
        XCTAssertEqual(preview.target.transform, source.transform)
        source.removeFromSuperview()
        XCTAssertNil(LiquidMorphTransition.sourcePreview(for: source, parameters: parameters))
    }

    func testDetachedContainerDoesNotStartOrComplete() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        let container = UIView(frame: window.bounds)
        window.rootViewController!.view.addSubview(container)
        let source = UIView(frame: CGRect(x: 20, y: 80, width: 40, height: 40))
        let menu = UIView(frame: CGRect(x: 20, y: 130, width: 280, height: 240))
        container.addSubview(source)
        container.addSubview(menu)
        let from = UITargetedPreview(view: source)
        let to = UITargetedPreview(view: menu)
        container.removeFromSuperview()
        let engine = LiquidMorphTransition()
        XCTAssertFalse(engine.animate(from: from, to: to, attachment: source.center, in: container) { XCTFail("Rejected transition completed") })
        window.isHidden = true
        XCTAssertFalse(engine.isAnimating)
    }

    func testRemovedPreviewViewDoesNotStart() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        let container = window.rootViewController!.view!
        let source = UIView(frame: CGRect(x: 20, y: 80, width: 40, height: 40))
        let menu = UIView(frame: CGRect(x: 20, y: 130, width: 280, height: 240))
        container.addSubview(source)
        container.addSubview(menu)
        let from = UITargetedPreview(view: source)
        let to = UITargetedPreview(view: menu)
        source.removeFromSuperview()
        let engine = LiquidMorphTransition()
        XCTAssertFalse(engine.animate(from: from, to: to, attachment: source.center, in: container) {})
        XCTAssertFalse(engine.isAnimating)
        window.isHidden = true
    }

    // A close requested while the menu is still opening must start at once. UIKit's opening
    // completion arrives ~1 s after the menu looks open (1.27 s measured on iOS 27), so deferring
    // the close until then leaves a menu that ignores taps outside it.
    func testCloseRequestedDuringOpenTakesOverImmediately() {
        checkCloseTakesOverOpen(after: 0.3)
    }

    func testCloseRequestedAsOpenStartsTakesOverImmediately() {
        checkCloseTakesOverOpen(after: 0)
    }

    private func checkCloseTakesOverOpen(after delay: CFTimeInterval) {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let container = controller.view!
        let source = UIView(frame: CGRect(x: 20, y: 100, width: 44, height: 44))
        source.backgroundColor = .systemBlue
        source.layer.cornerRadius = 22
        let menu = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        menu.frame = CGRect(x: 20, y: 100, width: 250, height: 240)
        container.addSubview(menu)
        container.addSubview(source)
        let accessory = UIView(frame: CGRect(x: 20, y: 350, width: 250, height: 30))
        accessory.alpha = 0
        container.addSubview(accessory)
        let originalFrame = source.frame
        let from = UITargetedPreview(view: source)
        let to = UITargetedPreview(view: menu)
        let engine = LiquidMorphTransition()
        var openCompletions = 0
        var closeCompletions = 0
        XCTAssertTrue(engine.animate(from: from, to: to, attachment: source.center, in: container, sourceIdentity: source, alongsideAnimations: { accessory.alpha = 1 }) {
            openCompletions += 1
            // The superseded opening must not report the running close as finished.
            XCTAssertEqual(engine.isAnimating, closeCompletions == 0)
        })
        let start = CACurrentMediaTime()
        while CACurrentMediaTime() - start < delay {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        XCTAssertTrue(engine.isAnimating)
        XCTAssertEqual(openCompletions, 0, "The opening must still be running when the close is requested")
        XCTAssertFalse(engine.animate(from: to, to: from, attachment: source.center, in: container, sourceIdentity: source) { XCTFail("Concurrent transition accepted") })

        var closeStarted = false
        XCTAssertTrue(engine.animate(from: to, to: from, attachment: source.center, in: container, sourceIdentity: source, interruptingCurrent: true, alongsideAnimations: {
            closeStarted = true
            accessory.alpha = 0
        }) {
            closeCompletions += 1
            XCTAssertFalse(engine.isAnimating)
        })
        XCTAssertTrue(closeStarted, "The close must start when requested, not after the opening completes")
        XCTAssertTrue(engine.isAnimating)

        let deadline = Date(timeIntervalSinceNow: 10)
        while (openCompletions == 0 || closeCompletions == 0) && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        // Drain a little longer so a duplicate callback would be counted.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        XCTAssertEqual(openCompletions, 1)
        XCTAssertEqual(closeCompletions, 1)
        XCTAssertFalse(engine.isAnimating)
        XCTAssertEqual(accessory.alpha, 0)
        XCTAssertEqual(source.frame, originalFrame)
        XCTAssertTrue(source.superview === container)
        XCTAssertTrue(menu.superview === container)
        XCTAssertEqual(source.alpha, 1)
        XCTAssertFalse(source.isHidden)
    }

    func testRoundTripRestoresHierarchyAndRejectsConcurrentMutation() {
        print("TEST ReduceMotion=\(UIAccessibility.isReduceMotionEnabled)")
        XCTAssertTrue(LiquidMorphTransition.isSupported)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        let container = controller.view!
        let source = UIView(frame: CGRect(x: 20, y: 100, width: 180, height: 48))
        source.backgroundColor = .systemBlue
        source.layer.cornerRadius = 24
        let menu = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        menu.frame = CGRect(x: 20, y: 160, width: 280, height: 240)
        container.addSubview(source)
        container.addSubview(menu)
        let accessory = UIView(frame: CGRect(x: 20, y: 410, width: 280, height: 30))
        accessory.alpha = 0
        container.addSubview(accessory)
        let originalFrame = source.frame
        let engine = LiquidMorphTransition()
        let done = expectation(description: "Round trip completes after UIKit cleanup")
        let from = UITargetedPreview(view: source)
        let to = UITargetedPreview(view: menu)
        XCTAssertTrue(engine.animate(from: from, to: to, attachment: source.center, in: container, alongsideAnimations: { accessory.alpha = 1 }) {
            XCTAssertEqual(accessory.alpha, 1)
            XCTAssertFalse(engine.isAnimating)
            XCTAssertTrue(source.superview === container)
            XCTAssertTrue(menu.superview === container)
            XCTAssertTrue(engine.animate(from: to, to: from, attachment: source.center, in: container, alongsideAnimations: { accessory.alpha = 0 }) {
                XCTAssertEqual(accessory.alpha, 0)
                XCTAssertEqual(source.frame, originalFrame)
                XCTAssertTrue(source.superview === container)
                XCTAssertTrue(menu.superview === container)
                XCTAssertEqual(source.alpha, 1)
                XCTAssertFalse(source.isHidden)
                XCTAssertFalse(engine.isAnimating)
                done.fulfill()
            })
        })
        XCTAssertTrue(engine.isAnimating)
        XCTAssertFalse(engine.animate(from: from, to: to, attachment: source.center, in: container) { XCTFail("Concurrent transition accepted") })
        wait(for: [done], timeout: 15)
        window.isHidden = true
    }
}
