import Foundation
import UIKit
import MobileCoreServices

public extension UIPasteboard {
    public func set(attributedString: NSAttributedString?) {
        guard let attributedString = attributedString else {
            return
        }
        do {
            let rtf = try attributedString.data(from: NSMakeRange(0, attributedString.length), documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.rtf])
            self.items = [[kUTTypeRTF as String: NSString(data: rtf, encoding: String.Encoding.utf8.rawValue)!, kUTTypeUTF8PlainText as String: attributedString.string]]
        } catch {
            
        }
    }
}
