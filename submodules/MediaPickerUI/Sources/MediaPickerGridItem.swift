import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import AccountContext
import TelegramPresentationData
import TelegramStringFormatting
import Photos
import CheckNode
import LegacyComponents
import PhotoResources
import InvisibleInkDustNode
import ImageBlur
import FastBlur

enum MediaPickerGridItemContent: Equatable {
    case asset(PHFetchResult<PHAsset>, Int)
    case media(MediaPickerScreen.Subject.Media, Int)
}

final class MediaPickerGridItem: GridItem {
    let content: MediaPickerGridItemContent
    let interaction: MediaPickerInteraction
    let theme: PresentationTheme
    let selectable: Bool
    let enableAnimations: Bool
    
    let section: GridSection? = nil
    
    init(content: MediaPickerGridItemContent, interaction: MediaPickerInteraction, theme: PresentationTheme, selectable: Bool, enableAnimations: Bool) {
        self.content = content
        self.interaction = interaction
        self.theme = theme
        self.selectable = selectable
        self.enableAnimations = enableAnimations
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        switch self.content {
        case let .asset(fetchResult, index):
            let node = MediaPickerGridItemNode()
            node.setup(interaction: self.interaction, fetchResult: fetchResult, index: index, theme: self.theme, selectable: self.selectable, enableAnimations: self.enableAnimations)
            return node
        case let .media(media, index):
            let node = MediaPickerGridItemNode()
            node.setup(interaction: self.interaction, media: media, index: index, theme: self.theme, selectable: self.selectable, enableAnimations: self.enableAnimations)
            return node
        }
    }
    
    func update(node: GridItemNode) {
        switch self.content {
        case let .asset(fetchResult, index):
            guard let node = node as? MediaPickerGridItemNode else {
                assertionFailure()
                return
            }
            node.setup(interaction: self.interaction, fetchResult: fetchResult, index: index, theme: self.theme, selectable: self.selectable, enableAnimations: self.enableAnimations)
        case let .media(media, index):
            guard let node = node as? MediaPickerGridItemNode else {
                assertionFailure()
                return
            }
            node.setup(interaction: self.interaction, media: media, index: index, theme: self.theme, selectable: self.selectable, enableAnimations: self.enableAnimations)
        }
    }
}

private let maskImage = generateImage(CGSize(width: 1.0, height: 24.0), opaque: false, rotatedContext: { size, context in
    let bounds = CGRect(origin: CGPoint(), size: size)
    context.clear(bounds)
    
    let gradientColors = [UIColor.black.withAlphaComponent(0.0).cgColor, UIColor.black.withAlphaComponent(0.6).cgColor] as CFArray
    
    var locations: [CGFloat] = [0.0, 1.0]
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!

    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
})

final class MediaPickerGridItemNode: GridItemNode {
    var currentMediaState: (TGMediaSelectableItem, Int)?
    var currentState: (PHFetchResult<PHAsset>, Int)?
    var enableAnimations: Bool = true
    private var selectable: Bool = false
    
    private let imageNode: ImageNode
    private var checkNode: InteractiveCheckNode?
    private let gradientNode: ASImageNode
    private let typeIconNode: ASImageNode
    private let durationNode: ImmediateTextNode
    
    private let activateAreaNode: AccessibilityAreaNode
    
    private var interaction: MediaPickerInteraction?
    private var theme: PresentationTheme?
        
    private let spoilerDisposable = MetaDisposable()
    var spoilerNode: SpoilerOverlayNode?
    
    private var currentIsPreviewing = false
            
    var selected: (() -> Void)?
        
    override init() {
        self.imageNode = ImageNode()
        self.imageNode.clipsToBounds = true
        self.imageNode.contentMode = .scaleAspectFill
        self.imageNode.isLayerBacked = false
        self.imageNode.animateFirstTransition = false
        
        self.gradientNode = ASImageNode()
        self.gradientNode.displaysAsynchronously = false
        self.gradientNode.displayWithoutProcessing = true
        self.gradientNode.image = maskImage
        
        self.typeIconNode = ASImageNode()
        self.typeIconNode.displaysAsynchronously = false
        self.typeIconNode.displayWithoutProcessing = true
        
        self.durationNode = ImmediateTextNode()
        
        self.activateAreaNode = AccessibilityAreaNode()
        self.activateAreaNode.accessibilityTraits = [.image]
                
        super.init()
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.activateAreaNode)
        
        self.imageNode.contentUpdated = { [weak self] image in
            self?.spoilerNode?.setImage(image)
        }
    }
    
    deinit {
        self.spoilerDisposable.dispose()
    }

    var identifier: String {
        return self.selectableItem?.uniqueIdentifier ?? ""
    }
    
    var selectableItem: TGMediaSelectableItem? {
        if let (media, _) = self.currentMediaState {
            return media
        } else if let (fetchResult, index) = self.currentState {
            return TGMediaAsset(phAsset: fetchResult[index])
        } else {
            return nil
        }
    }
    
    var _cachedTag: Int32?
    var tag: Int32? {
        if let tag = self._cachedTag {
            return tag
        } else if let (fetchResult, index) = self.currentState {
            let asset = fetchResult.object(at: index)
            if let localTimestamp = asset.creationDate?.timeIntervalSince1970 {
                let tag = Month(localTimestamp: Int32(exactly: floor(localTimestamp)) ?? 0).packedValue
                self._cachedTag = tag
                return tag
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    func updateSelectionState(animated: Bool = false) {
        if self.checkNode == nil, let _ = self.interaction?.selectionState, self.selectable, let theme = self.theme {
            let checkNode = InteractiveCheckNode(theme: CheckNodeTheme(theme: theme, style: .overlay))
            checkNode.valueChanged = { [weak self] value in
                if let strongSelf = self, let interaction = strongSelf.interaction, let selectableItem = strongSelf.selectableItem {
                    if !interaction.toggleSelection(selectableItem, value, false) {
                        strongSelf.checkNode?.setSelected(false, animated: false)
                    }
                }
            }
            self.addSubnode(checkNode)
            self.checkNode = checkNode
            self.setNeedsLayout()
        }

        if let interaction = self.interaction, let selectionState = interaction.selectionState  {
            let selected = selectionState.isIdentifierSelected(self.identifier)
            if let selectableItem = self.selectableItem {
                let index = selectionState.index(of: selectableItem)
                if index != NSNotFound {
                    self.checkNode?.content = .counter(Int(index))
                }
            }
            self.checkNode?.setSelected(selected, animated: animated)
        }
    }
    
    func updateHiddenMedia() {
        let wasHidden = self.isHidden
        self.isHidden = self.interaction?.hiddenMediaId == self.identifier
        if !self.isHidden && wasHidden {
            self.animateFadeIn(animateCheckNode: true, animateSpoilerNode: true)
        }
    }
    
    func animateFadeIn(animateCheckNode: Bool, animateSpoilerNode: Bool) {
        if animateCheckNode {
            self.checkNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
        self.gradientNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.typeIconNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.durationNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        if animateSpoilerNode {
            self.spoilerNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
    }
        
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
    }
    
    func setup(interaction: MediaPickerInteraction, media: MediaPickerScreen.Subject.Media, index: Int, theme: PresentationTheme, selectable: Bool, enableAnimations: Bool) {
        self.interaction = interaction
        self.theme = theme
        self.selectable = selectable
        self.enableAnimations = enableAnimations
        
        self.backgroundColor = theme.list.mediaPlaceholderColor
        
        if self.currentMediaState == nil || self.currentMediaState!.0.uniqueIdentifier != media.identifier || self.currentState!.1 != index {
            self.currentMediaState = (media.asset, index)
            self.setNeedsLayout()
        }
        
        self.updateSelectionState()
        self.updateHiddenMedia()
    }
        
    func setup(interaction: MediaPickerInteraction, fetchResult: PHFetchResult<PHAsset>, index: Int, theme: PresentationTheme, selectable: Bool, enableAnimations: Bool) {
        self.interaction = interaction
        self.theme = theme
        self.selectable = selectable
        self.enableAnimations = enableAnimations
        
        self.backgroundColor = theme.list.mediaPlaceholderColor
        
        if self.currentState == nil || self.currentState!.0 !== fetchResult || self.currentState!.1 != index {
            let editingContext = interaction.editingState
            let asset = fetchResult.object(at: index)
            
            if #available(iOS 15.0, *) {
                self.activateAreaNode.accessibilityLabel = "Photo \(asset.creationDate?.formatted(date: .abbreviated, time: .standard) ?? "")"
            }
            
            let editedSignal = Signal<UIImage?, NoError> { subscriber in
                if let signal = editingContext.thumbnailImageSignal(forIdentifier: asset.localIdentifier) {
                    let disposable = signal.start(next: { next in
                        if let image = next as? UIImage {
                            subscriber.putNext(image)
                        } else {
                            subscriber.putNext(nil)
                        }
                    }, error: { _ in
                    }, completed: nil)!

                    return ActionDisposable {
                        disposable.dispose()
                    }
                } else {
                    return EmptyDisposable
                }
            }
            
            let scale = min(2.0, UIScreenScale)
            let targetSize = CGSize(width: 128.0 * scale, height: 128.0 * scale)
            
            let assetImageSignal = assetImage(fetchResult: fetchResult, index: index, targetSize: targetSize, exact: false, deliveryMode: .fastFormat, synchronous: true)
            |> then(
                assetImage(fetchResult: fetchResult, index: index, targetSize: targetSize, exact: false, deliveryMode: .highQualityFormat, synchronous: false)
                |> delay(0.03, queue: Queue.concurrentDefaultQueue())
            )

            let originalSignal = assetImageSignal //assetImage(fetchResult: fetchResult, index: index, targetSize: targetSize, exact: false, synchronous: true)
            let imageSignal: Signal<UIImage?, NoError> = editedSignal
            |> mapToSignal { result in
                if let result = result {
                    return .single(result)
                } else {
                    return originalSignal
                }
            }
            self.imageNode.setSignal(imageSignal)
            
            let spoilerSignal = Signal<Bool, NoError> { subscriber in
                if let signal = editingContext.spoilerSignal(forIdentifier: asset.localIdentifier) {
                    let disposable = signal.start(next: { next in
                        if let next = next as? Bool {
                            subscriber.putNext(next)
                        }
                    }, error: { _ in
                    }, completed: nil)!
                    
                    return ActionDisposable {
                        disposable.dispose()
                    }
                } else {
                    return EmptyDisposable
                }
            }
            
            self.spoilerDisposable.set((spoilerSignal
            |> deliverOnMainQueue).start(next: { [weak self] hasSpoiler in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.updateHasSpoiler(hasSpoiler)
            }))
            
            if asset.isFavorite {
                self.typeIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Media Grid/Favorite"), color: .white)
                if self.typeIconNode.supernode == nil {
                    self.addSubnode(self.gradientNode)
                    self.addSubnode(self.typeIconNode)
                    self.setNeedsLayout()
                }
            } else if asset.mediaType == .video {
                if asset.mediaSubtypes.contains(.videoHighFrameRate) {
                    self.typeIconNode.image = UIImage(bundleImageName: "Media Editor/MediaSlomo")
                } else if asset.mediaSubtypes.contains(.videoTimelapse) {
                    self.typeIconNode.image = UIImage(bundleImageName: "Media Editor/MediaTimelapse")
                } else {
                    self.typeIconNode.image = UIImage(bundleImageName: "Media Editor/MediaVideo")
                }
                
                if self.typeIconNode.supernode == nil {
                    self.durationNode.attributedText = NSAttributedString(string: stringForDuration(Int32(asset.duration)), font: Font.semibold(12.0), textColor: .white)
                    
                    self.addSubnode(self.gradientNode)
                    self.addSubnode(self.typeIconNode)
                    self.addSubnode(self.durationNode)
                    self.setNeedsLayout()
                }
            } else {
                if self.typeIconNode.supernode != nil {
                    self.gradientNode.removeFromSupernode()
                    self.typeIconNode.removeFromSupernode()
                    self.durationNode.removeFromSupernode()
                }
            }
            
            self.currentState = (fetchResult, index)
            self.setNeedsLayout()
        }
        
        self.updateSelectionState()
        self.updateHiddenMedia()
    }
    
    private var didSetupSpoiler = false
    private func updateHasSpoiler(_ hasSpoiler: Bool) {
        var animated = true
        if !self.didSetupSpoiler {
            animated = false
            self.didSetupSpoiler = true
        }
    
        if hasSpoiler {
            if self.spoilerNode == nil {
                let spoilerNode = SpoilerOverlayNode(enableAnimations: self.enableAnimations)
                self.insertSubnode(spoilerNode, aboveSubnode: self.imageNode)
                self.spoilerNode = spoilerNode
                
                spoilerNode.setImage(self.imageNode.image)
                
                if animated {
                    spoilerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
            self.spoilerNode?.update(size: self.bounds.size, transition: .immediate)
            self.spoilerNode?.frame = CGRect(origin: .zero, size: self.bounds.size)
        } else if let spoilerNode = self.spoilerNode {
            self.spoilerNode = nil
            spoilerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak spoilerNode] _ in
                spoilerNode?.removeFromSupernode()
            })
        }
    }
    
    override func layout() {
        super.layout()
        
        self.imageNode.frame = self.bounds
        self.gradientNode.frame = CGRect(x: 0.0, y: self.bounds.height - 24.0, width: self.bounds.width, height: 24.0)
        self.typeIconNode.frame = CGRect(x: 0.0, y: self.bounds.height - 20.0, width: 19.0, height: 19.0)
        self.activateAreaNode.frame = self.bounds
        
        if self.durationNode.supernode != nil {
            let durationSize = self.durationNode.updateLayout(self.bounds.size)
            self.durationNode.frame = CGRect(origin: CGPoint(x: self.bounds.size.width - durationSize.width - 7.0, y: self.bounds.height - durationSize.height - 5.0), size: durationSize)
        }
        
        let checkSize = CGSize(width: 29.0, height: 29.0)
        self.checkNode?.frame = CGRect(origin: CGPoint(x: self.bounds.width - checkSize.width - 3.0, y: 3.0), size: checkSize)
        
        if let spoilerNode = self.spoilerNode, self.bounds.width > 0.0 {
            spoilerNode.frame = self.bounds
            spoilerNode.update(size: self.bounds.size, transition: .immediate)
        }
    }
    
    func transitionView() -> UIView {
        let view = self.imageNode.view.snapshotContentTree(unhide: true, keepTransform: true)!
        view.frame = self.convert(self.bounds, to: nil)
        return view
    }
        
    @objc func imageNodeTap(_ recognizer: UITapGestureRecognizer) {
        guard let (fetchResult, index) = self.currentState else {
            return
        }
        self.interaction?.openMedia(fetchResult, index, self.imageNode.image)
    }
}

class SpoilerOverlayNode: ASDisplayNode {
    private let blurNode: ASImageNode
    let dustNode: MediaDustNode
  
    private var maskView: UIView?
    private var maskLayer: CAShapeLayer?
    
    init(enableAnimations: Bool) {
        self.blurNode = ASImageNode()
        self.blurNode.displaysAsynchronously = false
        self.blurNode.contentMode = .scaleAspectFill
         
        self.dustNode = MediaDustNode(enableAnimations: enableAnimations)
        
        super.init()
        
        self.clipsToBounds = true
        self.isUserInteractionEnabled = false
                
        self.addSubnode(self.blurNode)
        self.addSubnode(self.dustNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let maskView = UIView()
        self.maskView = maskView
//        self.dustNode.view.mask = maskView
        
        let maskLayer = CAShapeLayer()
        maskLayer.fillRule = .evenOdd
        maskLayer.fillColor = UIColor.white.cgColor
        maskView.layer.addSublayer(maskLayer)
        self.maskLayer = maskLayer
    }
    
    func setImage(_ image: UIImage?) {
        self.blurNode.image = image.flatMap { blurredImage($0) }
    }
    
    func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.blurNode, frame: CGRect(origin: .zero, size: size))
        
        transition.updateFrame(node: self.dustNode, frame: CGRect(origin: .zero, size: size))
        self.dustNode.update(size: size, color: .white, transition: transition)
    }
}

private func blurredImage(_ image: UIImage) -> UIImage? {
    guard let image = image.cgImage else {
        return nil
    }
    
    let thumbnailSize = CGSize(width: image.width, height: image.height)
    let thumbnailContextSize = thumbnailSize.aspectFilled(CGSize(width: 20.0, height: 20.0))
    if let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0) {
        thumbnailContext.withFlippedContext { c in
            c.interpolationQuality = .none
            c.draw(image, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
        }
        imageFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
        
        let thumbnailContext2Size = thumbnailSize.aspectFitted(CGSize(width: 100.0, height: 100.0))
        if let thumbnailContext2 = DrawingContext(size: thumbnailContext2Size, scale: 1.0) {
            thumbnailContext2.withFlippedContext { c in
                c.interpolationQuality = .none
                if let image = thumbnailContext.generateImage()?.cgImage {
                    c.draw(image, in: CGRect(origin: CGPoint(), size: thumbnailContext2Size))
                }
            }
            imageFastBlur(Int32(thumbnailContext2Size.width), Int32(thumbnailContext2Size.height), Int32(thumbnailContext2.bytesPerRow), thumbnailContext2.bytes)
            adjustSaturationInContext(context: thumbnailContext2, saturation: 1.7)
            return thumbnailContext2.generateImage()
        }
    }
    return nil
}
