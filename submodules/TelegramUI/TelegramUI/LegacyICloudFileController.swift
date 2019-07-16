import Foundation
import UIKit
import Display
import TelegramPresentationData

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

func legacyICloudFileController(theme: PresentationTheme, completion: @escaping ([URL]) -> Void) -> ViewController {
    var dismissImpl: (() -> Void)?
    let legacyController = LegacyICloudFileController(presentation: .modal(animateIn: true), theme: theme, completion: { urls in
        dismissImpl?()
        completion(urls)
    })
    legacyController.statusBar.statusBarStyle = .Black
    
    let documentTypes: [String] = [
        "public.item"
//        "public.composite-content",
//        "public.text",
//        "public.image",
//        "public.audio",
//        "public.video",
//        "public.movie",
//        "public.font",
//        "public.data",
//        "org.telegram.Telegram.webp",
//        "com.apple.iwork.pages.pages",
//        "com.apple.iwork.numbers.numbers",
//        "com.apple.iwork.keynote.key"
    ]
    
    let controller = UIDocumentPickerViewController(documentTypes: documentTypes, in: .open)
    controller.delegate = legacyController
    if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
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
    }
    legacyController.bind(controller: UIViewController())
    return legacyController
}
