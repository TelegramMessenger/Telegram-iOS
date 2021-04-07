import Foundation
import UIKit
import Display

public func generatePdfPreviewImage(url: URL, size: CGSize) -> UIImage? {
    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
    return generatePdfPreviewImage(data: data, size: size)
}

public func generatePdfPreviewImage(data: Data, size: CGSize) -> UIImage? {
    guard let provider = CGDataProvider(data: data as CFData) else { return nil }
    guard let document = CGPDFDocument(provider) else { return nil }
    guard let firstPage = document.page(at: 1) else { return nil }
    
    let context = DrawingContext(size: size)
    context.withContext { c in
        var pageRect = firstPage.getBoxRect(.mediaBox)
        let pdfScale = 320.0 / pageRect.size.width
        pageRect.size = CGSize(width: pageRect.size.width * pdfScale, height: pageRect.size.height * pdfScale)
        pageRect.origin = CGPoint.zero
        
        c.setFillColor(UIColor.white.cgColor)
        c.fill(pageRect)
        
        c.translateBy(x: 0.0, y: pageRect.size.height)
        c.scaleBy(x: 1.0, y: -1.0)
        c.concatenate(firstPage.getDrawingTransform(.mediaBox, rect: pageRect, rotate: 0, preserveAspectRatio: true))
        c.drawPDFPage(firstPage)
    }
    return context.generateImage()
}
