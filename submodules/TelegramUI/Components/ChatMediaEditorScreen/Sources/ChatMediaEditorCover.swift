import Foundation
import UIKit
import Display
import SwiftSignalKit

public protocol ChatMediaEditorCoverAdapter: AnyObject {
    func coverImage(for uniqueId: String) -> UIImage?
    func coverPosition(for uniqueId: String) -> Double?
    func setCoverImage(_ image: UIImage, position: Double?, for uniqueId: String)
}

public let chatMediaEditorCoverMinimumDuration: Double = 60.0

public func chatMediaEditorCoverButtonIsVisible(hasCoverButton: Bool, isVideo: Bool, isAnimation: Bool, duration: Double) -> Bool {
    return hasCoverButton && isVideo && !isAnimation && duration >= chatMediaEditorCoverMinimumDuration
}

public final class ChatMediaEditorCoverModel {
    public let adapter: ChatMediaEditorCoverAdapter

    public init(adapter: ChatMediaEditorCoverAdapter) {
        self.adapter = adapter
    }

    public func coverImage(for uniqueId: String) -> UIImage? {
        return self.adapter.coverImage(for: uniqueId)
    }

    public func savedPosition(for uniqueId: String) -> Double? {
        return self.adapter.coverPosition(for: uniqueId)
    }

    public func saveFrame(_ image: UIImage, position: Double, for uniqueId: String) {
        self.adapter.setCoverImage(image, position: position, for: uniqueId)
    }

    public func saveGalleryImage(_ image: UIImage, for uniqueId: String) {
        self.adapter.setCoverImage(image, position: nil, for: uniqueId)
    }
}

public func chatMediaEditorCoverClampedPosition(_ position: Double, trimRange: Range<Double>?, duration: Double) -> Double {
    let lowerBound = max(0.0, trimRange?.lowerBound ?? 0.0)
    let upperBound = max(lowerBound, min(duration, trimRange?.upperBound ?? duration))
    return max(lowerBound, min(upperBound, position))
}

public func chatMediaEditorCoverEditingPosition(savedPosition: Double?, playerPosition: Double?, currentPosition: Double) -> Double {
    return savedPosition ?? playerPosition ?? currentPosition
}

public protocol ChatMediaEditorCoverFrameSource: AnyObject {
    var resultImage: UIImage? { get }
    func seek(_ position: Double, completion: @escaping () -> Void)
    func setOnNextDisplay(_ f: @escaping () -> Void)
}

public let chatMediaEditorCoverCaptureFallbackDelay: Double = 0.5

private final class ChatMediaEditorCoverCaptureState {
    var isCompleted = false
}

public func chatMediaEditorCaptureCoverFrame(source: ChatMediaEditorCoverFrameSource, position: Double, schedule: @escaping (Double, @escaping () -> Void) -> Void = { delay, f in Queue.mainQueue().after(delay, f) }, completion: @escaping (UIImage?, Double) -> Void) {
    let state = ChatMediaEditorCoverCaptureState()
    let finish: () -> Void = {
        if state.isCompleted {
            return
        }
        state.isCompleted = true
        completion(source.resultImage, position)
    }
    source.seek(position, completion: {
        source.setOnNextDisplay {
            finish()
        }
        schedule(chatMediaEditorCoverCaptureFallbackDelay) {
            finish()
        }
    })
}

public let chatMediaEditorCoverScrubberOffset: CGFloat = 16.0

public func chatMediaEditorCoverScrubberFrame(trimScrubberFrame: CGRect) -> CGRect {
    return trimScrubberFrame.offsetBy(dx: 0.0, dy: chatMediaEditorCoverScrubberOffset)
}

public let chatMediaEditorCoverButtonHeight: CGFloat = 26.0
let chatMediaEditorCoverButtonThumbnailSize: CGFloat = 24.0
let chatMediaEditorCoverButtonLabelInset: CGFloat = 28.0
let chatMediaEditorCoverButtonThumbnailInset: CGFloat = 22.0
public let chatMediaEditorCoverScrubberTrackHeight: CGFloat = 39.0
let chatMediaEditorCoverGalleryButtonOffset: CGFloat = 16.0
public let chatMediaEditorCoverSaveButtonHeight: CGFloat = 50.0
let chatMediaEditorCoverSideInset: CGFloat = 16.0

public func chatMediaEditorCoverButtonFrame(size: CGSize, safeInsets: UIEdgeInsets, headerFrame: CGRect, buttonWidth: CGFloat, toolbarSide: ChatMediaEditorToolbarSide? = nil) -> CGRect {
    let trackMinY = headerFrame.minY + floor((headerFrame.height - chatMediaEditorCoverScrubberTrackHeight) / 2.0)
    if toolbarSide != nil {
        return CGRect(x: headerFrame.minX + floorToScreenPixels((headerFrame.width - buttonWidth) / 2.0), y: trackMinY - 1.0 - chatMediaEditorCoverButtonHeight, width: buttonWidth, height: chatMediaEditorCoverButtonHeight)
    }
    let availableWidth = size.width - safeInsets.left - safeInsets.right
    return CGRect(x: safeInsets.left + floorToScreenPixels((availableWidth - buttonWidth) / 2.0), y: trackMinY - 1.0 - chatMediaEditorCoverButtonHeight, width: buttonWidth, height: chatMediaEditorCoverButtonHeight)
}

public func chatMediaEditorCoverGalleryButtonFrame(coverButtonFrame: CGRect, size: CGSize, safeInsets: UIEdgeInsets, buttonWidth: CGFloat) -> CGRect {
    let availableWidth = size.width - safeInsets.left - safeInsets.right
    return CGRect(x: safeInsets.left + floorToScreenPixels((availableWidth - buttonWidth) / 2.0), y: coverButtonFrame.minY + chatMediaEditorCoverGalleryButtonOffset, width: buttonWidth, height: chatMediaEditorCoverButtonHeight)
}

public struct ChatMediaEditorCoverEditLayout: Equatable {
    public var titleFrame: CGRect
    public var cancelFrame: CGRect
    public var saveFrame: CGRect
}

public func chatMediaEditorCoverEditLayout(size: CGSize, safeInsets: UIEdgeInsets, titleSize: CGSize, cancelSize: CGSize, statusIsland: ChatMediaEditorStatusIslandRow? = nil) -> ChatMediaEditorCoverEditLayout {
    var topY: CGFloat = 0.0
    if safeInsets.top > 20.0 {
        topY += safeInsets.top
    }
    var titleFrame = CGRect(x: safeInsets.left + floor((size.width - safeInsets.left - safeInsets.right - titleSize.width) / 2.0), y: topY + 26.0, width: titleSize.width, height: titleSize.height)
    var cancelFrame = CGRect(x: safeInsets.left + chatMediaEditorCoverSideInset, y: topY + 20.0, width: cancelSize.width, height: cancelSize.height)
    // Beside iPhone Duo's status island the title and Cancel sit on the island's clock line, as the editor's top row.
    if let statusIsland {
        titleFrame.origin.y = statusIsland.clockLineY - titleSize.height / 2.0
        cancelFrame.origin.y = statusIsland.clockLineY - cancelSize.height / 2.0
    }
    let saveFrame = CGRect(x: chatMediaEditorCoverSideInset, y: size.height - chatMediaEditorCoverSaveButtonHeight - chatMediaEditorCoverSideInset - safeInsets.bottom, width: size.width - chatMediaEditorCoverSideInset * 2.0, height: chatMediaEditorCoverSaveButtonHeight)
    return ChatMediaEditorCoverEditLayout(titleFrame: titleFrame, cancelFrame: cancelFrame, saveFrame: saveFrame)
}

private let chatMediaEditorCoverArrowImage: UIImage? = UIImage(bundleImageName: "Editor/ArrowRight").flatMap { generateTintedImage(image: $0, color: .white) }

final class ChatMediaEditorCoverButton: UIButton {
    private let wrapperView: UIView
    private let backgroundView: UIView
    private let thumbnailView: UIImageView
    private let label: UILabel
    private let iconView: UIImageView
    private let labelWidth: CGFloat

    init(title: String) {
        let font = Font.bold(14.0)
        self.labelWidth = floor((title as NSString).size(withAttributes: [.font: font]).width) + chatMediaEditorCoverButtonLabelInset

        self.wrapperView = UIView()
        self.wrapperView.isUserInteractionEnabled = false

        self.backgroundView = UIView()
        self.backgroundView.clipsToBounds = true
        self.backgroundView.layer.cornerRadius = chatMediaEditorCoverButtonHeight / 2.0
        self.backgroundView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)

        self.thumbnailView = UIImageView()
        self.thumbnailView.clipsToBounds = true
        self.thumbnailView.contentMode = .scaleAspectFill
        self.thumbnailView.layer.cornerRadius = chatMediaEditorCoverButtonThumbnailSize / 2.0
        self.thumbnailView.isHidden = true

        self.label = UILabel()
        self.label.backgroundColor = .clear
        self.label.font = font
        self.label.textColor = .white
        self.label.text = title
        self.label.sizeToFit()

        self.iconView = UIImageView(image: chatMediaEditorCoverArrowImage)
        self.iconView.alpha = 0.3
        self.iconView.contentMode = .center

        super.init(frame: .zero)

        self.isExclusiveTouch = true
        self.addSubview(self.wrapperView)
        self.wrapperView.addSubview(self.backgroundView)
        self.wrapperView.addSubview(self.thumbnailView)
        self.wrapperView.addSubview(self.label)
        self.wrapperView.addSubview(self.iconView)
        self.layoutContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var contentWidth: CGFloat {
        return self.thumbnailView.isHidden ? self.labelWidth : self.labelWidth + chatMediaEditorCoverButtonThumbnailInset
    }

    func setThumbnail(_ image: UIImage?) {
        self.thumbnailView.image = image
        self.thumbnailView.isHidden = image == nil
        self.layoutContent()
    }

    private func layoutContent() {
        let width = self.contentWidth
        self.wrapperView.bounds = CGRect(origin: .zero, size: CGSize(width: width, height: chatMediaEditorCoverButtonHeight))
        self.wrapperView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        self.backgroundView.frame = CGRect(origin: .zero, size: CGSize(width: width, height: chatMediaEditorCoverButtonHeight))
        self.thumbnailView.frame = CGRect(x: 1.0, y: 1.0, width: chatMediaEditorCoverButtonThumbnailSize, height: chatMediaEditorCoverButtonThumbnailSize)
        let labelX: CGFloat = self.thumbnailView.isHidden ? 10.0 : 10.0 + chatMediaEditorCoverButtonThumbnailInset
        let labelSize = self.label.bounds.size
        self.label.frame = CGRect(x: labelX, y: (chatMediaEditorCoverButtonHeight - labelSize.height) / 2.0, width: labelSize.width, height: labelSize.height)
        self.iconView.frame = CGRect(x: self.label.frame.maxX + 4.0, y: 7.0, width: 8.0, height: 12.0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.layoutContent()
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

final class ChatMediaEditorCoverEditView: UIView {
    let titleLabel: UILabel
    let cancelButton: UIButton
    let saveButton: UIButton
    let galleryButton: ChatMediaEditorCoverButton?

    init(title: String, cancelTitle: String, saveTitle: String, galleryTitle: String?) {
        self.titleLabel = UILabel()
        self.titleLabel.textColor = .white
        self.titleLabel.font = Font.bold(17.0)
        self.titleLabel.text = title
        self.titleLabel.sizeToFit()

        self.cancelButton = UIButton(type: .system)
        self.cancelButton.titleLabel?.font = Font.regular(17.0)
        self.cancelButton.setTitle(cancelTitle, for: .normal)
        self.cancelButton.setTitleColor(.white, for: .normal)
        self.cancelButton.tintColor = .white
        self.cancelButton.sizeToFit()

        self.saveButton = UIButton(type: .system)
        self.saveButton.clipsToBounds = true
        self.saveButton.layer.cornerRadius = 10.0
        self.saveButton.backgroundColor = UIColor(rgb: 0x0088ff)
        self.saveButton.titleLabel?.font = Font.bold(17.0)
        self.saveButton.setTitle(saveTitle, for: .normal)
        self.saveButton.setTitleColor(.white, for: .normal)
        self.saveButton.tintColor = .white

        self.galleryButton = galleryTitle.flatMap { ChatMediaEditorCoverButton(title: $0) }

        super.init(frame: .zero)

        self.addSubview(self.titleLabel)
        self.addSubview(self.cancelButton)
        self.addSubview(self.saveButton)
        if let galleryButton = self.galleryButton {
            self.addSubview(galleryButton)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result === self {
            return nil
        }
        return result
    }
}
