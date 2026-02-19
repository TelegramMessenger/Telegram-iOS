import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import Display
import AccountContext
import ChatControllerInteraction
import VisionKit
import PDFKit
import Pdf

extension ChatControllerImpl: VNDocumentCameraViewControllerDelegate {
    func presentDocumentScanner() {
        let documentScanner = VNDocumentCameraViewController()
        documentScanner.delegate = self
        if let rootViewController = self.context.sharedContext.mainWindow?.viewController?.view.window?.rootViewController {
            rootViewController.present(documentScanner, animated: true)
        }
    }
    
    func enqueueScan(scan: VNDocumentCameraScan, convertToPdf: Bool) {
        struct Item {
            let resource: TelegramMediaResource
            let previewResource: TelegramMediaResource?
            let fileName: String
            let mimeType: String
            let size: Int64
        }
        
        var items: [Item] = []
        
        var title = scan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            title = "Scan"
        }
        
        if convertToPdf {
            let pdfDocument = PDFDocument()
            for i in 0 ..< scan.pageCount {
                let image = scan.imageOfPage(at: i)
                if let pdfPage = PDFPage(image: image) {
                    pdfDocument.insert(pdfPage, at: i)
                }
            }
            if let data = pdfDocument.dataRepresentation() {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                
                let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                self.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                
                var previewResource: LocalFileMediaResource?
                if let image = generatePdfPreviewImage(data: data, size: CGSize(width: 256, height: 256.0)), let jpegData = image.jpegData(compressionQuality: 0.5) {
                    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                    self.context.account.postbox.mediaBox.storeResourceData(resource.id, data: jpegData, synchronous: true)
                    previewResource = resource
                }
                
                items.append(Item(resource: resource, previewResource: previewResource, fileName: "\(title).pdf", mimeType: "application/pdf", size: Int64(data.count)))
            }
        } else {
            for i in 0 ..< scan.pageCount {
                let image = scan.imageOfPage(at: i)
                if let data = image.jpegData(compressionQuality: 0.87) {
                    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                    self.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                    
                    var fileTitle = title
                    if scan.pageCount > 1 {
                        fileTitle += "\(fileTitle)-\(i)"
                    }
                    
                    items.append(Item(resource: resource, previewResource: nil, fileName: "\(fileTitle).jpg", mimeType: "image/jpeg", size: Int64(data.count)))
                }
            }
        }
        
        var messages: [EnqueueMessage] = []
        var groupingKey: Int64?
        if items.count > 1 {
            groupingKey = Int64.random(in: Int64.min ... Int64.max)
        }
        
        for item in items {
            let fileId = Int64.random(in: Int64.min ... Int64.max)
            var previewRepresentations: [TelegramMediaImageRepresentation] = []
            if let previewResource = item.previewResource {
                previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 320, height: 320), resource: previewResource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
            }

            var attributes: [TelegramMediaFileAttribute] = []
            attributes.append(.FileName(fileName: item.fileName))
            
            let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: fileId), partialReference: nil, resource: item.resource, previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: item.mimeType, size: item.size, attributes: attributes, alternativeRepresentations: [])
            let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: self.chatLocation.threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: groupingKey, correlationId: nil, bubbleUpEmojiOrStickersets: [])
            messages.append(message)
        
            if let _ = groupingKey, messages.count % 10 == 0 {
                groupingKey = Int64.random(in: Int64.min ... Int64.max)
            }
        }
        
        let transformedMessages = self.transformEnqueueMessages(messages)
        self.sendMessages(transformedMessages)
    }
    
    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true)
        self.enqueueScan(scan: scan, convertToPdf: true)
    }
}
