import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting

private let timezoneOffset: Int32 = {
    let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
    var now: time_t = time_t(nowTimestamp)
    var timeinfoNow: tm = tm()
    localtime_r(&now, &timeinfoNow)
    return Int32(timeinfoNow.tm_gmtoff)
}()

func listMessageDateHeaderId(timestamp: Int32) -> Int64 {
    var time: time_t = time_t(timestamp + timezoneOffset)
    var timeinfo: tm = tm()
    localtime_r(&time, &timeinfo)
    
    let roundedTimestamp = timeinfo.tm_year * 100 + timeinfo.tm_mon
    
    return Int64(roundedTimestamp)
}

func listMessageDateHeaderInfo(timestamp: Int32) -> (year: Int32, month: Int32) {
    var time: time_t = time_t(timestamp + timezoneOffset)
    var timeinfo: tm = tm()
    localtime_r(&time, &timeinfo)
    
    return (timeinfo.tm_year, timeinfo.tm_mon)
}

final class ListMessageDateHeader: ListViewItemHeader {
    private let timestamp: Int32
    private let roundedTimestamp: Int32
    private let month: Int32
    private let year: Int32
    
    let id: Int64
    let theme: PresentationTheme
    let strings: PresentationStrings
    let fontSize: PresentationFontSize
    
    init(timestamp: Int32, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize) {
        self.timestamp = timestamp
        self.theme = theme
        self.strings = strings
        self.fontSize = fontSize
        
        var time: time_t = time_t(timestamp + timezoneOffset)
        var timeinfo: tm = tm()
        localtime_r(&time, &timeinfo)
        
        self.roundedTimestamp = timeinfo.tm_year * 100 + timeinfo.tm_mon
        self.month = timeinfo.tm_mon
        self.year = timeinfo.tm_year
        
        self.id = Int64(self.roundedTimestamp)
    }
    
    let stickDirection: ListViewItemHeaderStickDirection = .top
    
    let height: CGFloat = 36.0
    
    func node() -> ListViewItemHeaderNode {
        return ListMessageDateHeaderNode(theme: self.theme, strings: self.strings, fontSize: self.fontSize, roundedTimestamp: self.roundedTimestamp, month: self.month, year: self.year)
    }
    
    func updateNode(_ node: ListViewItemHeaderNode, previous: ListViewItemHeader?, next: ListViewItemHeader?) {
    }
}

final class ListMessageDateHeaderNode: ListViewItemHeaderNode {
    var theme: PresentationTheme
    var strings: PresentationStrings
    var fontSize: PresentationFontSize
    let titleNode: ASTextNode
    let backgroundNode: ASDisplayNode
    
    init(theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, roundedTimestamp: Int32, month: Int32, year: Int32) {
        self.theme = theme
        self.strings = strings
        self.fontSize = fontSize
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = theme.list.plainBackgroundColor.withAlphaComponent(0.9)
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        super.init()
        
        let dateText = stringForMonth(strings: strings, month: month, ofYear: year)
        
        let sectionTitleFont = Font.regular(floor(fontSize.baseDisplaySize * 14.0 / 17.0))
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.titleNode)
        self.titleNode.attributedText = NSAttributedString(string: dateText, font: sectionTitleFont, textColor: theme.list.itemPrimaryTextColor)
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        if let attributedString = self.titleNode.attributedText?.mutableCopy() as? NSMutableAttributedString {
            attributedString.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.list.itemPrimaryTextColor, range: NSMakeRange(0, attributedString.length))
            self.titleNode.attributedText = attributedString
        }
        
        self.strings = strings
        
        self.backgroundNode.backgroundColor = theme.list.plainBackgroundColor.withAlphaComponent(0.9)
        self.setNeedsLayout()
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
        let titleSize = self.titleNode.measure(CGSize(width: size.width - leftInset - rightInset - 24.0, height: CGFloat.greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset + 12.0, y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
    }
}
