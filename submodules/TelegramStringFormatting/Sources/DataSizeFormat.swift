import Foundation
import TelegramCore
import TelegramPresentationData

public extension DataSizeStringFormatting {
    init(presentationData: PresentationData) {
        self.init(decimalSeparator: presentationData.dateTimeFormat.decimalSeparator, byte: presentationData.strings.FileSize_B(_:), kilobyte: presentationData.strings.FileSize_KB(_:), megabyte: presentationData.strings.FileSize_MB(_:), gigabyte: presentationData.strings.FileSize_GB(_:))
    }
    
    init (chatPresentationData: ChatPresentationData) {
        self.init(decimalSeparator: chatPresentationData.dateTimeFormat.decimalSeparator, byte: chatPresentationData.strings.FileSize_B(_:), kilobyte: chatPresentationData.strings.FileSize_KB(_:), megabyte: chatPresentationData.strings.FileSize_MB(_:), gigabyte: chatPresentationData.strings.FileSize_GB(_:))
    }
    
    init (strings: PresentationStrings, decimalSeparator: String) {
        self.init(decimalSeparator: decimalSeparator, byte: strings.FileSize_B(_:), kilobyte: strings.FileSize_KB(_:), megabyte: strings.FileSize_MB(_:), gigabyte: strings.FileSize_GB(_:))
    }
}
