import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import AvatarNode
import AppBundle
import AccountContext
import HierarchyTrackingLayer
import LokiRng
import SwiftSignalKit
import TelegramPresentationData

private let gradientColors: [NSArray] = [
    [UIColor(rgb: 0xff516a).cgColor, UIColor(rgb: 0xff885e).cgColor],
    [UIColor(rgb: 0xffa85c).cgColor, UIColor(rgb: 0xffcd6a).cgColor],
    [UIColor(rgb: 0x665fff).cgColor, UIColor(rgb: 0x82b1ff).cgColor],
    [UIColor(rgb: 0x54cb68).cgColor, UIColor(rgb: 0xa0de7e).cgColor],
    [UIColor(rgb: 0x4acccd).cgColor, UIColor(rgb: 0x00fcfd).cgColor],
    [UIColor(rgb: 0x2a9ef1).cgColor, UIColor(rgb: 0x72d5fd).cgColor],
    [UIColor(rgb: 0xd669ed).cgColor, UIColor(rgb: 0xe0a2f3).cgColor],
]

private func avatarViewLettersImage(size: CGSize, peerId: EnginePeer.Id, letters: [String], isStory: Bool) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, 2.0)
    let context = UIGraphicsGetCurrentContext()

    context?.beginPath()
    if isStory {
        context?.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height).insetBy(dx: 4.0, dy: 4.0))
    } else {
        context?.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
    }
    context?.clip()

    let colorIndex: Int
    if peerId.namespace == .max {
        colorIndex = 0
    } else {
        colorIndex = abs(Int(clamping: peerId.id._internalGetInt64Value()))
    }

    let colorsArray = gradientColors[colorIndex % gradientColors.count]
    var locations: [CGFloat] = [1.0, 0.0]
    let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!

    context?.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())

    context?.setBlendMode(.normal)

    let string = letters.count == 0 ? "" : (letters[0] + (letters.count == 1 ? "" : letters[1]))
    let attributedString = NSAttributedString(string: string, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 8.0), NSAttributedString.Key.foregroundColor: UIColor.white])

    let line = CTLineCreateWithAttributedString(attributedString)
    let lineBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)

    let lineOffset = CGPoint(x: string == "B" ? 1.0 : 0.0, y: 0.0)
    let lineOrigin = CGPoint(x: floor(-lineBounds.origin.x + (size.width - lineBounds.size.width) / 2.0) + lineOffset.x, y: floor(-lineBounds.origin.y + (size.height - lineBounds.size.height) / 2.0))

    context?.translateBy(x: size.width / 2.0, y: size.height / 2.0)
    context?.scaleBy(x: 1.0, y: -1.0)
    context?.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)

    context?.translateBy(x: lineOrigin.x, y: lineOrigin.y)
    if let context = context {
        CTLineDraw(line, context)
    }
    context?.translateBy(x: -lineOrigin.x, y: -lineOrigin.y)
    
    if isStory {
        context?.resetClip()
        
        let lineWidth: CGFloat = 2.0
        context?.setLineWidth(lineWidth)
        context?.addEllipse(in: CGRect(origin: CGPoint(x: size.width * 0.5, y: size.height * 0.5), size: CGSize(width: size.width, height: size.height)).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5))
        context?.replacePathWithStrokedPath()
        context?.clip()
        
        let colors: [CGColor] = [
            UIColor(rgb: 0x34C76F).cgColor,
            UIColor(rgb: 0x3DA1FD).cgColor
        ]
        var locations: [CGFloat] = [0.0, 1.0]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        context?.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    }

    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
}

private func makePeerBadgeImage(engine: TelegramEngine, peer: EnginePeer, count: Int) async -> UIImage {
    let avatarSize: CGFloat = 16.0
    let avatarInset: CGFloat = 2.0
    let avatarIconSpacing: CGFloat = 2.0
    let iconTextSpacing: CGFloat = 1.0
    let iconSize: CGFloat = 10.0
    let rightInset: CGFloat = 5.0
    
    let text = NSAttributedString(string: countString(Int64(count)), font: Font.semibold(10.0), textColor: .white)
    var textSize = text.boundingRect(with: CGSize(width: 200.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil).size
    textSize.width = ceil(textSize.width)
    textSize.height = ceil(textSize.height)
    
    var avatarSourceImage: UIImage?
    if let resource = smallestImageRepresentation(peer.profileImageRepresentations)?.resource, let peerReference = PeerReference(peer._asPeer()) {
        let disposable = fetchedMediaResource(mediaBox: engine.account.postbox.mediaBox, userLocation: .peer(peer.id), userContentType: .avatar, reference: .avatar(peer: peerReference, resource: resource)).startStrict()
        let signal = engine.account.postbox.mediaBox.resourceData(resource)
        |> filter { $0.complete }
        |> map { value -> Data? in
            if value.complete {
                return try? Data(contentsOf: URL(fileURLWithPath: value.path))
            } else {
                return nil
            }
        }
        |> take(1)
        |> timeout(0.9, queue: Queue.concurrentDefaultQueue(), alternate: .single(nil))
        
        if let imageData = await signal.get() {
            avatarSourceImage = UIImage(data: imageData)
        }
        
        disposable.dispose()
    }
    
    let size = CGSize(width: avatarInset + avatarSize + avatarIconSpacing + iconSize + iconTextSpacing + textSize.width + rightInset, height: avatarSize + avatarInset * 2.0)
    return generateImage(size, rotatedContext: { size, context in
        UIGraphicsPushContext(context)
        defer {
            UIGraphicsPopContext()
        }
        
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor(rgb: 0xFFB10D).cgColor)
        context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: size.height * 0.5).cgPath)
        context.fillPath()
        
        let avatarRect = CGRect(origin: CGPoint(x: avatarInset, y: avatarInset), size: CGSize(width: avatarSize, height: avatarSize))
        
        if let avatarSourceImage {
            context.addEllipse(in: avatarRect)
            context.clip()
            avatarSourceImage.draw(in: avatarRect)
            context.resetClip()
        } else if let image = avatarViewLettersImage(size: CGSize(width: avatarSize, height: avatarSize), peerId: peer.id, letters: peer.displayLetters, isStory: false) {
            image.draw(in: avatarRect)
        }
        
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Premium/Stars/ButtonStar"), color: .white) {
            let iconFrame = CGRect(origin: CGPoint(x: avatarInset + avatarSize + avatarIconSpacing, y: floorToScreenPixels((size.height - iconSize) * 0.5) + 1.0), size: CGSize(width: iconSize, height: iconSize))
            image.draw(in: iconFrame)
        }
        
        text.draw(at: CGPoint(x: avatarInset + avatarSize + avatarIconSpacing + iconSize + iconTextSpacing, y: floorToScreenPixels((size.height - textSize.height) * 0.5)))
    })!
}

private actor LiveChatReactionItemTaskQueue {
    private final class PeerTask {
        let peer: EnginePeer
        let count: Int
        let completion: (UIImage) -> Void
        
        init(peer: EnginePeer, count: Int, completion: @escaping (UIImage) -> Void) {
            self.peer = peer
            self.count = count
            self.completion = completion
        }
    }
    
    private let engine: TelegramEngine
    private var tasks: [PeerTask] = []
    
    init(engine: TelegramEngine) {
        self.engine = engine
    }
    
    func add(peer: EnginePeer, count: Int, completion: @escaping (UIImage) -> Void) {
        self.tasks.append(PeerTask(peer: peer, count: count, completion: completion))
        if self.tasks.count == 1 {
            Task {
                await processTasks()
            }
        }
    }
    
    private func processTasks() async {
        while !self.tasks.isEmpty {
            let task = self.tasks.removeFirst()
            let image = await makePeerBadgeImage(engine: self.engine, peer: task.peer, count: task.count)
            task.completion(image)
        }
    }
}

final class LiveChatReactionStreamView: UIView {
    private final class ItemLayer: SimpleLayer {
        let amplitude: CGFloat
        let period: CGFloat
        let phaseOffset: CGFloat
        let baseX: CGFloat
        let verticalVelocity: CGFloat
        var timeValue: CGFloat = 0.0
        
        init(image: UIImage, amplitude: CGFloat, period: CGFloat, phaseOffset: CGFloat, baseX: CGFloat, verticalVelocity: CGFloat) {
            self.amplitude = amplitude
            self.period = period
            self.phaseOffset = phaseOffset
            self.baseX = baseX
            self.verticalVelocity = verticalVelocity
            
            super.init()
            
            self.contents = image.cgImage
            self.allowsEdgeAntialiasing = true
        }

        override init(layer: Any) {
            self.amplitude = 0.0
            self.period = 0.0
            self.phaseOffset = 0.0
            self.baseX = 0.0
            self.verticalVelocity = 0.0
            
            super.init(layer: layer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    private var nextId: Int = 0
    private var itemLayers: [Int: ItemLayer] = [:]
    private let itemLayerContainer: SimpleLayer
    private let hierarchyTracker: HierarchyTrackingLayer
    private var previousTimestamp: Double = 0.0
    private var displayLink: SharedDisplayLinkDriver.Link?
    private var previousPhysicsTimestamp: Double = 0.0
    
    private let taskQueue: LiveChatReactionItemTaskQueue

    init(context: AccountContext) {
        self.itemLayerContainer = SimpleLayer()
        self.hierarchyTracker = HierarchyTrackingLayer()
        self.taskQueue = LiveChatReactionItemTaskQueue(engine: context.engine)
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.itemLayerContainer)
        
        self.layer.addSublayer(self.hierarchyTracker)
        self.hierarchyTracker.isInHierarchyUpdated = { [weak self] inHierarchy in
            guard let self else {
                return
            }
            if inHierarchy {
                if self.displayLink == nil {
                    self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.updatePhysics()
                    })
                }
            } else {
                self.displayLink = nil
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func add(peer: EnginePeer, count: Int) {
        if !self.hierarchyTracker.isInHierarchy {
            return
        }
        let timestamp = CFAbsoluteTimeGetCurrent()
        if timestamp < self.previousTimestamp + 0.2 {
            return
        }
        self.previousTimestamp = timestamp
        Task {
            await self.taskQueue.add(peer: peer, count: count, completion: { [weak self] image in
                Task { @MainActor in
                    guard let self else {
                        return
                    }
                    self.addRenderedItem(image: image)
                }
            })
        }
    }
    
    private func addRenderedItem(image: UIImage) {
        let id = self.nextId
        self.nextId += 1
        
        let random = LokiRng(seed0: UInt(id), seed1: 1, seed2: 0)
        let itemX: CGFloat = -image.size.width - 8.0 + 20.0 * CGFloat(LokiRng.random(withSeed0: UInt(id), seed1: 0, seed2: 0) - 0.5)
        let phaseOffset: CGFloat = CGFloat(random.next())
        let itemLayer = ItemLayer(image: image, amplitude: 0.0 + CGFloat(random.next()) * 6.0, period: 1.5 + CGFloat(random.next()) * 2.0, phaseOffset: phaseOffset, baseX: itemX, verticalVelocity: -(1.0 + CGFloat(random.next()) * 0.2) * 90.0)
        itemLayer.frame = CGRect(origin: CGPoint(x: itemX, y: -image.size.height * 0.5), size: image.size)
        self.itemLayers[id] = itemLayer
        self.itemLayerContainer.addSublayer(itemLayer)
        
        let itemDuration: Double = 1.2 + Double(random.next()) * 0.8
        
        itemLayer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
        itemLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, completion: { [weak self, weak itemLayer] _ in
            guard let itemLayer else {
                return
            }
            
            let delay: Double = itemDuration - 0.1 - 0.18
            
            let transition: ComponentTransition = .easeInOut(duration: 0.2)
            transition.animateBlur(layer: itemLayer, fromRadius: 0.0, toRadius: 8.0, delay: delay)
            
            itemLayer.animateScale(from: 1.0, to: 0.001, duration: 0.2, delay: delay, removeOnCompletion: false)
            itemLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, delay: delay, removeOnCompletion: false, completion: { [weak self] _ in
                guard let self else {
                    return
                }
                if let itemLayer = self.itemLayers[id] {
                    self.itemLayers.removeValue(forKey: id)
                    itemLayer.removeFromSuperlayer()
                }
            })
        })
    }
    
    private func updatePhysics() {
        let timestamp = CACurrentMediaTime()
        let dt = max(1.0 / 120.0, min(1.0 / 30.0, timestamp - self.previousPhysicsTimestamp))
        self.previousPhysicsTimestamp = timestamp

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        for (_, itemLayer) in self.itemLayers {
            itemLayer.timeValue += dt
            let itemPhase = (itemLayer.timeValue.truncatingRemainder(dividingBy: itemLayer.period) / itemLayer.period + itemLayer.phaseOffset).truncatingRemainder(dividingBy: 1.0)
            let phaseAngle = itemPhase * CGFloat.pi * 2.0
            let phaseFraction = sin(phaseAngle)
            
            let newX = itemLayer.baseX + phaseFraction * itemLayer.amplitude
            let newY = itemLayer.position.y + itemLayer.verticalVelocity * dt
            itemLayer.position = CGPoint(x: newX, y: newY)

            let horizontalVelocity = itemLayer.amplitude * cos(phaseAngle) * (CGFloat.pi * 2.0 / itemLayer.period)
            let rotationAngle = atan2(itemLayer.verticalVelocity, horizontalVelocity) + CGFloat.pi * 0.5
            itemLayer.setValue(rotationAngle, forKeyPath: "transform.rotation.z")
        }
        
        CATransaction.commit()
    }

    func update(size: CGSize, sourcePoint: CGPoint, transition: ComponentTransition) {
        transition.setFrame(layer: self.itemLayerContainer, frame: CGRect(origin: sourcePoint, size: CGSize()))
    }
}
