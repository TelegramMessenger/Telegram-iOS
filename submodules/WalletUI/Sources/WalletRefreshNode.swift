import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AppBundle

func stringForShortTimestamp(hours: Int32, minutes: Int32, dateTimeFormat: WalletPresentationDateTimeFormat) -> String {
    switch dateTimeFormat.timeFormat {
    case .regular:
        let hourString: String
        if hours == 0 {
            hourString = "12"
        } else if hours > 12 {
            hourString = "\(hours - 12)"
        } else {
            hourString = "\(hours)"
        }
        
        let periodString: String
        if hours >= 12 {
            periodString = "PM"
        } else {
            periodString = "AM"
        }
        if minutes >= 10 {
            return "\(hourString):\(minutes) \(periodString)"
        } else {
            return "\(hourString):0\(minutes) \(periodString)"
        }
    case .military:
        return String(format: "%02d:%02d", arguments: [Int(hours), Int(minutes)])
    }
}

private func stringForTimestamp(day: Int32, month: Int32, year: Int32, dateTimeFormat: WalletPresentationDateTimeFormat) -> String {
    let separator = dateTimeFormat.dateSeparator
    switch dateTimeFormat.dateFormat {
    case .monthFirst:
        return String(format: "%d%@%d%@%02d", month, separator, day, separator, year - 100)
    case .dayFirst:
        return String(format: "%d%@%02d%@%02d", day, separator, month, separator, year - 100)
    }
}

private func stringForTimestamp(day: Int32, month: Int32, dateTimeFormat: WalletPresentationDateTimeFormat) -> String {
    let separator = dateTimeFormat.dateSeparator
    switch dateTimeFormat.dateFormat {
    case .monthFirst:
        return String(format: "%d%@%d", month, separator, day)
    case .dayFirst:
        return String(format: "%d%@%02d", day, separator, month)
    }
}

private enum RelativeTimestampFormatDay {
    case today
    case yesterday
}

private func stringForRelativeUpdateTime(strings: WalletStrings, day: RelativeTimestampFormatDay, dateTimeFormat: WalletPresentationDateTimeFormat, hours: Int32, minutes: Int32) -> String {
    let dayString: String
    switch day {
    case .today:
        dayString = strings.Wallet_Updated_TodayAt(stringForShortTimestamp(hours: hours, minutes: minutes, dateTimeFormat: dateTimeFormat)).0
    case .yesterday:
        dayString = strings.Wallet_Updated_YesterdayAt(stringForShortTimestamp(hours: hours, minutes: minutes, dateTimeFormat: dateTimeFormat)).0
    }
    return dayString
}

private func lastUpdateTimestampString(strings: WalletStrings, dateTimeFormat: WalletPresentationDateTimeFormat, statusTimestamp: Int32, relativeTo timestamp: Int32) -> String {
    let difference = timestamp - statusTimestamp
    let expanded = true
    if difference < 60 {
        return strings.Wallet_Updated_JustNow
    } else if difference < 60 * 60 && !expanded {
        let minutes = difference / 60
        return strings.Wallet_Updated_MinutesAgo(minutes)
    } else {
        var t: time_t = time_t(statusTimestamp)
        var timeinfo: tm = tm()
        localtime_r(&t, &timeinfo)
        
        var now: time_t = time_t(timestamp)
        var timeinfoNow: tm = tm()
        localtime_r(&now, &timeinfoNow)
        
        if timeinfo.tm_year != timeinfoNow.tm_year {
            return strings.Wallet_Updated_AtDate(stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, year: timeinfo.tm_year, dateTimeFormat: dateTimeFormat)).0
        }
        
        let dayDifference = timeinfo.tm_yday - timeinfoNow.tm_yday
        if dayDifference == 0 || dayDifference == -1 {
            let day: RelativeTimestampFormatDay
            if dayDifference == 0 {
                if expanded {
                    day = .today
                } else {
                    let minutes = difference / (60 * 60)
                    return strings.Wallet_Updated_HoursAgo(minutes)
                }
            } else {
                day = .yesterday
            }
            return stringForRelativeUpdateTime(strings: strings, day: day, dateTimeFormat: dateTimeFormat, hours: timeinfo.tm_hour, minutes: timeinfo.tm_min)
        } else {
            return strings.Wallet_Updated_AtDate(stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, year: timeinfo.tm_year, dateTimeFormat: dateTimeFormat)).0
        }
    }
}

enum WalletRefreshState: Equatable {
    case pullToRefresh(Int32, CGFloat)
    case refreshing
}

final class WalletRefreshNode: ASDisplayNode {
    private let strings: WalletStrings
    private let dateTimeFormat: WalletPresentationDateTimeFormat
    private let iconContainer: ASDisplayNode
    private let iconNode: ASImageNode
    private let titleNode: ImmediateTextNode
    
    private var state: WalletRefreshState?
    
    var refreshProgress: Float = 0.0
    
    private let animator: ConstantDisplayLinkAnimator
    
    init(strings: WalletStrings, dateTimeFormat: WalletPresentationDateTimeFormat) {
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        
        self.iconContainer = ASDisplayNode()
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Wallet/RefreshIcon"), color: UIColor(white: 0.6, alpha: 1.0))
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(), size: image.size)
        }
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        
        var updateImpl: (() -> Void)?
        self.animator = ConstantDisplayLinkAnimator(update: {
            updateImpl?()
        })
        
        super.init()
        
        self.iconContainer.addSubnode(self.iconNode)
        self.addSubnode(self.iconContainer)
        self.addSubnode(self.titleNode)
        
        updateImpl = { [weak self] in
            self?.updateAnimation()
        }
    }
    
    private var currentAngle: CGFloat = 0.0
    private var currentExtraSpeed: CGFloat = 0.0
    private var animateToZeroState: (Double, CGFloat)?
    
    private func updateAnimation() {
        guard let state = self.state else {
            return
        }
        
        var speed: CGFloat = 0.0
        var baseValue: CGFloat = 0.0
        
        switch state {
        case .refreshing:
            speed = 0.01
            self.animateToZeroState = nil
        case let .pullToRefresh(_, value):
            if self.currentExtraSpeed.isZero && self.animateToZeroState == nil && !self.currentAngle.isZero {
                self.animateToZeroState = (CACurrentMediaTime(), self.currentAngle)
            }
            if self.animateToZeroState == nil {
                baseValue = value
            }
        }
        
        if let (startTime, startValue) = self.animateToZeroState {
            let endValue: CGFloat = floor(startValue) + 1.0
            let duration: Double = Double(endValue - startValue) * 1.0
            let timeDelta = (startTime + duration - CACurrentMediaTime())
            let t: CGFloat = 1.0 - CGFloat(max(0.0, min(1.0, timeDelta / duration)))
            if t >= 1.0 - CGFloat.ulpOfOne {
                self.animateToZeroState = nil
                self.currentAngle = 0.0
            } else {
                let bt = bezierPoint(0.23, 1.0, 0.32, 1.0, t)
                self.currentAngle = startValue * (1.0 - bt) + endValue * bt
            }
        } else {
            self.currentAngle += speed + self.currentExtraSpeed
        }
        self.currentExtraSpeed *= 0.97
        if abs(self.currentExtraSpeed) < 0.0001 {
            self.currentExtraSpeed = 0.0
        }
        
        self.iconNode.layer.transform = CATransform3DMakeRotation((baseValue + self.currentAngle) * CGFloat.pi * 2.0, 0.0, 0.0, 1.0)
        
        if !self.currentExtraSpeed.isZero || !speed.isZero || self.animateToZeroState != nil {
            self.animator.isPaused = false
        } else {
            self.animator.isPaused = true
        }
    }
    
    private var cachedProgress: Float = 0.0
    
    func update(state: WalletRefreshState) {
        if self.state == state && self.cachedProgress == self.refreshProgress {
            return
        }
        let ignoreProgressValue = self.refreshProgress == 0.0 || (self.cachedProgress == 0.0 && self.refreshProgress == 1.0)
        self.cachedProgress = self.refreshProgress
        
        let previousState = self.state
        self.state = state
        
        var pullProgress: CGFloat = 0.0
        
        let title: String
        switch state {
        case let .pullToRefresh(ts, progress):
            title = lastUpdateTimestampString(strings: self.strings, dateTimeFormat: dateTimeFormat, statusTimestamp: ts, relativeTo: Int32(Date().timeIntervalSince1970))
            pullProgress = progress
        case .refreshing:
            if ignoreProgressValue {
                title = self.strings.Wallet_Info_Updating
            } else {
                let percent = Int(self.refreshProgress * 100.0)
                title = self.strings.Wallet_Info_Updating + " \(percent)%"
            }
        }
        
        if let previousState = previousState {
            switch state {
            case .refreshing:
                switch previousState {
                case .refreshing:
                    break
                default:
                    self.currentExtraSpeed = 0.05
                }
            default:
                self.currentExtraSpeed = 0.0
            }
        }
        
        self.updateAnimation()
        
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.regular(13.0), textColor: UIColor(white: 1.0, alpha: 0.6))
        
        let iconSize = self.iconNode.image?.size ?? CGSize(width: 20.0, height: 20.0)
        let titleSize = self.titleNode.updateLayout(CGSize(width: 200.0, height: 100.0))
        let iconSpacing: CGFloat = 1.0
        
        let contentWidth = iconSize.width + titleSize.width + iconSpacing
        let contentOrigin = floor(-contentWidth / 2.0)
        
        self.iconContainer.frame = CGRect(origin: CGPoint(x: contentOrigin, y: floor(-iconSize.height / 2.0)), size: iconSize)
        self.titleNode.frame = CGRect(origin: CGPoint(x: contentOrigin + iconSize.width + iconSpacing, y: floor(-titleSize.height / 2.0)), size: titleSize)
    }
}
