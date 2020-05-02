import Foundation
import UIKit
import Display
import SyncCore
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import ListSectionHeaderNode

private let timezoneOffset: Int32 = {
    let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
    var now: time_t = time_t(nowTimestamp)
    var timeinfoNow: tm = tm()
    localtime_r(&now, &timeinfoNow)
    return Int32(timeinfoNow.tm_gmtoff)
}()

func listMessageDateHeaderId(timestamp: Int32) -> Int64 {
    let unclippedValue: Int64 = min(Int64(Int32.max), Int64(timestamp) + Int64(timezoneOffset))
    
    var time: time_t = time_t(Int32(clamping: unclippedValue))
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
    
    let height: CGFloat = 28.0
    
    func node() -> ListViewItemHeaderNode {
        return ListMessageDateHeaderNode(theme: self.theme, strings: self.strings, fontSize: self.fontSize, roundedTimestamp: self.roundedTimestamp, month: self.month, year: self.year)
    }
    
    func updateNode(_ node: ListViewItemHeaderNode, previous: ListViewItemHeader?, next: ListViewItemHeader?) {
    }
}

final class ListMessageDateHeaderNode: ListViewItemHeaderNode {
    var theme: PresentationTheme
    var strings: PresentationStrings
    let headerNode: ListSectionHeaderNode
    
    let month: Int32
    let year: Int32
    
    init(theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, roundedTimestamp: Int32, month: Int32, year: Int32) {
        self.theme = theme
        self.strings = strings
        self.month = month
        self.year = year
        
        self.headerNode = ListSectionHeaderNode(theme: theme)
        
        super.init()
        
        self.addSubnode(self.headerNode)
        
        self.headerNode.title = stringForMonth(strings: strings, month: month, ofYear: year).uppercased()
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.headerNode.updateTheme(theme: theme)
        
        self.strings = strings
        self.headerNode.title = stringForMonth(strings: strings, month: self.month, ofYear: self.year).uppercased()
        
        self.setNeedsLayout()
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
        let headerFrame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: size.width, height: size.height + UIScreenPixel))
        self.headerNode.frame = headerFrame
            self.headerNode.updateLayout(size: headerFrame.size, leftInset: leftInset, rightInset: rightInset)
    }
}
