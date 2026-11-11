import Foundation
import UIKit
import UniformTypeIdentifiers
import Display
import TelegramPresentationData
import LegacyUI
import TelegramCore

private class DocumentPickerViewController: UIDocumentPickerViewController {
    var forceDarkTheme = false
    var didDisappear: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13.0, *), self.forceDarkTheme {
            self.overrideUserInterfaceStyle = .dark
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.didDisappear?()
    }
}

/// The host's own content: it draws nothing, so a touch that reaches it means the picker is not on top.
private final class DocumentPickerHostView: UIView {
    var passesTouchesThrough: (() -> Bool)?
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result === self, let passesTouchesThrough = self.passesTouchesThrough, passesTouchesThrough() {
            return nil
        }
        return result
    }
}

private final class DocumentPickerHostViewController: UIViewController {
    let hostView = DocumentPickerHostView()
    
    override func loadView() {
        self.view = self.hostView
    }
}

private final class LegacyICloudFileController: LegacyController, UIDocumentPickerDelegate {
    let completion: ([URL]) -> Void
    private let pickerPresentation = DocumentPickerPresentation()
    private var sceneActivationObserver: NSObjectProtocol?
    
    init(presentation: LegacyControllerPresentation, theme: PresentationTheme?, completion: @escaping ([URL]) -> Void) {
        self.completion = completion
        
        super.init(presentation: presentation, theme: theme)
        
        // Touches the host view lets through go on to the controllers below.
        self.hasSparseContainerView = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let sceneActivationObserver = self.sceneActivationObserver {
            NotificationCenter.default.removeObserver(sceneActivationObserver)
        }
    }
    
    func bindHost(_ hostController: DocumentPickerHostViewController) {
        hostController.hostView.passesTouchesThrough = { [weak self] in
            // Hit-testing can also come from a hover; giving up on a lost picker is idempotent, so that is harmless.
            guard let self, self.pickerPresentation.isLost else {
                return false
            }
            DispatchQueue.main.async { [weak self] in
                self?.cancelIfPickerLost(reason: "touch")
            }
            return true
        }
        self.bind(controller: hostController)
    }
    
    func pickerPresentationRequested(_ picker: UIViewController) {
        self.pickerPresentation.presentationRequested(picker: picker)
        
        // The picker's presentation can be cancelled while UIKit holds it back (a Files app locked with Face ID
        // makes the app inactive then, and with passcode auto-lock on the app lock dismisses what the root presents). The host checks once
        // UIKit can no longer be holding it, and again shortly after the scene is active again, when UIKit has
        // settled its presentations; a touch on the host checks too.
        DispatchQueue.main.asyncAfter(deadline: .now() + DocumentPickerPresentation.presentationDelayLimit + 0.1, execute: { [weak self] in
            self?.cancelIfPickerLost(reason: "presentation limit")
        })
        if self.sceneActivationObserver == nil {
            self.sceneActivationObserver = NotificationCenter.default.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main, using: { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: { [weak self] in
                    self?.cancelIfPickerLost(reason: "scene activation")
                })
            })
        }
    }
    
    func pickerDidDisappear() {
        self.pickerPresentation.pickerDidDisappear()
    }
    
    private func cancelIfPickerLost(reason: String) {
        if self.pickerPresentation.isLost {
            Logger.shared.log("LegacyICloudFilePicker", "the document picker is gone without a result, cancelling (\(reason))")
            self.finish(urls: [])
        }
    }
    
    private func finish(urls: [URL]) {
        if self.pickerPresentation.finish() {
            self.completion(urls)
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.finish(urls: [])
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.finish(urls: urls)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        self.finish(urls: [url])
    }
}

public enum LegacyICloudFilePickerMode {
    case `default`
    case `import`
    case `export`
    
    /// iOS 14 replaced `UIDocumentPickerMode` with an `asCopy` flag on the opening/exporting
    /// initializers: the old `.open` is `asCopy: false`, while `.import` and `.exportToService`
    /// are both `asCopy: true`.
    var asCopy: Bool {
        switch self {
        case .default:
            return false
        case .import, .export:
            return true
        }
    }
}

public func legacyICloudFilePicker(theme: PresentationTheme, mode: LegacyICloudFilePickerMode = .default, hasMultiselection: Bool = false, url: URL? = nil, documentTypes: [String] = ["public.item"], forceDarkTheme: Bool = false, dismissed: @escaping () -> Void = {}, completion: @escaping ([URL]) -> Void) -> ViewController {
    var dismissImpl: (() -> Void)?
    let legacyController = LegacyICloudFileController(presentation: .modal(animateIn: true), theme: theme, completion: { urls in
        dismissImpl?()
        completion(urls)
    })
    legacyController.statusBar.statusBarStyle = .Black
    
    let controller: DocumentPickerViewController
    if case .export = mode, let url {
        controller = DocumentPickerViewController(forExporting: [url], asCopy: true)
    } else {
        // The old `documentTypes:` initializer took raw UTI strings, so identifiers the system does
        // not know (e.g. "org.xiph.flac", which the app does not declare) must not be dropped --
        // dropping them would silently make those files unselectable, and dropping all of them would
        // silently widen the picker to every file.
        let contentTypes = documentTypes.map { UTType($0) ?? UTType(importedAs: $0) }
        controller = DocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: mode.asCopy)
    }
    controller.forceDarkTheme = forceDarkTheme || theme.overallDarkAppearance
    controller.didDisappear = { [weak legacyController] in
        legacyController?.pickerDidDisappear()
        dismissImpl?()
    }
    controller.delegate = legacyController
    if #available(iOSApplicationExtension 11.0, iOS 11.0, *), hasMultiselection {
        controller.allowsMultipleSelection = true
    }
    
    legacyController.presentationCompleted = { [weak legacyController] in
        if let legacyController = legacyController {
            if let window = legacyController.view.window {
                controller.popoverPresentationController?.sourceView = window
                controller.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
                window.rootViewController?.present(controller, animated: true)
                legacyController.presentationCompleted = nil
                legacyController.pickerPresentationRequested(controller)
            }
        }
    }
    
    dismissImpl = { [weak legacyController] in
        if let legacyController = legacyController {
            legacyController.dismiss()
        }
        dismissed()
    }
    legacyController.bindHost(DocumentPickerHostViewController())
    return legacyController
}
