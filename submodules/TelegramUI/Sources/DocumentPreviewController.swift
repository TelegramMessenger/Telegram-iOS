import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import QuickLook
import Display
import TelegramPresentationData

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
    
    private var tempFile: TempBoxFile?
    
    init(theme: PresentationTheme, strings: PresentationStrings, postbox: Postbox, file: TelegramMediaFile) {
        self.postbox = postbox
        self.file = file
        
        super.init(nibName: nil, bundle: nil)
        
        self.navigationBar.barTintColor = theme.rootController.navigationBar.opaqueBackgroundColor
        self.navigationBar.tintColor = theme.rootController.navigationBar.accentTextColor
        self.navigationBar.shadowImage = generateImage(CGSize(width: 1.0, height: 1.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(theme.rootController.navigationBar.separatorColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: UIScreenPixel)))
        })
        self.navigationBar.isTranslucent = false
        self.navigationBar.titleTextAttributes = [NSAttributedString.Key.font: Font.semibold(17.0), NSAttributedString.Key.foregroundColor: theme.rootController.navigationBar.primaryTextColor]
        
        let controller = QLPreviewController(nibName: nil, bundle: nil)
        controller.navigation_setDismiss({
        }, rootController: self)
        controller.delegate = self
        controller.dataSource = self
        controller.navigationItem.setLeftBarButton(UIBarButtonItem(title: strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed)), animated: false)
        self.setViewControllers([controller], animated: false)
        
        if let path = self.postbox.mediaBox.completedResourcePath(self.file.resource) {
            var updatedPath = path
            if let fileName = self.file.fileName {
                let tempFile = TempBox.shared.file(path: path, fileName: fileName)
                updatedPath = tempFile.path
                self.tempFile = tempFile
            }
            self.item = DocumentPreviewItem(url: URL(fileURLWithPath: updatedPath), title: self.file.fileName ?? strings.Message_File)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let tempFile = self.tempFile {
            TempBox.shared.dispose(tempFile)
        }
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

final class CompactDocumentPreviewController: QLPreviewController, QLPreviewControllerDelegate, QLPreviewControllerDataSource {
    private let postbox: Postbox
    private let file: TelegramMediaFile
    private let canShare: Bool
    
    private var item: DocumentPreviewItem?
    
    private var tempFile: TempBoxFile?
    
    init(theme: PresentationTheme, strings: PresentationStrings, postbox: Postbox, file: TelegramMediaFile, canShare: Bool = true) {
        self.postbox = postbox
        self.file = file
        self.canShare = canShare
        
        super.init(nibName: nil, bundle: nil)
        
        self.delegate = self
        self.dataSource = self
        
        if let path = self.postbox.mediaBox.completedResourcePath(self.file.resource) {
            var updatedPath = path
            if let fileName = self.file.fileName {
                let tempFile = TempBox.shared.file(path: path, fileName: fileName)
                updatedPath = tempFile.path
                self.tempFile = tempFile
            }
            self.item = DocumentPreviewItem(url: URL(fileURLWithPath: updatedPath), title: self.file.fileName ?? strings.Message_File)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let tempFile = self.tempFile {
            TempBox.shared.dispose(tempFile)
        }
        self.timer?.invalidate()
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
    
    private var navigationBars: [UINavigationBar] = []
    private var toolbars: [UIView] = []
    private var observations : [NSKeyValueObservation] = []
    
    private var initialized = false
    private var timer: SwiftSignalKit.Timer?
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if !self.canShare && !self.initialized {
            self.initialized = true
            
            self.timer = SwiftSignalKit.Timer(timeout: 0.01, repeat: true, completion: { [weak self] in
                self?.tick()
            }, queue: Queue.mainQueue())
            self.timer?.start()
        }
    }
    
    private func tick() {
        self.navigationItem.rightBarButtonItems = [UIBarButtonItem()]
        self.navigationItem.setRightBarButton(UIBarButtonItem(), animated: false)
        
        self.navigationController?.toolbar.isHidden = true

        let (navigationBars, toolbars) = navigationAndToolbarsInSubviews(forView: self.view)
        self.navigationBars = navigationBars
        self.toolbars = toolbars

        for navigationBar in self.navigationBars {
            navigationBar.topItem?.rightBarButtonItem = UIBarButtonItem()
            navigationBar.topItem?.rightBarButtonItems = [UIBarButtonItem()]
        }
        
        for toolbar in self.toolbars {
            toolbar.isHidden = true
        }
    }

    private func navigationAndToolbarsInSubviews(forView view: UIView) -> ([UINavigationBar], [UIView]) {
        var navigationBars: [UINavigationBar] = []
        var toolbars: [UIView] = []
        for subview in view.subviews {
            if let subview = subview as? UINavigationBar {
                navigationBars.append(subview)
            } else if let subview = subview as? UIToolbar {
                toolbars.append(subview)
            } else {
                let (subNavigationBars, subToolbars) = navigationAndToolbarsInSubviews(forView: subview)
                navigationBars.append(contentsOf: subNavigationBars)
                toolbars.append(contentsOf: subToolbars)
            }
        }
        return (navigationBars, toolbars)
    }
    
}

func presentDocumentPreviewController(rootController: UIViewController, theme: PresentationTheme, strings: PresentationStrings, postbox: Postbox, file: TelegramMediaFile, canShare: Bool) {
    if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
        let navigationBar = UINavigationBar.appearance(whenContainedInInstancesOf: [QLPreviewController.self])
        navigationBar.barTintColor = theme.rootController.navigationBar.opaqueBackgroundColor
        navigationBar.setBackgroundImage(generateImage(CGSize(width: 1.0, height: 1.0), rotatedContext: { size, context in
            context.setFillColor(theme.rootController.navigationBar.opaqueBackgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
        }), for: .default)
        navigationBar.isTranslucent = true
        navigationBar.tintColor = theme.rootController.navigationBar.accentTextColor
        navigationBar.shadowImage = generateImage(CGSize(width: 1.0, height: 1.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(theme.rootController.navigationBar.separatorColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: UIScreenPixel)))
        })
        navigationBar.titleTextAttributes = [NSAttributedString.Key.font: Font.semibold(17.0), NSAttributedString.Key.foregroundColor: theme.rootController.navigationBar.primaryTextColor]
    }
    
    rootController.present(CompactDocumentPreviewController(theme: theme, strings: strings, postbox: postbox, file: file, canShare: canShare), animated: true, completion: nil)
}
