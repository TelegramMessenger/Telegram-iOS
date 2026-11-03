import Foundation
import UIKit
import Display
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import CompanionRenderer
import MetalEngine
import ComponentFlow
import ViewControllerComponent
import ComponentDisplayAdapters
import WallpaperBackgroundNode
import GlassBackgroundComponent
import GlassBarButtonComponent
import BundleIconComponent
import ListSectionComponent
import ListActionItemComponent
import MultilineTextComponent
import ButtonComponent
import UndoUI
import ContextUI

private final class CompanionOptionsContentSource: ContextReferenceContentSource {
    private let sourceView: UIView

    init(sourceView: UIView) { self.sourceView = sourceView }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(
            referenceView: self.sourceView,
            contentAreaInScreenSpace: mainWindowScreenBounds,
            actionsPosition: .bottom
        )
    }
}

private struct CompanionPreset {
    let id: String
    let title: String
    let files: [String]

    static let all: [CompanionPreset] = CompanionRenderer.presets().compactMap { row in
        guard let id = row["id"] as? String, let title = row["title"] as? String, let files = row["files"] as? [String] else { return nil }
        return CompanionPreset(id: id, title: title, files: files)
    }
}

private final class CompanionDisplayLinkTarget: NSObject {
    weak var view: DebugCompanionScreenComponent.View?
    @objc func tick(_ link: CADisplayLink) { self.view?.tick(link) }
}

private final class DebugCompanionScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    let context: AccountContext

    init(context: AccountContext) { self.context = context }
    static func ==(lhs: DebugCompanionScreenComponent, rhs: DebugCompanionScreenComponent) -> Bool { lhs.context === rhs.context }

    final class View: UIView {
        private var context: AccountContext!
        private var catalog: CompanionCatalog?
        private var wallpaper: WallpaperBackgroundNode?
        private let characterContainer = UIView()
        private let character = CompanionLayer()
        private let panel = GlassBackgroundView()
        private let scrollView = UIScrollView()
        private let presetsScrollView = UIScrollView()
        private var presetButtons: [String: ComponentView<Empty>] = [:]
        private var selectedPreset: String?
        private var loadingPreset: String?
        private var pendingPreset: CompanionPreset?
        private var sections: [String: ComponentView<Empty>] = [:]
        private let closeButton = ComponentView<Empty>()
        private let resetButton = ComponentView<Empty>()
        private let fetch = MetaDisposable()
        private let resourceData = MetaDisposable()
        private var presentationDisposable: Disposable?
        private var presentationData: PresentationData?
        private weak var errorOverlay: UndoOverlayController?
        private weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        private var options: [CompanionOption] = []
        private var rows: [[String: Any]] = []
        private var resourceNames: [String: String] = [:]
        private var loadingKey: String?
        private var generation = 0
        private var displayLink: CADisplayLink?
        private var previousTimestamp: CFTimeInterval = 0
        private var resourceDirectory: String?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.characterContainer)
            self.characterContainer.disablesInteractiveTransitionGestureRecognizer = true
            self.characterContainer.layer.addSublayer(self.character)
            self.characterContainer.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan(_:))))
            self.characterContainer.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:))))
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(resetCamera))
            doubleTap.numberOfTapsRequired = 2
            self.characterContainer.addGestureRecognizer(doubleTap)
            self.addSubview(self.panel)
            self.panel.contentView.addSubview(self.scrollView)
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.showsVerticalScrollIndicator = false
            self.presetsScrollView.showsHorizontalScrollIndicator = false
            self.presetsScrollView.alwaysBounceHorizontal = true
            self.presetsScrollView.contentInsetAdjustmentBehavior = .never
            self.panel.contentView.addSubview(self.presetsScrollView)
            NotificationCenter.default.addObserver(self, selector: #selector(applicationStateChanged), name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(applicationStateChanged), name: UIApplication.didBecomeActiveNotification, object: nil)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        deinit {
            self.displayLink?.invalidate()
            self.fetch.dispose()
            self.resourceData.dispose()
            self.presentationDisposable?.dispose()
            NotificationCenter.default.removeObserver(self)
        }

        private func setup(context: AccountContext) {
            self.context = context
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let wallpaper = createWallpaperBackgroundNode(context: context, forChatDisplay: true, useSharedAnimationPhase: false)
            wallpaper.view.isUserInteractionEnabled = false
            self.wallpaper = wallpaper
            self.insertSubview(wallpaper.view, at: 0)
            self.initializeRenderer()
            let catalog = CompanionCatalog(context: context)
            self.catalog = catalog
            catalog.updated = { [weak self] options, error in
                guard let self else { return }
                self.options = options
                if let pendingPreset = self.pendingPreset {
                    self.pendingPreset = nil
                    if let error {
                        self.cancelSelection()
                        self.showError(error, retry: { [weak self] in self?.selectPreset(pendingPreset) })
                    } else { self.selectPreset(pendingPreset) }
                } else if let error { self.showError(error, retry: { [weak self] in self?.catalog?.load() }) }
                self.state?.updated(transition: .immediate)
            }
            catalog.load()
            self.presentationDisposable = (context.sharedContext.presentationData |> deliverOnMainQueue).start(next: { [weak self] data in
                guard let self else { return }
                self.presentationData = data
                self.state?.updated(transition: .immediate)
            })
        }

        private func initializeRenderer() {
            do {
                let bundle = Bundle(for: CompanionRenderer.self)
                guard let path = bundle.path(forResource: "CompanionResources", ofType: "bundle"), let directory = Bundle(path: path)?.resourcePath else {
                    throw NSError(domain: "Companion", code: 1, userInfo: [NSLocalizedDescriptionKey: "Companion resources are missing."])
                }
                self.resourceDirectory = directory
                let renderer = try CompanionRenderer(device: MetalEngine.shared.device, resourceDirectory: directory)
                try renderer.loadDefault()
                self.character.renderer = renderer
                self.selectedPreset = "classic"
                self.refreshRows()
            } catch { self.showError(error.localizedDescription) }
        }

        fileprivate func updateVisibility(_ visible: Bool) {
            self.character.active = visible
            if visible && self.displayLink == nil {
                let target = CompanionDisplayLinkTarget()
                target.view = self
                let link = CADisplayLink(target: target, selector: #selector(CompanionDisplayLinkTarget.tick(_:)))
                link.add(to: .main, forMode: .common)
                self.displayLink = link
            } else if !visible {
                self.displayLink?.invalidate()
                self.displayLink = nil
                self.character.releaseSurface()
            }
            self.applicationStateChanged()
            if visible { self.character.setNeedsUpdate() }
        }

        @objc private func applicationStateChanged() {
            self.displayLink?.isPaused = UIApplication.shared.applicationState != .active
            self.previousTimestamp = 0
        }
        fileprivate func tick(_ link: CADisplayLink) {
            self.character.deltaTime = self.previousTimestamp == 0 ? 0 : Float(min(0.1, link.timestamp - self.previousTimestamp))
            self.previousTimestamp = link.timestamp
            self.character.setNeedsUpdate()
        }
        @objc private func pan(_ gesture: UIPanGestureRecognizer) {
            if gesture.state == .began {
                self.animateCharacterScale(to: 1.4, returning: false)
            }
            let offset = gesture.translation(in: self.characterContainer)
            gesture.setTranslation(.zero, in: self.characterContainer)
            self.character.renderer?.orbitX(Float(offset.x), y: Float(offset.y))
            if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
                self.character.renderer?.returnToInitialOrbit()
                self.animateCharacterScale(to: 1.0, returning: true)
            }
        }
        private func animateCharacterScale(to scale: CGFloat, returning: Bool) {
            let currentScale = (self.character.presentation() ?? self.character).transform.m11
            self.character.removeAnimation(forKey: "transform.scale")
            self.character.transform = CATransform3DMakeScale(scale, scale, 1.0)
            if returning {
                self.character.animateSpring(from: currentScale as NSNumber, to: scale as NSNumber, keyPath: "transform.scale", duration: 0.5, damping: 55.0)
            } else {
                self.character.animateScale(from: currentScale, to: scale, duration: 0.2)
            }
        }
        @objc private func pinch(_ gesture: UIPinchGestureRecognizer) {
            self.character.renderer?.zoom(by: Float(gesture.scale))
            gesture.scale = 1
        }
        @objc private func resetCamera() { self.character.renderer?.resetCamera() }
        private func reset() {
            self.cancelSelection()
            do {
                if self.character.renderer == nil { self.initializeRenderer() }
                else { try self.character.renderer?.loadDefault() }
                self.selectedPreset = "classic"
                self.refreshRows()
            } catch { self.showError(error.localizedDescription) }
        }
        private func refreshRows() {
            self.rows = self.character.renderer?.componentRows() as? [[String: Any]] ?? []
            self.state?.updated(transition: .immediate)
            self.character.setNeedsUpdate()
        }
        private func rowKey(_ row: [String: Any]) -> String { "\(row["kind"] ?? 0):\(row["socket"] ?? "")" }

        private func openOptions(_ row: [String: Any], sourceView: UIView) {
            guard let rawKind = row["kind"] as? Int, let kind = CompanionComponentKind(rawValue: rawKind),
                let controller = self.environment?.controller(), let presentationData = self.presentationData else { return }
            let socket = row["socket"] as? String ?? ""
            var items: [ContextMenuItem] = []
            if kind != .model {
                items.append(.action(ContextMenuActionItem(
                    text: kind == .item ? "None" : "Embedded / Default",
                    icon: { _ in nil },
                    action: { [weak self] _, dismiss in
                        dismiss(.default)
                        self?.cancelSelection()
                        self?.apply(url: nil, name: nil, kind: kind, socket: socket)
                    }
                )))
            }
            for option in self.options where option.matches(kind) && (kind != .item || option.socket == nil || option.socket == socket) {
                items.append(.action(ContextMenuActionItem(
                    text: option.title,
                    icon: { _ in nil },
                    action: { [weak self] _, dismiss in
                        dismiss(.default)
                        self?.select(option, kind: kind, socket: socket, key: self?.rowKey(row) ?? "")
                    }
                )))
            }
            if self.options.isEmpty {
                items.append(.action(ContextMenuActionItem(
                    text: "Retry",
                    icon: { _ in nil },
                    action: { [weak self] _, dismiss in
                        dismiss(.default)
                        self?.catalog?.load()
                    }
                )))
            }
            let menu = makeContextController(
                context: self.context,
                presentationData: presentationData,
                source: .reference(CompanionOptionsContentSource(sourceView: sourceView)),
                items: .single(ContextController.Items(content: .list(items)))
            )
            controller.presentInGlobalOverlay(menu)
        }
        private func cancelSelection() {
            self.generation += 1
            self.fetch.set(nil)
            self.resourceData.set(nil)
            self.loadingKey = nil
            self.loadingPreset = nil
            self.pendingPreset = nil
        }

        private func selectPreset(_ preset: CompanionPreset) {
            self.cancelSelection()
            self.loadingPreset = preset.id
            self.state?.updated(transition: .immediate)
            let isBundled = self.resourceDirectory.map { directory in
                preset.files.allSatisfy { FileManager.default.fileExists(atPath: URL(fileURLWithPath: directory).appendingPathComponent($0).path) }
            } ?? false
            if self.options.isEmpty && !isBundled {
                self.pendingPreset = preset
                self.catalog?.load()
                return
            }
            self.loadPreset(preset, index: 0, files: [:], generation: self.generation)
        }

        private func loadPreset(_ preset: CompanionPreset, index: Int, files: [String: URL], generation: Int) {
            guard self.generation == generation else { return }
            self.fetch.set(nil)
            self.resourceData.set(nil)
            if index == preset.files.count {
                do {
                    guard let renderer = self.character.renderer else {
                        self.cancelSelection()
                        self.state?.updated(transition: .immediate)
                        return
                    }
                    try renderer.applyPreset(preset.id, files: files)
                    for (name, url) in files { self.resourceNames[url.lastPathComponent] = name }
                    self.cancelSelection()
                    self.selectedPreset = preset.id
                    self.refreshRows()
                } catch { self.presetFailed(preset, error: error.localizedDescription) }
                return
            }
            let name = preset.files[index]
            let advance: (URL) -> Void = { [weak self] url in
                var files = files
                files[name] = url
                // Leave the signal callback before replacing its disposable.
                Queue.mainQueue().async { [weak self] in
                    self?.loadPreset(preset, index: index + 1, files: files, generation: generation)
                }
            }
            if let directory = self.resourceDirectory {
                let url = URL(fileURLWithPath: directory).appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: url.path) { advance(url); return }
            }
            guard let option = self.options.first(where: { $0.name == name }),
                let size = option.file.size, size > 0, size <= 32 * 1024 * 1024 else {
                self.presetFailed(preset, error: "Preset component is unavailable: \(name)")
                return
            }
            let mediaBox = self.context.account.postbox.mediaBox
            let reference = FileMediaReference.message(message: MessageReference(option.message), media: option.file)
            self.fetch.set((fetchedMediaResource(mediaBox: mediaBox, userLocation: .peer(option.message.id.peerId), userContentType: .file, reference: reference.resourceReference(option.file.resource))
            |> deliverOnMainQueue).start(error: { [weak self] _ in
                guard let self, self.generation == generation else { return }
                self.presetFailed(preset, error: "Could not download \(name).")
            }))
            guard self.generation == generation else { return }
            self.resourceData.set((mediaBox.resourceData(option.file.resource)
            |> filter { $0.complete }
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] data in
                guard let self, self.generation == generation else { return }
                advance(URL(fileURLWithPath: data.path))
            }))
        }

        private func presetFailed(_ preset: CompanionPreset, error: String) {
            self.cancelSelection()
            self.state?.updated(transition: .immediate)
            self.showError(error, retry: { [weak self] in self?.selectPreset(preset) })
        }

        private func select(_ option: CompanionOption, kind: CompanionComponentKind, socket: String, key: String) {
            self.cancelSelection()
            if let directory = self.resourceDirectory, ["catalog_classic.model.glb", "catalog_classic_wave.animation.glb", "catalog_classic.materials.glb", "catalog_classic.scene.glb"].contains(option.name) {
                self.apply(url: URL(fileURLWithPath: directory).appendingPathComponent(option.name), name: option.name, kind: kind, socket: socket)
                return
            }
            guard let size = option.file.size, size > 0, size <= 32 * 1024 * 1024 else {
                self.showError("The component must be a GLB smaller than 32 MB.")
                return
            }
            self.loadingKey = key
            self.state?.updated(transition: .immediate)
            let generation = self.generation
            let mediaBox = self.context.account.postbox.mediaBox
            let reference = FileMediaReference.message(message: MessageReference(option.message), media: option.file)
            self.fetch.set((fetchedMediaResource(mediaBox: mediaBox, userLocation: .peer(option.message.id.peerId), userContentType: .file, reference: reference.resourceReference(option.file.resource))
            |> deliverOnMainQueue).start(error: { [weak self] _ in
                guard let self, self.generation == generation else { return }
                self.cancelSelection()
                self.state?.updated(transition: .immediate)
                self.showError("Could not download \(option.name). Select it again to retry.")
            }))
            self.resourceData.set((mediaBox.resourceData(option.file.resource)
            |> filter { $0.complete }
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] data in
                guard let self, self.generation == generation else { return }
                self.cancelSelection()
                self.apply(url: URL(fileURLWithPath: data.path), name: option.name, kind: kind, socket: socket)
            }))
        }

        private func apply(url: URL?, name: String?, kind: CompanionComponentKind, socket: String) {
            do {
                guard let renderer = self.character.renderer else { return }
                try renderer.setComponentAt(url, kind: kind, socket: socket)
                self.selectedPreset = nil
                if let url, let name { self.resourceNames[url.lastPathComponent] = name }
                if kind == .model { renderer.resetCamera() }
                self.refreshRows()
                if !renderer.customizationNotice.isEmpty { self.showError(renderer.customizationNotice) }
            } catch {
                self.state?.updated(transition: .immediate)
                self.showError(error.localizedDescription)
            }
        }


        private func showError(_ text: String, retry: (() -> Void)? = nil) {
            guard self.window != nil, let controller = self.environment?.controller(), let presentationData = self.presentationData else { return }
            self.errorOverlay?.dismissWithCommitAction()
            let overlay = UndoOverlayController(
                presentationData: presentationData,
                content: .info(title: "Companion", text: text, timeout: 5.0, customUndoText: retry == nil ? nil : "Retry"),
                elevatedLayout: false,
                position: .bottom,
                animateInAsReplacement: false,
                action: { action in
                    if case .undo = action {
                        retry?()
                        return true
                    }
                    return false
                }
            )
            self.errorOverlay = overlay
            controller.present(overlay, in: .window(.root))
        }

        func update(component: DebugCompanionScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            self.environment = environment
            // Initial synchronous subscriptions must not re-enter component layout.
            if self.context == nil { self.setup(context: component.context) }
            self.state = state
            self.updateVisibility((environment.controller() as? DebugCompanionScreen)?.renderingVisible == true)
            let theme = environment.theme
            self.backgroundColor = theme.list.blocksBackgroundColor
            if let wallpaper = self.wallpaper, let presentationData = self.presentationData {
                wallpaper.update(wallpaper: presentationData.chatWallpaper, animated: false)
                transition.setFrame(view: wallpaper.view, frame: CGRect(origin: .zero, size: availableSize))
                wallpaper.updateLayout(size: availableSize, displayMode: .aspectFill, transition: transition.containedViewLayoutTransition)
            }

            let top = environment.statusBarHeight + 8.0
            let sideInset = max(12.0, environment.safeInsets.left + 12.0)
            let rightInset = max(12.0, environment.safeInsets.right + 12.0)
            let panelInset: CGFloat = 5.0
            let panelWidth = availableSize.width - panelInset * 2.0
            let panelHeight = min(availableSize.height * 0.40, max(150.0, availableSize.height - top - 160.0))
            let panelFrame = CGRect(x: floor((availableSize.width - panelWidth) * 0.5), y: availableSize.height - panelInset - panelHeight, width: panelWidth, height: panelHeight)
            self.panel.update(size: panelFrame.size, cornerRadii: .init(topLeft: 32.0, topRight: 32.0, bottomLeft: max(0.0, environment.screenCornerRadii.bottomLeft - panelInset), bottomRight: max(0.0, environment.screenCornerRadii.bottomRight - panelInset)), isDark: theme.overallDarkAppearance, tintColor: .init(kind: .panel), transition: transition)
            transition.setFrame(view: self.panel, frame: panelFrame)
            let settingsTop: CGFloat = 76.0
            transition.setFrame(view: self.scrollView, frame: CGRect(x: 0, y: settingsTop, width: panelWidth, height: max(0.0, panelHeight - settingsTop - max(12.0, environment.safeInsets.bottom - panelInset))))

            let previewTop = max(top + 44.0, environment.sideColumnNavigationButtonFrame?.maxY ?? 0.0)
            let previewHeight = max(1.0, panelFrame.minY - previewTop)
            transition.setFrame(view: self.characterContainer, frame: CGRect(x: 0, y: previewTop, width: availableSize.width, height: previewHeight))
            let characterSide = min(availableSize.width, previewHeight * 1.2)
            transition.setBounds(layer: self.character, bounds: CGRect(x: 0, y: 0, width: characterSide, height: characterSide))
            transition.setPosition(layer: self.character, position: CGPoint(x: availableSize.width * 0.5, y: previewHeight * 0.5))
            self.character.setNeedsUpdate()

            let closeSize = self.closeButton.update(transition: transition, component: AnyComponent(GlassBarButtonComponent(
                size: CGSize(width: 44, height: 44), backgroundColor: nil, isDark: theme.overallDarkAppearance, state: .glass,
                component: AnyComponentWithIdentity(id: "back", component: AnyComponent(BundleIconComponent(name: "Navigation/Back", tintColor: theme.list.itemPrimaryTextColor))),
                action: { [weak self] _ in
                    guard let controller = self?.environment?.controller() else { return }
                    if let navigationController = controller.navigationController as? NavigationController {
                        navigationController.filterController(controller, animated: true)
                    } else { controller.dismiss() }
                }
            )), environment: {}, containerSize: CGSize(width: 44, height: 44))
            if let view = self.closeButton.view {
                if view.superview == nil { self.addSubview(view) }
                transition.setFrame(view: view, frame: environment.sideColumnNavigationButtonFrame ?? CGRect(x: sideInset, y: top, width: closeSize.width, height: closeSize.height))
            }
            let resetSize = self.resetButton.update(transition: transition, component: AnyComponent(GlassBarButtonComponent(
                size: CGSize(width: 76, height: 44), backgroundColor: nil, isDark: theme.overallDarkAppearance, state: .glass,
                component: AnyComponentWithIdentity(id: "reset", component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "Reset", font: Font.semibold(17), textColor: theme.list.itemPrimaryTextColor))))),
                action: { [weak self] _ in self?.reset() }
            )), environment: {}, containerSize: CGSize(width: 76, height: 44))
            if let view = self.resetButton.view {
                if view.superview == nil { self.addSubview(view) }
                transition.setFrame(view: view, frame: CGRect(x: availableSize.width - rightInset - environment.navigationBarTrailingButtonsInset - resetSize.width, y: top, width: resetSize.width, height: resetSize.height))
            }

            var groups: [(String, [[String: Any]])] = []
            for row in self.rows {
                let kind = CompanionComponentKind(rawValue: row["kind"] as? Int ?? 0)
                let group: String
                switch kind {
                case .item, .itemMaterials, .itemAnimation: group = "Accessories"
                case .scene: group = "Scene"
                default: group = "Character"
                }
                if let index = groups.firstIndex(where: { $0.0 == group }) { groups[index].1.append(row) }
                else { groups.append((group, [row])) }
            }
            var validIds = Set<String>()
            transition.setFrame(view: self.presetsScrollView, frame: CGRect(x: 0, y: 16, width: panelWidth, height: 48))
            var presetX: CGFloat = 16
            for (index, preset) in CompanionPreset.all.enumerated() {
                let button = self.presetButtons[preset.id] ?? ComponentView<Empty>()
                self.presetButtons[preset.id] = button
                let selected = self.selectedPreset == preset.id
                let foreground = selected ? theme.list.itemCheckColors.foregroundColor : theme.list.itemPrimaryTextColor
                let size = button.update(transition: transition, component: AnyComponent(ButtonComponent(
                    background: .init(color: selected ? theme.list.itemAccentColor : theme.list.itemPrimaryTextColor.withAlphaComponent(0.08), foreground: foreground, pressedColor: theme.list.itemPrimaryTextColor.withAlphaComponent(0.15), cornerRadius: 22),
                    content: AnyComponentWithIdentity(id: "number", component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "\(index + 1)", font: Font.semibold(17), textColor: foreground))))),
                    displaysProgress: self.loadingPreset == preset.id,
                    action: { [weak self] in self?.selectPreset(preset) }
                )), environment: {}, containerSize: CGSize(width: 44, height: 44))
                if let view = button.view {
                    if view.superview == nil { self.presetsScrollView.addSubview(view) }
                    view.isAccessibilityElement = true
                    view.accessibilityLabel = "\(index + 1). \(preset.title)"
                    view.accessibilityTraits = selected ? [.button, .selected] : [.button]
                    transition.setFrame(view: view, frame: CGRect(x: presetX, y: 2, width: size.width, height: size.height))
                }
                presetX += size.width + 8
            }
            self.presetsScrollView.contentSize = CGSize(width: presetX + 8, height: 48)
            var contentY: CGFloat = 4
            for (group, rows) in groups {
                validIds.insert(group)
                let section = self.sections[group] ?? ComponentView<Empty>()
                self.sections[group] = section
                var items: [AnyComponentWithIdentity<Empty>] = []
                for row in rows {
                    let key = self.rowKey(row)
                    let value = row["value"] as? String ?? "Default"
                    let name = (self.resourceNames[value] ?? value).replacingOccurrences(of: "catalog_", with: "").components(separatedBy: ".").first!.replacingOccurrences(of: "_", with: " ").capitalized
                    let title = NSMutableAttributedString(string: row["title"] as? String ?? "", font: Font.regular(16), textColor: theme.list.itemPrimaryTextColor)
                    title.append(NSAttributedString(string: "\n" + (self.loadingKey == key ? "Loading…" : name), font: Font.regular(13), textColor: theme.list.itemSecondaryTextColor))
                    items.append(AnyComponentWithIdentity(id: key, component: AnyComponent(ListActionItemComponent(
                        theme: theme, style: .glass,
                        title: AnyComponent(MultilineTextComponent(text: .plain(title), maximumNumberOfLines: 2)),
                        accessory: self.loadingKey == key ? .activity : .arrow,
                        action: { [weak self] sourceView in self?.openOptions(row, sourceView: sourceView) }
                    ))))
                }
                let size = section.update(transition: transition, component: AnyComponent(ListSectionComponent(
                    theme: theme, style: .glass, background: .none(clipped: false),
                    header: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: group, font: Font.semibold(13), textColor: theme.list.itemSecondaryTextColor)))),
                    footer: nil, items: items
                )), environment: {}, containerSize: CGSize(width: panelWidth - 16, height: 10000))
                if let view = section.view {
                    if view.superview == nil { self.scrollView.addSubview(view) }
                    transition.setFrame(view: view, frame: CGRect(x: 8, y: contentY, width: size.width, height: size.height))
                }
                contentY += size.height + 16
            }
            for key in Array(self.sections.keys) where !validIds.contains(key) { self.sections.removeValue(forKey: key)?.view?.removeFromSuperview() }
            self.scrollView.contentSize = CGSize(width: panelWidth, height: contentY)
            let maxOffset = max(0, self.scrollView.contentSize.height - self.scrollView.bounds.height)
            if self.scrollView.contentOffset.y > maxOffset { self.scrollView.contentOffset.y = maxOffset }
            return availableSize
        }
    }

    func makeView() -> View { View(frame: .zero) }
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class DebugCompanionScreen: ViewControllerComponentContainer {
    fileprivate var renderingVisible = false

    public init(context: AccountContext, standalone: Bool = false) {
        super.init(context: context, component: DebugCompanionScreenComponent(context: context), navigationBarAppearance: .none)
    }
    required public init(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override public func viewWillAppear(_ animated: Bool) {
        self.renderingVisible = true
        super.viewWillAppear(animated)
        (self.node.hostView.componentView as? DebugCompanionScreenComponent.View)?.updateVisibility(true)
    }

    override public func viewDidDisappear(_ animated: Bool) {
        self.renderingVisible = false
        super.viewDidDisappear(animated)
        (self.node.hostView.componentView as? DebugCompanionScreenComponent.View)?.updateVisibility(false)
    }
}
