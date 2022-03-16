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

enum MediaPickerGridItemContent: Equatable {
    case asset(PHFetchResult<PHAsset>, Int)
}

final class MediaPickerGridItem: GridItem {
    let content: MediaPickerGridItemContent
    let interaction: MediaPickerInteraction
    let theme: PresentationTheme
    
    let section: GridSection? = nil
    
    init(content: MediaPickerGridItemContent, interaction: MediaPickerInteraction, theme: PresentationTheme) {
        self.content = content
        self.interaction = interaction
        self.theme = theme
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        switch self.content {
            case let .asset(fetchResult, index):
                let node = MediaPickerGridItemNode()
                node.setup(interaction: self.interaction, fetchResult: fetchResult, index: index, theme: self.theme)
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
                node.setup(interaction: self.interaction, fetchResult: fetchResult, index: index, theme: self.theme)
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
    var currentState: (PHFetchResult<PHAsset>, Int)?
    private let imageNode: ImageNode
    private var checkNode: InteractiveCheckNode?
    private let gradientNode: ASImageNode
    private let typeIconNode: ASImageNode
    private let durationNode: ImmediateTextNode
    
    private var interaction: MediaPickerInteraction?
    private var theme: PresentationTheme?
        
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
                
        super.init()
        
        self.addSubnode(self.imageNode)
    }

    var identifier: String {
        return self.asset?.localIdentifier ?? ""
    }
    
    var asset: PHAsset? {
        if let (fetchResult, index) = self.currentState {
            return fetchResult[index]
        } else {
            return nil
        }
    }
    
    var _cachedTag: Int32?
    var tag: Int32? {
        if let tag = self._cachedTag {
            return tag
        } else if let asset = self.asset, let localTimestamp = asset.creationDate?.timeIntervalSince1970 {
            let tag = Month(localTimestamp: Int32(localTimestamp)).packedValue
            self._cachedTag = tag
            return tag
        } else {
            return nil
        }
    }
    
    func updateSelectionState(animated: Bool = false) {
        if self.checkNode == nil, let _ = self.interaction?.selectionState, let theme = self.theme {
            let checkNode = InteractiveCheckNode(theme: CheckNodeTheme(theme: theme, style: .overlay))
            checkNode.valueChanged = { [weak self] value in
                if let strongSelf = self, let asset = strongSelf.asset, let interaction = strongSelf.interaction {
                    if let legacyAsset = TGMediaAsset(phAsset: asset) {
                        interaction.toggleSelection(legacyAsset, value, false)
                    }
                }
            }
            self.addSubnode(checkNode)
            self.checkNode = checkNode
            self.setNeedsLayout()
        }

        if let asset = self.asset, let interaction = self.interaction, let selectionState = interaction.selectionState  {
            let selected = selectionState.isIdentifierSelected(asset.localIdentifier)
            if let legacyAsset = TGMediaAsset(phAsset: asset) {
                let index = selectionState.index(of: legacyAsset)
                if index != NSNotFound {
                    self.checkNode?.content = .counter(Int(index))
                }
            }
            self.checkNode?.setSelected(selected, animated: animated)
        }
    }
    
    func updateHiddenMedia() {
        if let asset = self.asset {
            let wasHidden = self.isHidden
            self.isHidden = self.interaction?.hiddenMediaId == asset.localIdentifier
            if !self.isHidden && wasHidden {
                self.animateFadeIn(animateCheckNode: true)
            }
        }
    }
    
    func animateFadeIn(animateCheckNode: Bool) {
        if animateCheckNode {
            self.checkNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
        self.gradientNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.typeIconNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.durationNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
        
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
    }
        
    func setup(interaction: MediaPickerInteraction, fetchResult: PHFetchResult<PHAsset>, index: Int, theme: PresentationTheme) {
        self.interaction = interaction
        self.theme = theme
        
        self.backgroundColor = theme.list.mediaPlaceholderColor
        
        if self.currentState == nil || self.currentState!.0 !== fetchResult || self.currentState!.1 != index {
            let editingContext = interaction.editingState
            let asset = fetchResult.object(at: index)
            
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
            let originalSignal = assetImage(fetchResult: fetchResult, index: index, targetSize: targetSize, exact: false)
            let imageSignal: Signal<UIImage?, NoError> = editedSignal
            |> mapToSignal { result in
                if let result = result {
                    return .single(result)
                } else {
                    return originalSignal
                }
            }
            self.imageNode.setSignal(imageSignal)
            
            if asset.mediaType == .video {
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
    
    override func layout() {
        super.layout()
        
        self.imageNode.frame = self.bounds
        self.gradientNode.frame = CGRect(x: 0.0, y: self.bounds.height - 24.0, width: self.bounds.width, height: 24.0)
        self.typeIconNode.frame = CGRect(x: 0.0, y: self.bounds.height - 20.0, width: 19.0, height: 19.0)
        
        if self.durationNode.supernode != nil {
            let durationSize = self.durationNode.updateLayout(self.bounds.size)
            self.durationNode.frame = CGRect(origin: CGPoint(x: self.bounds.size.width - durationSize.width - 7.0, y: self.bounds.height - durationSize.height - 5.0), size: durationSize)
        }
        
        let checkSize = CGSize(width: 29.0, height: 29.0)
        self.checkNode?.frame = CGRect(origin: CGPoint(x: self.bounds.width - checkSize.width - 3.0, y: 3.0), size: checkSize)
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

