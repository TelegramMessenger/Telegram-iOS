import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import ConfettiEffect
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import TelegramStringFormatting

final class PeerInfoBirthdayOverlay: ASDisplayNode {
    private let context: AccountContext
    
    private var disposable: Disposable?
    
    init(context: AccountContext) {
        self.context = context
    
        super.init()
        
        self.isUserInteractionEnabled = false
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    func setup(size: CGSize, birthday: TelegramBirthday, sourceRect: CGRect?) {
        self.setupAnimations(size: size, birthday: birthday, sourceRect: sourceRect)
        
        Queue.mainQueue().after(0.1) {
            self.view.addSubview(ConfettiView(frame: CGRect(origin: .zero, size: size)))
        }
    }
    
    private func setupAnimations(size: CGSize, birthday: TelegramBirthday, sourceRect: CGRect?) {
        self.disposable = (combineLatest(
            self.context.engine.stickers.loadedStickerPack(reference: .animatedEmojiAnimations, forceActualized: false),
            self.context.engine.stickers.loadedStickerPack(reference: .name("FestiveFontEmoji"), forceActualized: false)
        )
        |> map { animatedEmoji, numbers -> (FileMediaReference?, [FileMediaReference]) in
            var effectFile: FileMediaReference?
            if case let .result(_, items, _) = animatedEmoji {
                let randomKey = ["🎉", "🎈", "🎆"].randomElement()!
                outer: for item in items {
                    let indexKeys = item.getStringRepresentationsOfIndexKeys()
                    for key in indexKeys {
                        if key == randomKey {
                            effectFile = .stickerPack(stickerPack: .animatedEmojiAnimations, media: item.file._parse())
                            break outer
                        }
                    }
                }
            }
            var numberFiles: [FileMediaReference] = []
            if let age = ageForBirthday(birthday), case let .result(info, items, _) = numbers {
                let ageKeys = ageToKeys(age)
                for ageKey in ageKeys {
                    for item in items {
                        let indexKeys = item.getStringRepresentationsOfIndexKeys()
                        for key in indexKeys {
                            if key == ageKey {
                                numberFiles.append(.stickerPack(stickerPack: .id(id: info.id.id, accessHash: info.accessHash), media: item.file._parse()))
                            }
                        }
                    }
                }
            }
            return (effectFile, numberFiles)
        }
        |> deliverOnMainQueue).start(next: { [weak self] effectAndNumberFiles in
            guard let self else {
                return
            }
            let (effectFile, numberFiles) = effectAndNumberFiles
            
            if let effectFile {
                let _ = freeMediaFileInteractiveFetched(account: self.context.account, userLocation: .peer(self.context.account.peerId), fileReference: effectFile).startStandalone()
                self.setupEffectAnimation(size: size, file: effectFile, sourceRect: sourceRect)
            }
            for file in numberFiles {
                let _ = freeMediaFileInteractiveFetched(account: self.context.account, userLocation: .peer(self.context.account.peerId), fileReference: file).startStandalone()
            }
            self.setupNumberAnimations(size: size, files: numberFiles, sourceRect: sourceRect)
        })
    }
    
    private func setupEffectAnimation(size: CGSize, file: FileMediaReference, sourceRect: CGRect?) {
        guard let dimensions = file.media.dimensions else {
            return
        }
        let minSide = min(size.width, size.height)
        let pixelSize = dimensions.cgSize.aspectFitted(CGSize(width: 512.0, height: 512.0))
        let animationSize = dimensions.cgSize.aspectFitted(CGSize(width: minSide, height: minSide))
        
        let animationNode = DefaultAnimatedStickerNodeImpl()
        let source = AnimatedStickerResourceSource(account: self.context.account, resource: file.media.resource, fitzModifier: nil)
        let pathPrefix = self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.media.resource.id)
        animationNode.setup(source: source, width: Int(pixelSize.width), height: Int(pixelSize.height), playbackMode: .once, mode: .direct(cachePathPrefix: pathPrefix))
        self.addSubnode(animationNode)
        
        let startY = sourceRect?.midY ?? size.height / 2.0
        
        animationNode.updateLayout(size: animationSize)
        animationNode.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
        animationNode.frame = CGRect(origin: CGPoint(x: floor((size.width - animationSize.width) / 2.0), y: startY - animationSize.height / 2.0), size: animationSize)
        animationNode.visibility = true
    }
    
    private func setupNumberAnimations(size: CGSize, files: [FileMediaReference], sourceRect: CGRect?) {
        guard !files.isEmpty else {
            return
        }
        
        let startY = sourceRect?.midY ?? 475.0
        
        var offset: CGFloat = 0.0
        var scaleDelay: Double = 0.0
        if files.count > 1 {
            offset -= 45.0
        }
        for file in files {
            guard let dimensions = file.media.dimensions else {
                continue
            }
            
            let animationSize = dimensions.cgSize.aspectFitted(CGSize(width: 144.0, height: 144.0))
            let pixelSize = dimensions.cgSize.aspectFitted(CGSize(width: 256.0, height: 256.0))
            
            let animationNode = DefaultAnimatedStickerNodeImpl()
            let source = AnimatedStickerResourceSource(account: self.context.account, resource: file.media.resource, fitzModifier: nil)
            let pathPrefix: String? = self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.media.resource.id)
            animationNode.setup(source: source, width: Int(pixelSize.width), height: Int(pixelSize.height), playbackMode: .loop, mode: .direct(cachePathPrefix: pathPrefix))
            self.addSubnode(animationNode)
            
            animationNode.updateLayout(size: animationSize)
            animationNode.bounds = CGRect(origin: .zero, size: animationSize)
            animationNode.transform = CATransform3DMakeScale(0.001, 0.001, 1.0)
            animationNode.visibility = true

            let path = UIBezierPath()
            let startPoint = CGPoint(x: 90.0 + offset * 0.7, y: startY + CGFloat.random(in: -20.0 ..< 20.0))
            animationNode.position = startPoint
            path.move(to: startPoint)
            path.addCurve(to: CGPoint(x: 205.0 + offset, y: -90.0), controlPoint1: CGPoint(x: 213.0 + offset * 0.8, y: 380.0 + CGFloat.random(in: -20.0 ..< 20.0)), controlPoint2: CGPoint(x: 206.0 + offset * 0.8, y: 134.0 + CGFloat.random(in: -20.0 ..< 20.0)))
                        
            let riseAnimation = CAKeyframeAnimation(keyPath: "position")
            riseAnimation.path = path.cgPath
            riseAnimation.duration = 2.2
            riseAnimation.calculationMode = .cubic
            riseAnimation.timingFunction = CAMediaTimingFunction(name: .easeIn)
            riseAnimation.beginTime = CACurrentMediaTime() + 0.5
            riseAnimation.isRemovedOnCompletion = false
            riseAnimation.fillMode = .forwards
            riseAnimation.completion = { [weak self] _ in
                self?.removeFromSupernode()
            }
            animationNode.layer.add(riseAnimation, forKey: "position")
            offset += 132.0
            
            let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
            scaleAnimation.duration = 2.0
            scaleAnimation.values = [0.0, 0.45, 1.0]
            scaleAnimation.keyTimes = [0.0, 0.3, 1.0]
            scaleAnimation.beginTime = CACurrentMediaTime() + scaleDelay
            scaleAnimation.isRemovedOnCompletion = false
            scaleAnimation.fillMode = .forwards
            animationNode.layer.add(scaleAnimation, forKey: "scale")
            scaleDelay += 0.3
        }
    }
    
    static func preloadBirthdayAnimations(context: AccountContext, birthday: TelegramBirthday) {
        let preload = combineLatest(
            context.engine.stickers.loadedStickerPack(reference: .animatedEmojiAnimations, forceActualized: false),
            context.engine.stickers.loadedStickerPack(reference: .name("FestiveFontEmoji"), forceActualized: false)
        )
        |> mapToSignal { animatedEmoji, numbers -> Signal<Never, NoError> in
            var signals: [Signal<FetchResourceSourceType, FetchResourceError>] = []
            if case let .result(_, items, _) = animatedEmoji {
                for item in items {
                    let indexKeys = item.getStringRepresentationsOfIndexKeys()
                    for key in indexKeys {
                        if ["🎉", "🎈", "🎆"].contains(key) {
                            signals.append(freeMediaFileInteractiveFetched(account: context.account, userLocation: .peer(context.account.peerId), fileReference: .stickerPack(stickerPack: .animatedEmojiAnimations, media: item.file._parse())))
                        }
                    }
                }
            }
            if let age = ageForBirthday(birthday), case let .result(info, items, _) = numbers {
                let ageKeys = ageToKeys(age)
                for item in items {
                    let indexKeys = item.getStringRepresentationsOfIndexKeys()
                    for key in indexKeys {
                        if ageKeys.contains(key) {
                            signals.append(freeMediaFileInteractiveFetched(account: context.account, userLocation: .peer(context.account.peerId), fileReference: .stickerPack(stickerPack: .id(id: info.id.id, accessHash: info.accessHash), media: item.file._parse())))
                        }
                    }
                }
            }
            if !signals.isEmpty {
                return combineLatest(signals)
                |> `catch` { _ in
                    return .complete()
                }
                |> ignoreValues
            } else {
                return .complete()
            }
        }
        let _ = preload.startStandalone()
    }
}

private func ageToKeys(_ age: Int) -> [String] {
    return "\(age)".map { String($0) }.map {
        switch $0 {
        case "0":
            return "0️⃣"
        case "1":
            return "1️⃣"
        case "2":
            return "2️⃣"
        case "3":
            return "3️⃣"
        case "4":
            return "4️⃣"
        case "5":
            return "5️⃣"
        case "6":
            return "6️⃣"
        case "7":
            return "7️⃣"
        case "8":
            return "8️⃣"
        case "9":
            return "9️⃣"
        default:
            return $0
        }
    }
}
