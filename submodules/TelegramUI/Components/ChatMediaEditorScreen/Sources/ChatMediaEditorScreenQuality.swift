import Foundation
import UIKit
import Display
import ComponentFlow
import LegacyComponents
import MediaEditor
import MediaPickerUI
import TooltipUI
import SliderComponent
import ChatMediaSend

public let chatMediaEditorVideoQualityPresets: [MediaQualityPreset] = [.compressedVeryLow, .compressedLow, .compressedMedium, .compressedHigh, .compressedVeryHigh]

private func chatMediaEditorVideoPresetMaximumSide(_ preset: MediaQualityPreset) -> CGFloat {
    switch preset {
    case .compressedVeryLow:
        return 480.0
    case .compressedLow:
        return 640.0
    case .compressedMedium:
        return 848.0
    case .compressedHigh:
        return 1280.0
    case .compressedVeryHigh:
        return 1920.0
    default:
        return 848.0
    }
}

public func chatMediaEditorLegacyVideoPreset(_ preset: MediaQualityPreset) -> Int {
    switch preset {
    case .compressedVeryLow:
        return 1
    case .compressedLow:
        return 2
    case .compressedMedium:
        return 3
    case .compressedHigh:
        return 4
    case .compressedVeryHigh:
        return 5
    default:
        return 3
    }
}

public func chatMediaEditorBestAvailableVideoPreset(dimensions: CGSize) -> MediaQualityPreset {
    let maxSide = max(dimensions.width, dimensions.height)
    for preset in [MediaQualityPreset.compressedVeryHigh, .compressedHigh, .compressedMedium] {
        if maxSide >= chatMediaEditorVideoPresetMaximumSide(preset) {
            return preset
        }
    }
    return .compressedLow
}

public func chatMediaEditorVideoQualityPickerPresets(dimensions: CGSize) -> [MediaQualityPreset] {
    let best = chatMediaEditorBestAvailableVideoPreset(dimensions: dimensions)
    guard let maxIndex = chatMediaEditorVideoQualityPresets.firstIndex(of: best) else {
        return chatMediaEditorVideoQualityPresets
    }
    return Array(chatMediaEditorVideoQualityPresets[0 ... maxIndex])
}

public func chatMediaEditorInitialVideoQualityPreset(preferred: MediaQualityPreset, dimensions: CGSize) -> MediaQualityPreset {
    let presets = chatMediaEditorVideoQualityPickerPresets(dimensions: dimensions)
    guard let index = chatMediaEditorVideoQualityPresets.firstIndex(of: preferred), let last = presets.last else {
        return preferred
    }
    return index < presets.count ? preferred : last
}

public func chatMediaEditorVideoQualityPickerInitialPreset(values: MediaEditorValues, fallback: MediaQualityPreset) -> MediaQualityPreset {
    let presets = chatMediaEditorVideoQualityPickerPresets(dimensions: values.originalDimensions.cgSize)
    var preset = fallback
    if let current = values.qualityPreset, chatMediaEditorVideoQualityPresets.contains(current) {
        preset = current
    }
    guard let index = chatMediaEditorVideoQualityPresets.firstIndex(of: preset), let last = presets.last else {
        return presets.last ?? .compressedMedium
    }
    return index < presets.count ? preset : last
}

public func chatMediaEditorToolbarVideoPreset(values: MediaEditorValues, fallback: MediaQualityPreset) -> Int {
    return chatMediaEditorLegacyVideoPreset(chatMediaEditorVideoQualityPickerInitialPreset(values: values, fallback: fallback))
}

public func chatMediaEditorVideoQualityTitle(_ preset: MediaQualityPreset) -> String {
    switch preset {
    case .compressedVeryLow:
        return "240p"
    case .compressedLow:
        return "360p"
    case .compressedMedium:
        return "480p"
    case .compressedHigh:
        return "720p"
    case .compressedVeryHigh:
        return "1080p"
    default:
        return ""
    }
}

public func chatMediaEditorCommitVideoQuality(values: MediaEditorValues, preset: MediaQualityPreset, fallback: MediaQualityPreset, defaults: UserDefaults) -> MediaEditorValues? {
    if preset == chatMediaEditorVideoQualityPickerInitialPreset(values: values, fallback: fallback) {
        return nil
    }
    defaults.set(NSNumber(value: chatMediaEditorLegacyVideoPreset(preset)), forKey: chatMediaEditorPreferredVideoPresetKey)
    return values.withUpdatedQualityPreset(preset)
}

public func chatMediaEditorVideoQualityIsEnabled(values: MediaEditorValues) -> Bool {
    return !values.videoIsMuted
}

public func chatMediaEditorShowsQualityTab(isGallery: Bool, hasCaptionModel: Bool, isAnimation: Bool) -> Bool {
    return isGallery && hasCaptionModel && !isAnimation
}

public func chatMediaEditorDisabledToolbarTabs(isVideo: Bool, values: MediaEditorValues) -> TGPhotoEditorTab {
    var tabs: TGPhotoEditorTab = []
    if isVideo && !chatMediaEditorVideoQualityIsEnabled(values: values) {
        tabs.insert(.qualityTab)
    }
    return tabs
}

func chatMediaEditorVideoQualityInfoString(values: MediaEditorValues, preset: MediaQualityPreset, duration: Double) -> String {
    let dimensions = chatMediaEditorVideoFileDimensions(values: values.withUpdatedQualityPreset(preset), duration: duration)
    let legacyPreset = TGMediaVideoConversionPreset(rawValue: UInt32(chatMediaEditorLegacyVideoPreset(preset)))
    let estimatedSize = TGMediaVideoConverter.estimatedSize(for: legacyPreset, duration: duration, hasAudio: true)
    let sizeString = TGStringUtils.string(forFileSize: Int64(estimatedSize), precision: 1) ?? ""
    return "MP4 • ~\(sizeString) • \(dimensions.width)x\(dimensions.height)"
}

let chatMediaEditorQualityPanelSize: CGFloat = 75.0
let chatMediaEditorQualityPanelTopInset: CGFloat = 7.0
private let chatMediaEditorQualitySliderMargin: CGFloat = 15.0

final class ChatMediaEditorQualityPanelView: UIView {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let slider = ComponentView<Empty>()
    var selectionUpdated: ((MediaQualityPreset) -> Void)?
    var trackingUpdated: ((Bool) -> Void)?

    init(title: String) {
        super.init(frame: .zero)
        self.backgroundColor = UIColor(white: 0.0, alpha: 0.9)
        self.clipsToBounds = true

        let font = UIFont.boldSystemFont(ofSize: 13.0)
        self.titleLabel.font = font
        self.titleLabel.textColor = .white
        self.titleLabel.textAlignment = .left
        self.titleLabel.text = title
        self.addSubview(self.titleLabel)

        self.valueLabel.font = font
        self.valueLabel.textColor = TGPhotoEditorInterfaceAssets.accentColor()
        self.valueLabel.textAlignment = .right
        self.addSubview(self.valueLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(presets: [MediaQualityPreset], selected: MediaQualityPreset, size: CGSize, transition: ComponentTransition) {
        self.valueLabel.text = chatMediaEditorVideoQualityTitle(selected)
        self.titleLabel.frame = CGRect(x: chatMediaEditorQualitySliderMargin + 6.0, y: 4.0, width: 160.0, height: 20.0)
        self.valueLabel.frame = CGRect(x: size.width - chatMediaEditorQualitySliderMargin - 100.0 - 6.0, y: 4.0, width: 100.0, height: 20.0)

        let sliderMargin = chatMediaEditorQualitySliderMargin + 7.0
        let selectedIndex = presets.firstIndex(of: selected) ?? 0
        let sliderSize = self.slider.update(
            transition: transition,
            component: AnyComponent(SliderComponent(
                content: .discrete(SliderComponent.Discrete(
                    valueCount: presets.count,
                    value: selectedIndex,
                    markPositions: true,
                    valueUpdated: { [weak self] index in
                        guard let self, index >= 0, index < presets.count else {
                            return
                        }
                        self.selectionUpdated?(presets[index])
                    }
                )),
                useNative: true,
                trackBackgroundColor: UIColor(rgb: 0xffffff, alpha: 0.1),
                trackForegroundColor: UIColor(rgb: 0xffffff),
                trackHeight: 6.0,
                displaysBorderOnTracking: true,
                isTrackingUpdated: { [weak self] isTracking in
                    self?.trackingUpdated?(isTracking)
                }
            )),
            environment: {},
            containerSize: CGSize(width: max(0.0, size.width - sliderMargin * 2.0), height: 44.0)
        )
        if let sliderView = self.slider.view {
            if sliderView.superview == nil {
                self.addSubview(sliderView)
            }
            transition.setFrame(view: sliderView, frame: CGRect(origin: CGPoint(x: sliderMargin, y: 35.0 - sliderSize.height / 2.0), size: sliderSize))
        }
    }
}

extension ChatMediaEditorScreen.Node {
    var showsQualityTab: Bool {
        return chatMediaEditorShowsQualityTab(isGallery: self.isGallery, hasCaptionModel: self.captionModel != nil, isAnimation: self.pageModel.currentItem.isAnimation)
    }

    var isEditingQuality: Bool {
        return self.activeTool == .quality
    }

    var toolbarVideoQualityPreset: Int {
        guard self.subject.isVideo else {
            return 0
        }
        return chatMediaEditorToolbarVideoPreset(values: self.mediaEditor.values, fallback: chatMediaEditorPreferredVideoQualityPreset())
    }

    var qualityInfoString: String? {
        guard self.isEditingQuality, let selection = self.qualitySelection else {
            return nil
        }
        let duration = self.mediaEditor.originalDuration ?? self.mediaEditor.duration ?? 0.0
        return chatMediaEditorVideoQualityInfoString(values: self.mediaEditor.values, preset: selection, duration: duration)
    }

    func qualityTabPressed() {
        guard self.showsQualityTab else {
            return
        }
        if self.subject.isVideo {
            guard chatMediaEditorVideoQualityIsEnabled(values: self.mediaEditor.values) else {
                return
            }
            self.resetCurrentPageZoom()
            self.openQuality()
            return
        }
        guard let captionModel = self.captionModel else {
            return
        }
        let isHighQuality = captionModel.toggleHighQualityPhoto()
        self.requestLayout(transition: .immediate)
        self.presentPhotoQualityTooltip(isHighQuality: isHighQuality)
    }

    private func openQuality() {
        guard self.activeTool == nil, !self.isSending, !self.isInvalidated, let controller = self.controller, !controller.isDismissing, self.validLayout != nil else {
            return
        }
        if self.entitiesView.hasSelection {
            self.entitiesView.selectEntity(nil)
        }
        let values = self.mediaEditor.values
        self.toolStartValues = values
        self.qualitySelection = chatMediaEditorVideoQualityPickerInitialPreset(values: values, fallback: chatMediaEditorPreferredVideoQualityPreset())

        let title = self.context.sharedContext.currentPresentationData.with { $0 }.strings.PhotoEditor_QualityTool
        let panelView = ChatMediaEditorQualityPanelView(title: title)
        panelView.selectionUpdated = { [weak self] preset in
            guard let self, self.isEditingQuality, self.qualitySelection != preset else {
                return
            }
            self.qualitySelection = preset
            self.requestLayout(transition: .immediate)
        }
        panelView.trackingUpdated = { [weak self] isTracking in
            self?.setInteractionTracking(isTracking, source: "quality")
        }
        panelView.alpha = 0.0
        if let toolbarView = self.toolbar.view {
            self.view.insertSubview(panelView, belowSubview: toolbarView)
        } else {
            self.view.addSubview(panelView)
        }
        self.qualityPanelView = panelView

        self.activeTool = .quality
        self.updateEntityInteraction()
        if let layout = self.validLayout {
            self.updateQualityLayout(layout: layout, transition: .immediate)
        }
        self.requestLayout(transition: .animated(duration: 0.3, curve: .spring))
        UIView.animate(withDuration: 0.3, animations: {
            panelView.alpha = 1.0
        })
    }

    func commitQuality() {
        guard self.isEditingQuality, let selection = self.qualitySelection else {
            return
        }
        if let values = chatMediaEditorCommitVideoQuality(values: self.mediaEditor.values, preset: selection, fallback: chatMediaEditorPreferredVideoQualityPreset(), defaults: .standard) {
            self.mediaEditor.values = values
            self.selectionEditCommitted()
        } else {
            self.toolStartValues = nil
        }
        self.closeQuality()
    }

    func cancelQuality() {
        guard self.isEditingQuality else {
            return
        }
        self.toolStartValues = nil
        self.closeQuality()
    }

    private func closeQuality() {
        let panelView = self.qualityPanelView
        panelView?.trackingUpdated = nil
        self.qualityPanelView = nil
        self.setInteractionTracking(false, source: "quality")
        self.qualitySelection = nil
        self.activeTool = nil
        self.updateEntityInteraction()
        self.requestLayout(transition: .animated(duration: 0.3, curve: .spring))
        UIView.animate(withDuration: 0.2, animations: {
            panelView?.alpha = 0.0
        }, completion: { _ in
            panelView?.removeFromSuperview()
        })
    }

    func updateQualityLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        guard let panelView = self.qualityPanelView, let selection = self.qualitySelection else {
            return
        }
        let side = self.toolbarSide(layout: layout)
        let panelFrame = chatMediaEditorQualityPanelFrame(size: layout.size, safeInsets: self.editorSafeInsets(layout: layout), toolbarSide: side)
        let contentSize = side == nil ? panelFrame.size : CGSize(width: panelFrame.height, height: panelFrame.width)
        let rotation: CGFloat
        switch side {
        case .left:
            rotation = -CGFloat.pi / 2.0
        case .right:
            rotation = CGFloat.pi / 2.0
        case nil:
            rotation = 0.0
        }
        transition.updateBounds(layer: panelView.layer, bounds: CGRect(origin: .zero, size: contentSize))
        transition.updatePosition(layer: panelView.layer, position: CGPoint(x: panelFrame.midX, y: panelFrame.midY))
        transition.updateTransform(layer: panelView.layer, transform: CGAffineTransform(rotationAngle: rotation))
        let presets = chatMediaEditorVideoQualityPickerPresets(dimensions: self.mediaEditor.values.originalDimensions.cgSize)
        panelView.update(presets: presets, selected: selection, size: contentSize, transition: ComponentTransition(transition))
    }

    private func presentPhotoQualityTooltip(isHighQuality: Bool) {
        let strings = self.context.sharedContext.currentPresentationData.with { $0 }.strings
        let text = isHighQuality ? strings.Media_PhotoHdOn : strings.Media_PhotoHdOff
        guard let icon = TGPhotoEditorInterfaceAssets.qualityIcon(forHighQuality: isHighQuality, filled: true) else {
            return
        }
        var sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.maxY - 60.0, width: 1.0, height: 1.0)
        if let toolbarView = self.toolbar.view as? ChatMediaEditorBottomControlsComponent.View, let frame = toolbarView.middleItemFrame(id: chatMediaEditorBottomControlsTabId(.qualityTab), in: nil) {
            sourceRect = frame
        }
        let controller = TooltipScreen(
            account: self.context.account,
            sharedContext: self.context.sharedContext,
            text: .plain(text: text),
            style: .customBlur(UIColor(rgb: 0x18181a), 0.0),
            icon: .image(icon),
            location: .point(sourceRect, .bottom),
            displayDuration: .custom(2.0),
            shouldDismissOnTouch: { _, _ in
                return .dismiss(consume: false)
            }
        )
        self.context.sharedContext.presentGlobalController(controller, nil)
    }
}
