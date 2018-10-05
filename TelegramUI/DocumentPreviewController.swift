import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import QuickLook
import Display

private final class DocumentPreviewItem: NSObject, QLPreviewItem {
    private let url: URL
    private let title: String
    
    var previewItemURL: URL? {
        return self.url
    }
    
    var previewItemTitle: String? {
        return self.title
    }
    
    init(url: URL, title: String) {
        self.url = url
        self.title = title
    }
}

final class DocumentPreviewController: UINavigationController, QLPreviewControllerDelegate, QLPreviewControllerDataSource {
    private let postbox: Postbox
    private let file: TelegramMediaFile
    
    private var item: DocumentPreviewItem?
    
    init(theme: PresentationTheme, strings: PresentationStrings, postbox: Postbox, file: TelegramMediaFile) {
        self.postbox = postbox
        self.file = file
        
        super.init(nibName: nil, bundle: nil)
        
        self.navigationBar.barTintColor = theme.rootController.navigationBar.backgroundColor
        self.navigationBar.tintColor = theme.rootController.navigationBar.accentTextColor
        self.navigationBar.shadowImage = generateImage(CGSize(width: 1.0, height: 1.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(theme.rootController.navigationBar.separatorColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: UIScreenPixel)))
        })
        self.navigationBar.isTranslucent = false
        self.navigationBar.titleTextAttributes = [NSAttributedStringKey.font: Font.semibold(17.0), NSAttributedStringKey.foregroundColor: theme.rootController.navigationBar.primaryTextColor]
        
        let controller = QLPreviewController(nibName: nil, bundle: nil)
        controller.navigation_setDismiss({ [weak self] in
            //self?.cancelPressed()
        }, rootController: self)
        controller.delegate = self
        controller.dataSource = self
        controller.navigationItem.setLeftBarButton(UIBarButtonItem(title: strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed)), animated: false)
        self.setViewControllers([controller], animated: false)
        
        var pathExtension: String?
        if let fileName = self.file.fileName {
            let pathExtensionCandidate = (fileName as NSString).pathExtension
            if !pathExtensionCandidate.isEmpty {
                pathExtension = pathExtensionCandidate
            }
        }
        
        if let path = self.postbox.mediaBox.completedResourcePath(self.file.resource, pathExtension: pathExtension) {
            self.item = DocumentPreviewItem(url: URL(fileURLWithPath: path), title: self.file.fileName ?? strings.Message_File)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func cancelPressed() {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        if self.item != nil {
            return 1
        } else {
            return 0
        }
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        if let item = self.item {
            return item
        } else {
            assertionFailure()
            return DocumentPreviewItem(url: URL(fileURLWithPath: ""), title: "")
        }
    }
    
    func previewControllerWillDismiss(_ controller: QLPreviewController) {
        self.cancelPressed()
    }
    
    func previewControllerDidDismiss(_ controller: QLPreviewController) {
        //self.cancelPressed()
    }
}
