import Foundation
import UIKit
import Display
import LegacyComponents
import AccountContext
import TelegramPresentationData
import ComponentFlow
import GlassBackgroundComponent
import GlassBarButtonComponent
import PlainButtonComponent
import BundleIconComponent

private let toolbarButtonSide: CGFloat = 44.0
private let toolbarSideButtonSide: CGFloat = 44.0
private let centerButtonSpacing: CGFloat = 10.0

private let toolbarTabOrder: [TGPhotoEditorTab] = [
    .cropTab,
    .stickerTab,
    .paintTab,
    .eraserTab,
    .textTab,
    .toolsTab,
    .rotateTab,
    .qualityTab,
    .timerTab,
    .mirrorTab,
    .aspectRatioTab,
    .tintTab,
    .blurTab,
    .curvesTab
]

private let dontHighlightOnSelectionTabs = Set<UInt>([
    TGPhotoEditorTab.rotateTab.rawValue,
    TGPhotoEditorTab.stickerTab.rawValue,
    TGPhotoEditorTab.textTab.rawValue,
    TGPhotoEditorTab.qualityTab.rawValue,
    TGPhotoEditorTab.timerTab.rawValue,
    TGPhotoEditorTab.mirrorTab.rawValue,
    TGPhotoEditorTab.aspectRatioTab.rawValue
])


private final class MediaPickerPhotoToolbarImageCache {
    private var images: [String: UIImage] = [:]

    func qualityIcon(isPhoto: Bool, highQuality: Bool, preset: Int, color: UIColor) -> UIImage? {
        let key = "quality-\(isPhoto)-\(highQuality)-\(preset)-\(self.colorKey(color))"
        if let image = self.images[key] {
            return image
        }
        let image = generateQualityIcon(isPhoto: isPhoto, highQuality: highQuality, preset: preset, color: color)
        self.images[key] = image
        return image
    }

    func timerIcon(value: Int, color: UIColor) -> UIImage? {
        let key = "timer-\(value)-\(self.colorKey(color))"
        if let image = self.images[key] {
            return image
        }
        let image = generateTimerIcon(value: value, color: color)
        self.images[key] = image
        return image
    }

    private func colorKey(_ color: UIColor) -> String {
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return "\(Int(red * 255.0))-\(Int(green * 255.0))-\(Int(blue * 255.0))-\(Int(alpha * 255.0))"
        }
        var white: CGFloat = 0.0
        if color.getWhite(&white, alpha: &alpha) {
            return "\(Int(white * 255.0))-\(Int(alpha * 255.0))"
        }
        return color.description
    }
}

private func generateQualityIcon(isPhoto: Bool, highQuality: Bool, preset: Int, color: UIColor) -> UIImage? {
    let label: String
    if isPhoto {
        label = highQuality ? "HD" : "SD"
    } else {
        switch preset {
        case 1:
            label = "240"
        case 2:
            label = "360"
        case 3:
            label = "480"
        case 4:
            label = "720"
        case 5:
            label = "HD"
        default:
            label = "480"
        }
    }

    let size = CGSize(width: isPhoto ? 24.0 : 28.0, height: 24.0)
    let lineWidth = 2.0 - UIScreenPixel
    let rect = CGRect(origin: .zero, size: size).insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0)

    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
    guard let context = UIGraphicsGetCurrentContext() else {
        UIGraphicsEndImageContext()
        return nil
    }

    context.setStrokeColor(color.cgColor)
    context.setLineWidth(lineWidth)
    context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 7.0).cgPath)
    context.strokePath()

    let font = Font.with(size: 11.0, design: .round, weight: .bold)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .kern: -0.7
    ]
    let textSize = label.size(withAttributes: attributes)
    label.draw(
        in: CGRect(
            x: floorToScreenPixels((size.width - textSize.width) / 2.0) + UIScreenPixel,
            y: 5.0,
            width: textSize.width,
            height: textSize.height
        ),
        withAttributes: attributes
    )

    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
}

private func generateTimerIcon(value: Int, color: UIColor) -> UIImage? {
    let size = CGSize(width: 24.0, height: 24.0)
    let lineWidth = 2.0 - UIScreenPixel

    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
    guard let context = UIGraphicsGetCurrentContext() else {
        UIGraphicsEndImageContext()
        return nil
    }

    context.setStrokeColor(color.cgColor)
    context.setLineWidth(lineWidth)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    let bodyRect = CGRect(x: 4.0, y: 5.0, width: 16.0, height: 16.0).insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0)
    context.strokeEllipse(in: bodyRect)

    context.move(to: CGPoint(x: 9.0, y: 2.5))
    context.addLine(to: CGPoint(x: 15.0, y: 2.5))
    context.strokePath()

    context.move(to: CGPoint(x: 12.0, y: 5.0))
    context.addLine(to: CGPoint(x: 12.0, y: 8.0))
    context.strokePath()

    if value == 0 {
        context.move(to: CGPoint(x: 12.0, y: 13.0))
        context.addLine(to: CGPoint(x: 12.0, y: 9.0))
        context.move(to: CGPoint(x: 12.0, y: 13.0))
        context.addLine(to: CGPoint(x: 15.0, y: 13.0))
        context.strokePath()
    } else {
        let label = "\(value)"
        let font = Font.with(size: 10.0, design: .round, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let textSize = label.size(withAttributes: attributes)
        label.draw(
            in: CGRect(
                x: floorToScreenPixels((size.width - textSize.width) / 2.0),
                y: 9.0,
                width: textSize.width,
                height: textSize.height
            ),
            withAttributes: attributes
        )
    }

    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
}

private final class MediaPickerPhotoToolbarComponent: Component {
    let context: AccountContext
    let solidBackground: Bool
    let backButtonType: TGPhotoEditorBackButton
    let doneButtonType: TGPhotoEditorDoneButton
    let currentTabs: TGPhotoEditorTab
    let activeTab: TGPhotoEditorTab
    let highlightedTabs: TGPhotoEditorTab
    let disabledTabs: TGPhotoEditorTab
    let qualityIsPhoto: Bool
    let qualityHighQuality: Bool
    let qualityPreset: Int
    let timerValue: Int
    let hasSendStarsButton: Bool
    let sendPaidMessageStars: Int64
    let editButtonsHidden: Bool
    let editButtonsEnabled: Bool
    let centerButtonsHidden: Bool
    let allButtonsHidden: Bool
    let cancelDoneButtonsHidden: Bool
    let doneButtonEnabled: Bool
    let interfaceOrientation: UIInterfaceOrientation
    let bottomInset: CGFloat
    let infoString: String?
    let cancelPressed: (() -> Void)?
    let donePressed: (() -> Void)?
    let doneLongPressed: ((Any?) -> Void)?
    let tabPressed: ((TGPhotoEditorTab) -> Void)?

    init(
        context: AccountContext,
        solidBackground: Bool,
        backButtonType: TGPhotoEditorBackButton,
        doneButtonType: TGPhotoEditorDoneButton,
        currentTabs: TGPhotoEditorTab,
        activeTab: TGPhotoEditorTab,
        highlightedTabs: TGPhotoEditorTab,
        disabledTabs: TGPhotoEditorTab,
        qualityIsPhoto: Bool,
        qualityHighQuality: Bool,
        qualityPreset: Int,
        timerValue: Int,
        hasSendStarsButton: Bool,
        sendPaidMessageStars: Int64,
        editButtonsHidden: Bool,
        editButtonsEnabled: Bool,
        centerButtonsHidden: Bool,
        allButtonsHidden: Bool,
        cancelDoneButtonsHidden: Bool,
        doneButtonEnabled: Bool,
        interfaceOrientation: UIInterfaceOrientation,
        bottomInset: CGFloat,
        infoString: String?,
        cancelPressed: (() -> Void)?,
        donePressed: (() -> Void)?,
        doneLongPressed: ((Any?) -> Void)?,
        tabPressed: ((TGPhotoEditorTab) -> Void)?
    ) {
        self.context = context
        self.solidBackground = solidBackground
        self.backButtonType = backButtonType
        self.doneButtonType = doneButtonType
        self.currentTabs = currentTabs
        self.activeTab = activeTab
        self.highlightedTabs = highlightedTabs
        self.disabledTabs = disabledTabs
        self.qualityIsPhoto = qualityIsPhoto
        self.qualityHighQuality = qualityHighQuality
        self.qualityPreset = qualityPreset
        self.timerValue = timerValue
        self.hasSendStarsButton = hasSendStarsButton
        self.sendPaidMessageStars = sendPaidMessageStars
        self.editButtonsHidden = editButtonsHidden
        self.editButtonsEnabled = editButtonsEnabled
        self.centerButtonsHidden = centerButtonsHidden
        self.allButtonsHidden = allButtonsHidden
        self.cancelDoneButtonsHidden = cancelDoneButtonsHidden
        self.doneButtonEnabled = doneButtonEnabled
        self.interfaceOrientation = interfaceOrientation
        self.bottomInset = bottomInset
        self.infoString = infoString
        self.cancelPressed = cancelPressed
        self.donePressed = donePressed
        self.doneLongPressed = doneLongPressed
        self.tabPressed = tabPressed
    }

    static func ==(lhs: MediaPickerPhotoToolbarComponent, rhs: MediaPickerPhotoToolbarComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.solidBackground != rhs.solidBackground {
            return false
        }
        if lhs.backButtonType != rhs.backButtonType {
            return false
        }
        if lhs.doneButtonType != rhs.doneButtonType {
            return false
        }
        if lhs.currentTabs != rhs.currentTabs {
            return false
        }
        if lhs.activeTab != rhs.activeTab {
            return false
        }
        if lhs.highlightedTabs != rhs.highlightedTabs {
            return false
        }
        if lhs.disabledTabs != rhs.disabledTabs {
            return false
        }
        if lhs.qualityIsPhoto != rhs.qualityIsPhoto {
            return false
        }
        if lhs.qualityHighQuality != rhs.qualityHighQuality {
            return false
        }
        if lhs.qualityPreset != rhs.qualityPreset {
            return false
        }
        if lhs.timerValue != rhs.timerValue {
            return false
        }
        if lhs.hasSendStarsButton != rhs.hasSendStarsButton {
            return false
        }
        if lhs.sendPaidMessageStars != rhs.sendPaidMessageStars {
            return false
        }
        if lhs.editButtonsHidden != rhs.editButtonsHidden {
            return false
        }
        if lhs.editButtonsEnabled != rhs.editButtonsEnabled {
            return false
        }
        if lhs.centerButtonsHidden != rhs.centerButtonsHidden {
            return false
        }
        if lhs.allButtonsHidden != rhs.allButtonsHidden {
            return false
        }
        if lhs.cancelDoneButtonsHidden != rhs.cancelDoneButtonsHidden {
            return false
        }
        if lhs.doneButtonEnabled != rhs.doneButtonEnabled {
            return false
        }
        if lhs.interfaceOrientation != rhs.interfaceOrientation {
            return false
        }
        if lhs.bottomInset != rhs.bottomInset {
            return false
        }
        if lhs.infoString != rhs.infoString {
            return false
        }
        return true
    }

    final class View: UIView {
        fileprivate let cancelButton = ComponentView<Empty>()
        fileprivate let doneButton = ComponentView<Empty>()
        private let doneButtonContextView = ContextControllerSourceView()

        private let buttonsBackgroundView = GlassBackgroundView()
        private let selectionView = UIView()
        private let infoLabel = UILabel()
        private let imageCache = MediaPickerPhotoToolbarImageCache()
        private var centerButtonViews: [UInt: ComponentView<Empty>] = [:]

        private var component: MediaPickerPhotoToolbarComponent?
        private var cancelPressed: (() -> Void)?
        private var donePressed: (() -> Void)?
        private var doneLongPressed: ((Any?) -> Void)?
        private var tabPressed: ((TGPhotoEditorTab) -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.clipsToBounds = false
            self.addSubview(self.buttonsBackgroundView)

            self.selectionView.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.15)
            self.selectionView.isUserInteractionEnabled = false
            self.selectionView.alpha = 0.0

            self.infoLabel.backgroundColor = .clear
            self.infoLabel.textAlignment = .center
            self.infoLabel.textColor = .white
            self.infoLabel.font = Font.regular(13.0)
            self.infoLabel.isUserInteractionEnabled = false
            self.addSubview(self.infoLabel)

            self.doneButtonContextView.beginDelay = 0.4
            self.doneButtonContextView.activated = { [weak self] gesture, _ in
                guard let self else {
                    gesture.cancel()
                    return
                }
                self.doneLongPressed?(self.doneButtonContextView)
            }
            self.doneButtonContextView.shouldBegin = { [weak self] _ in
                guard let self, let component = self.component else {
                    return false
                }
                return self.doneLongPressed != nil && component.doneButtonEnabled && !component.cancelDoneButtonsHidden && !component.allButtonsHidden
            }
        }

        required init?(coder: NSCoder) {
            preconditionFailure()
        }

        fileprivate var cancelButtonFrame: CGRect {
            return self.cancelButton.view?.frame ?? .zero
        }

        fileprivate var doneButtonFrame: CGRect {
            return self.doneButtonContextView.frame
        }

        fileprivate var doneButtonSourceView: UIView {
            return self.doneButtonContextView
        }

        fileprivate func viewForTab(_ tab: TGPhotoEditorTab) -> UIView? {
            return self.centerButtonViews[tab.rawValue]?.view
        }

        func update(component: MediaPickerPhotoToolbarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.cancelPressed = component.cancelPressed
            self.donePressed = component.donePressed
            self.doneLongPressed = component.doneLongPressed
            self.tabPressed = component.tabPressed

            //let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let accentColor = UIColor(rgb: 0xffd300) //presentationData.theme.list.itemAccentColor
            let selectedIconColor = UIColor.white //(rgb: 0xffd300)

            self.backgroundColor = .clear //component.solidBackground ? UIColor(rgb: 0x000000, alpha: 0.55) : .clear

            let cancelSize = self.cancelButton.update(
                transition: transition,
                component: AnyComponent(
                    GlassBarButtonComponent(
                        size: CGSize(width: toolbarButtonSide, height: toolbarButtonSide),
                        backgroundColor: nil,
                        isDark: true,
                        state: .glass,
                        isEnabled: !component.cancelDoneButtonsHidden && !component.allButtonsHidden,
                        isVisible: true,
                        component: AnyComponentWithIdentity(
                            id: "close",
                            component: AnyComponent(
                                BundleIconComponent(
                                    name: component.backButtonType == TGPhotoEditorBackButtonBack ? "Navigation/Back" : "Navigation/Close",
                                    tintColor: .white
                                )
                            )
                        ),
                        action: { [weak self] _ in
                            self?.cancelPressed?()
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: toolbarButtonSide, height: toolbarButtonSide)
            )

            let doneIconName: String
            let doneBackgroundColor: UIColor? = UIColor(rgb: 0x0088ff)
            var doneWidth: CGFloat = toolbarButtonSide
            switch component.doneButtonType {
            case TGPhotoEditorDoneButtonSend:
                doneIconName = "Media Editor/Send"
                doneWidth = 46.0
            case TGPhotoEditorDoneButtonSchedule:
                doneIconName = "Chat/Input/ScheduleIcon"
                doneWidth = 46.0
            case TGPhotoEditorDoneButtonDone:
                doneIconName = "Navigation/Done"
            default:
                doneIconName = "Navigation/Done"
            }
            
            let doneSize = self.doneButton.update(
                transition: transition,
                component: AnyComponent(
                    GlassBarButtonComponent(
                        size: CGSize(width: doneWidth, height: toolbarButtonSide),
                        backgroundColor: doneBackgroundColor,
                        isDark: true,
                        state: doneBackgroundColor != nil ? .tintedGlass : .glass,
                        isEnabled: component.doneButtonEnabled && !component.cancelDoneButtonsHidden && !component.allButtonsHidden,
                        isVisible: true,
                        component: AnyComponentWithIdentity(
                            id: "done",
                            component: AnyComponent(
                                BundleIconComponent(
                                    name: doneIconName,
                                    tintColor: .white
                                )
                            )
                        ),
                        action: { [weak self] _ in
                            self?.donePressed?()
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: doneWidth, height: toolbarButtonSide)
            )
            
//            let doneContent: AnyComponentWithIdentity<Empty>
//            let doneFixedSize: CGSize?
//            let doneAvailableSize: CGSize
//            if component.hasSendStarsButton {
//                let text = "\u{2b50}\u{fe0f} \(component.sendPaidMessageStars)"
//                doneContent = AnyComponentWithIdentity(
//                    id: "stars-\(component.sendPaidMessageStars)",
//                    component: AnyComponent(Text(text: text, font: Font.with(size: 17.0, design: .round, weight: .semibold, traits: .monospacedNumbers), color: .white))
//                )
//                doneFixedSize = nil
//                doneAvailableSize = CGSize(width: 180.0, height: toolbarSideButtonSide)
//            } else {
//                doneContent = self.sideButtonContent(iconName: self.doneIconName(component.doneButtonType), color: .white, id: "done-\(component.doneButtonType.rawValue)")
//                doneFixedSize = CGSize(width: toolbarSideButtonSide, height: toolbarSideButtonSide)
//                doneAvailableSize = CGSize(width: toolbarSideButtonSide, height: toolbarSideButtonSide)
//            }
//            let doneSize = self.doneButton.update(
//                content: doneContent,
//                fixedSize: doneFixedSize,
//                availableSize: doneAvailableSize,
//                isEnabled: component.doneButtonEnabled && !component.cancelDoneButtonsHidden && !component.allButtonsHidden,
//                transition: transition
//            )

            let sideAlpha = component.allButtonsHidden ? 0.0 : 1.0
            let sideFrames = self.sideButtonFrames(availableSize: availableSize, cancelSize: cancelSize, doneSize: doneSize, component: component)
            if let cancelButtonView = self.cancelButton.view {
                if cancelButtonView.superview == nil {
                    self.addSubview(cancelButtonView)
                }
                transition.setAlpha(view: cancelButtonView, alpha: sideAlpha)
                transition.setFrame(view: cancelButtonView, frame: sideFrames.cancel)
            }
            if let doneButtonView = self.doneButton.view {
                if self.doneButtonContextView.superview == nil {
                    self.addSubview(self.doneButtonContextView)
                }
                if doneButtonView.superview !== self.doneButtonContextView {
                    self.doneButtonContextView.addSubview(doneButtonView)
                }
                self.doneButtonContextView.targetViewForActivationProgress = doneButtonView
                self.doneButtonContextView.isGestureEnabled = component.doneLongPressed != nil && component.doneButtonEnabled && !component.cancelDoneButtonsHidden && !component.allButtonsHidden
                transition.setAlpha(view: self.doneButtonContextView, alpha: sideAlpha * (component.doneButtonEnabled ? 1.0 : 0.2))
                transition.setFrame(view: self.doneButtonContextView, frame: sideFrames.done)
                transition.setFrame(view: doneButtonView, frame: CGRect(origin: .zero, size: sideFrames.done.size))
            }

            self.updateCenterButtons(
                component: component,
                availableSize: availableSize,
                doneSize: doneSize,
                selectedIconColor: selectedIconColor,
                accentColor: accentColor,
                transition: transition
            )

            self.updateInfoLabel(component: component, availableSize: availableSize, transition: transition)

            return availableSize
        }

        private func doneIconName(_ type: TGPhotoEditorDoneButton) -> String {
            switch type.rawValue {
            case 1:
                return "Editor/Commit"
            case 2:
                return "Editor/Commit"
            case 3:
                return "PhotoPickerSendIcon"
            default:
                return "PhotoPickerSendIcon"
            }
        }

        private func sideButtonFrames(availableSize: CGSize, cancelSize: CGSize, doneSize: CGSize, component: MediaPickerPhotoToolbarComponent) -> (cancel: CGRect, done: CGRect) {
            let sideInset: CGFloat = 26.0
            if availableSize.width > availableSize.height {
                let cancelFrame = CGRect(origin: CGPoint(x: sideInset, y: 0.0), size: cancelSize)
                let doneFrame: CGRect
                if component.hasSendStarsButton {
                    doneFrame = CGRect(x: availableSize.width - doneSize.width - 2.0, y: 0.0, width: doneSize.width, height: doneSize.height)
                } else {
                    doneFrame = CGRect(x: availableSize.width - doneSize.width - sideInset, y: 0.0, width: doneSize.width, height: doneSize.height)
                }
                return (cancelFrame, doneFrame)
            } else {
                let offset: CGFloat = component.interfaceOrientation == .landscapeLeft ? availableSize.width - toolbarSideButtonSide : 0.0
                let cancelFrame = CGRect(x: offset, y: availableSize.height - toolbarSideButtonSide, width: toolbarSideButtonSide, height: toolbarSideButtonSide)
                let doneFrame = CGRect(x: offset, y: 0.0, width: toolbarSideButtonSide, height: toolbarSideButtonSide)
                return (cancelFrame, doneFrame)
            }
        }

        private func updateCenterButtons(component: MediaPickerPhotoToolbarComponent, availableSize: CGSize, doneSize: CGSize, selectedIconColor: UIColor, accentColor: UIColor, transition: ComponentTransition) {
            let tabs = toolbarTabOrder.filter { component.currentTabs.contains($0) }
            let visibleRawValues = Set(tabs.map { $0.rawValue })

            for (rawValue, buttonView) in Array(self.centerButtonViews) {
                if !visibleRawValues.contains(rawValue) {
                    if let view = buttonView.view {
                        transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                            view.removeFromSuperview()
                        })
                    }
                    self.centerButtonViews.removeValue(forKey: rawValue)
                }
            }

            guard !tabs.isEmpty else {
                transition.setAlpha(view: self.buttonsBackgroundView, alpha: 0.0)
                transition.setAlpha(view: self.selectionView, alpha: 0.0)
                self.buttonsBackgroundView.isUserInteractionEnabled = false
                return
            }

            let buttonFrames = self.centerButtonFrames(tabs: tabs, availableSize: availableSize, doneSize: doneSize, component: component)
            var backgroundFrame = CGRect.null
            for tab in tabs {
                if let frame = buttonFrames[tab.rawValue] {
                    backgroundFrame = backgroundFrame.union(frame)
                }
            }
            if backgroundFrame.isNull {
                transition.setAlpha(view: self.buttonsBackgroundView, alpha: 0.0)
                transition.setAlpha(view: self.selectionView, alpha: 0.0)
                self.buttonsBackgroundView.isUserInteractionEnabled = false
                return
            }
            backgroundFrame = CGRect(
                x: floorToScreenPixels(backgroundFrame.minX),
                y: floorToScreenPixels(backgroundFrame.minY),
                width: ceil(backgroundFrame.width),
                height: ceil(backgroundFrame.height)
            )

            let centerHidden = component.allButtonsHidden || component.centerButtonsHidden || component.editButtonsHidden
            let centerAlpha: CGFloat = centerHidden ? 0.0 : (component.editButtonsEnabled ? 1.0 : 0.2)
            self.buttonsBackgroundView.isUserInteractionEnabled = !centerHidden && component.editButtonsEnabled
            transition.setAlpha(view: self.buttonsBackgroundView, alpha: centerAlpha)
            transition.setFrame(view: self.buttonsBackgroundView, frame: backgroundFrame)
            
            let minSide = min(backgroundFrame.width, backgroundFrame.height)
            self.buttonsBackgroundView.update(size: backgroundFrame.size, cornerRadius: minSide * 0.5, isDark: true, tintColor: .init(kind: .panel), isInteractive: true, isVisible: !centerHidden, transition: transition)

            if self.selectionView.superview == nil {
                self.buttonsBackgroundView.contentView.insertSubview(self.selectionView, at: 0)
            } else {
                self.buttonsBackgroundView.contentView.sendSubviewToBack(self.selectionView)
            }

            var selectionFrame: CGRect?

            for tab in tabs {
                guard let buttonFrame = buttonFrames[tab.rawValue] else {
                    continue
                }

                let rawValue = tab.rawValue
                let buttonView: ComponentView<Empty>
                if let current = self.centerButtonViews[rawValue] {
                    buttonView = current
                } else {
                    buttonView = ComponentView<Empty>()
                    self.centerButtonViews[rawValue] = buttonView
                }

                let isDisabled = component.disabledTabs.contains(tab)
                let isHighlighted = component.highlightedTabs.contains(tab)
                let selectedVisual = component.activeTab == tab && !dontHighlightOnSelectionTabs.contains(rawValue)
                let iconColor: UIColor
                if selectedVisual {
                    iconColor = selectedIconColor
                } else if isHighlighted && !isDisabled {
                    iconColor = accentColor
                } else {
                    iconColor = .white
                }

                let content: AnyComponent<Empty>
                switch tab {
                case .qualityTab:
                    content = AnyComponent(
                        Image(
                            image: self.imageCache.qualityIcon(
                                isPhoto: component.qualityIsPhoto,
                                highQuality: component.qualityHighQuality,
                                preset: component.qualityPreset,
                                color: iconColor
                            ),
                            size: CGSize(width: 28.0, height: 22.0),
                            contentMode: .center
                        )
                    )
                case .timerTab:
                    content = AnyComponent(
                        Image(
                            image: self.imageCache.timerIcon(value: component.timerValue, color: iconColor),
                            size: CGSize(width: 24.0, height: 24.0),
                            contentMode: .center
                        )
                    )
                default:
                    content = AnyComponent(
                        BundleIconComponent(
                            name: self.iconName(tab),
                            tintColor: iconColor,
                            maxSize: CGSize(width: 28.0, height: 28.0)
                        )
                    )
                }
                let buttonSize = buttonView.update(
                    transition: transition,
                    component: AnyComponent(
                        PlainButtonComponent(
                            content: content,
                            minSize: CGSize(width: toolbarButtonSide, height: toolbarButtonSide),
                            action: { [weak self] in
                                self?.tabPressed?(tab)
                            },
                            isEnabled: component.editButtonsEnabled && !isDisabled,
                            animateAlpha: true,
                            animateScale: false,
                            animateContents: false
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: toolbarButtonSide, height: toolbarButtonSide)
                )

                if let view = buttonView.view {
                    if view.superview == nil {
                        self.buttonsBackgroundView.contentView.addSubview(view)
                    }
                    let localFrame = CGRect(
                        x: buttonFrame.minX - backgroundFrame.minX,
                        y: buttonFrame.minY - backgroundFrame.minY,
                        width: buttonSize.width,
                        height: buttonSize.height
                    )
                    if selectedVisual {
                        let selectionSide = max(0.0, min(backgroundFrame.width, backgroundFrame.height) - 6.0)
                        selectionFrame = CGRect(
                            x: floorToScreenPixels(localFrame.midX - selectionSide / 2.0),
                            y: floorToScreenPixels(localFrame.midY - selectionSide / 2.0),
                            width: selectionSide,
                            height: selectionSide
                        )
                    }
                    transition.setFrame(view: view, frame: localFrame)
                    transition.setAlpha(view: view, alpha: isDisabled ? 0.2 : 1.0)
                }
            }

            if let selectionFrame = selectionFrame {
                self.selectionView.layer.cornerRadius = selectionFrame.width * 0.5
                transition.setFrame(view: self.selectionView, frame: selectionFrame)
                transition.setAlpha(view: self.selectionView, alpha: centerHidden ? 0.0 : 1.0)
            } else {
                transition.setAlpha(view: self.selectionView, alpha: 0.0)
            }
        }

        private func iconName(_ tab: TGPhotoEditorTab) -> String {
            switch tab {
            case .cropTab:
                return "Media Editor/Crop"
            case .toolsTab:
                return "Media Editor/Adjustments"
            case .rotateTab:
                return "Editor/Rotate"
            case .paintTab:
                return "Media Editor/Pencil"
            case .stickerTab:
                return "Media Editor/AddSticker"
            case .textTab:
                return "Media Editor/AddText"
            case .eraserTab:
                return "Editor/Eraser"
            case .mirrorTab:
                return "Media Editor/Mirror"
            case .aspectRatioTab:
                return "Editor/AspectRatio"
            case .tintTab:
                return "Media Editor/Tint"
            case .blurTab:
                return "Media Editor/Blur"
            case .curvesTab:
                return "Media Editor/Curves"
            default:
                return "Media Editor/Crop"
            }
        }

        private func centerButtonFrames(tabs: [TGPhotoEditorTab], availableSize: CGSize, doneSize: CGSize, component: MediaPickerPhotoToolbarComponent) -> [UInt: CGRect] {
            var result: [UInt: CGRect] = [:]
            let count = tabs.count
            guard count != 0 else {
                return result
            }

            let totalLength = CGFloat(count) * toolbarButtonSide + CGFloat(count - 1) * centerButtonSpacing
            let step = toolbarButtonSide + centerButtonSpacing

            if availableSize.width > availableSize.height {
                let leftEdge = toolbarSideButtonSide
                let rightEdge: CGFloat = component.hasSendStarsButton ? doneSize.width + 2.0 : toolbarSideButtonSide
                let availableWidth = availableSize.width - leftEdge - rightEdge
                let startX = floorToScreenPixels(leftEdge + (availableWidth - totalLength) / 2.0)

                for i in 0 ..< count {
                    result[tabs[i].rawValue] = CGRect(
                        x: startX + CGFloat(i) * step,
                        y: 0.0,
                        width: toolbarButtonSide,
                        height: toolbarButtonSide
                    )
                }
            } else {
                let x: CGFloat
                if component.interfaceOrientation == .landscapeLeft {
                    x = availableSize.width - toolbarButtonSide - 8.0
                } else {
                    x = 8.0
                }

                let topInset = toolbarSideButtonSide
                let bottomInset = toolbarSideButtonSide
                let availableHeight = availableSize.height - topInset - bottomInset
                let startY = floorToScreenPixels(topInset + (availableHeight - totalLength) / 2.0)

                for i in 0 ..< count {
                    result[tabs[i].rawValue] = CGRect(
                        x: x,
                        y: startY + CGFloat(i) * step,
                        width: toolbarButtonSide,
                        height: toolbarButtonSide
                    )
                }
            }

            return result
        }

        private func updateInfoLabel(component: MediaPickerPhotoToolbarComponent, availableSize: CGSize, transition: ComponentTransition) {
            self.infoLabel.text = component.infoString
            self.infoLabel.isHidden = component.infoString == nil
            guard component.infoString != nil else {
                return
            }

            if availableSize.width > availableSize.height {
                self.infoLabel.transform = .identity
                transition.setFrame(view: self.infoLabel, frame: CGRect(x: toolbarSideButtonSide + 10.0, y: 0.0, width: availableSize.width - (toolbarSideButtonSide + 10.0) * 2.0, height: toolbarSideButtonSide))
            } else {
                let bounds = CGRect(x: 0.0, y: 0.0, width: availableSize.height - (toolbarSideButtonSide + 10.0) * 2.0, height: availableSize.width)
                self.infoLabel.bounds = bounds
                self.infoLabel.center = CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0)
                if component.interfaceOrientation == .landscapeLeft {
                    self.infoLabel.transform = CGAffineTransform(rotationAngle: .pi / 2.0)
                } else if component.interfaceOrientation == .landscapeRight {
                    self.infoLabel.transform = CGAffineTransform(rotationAngle: -.pi / 2.0)
                } else {
                    self.infoLabel.transform = .identity
                }
            }
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public func makeMediaPickerPhotoToolbarView(context: AccountContext, backButton: TGPhotoEditorBackButton, doneButton: TGPhotoEditorDoneButton, solidBackground: Bool, hasSendStarsButton: Bool) -> (UIView & TGPhotoToolbarViewProtocol)? {
    return MediaPickerPhotoToolbarView(context: context, backButton: backButton, doneButton: doneButton, solidBackground: solidBackground, hasSendStarsButton: hasSendStarsButton)
}

final class MediaPickerPhotoToolbarView: UIView, TGPhotoToolbarViewProtocol {
    private let context: AccountContext
    private let solidBackground: Bool
    private let hasSendStarsButton: Bool
    private let rootView = ComponentView<Empty>()

    private var transitionedOut = false

    var cancelPressed: (() -> Void)? {
        didSet {
            self.update(transition: .immediate)
        }
    }
    var donePressed: (() -> Void)? {
        didSet {
            self.update(transition: .immediate)
        }
    }
    var doneLongPressed: ((Any?) -> Void)? {
        didSet {
            self.update(transition: .immediate)
        }
    }
    var tabPressed: ((TGPhotoEditorTab) -> Void)? {
        didSet {
            self.update(transition: .immediate)
        }
    }

    var interfaceOrientation: UIInterfaceOrientation = .portrait {
        didSet {
            self.update(transition: .immediate)
        }
    }
    
    var bottomInset: CGFloat = 0.0
    
    var backButtonType: TGPhotoEditorBackButton {
        didSet {
            self.update(transition: .immediate)
        }
    }

    var doneButtonType: TGPhotoEditorDoneButton {
        didSet {
            self.update(transition: .immediate)
        }
    }

    var sendPaidMessageStars: Int64 = 0 {
        didSet {
            self.update(transition: ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut)))
        }
    }

    private(set) var currentTabs: TGPhotoEditorTab = []
    private var activeTab: TGPhotoEditorTab = []
    private var highlightedTabs: TGPhotoEditorTab = []
    private var disabledTabs: TGPhotoEditorTab = []
    private var editButtonsHidden = false
    private var editButtonsEnabled = true
    private var centerButtonsHidden = false
    private var allButtonsHidden = false
    private var cancelDoneButtonsHidden = false
    private var doneButtonEnabled = true
    private var qualityIsPhoto = false
    private var qualityHighQuality = false
    private var qualityPreset = 3
    private var timerValue = 0
    private var infoString: String?

    var doneButton: UIView {
        return (self.rootView.view as? MediaPickerPhotoToolbarComponent.View)?.doneButtonSourceView ?? UIView()
    }

    var cancelButtonFrame: CGRect {
        return (self.rootView.view as? MediaPickerPhotoToolbarComponent.View)?.cancelButtonFrame ?? .zero
    }

    var doneButtonFrame: CGRect {
        return (self.rootView.view as? MediaPickerPhotoToolbarComponent.View)?.doneButtonFrame ?? .zero
    }

    init(context: AccountContext, backButton: TGPhotoEditorBackButton, doneButton: TGPhotoEditorDoneButton, solidBackground: Bool, hasSendStarsButton: Bool) {
        self.context = context
        self.backButtonType = backButton
        self.doneButtonType = doneButton
        self.solidBackground = solidBackground
        self.hasSendStarsButton = hasSendStarsButton

        super.init(frame: .zero)

        self.clipsToBounds = false
        self.backgroundColor = .clear
        self.update(transition: .immediate)
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.update(transition: .immediate)
        self.updateRootFrame(transition: .immediate)
    }

    func transitionIn(animated: Bool) {
        self.transitionIn(animated: animated, transparent: false)
    }

    func transitionIn(animated: Bool, transparent: Bool) {
        self.transitionedOut = false
        self.isHidden = false
        if !transparent {
            self.backgroundColor = UIColor(rgb: 0x000000)
        }

        let transition = animated ? ComponentTransition(animation: .curve(duration: 0.3, curve: .easeInOut)) : .immediate
        self.updateRootFrame(transition: transition)

        if !transparent {
            self.backgroundColor = .clear
        }
    }

    func transitionOut(animated: Bool) {
        self.transitionOut(animated: animated, transparent: false, hideOnCompletion: false)
    }

    func transitionOut(animated: Bool, transparent: Bool, hideOnCompletion: Bool) {
        self.transitionedOut = true
        if !transparent {
            self.backgroundColor = UIColor(rgb: 0x000000)
        }

        let duration: Double = animated ? 0.3 : 0.0
        let transition = animated ? ComponentTransition(animation: .curve(duration: duration, curve: .easeInOut)) : .immediate
        self.updateRootFrame(transition: transition)

        if hideOnCompletion {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.isHidden = true
            }
        }
    }

    func setDoneButtonEnabled(_ enabled: Bool, animated: Bool) {
        self.doneButtonEnabled = enabled
        self.update(transition: self.transition(animated: animated))
    }

    func setEditButtonsEnabled(_ enabled: Bool, animated: Bool) {
        self.editButtonsEnabled = enabled
        self.update(transition: self.transition(animated: animated))
    }

    func setEditButtonsHidden(_ hidden: Bool, animated: Bool) {
        self.editButtonsHidden = hidden
        self.update(transition: self.transition(animated: animated))
    }

    func setEditButtonsHighlighted(_ buttons: TGPhotoEditorTab) {
        self.highlightedTabs = buttons
        self.update(transition: .immediate)
    }

    func setEditButtonsDisabled(_ buttons: TGPhotoEditorTab) {
        self.disabledTabs = buttons
        self.update(transition: .immediate)
    }

    func setCenterButtonsHidden(_ hidden: Bool, animated: Bool) {
        self.centerButtonsHidden = hidden
        self.update(transition: self.transition(animated: animated))
    }

    func setAllButtonsHidden(_ hidden: Bool, animated: Bool) {
        self.allButtonsHidden = hidden
        self.update(transition: self.transition(animated: animated))
    }

    func setCancelDoneButtonsHidden(_ hidden: Bool, animated: Bool) {
        self.cancelDoneButtonsHidden = hidden
        self.update(transition: self.transition(animated: animated))
    }

    func setToolbarTabs(_ tabs: TGPhotoEditorTab, animated: Bool) {
        self.currentTabs = tabs
        self.update(transition: self.transition(animated: animated))
    }

    func setActiveTab(_ tab: TGPhotoEditorTab) {
        self.activeTab = tab
        self.update(transition: .spring(duration: 0.4))
    }

    func setQualityButtonIsPhoto(_ isPhoto: Bool, highQuality: Bool, videoPreset: Int) {
        self.qualityIsPhoto = isPhoto
        self.qualityHighQuality = highQuality
        self.qualityPreset = videoPreset
        self.update(transition: .immediate)
    }

    func setTimerButtonValue(_ value: Int) {
        self.timerValue = value
        self.update(transition: .immediate)
    }

    func setInfoString(_ string: String?) {
        self.infoString = string
        self.update(transition: .immediate)
    }

    @objc(viewForTab:)
    func view(for tab: TGPhotoEditorTab) -> UIView? {
        return (self.rootView.view as? MediaPickerPhotoToolbarComponent.View)?.viewForTab(tab)
    }

    private func transition(animated: Bool) -> ComponentTransition {
        if animated {
            return ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut))
        } else {
            return .immediate
        }
    }

    private func update(transition: ComponentTransition) {
        let size = self.bounds.size
        let _ = self.rootView.update(
            transition: transition,
            component: AnyComponent(
                MediaPickerPhotoToolbarComponent(
                    context: self.context,
                    solidBackground: self.solidBackground,
                    backButtonType: self.backButtonType,
                    doneButtonType: self.doneButtonType,
                    currentTabs: self.currentTabs,
                    activeTab: self.activeTab,
                    highlightedTabs: self.highlightedTabs,
                    disabledTabs: self.disabledTabs,
                    qualityIsPhoto: self.qualityIsPhoto,
                    qualityHighQuality: self.qualityHighQuality,
                    qualityPreset: self.qualityPreset,
                    timerValue: self.timerValue,
                    hasSendStarsButton: self.hasSendStarsButton,
                    sendPaidMessageStars: self.sendPaidMessageStars,
                    editButtonsHidden: self.editButtonsHidden,
                    editButtonsEnabled: self.editButtonsEnabled,
                    centerButtonsHidden: self.centerButtonsHidden,
                    allButtonsHidden: self.allButtonsHidden,
                    cancelDoneButtonsHidden: self.cancelDoneButtonsHidden,
                    doneButtonEnabled: self.doneButtonEnabled,
                    interfaceOrientation: self.interfaceOrientation,
                    bottomInset: self.bottomInset,
                    infoString: self.infoString,
                    cancelPressed: self.cancelPressed,
                    donePressed: self.donePressed,
                    doneLongPressed: self.doneLongPressed,
                    tabPressed: self.tabPressed
                )
            ),
            environment: {},
            forceUpdate: true,
            containerSize: size
        )

        if let view = self.rootView.view {
            if view.superview == nil {
                self.addSubview(view)
            }
            self.updateRootFrame(transition: transition)
        }
    }

    private func updateRootFrame(transition: ComponentTransition) {
        guard let view = self.rootView.view else {
            return
        }

        var frame = CGRect(origin: .zero, size: self.bounds.size)
        if self.transitionedOut {
            if self.bounds.width > self.bounds.height {
                frame.origin.y = self.bounds.height
            } else if self.interfaceOrientation == .landscapeLeft {
                frame.origin.x = -self.bounds.width
            } else {
                frame.origin.x = self.bounds.width
            }
        }
        transition.setFrame(view: view, frame: frame)
    }
}
