import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

private let titleFont = Font.regular(17.0)

private func formatDate(_ value: Int32) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.YYYY"
    return formatter.string(from: Date(timeIntervalSince1970: Double(value)))
}

final class BotPaymentDateItemNode: BotPaymentDisclosureItemNode {
    var timestamp: Int32? {
        didSet {
            self.text = timestamp.flatMap({ formatDate($0) }) ?? ""
        }
    }
    
    init(title: String, placeholder: String, timestamp: Int32?, strings: PresentationStrings) {
        super.init(title: title, placeholder: placeholder, text: timestamp.flatMap({ formatDate($0) }) ?? "")
    }
}
