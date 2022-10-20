import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import AuthorizationUtils

private func timerValueString(days: Int32, hours: Int32, minutes: Int32, color: UIColor, strings: PresentationStrings) -> NSAttributedString {
    var daysString = ""
    if days > 0 {
        daysString = strings.MessageTimer_Days(days) + " "
    }
    
    var hoursString = ""
    if hours > 0 || days > 0 {
        hoursString = strings.MessageTimer_Hours(hours) + " "
    }
    
    let minutesString = strings.MessageTimer_Minutes(minutes)
    
    return NSAttributedString(string: daysString + hoursString + minutesString, font: Font.regular(21.0), textColor: color)
}

final class AuthorizationSequenceAwaitingAccountResetControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let strings: PresentationStrings
    private let theme: PresentationTheme
    
    private let titleNode: ASTextNode
    private let noticeNode: ASTextNode
    
    private let timerTitleNode: ASTextNode
    private let timerValueNode: ASTextNode
    private let resetNode: HighlightableButtonNode
    
    private var layoutArguments: (ContainerViewLayout, CGFloat)?
    
    var reset: (() -> Void)?
    
    private var protectedUntil: Int32 = 0
    
    private var timer: SwiftSignalKit.Timer?
    
    init(strings: PresentationStrings, theme: PresentationTheme) {
        self.strings = strings
        self.theme = theme
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: strings.Login_ResetAccountProtected_Title, font: Font.light(30.0), textColor: self.theme.list.itemPrimaryTextColor)
        
        self.noticeNode = ASTextNode()
        self.noticeNode.isUserInteractionEnabled = false
        self.noticeNode.displaysAsynchronously = false
        
        self.timerTitleNode = ASTextNode()
        self.timerTitleNode.isUserInteractionEnabled = false
        self.timerTitleNode.displaysAsynchronously = false
        self.timerTitleNode.attributedText = NSAttributedString(string: strings.Login_ResetAccountProtected_TimerTitle, font: Font.regular(16.0), textColor: self.theme.list.itemPrimaryTextColor)
        
        self.timerValueNode = ASTextNode()
        self.timerValueNode.isUserInteractionEnabled = false
        self.timerValueNode.displaysAsynchronously = false
        
        self.resetNode = HighlightableButtonNode()
        self.resetNode.setAttributedTitle(NSAttributedString(string: strings.Login_ResetAccountProtected_Reset, font: Font.regular(21.0), textColor: self.theme.list.itemAccentColor), for: [])
        self.resetNode.setAttributedTitle(NSAttributedString(string: strings.Login_ResetAccountProtected_Reset, font: Font.regular(21.0), textColor: self.theme.list.itemPlaceholderTextColor), for: [.disabled])
        self.resetNode.displaysAsynchronously = false
        self.resetNode.isEnabled = false
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.theme.list.plainBackgroundColor
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.noticeNode)
        self.addSubnode(self.timerTitleNode)
        self.addSubnode(self.timerValueNode)
        self.addSubnode(self.resetNode)
        
        self.resetNode.addTarget(self, action: #selector(self.resetPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    func updateData(protectedUntil: Int32, number: String) {
        self.protectedUntil = protectedUntil
        self.updateTimerValue()
        
        self.noticeNode.attributedText = NSAttributedString(string: strings.Login_ResetAccountProtected_Text(number).string, font: Font.regular(16.0), textColor: self.theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
        
        if let (layout, navigationHeight) = self.layoutArguments {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
        
        if self.timer == nil {
            let timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
                self?.updateTimerValue()
            }, queue: Queue.mainQueue())
            self.timer = timer
            timer.start()
        }
    }
    
    private func updateTimerValue() {
        let timerSeconds = max(0, self.protectedUntil - Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970))
        
        let secondsInAMinute: Int32 = 60
        let secondsInAnHour: Int32 = 60 * secondsInAMinute
        let secondsInADay: Int32 = 24 * secondsInAnHour
        
        let days = timerSeconds / secondsInADay
        
        let hourSeconds = timerSeconds % secondsInADay
        let hours = hourSeconds / secondsInAnHour
        
        let minuteSeconds = hourSeconds % secondsInAnHour
        var minutes = minuteSeconds / secondsInAMinute
        
        if days == 0 && hours == 0 && minutes == 0 && timerSeconds > 0 {
            minutes = 1
        }
        
        self.timerValueNode.attributedText = timerValueString(days: days, hours: hours, minutes: minutes, color: self.theme.list.itemPrimaryTextColor, strings: self.strings)
        
        self.resetNode.isEnabled = timerSeconds <= 0
        
        if let (layout, navigationHeight) = self.layoutArguments {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.layoutArguments = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top = navigationBarHeight
        
        if max(layout.size.width, layout.size.height) > 1023.0 {
            self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_ResetAccountProtected_Title, font: Font.light(40.0), textColor: self.theme.list.itemPrimaryTextColor)
        } else {
            self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_ResetAccountProtected_Title, font: Font.light(30.0), textColor: self.theme.list.itemPrimaryTextColor)
        }
        
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        
        let noticeSize = self.noticeNode.measure(CGSize(width: layout.size.width - 28.0, height: CGFloat.greatestFiniteMagnitude))
        
        let timerTitleSize = self.timerTitleNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        let timerValueSize = self.timerValueNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        let resetSize = self.resetNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        
        var items: [AuthorizationLayoutItem] = []
        items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.noticeNode, size: noticeSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 20.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        items.append(AuthorizationLayoutItem(node: self.timerTitleNode, size: timerTitleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 100.0, maxValue: 100.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.self.timerValueNode, size: timerValueSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.resetNode, size: resetSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        let _ = layoutAuthorizationItems(bounds: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom - 20.0)), items: items, transition: transition, failIfDoesNotFit: false)
    }
    
    @objc func resetPressed() {
        self.reset?()
    }
}


