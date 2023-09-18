import Foundation
import UIKit
import Display
import TelegramPresentationData
import LegacyUI

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

private final class LegacyICloudFileController: LegacyController, UIDocumentPickerDelegate {
    let completion: ([URL]) -> Void
    
    init(presentation: LegacyControllerPresentation, theme: PresentationTheme?, completion: @escaping ([URL]) -> Void) {
        self.completion = completion
        
        super.init(presentation: presentation, theme: theme)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.completion([])
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.completion(urls)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        self.completion([url])
    }
}

public enum LegacyICloudFilePickerMode {
    case `default`
    case `import`
    case `export`
    
    var documentPickerMode: UIDocumentPickerMode {
        switch self {
        case .default:
            return .open
        case .import:
            return .import
        case .export:
            return .exportToService
        }
    }
}

public func legacyICloudFilePicker(theme: PresentationTheme, mode: LegacyICloudFilePickerMode = .default, url: URL? = nil,  documentTypes: [String] = ["public.item"], forceDarkTheme: Bool = false, dismissed: @escaping () -> Void = {}, completion: @escaping ([URL]) -> Void) -> ViewController {
    var dismissImpl: (() -> Void)?
    let legacyController = LegacyICloudFileController(presentation: .modal(animateIn: true), theme: theme, completion: { urls in
        dismissImpl?()
        completion(urls)
    })
    legacyController.statusBar.statusBarStyle = .Black
    
    let controller: DocumentPickerViewController
    if case .export = mode, let url {
        if #available(iOS 14.0, *) {
            controller = DocumentPickerViewController(forExporting: [url], asCopy: true)
        } else {
            controller = DocumentPickerViewController(url: url, in: mode.documentPickerMode)
        }
    } else {
        controller = DocumentPickerViewController(documentTypes: documentTypes, in: mode.documentPickerMode)
    }
    controller.forceDarkTheme = forceDarkTheme || theme.overallDarkAppearance
    controller.didDisappear = {
        dismissImpl?()
    }
    controller.delegate = legacyController
    if #available(iOSApplicationExtension 11.0, iOS 11.0, *), case .default = mode {
        controller.allowsMultipleSelection = true
    }
    
    legacyController.presentationCompleted = { [weak legacyController] in
        if let legacyController = legacyController {
            if let window = legacyController.view.window {
                controller.popoverPresentationController?.sourceView = window
                controller.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
                window.rootViewController?.present(controller, animated: true)
                legacyController.presentationCompleted = nil
            }
        }
    }
    
    dismissImpl = { [weak legacyController] in
        if let legacyController = legacyController {
            legacyController.dismiss()
        }
        dismissed()
    }
    legacyController.bind(controller: UIViewController())
    return legacyController
}
