import Foundation
import UIKit
import Display
import AppBundle
import PresentationStrings

private func generateStatusCheckImage(theme: PresentationTheme, single: Bool) -> UIImage? {
    return generateImage(CGSize(width: single ? 13.0 : 18.0, height: 13.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.translateBy(x: 1.0, y: 2.0)
        context.setStrokeColor(theme.chatList.checkmarkColor.cgColor)
        context.setLineWidth(1.32)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        let _ = try? drawSvgPath(context, path: "M0,4.48 L3.59439858,7.93062264 L3.59439858,7.93062264 C3.63384129,7.96848764 3.69651158,7.96720866 3.73437658,7.92776595 C3.7346472,7.92748405 3.73491615,7.92720055 3.73518342,7.92691547 L11.1666667,0 S ")
        
        if !single {
            let _ = try? drawSvgPath(context, path: "M7.33333333,8 L14.8333333,0 S ")
        }
    })
}

private func generateBadgeBackgroundImage(theme: PresentationTheme, diameter: CGFloat, active: Bool, reaction: Bool, icon: UIImage? = nil) -> UIImage? {
    return generateImage(CGSize(width: diameter, height: diameter), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        if active {
            if reaction {
                context.setFillColor(theme.chatList.reactionBadgeActiveBackgroundColor.cgColor)
            } else {
                context.setFillColor(theme.chatList.unreadBadgeActiveBackgroundColor.cgColor)
            }
        } else {
            context.setFillColor(theme.chatList.unreadBadgeInactiveBackgroundColor.cgColor)
        }
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        if let icon = icon, let cgImage = icon.cgImage {
            context.draw(cgImage, in: CGRect(origin: CGPoint(x: floor((size.width - icon.size.width) / 2.0), y: floor((size.height - icon.size.height) / 2.0)), size: icon.size))
        }
    })?.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
}

private func generateClockFrameImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 11.0, height: 11.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        let strokeWidth: CGFloat = 1.0
        context.setLineWidth(strokeWidth)
        context.strokeEllipse(in: CGRect(x: strokeWidth / 2.0, y: strokeWidth / 2.0, width: size.width - strokeWidth, height: size.height - strokeWidth))
        context.fill(CGRect(x: (11.0 - strokeWidth) / 2.0, y: strokeWidth * 3.0, width: strokeWidth, height: 11.0 / 2.0 - strokeWidth * 3.0))
    })
}

private func generateClockMinImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 11.0, height: 11.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        let strokeWidth: CGFloat = 1.0
        context.fill(CGRect(x: (11.0 - strokeWidth) / 2.0, y: (11.0 - strokeWidth) / 2.0, width: 11.0 / 2.0 - strokeWidth, height: strokeWidth))
    })
}

public enum RecentStatusOnlineIconState {
    case regular
    case highlighted
    case pinned
    case panel
}

public enum ScamIconType {
    case regular
    case outgoing
    case service
}

public struct PresentationResourcesChatList {
    public static func pendingImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListPending.rawValue, { theme in
            return generateImage(CGSize(width: 12.0, height: 14.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.translateBy(x: 0.0, y: 1.0)
                context.setStrokeColor(theme.chatList.pendingIndicatorColor.cgColor)
                let lineWidth: CGFloat = 0.99
                context.setLineWidth(lineWidth)
                context.strokeEllipse(in: CGRect(origin: CGPoint(x: lineWidth / 2.0, y: lineWidth / 2.0), size: CGSize(width: 12.0 - lineWidth, height: 12.0 - lineWidth)))
                context.setLineCap(.round)
                let _ = try? drawSvgPath(context, path: "M6.01830142,3 L6.01830142,6.23251697 L4.5,7.81306587 S ")
            })
        })
    }
    
    public static func singleCheckImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListSingleCheck.rawValue, { theme in
            return generateStatusCheckImage(theme: theme, single: true)
        })
    }
    
    public static func doubleCheckImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListDoubleCheck.rawValue, { theme in
            return generateStatusCheckImage(theme: theme, single: false)
        })
    }
    
    public static func clockFrameImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListClockFrame.rawValue, { theme in
            return generateClockFrameImage(color: theme.chatList.pendingIndicatorColor)
        })
    }
    
    public static func clockMinImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListClockMin.rawValue, { theme in
            return generateClockMinImage(color: theme.chatList.pendingIndicatorColor)
        })
    }
    
    public static func lockTopUnlockedImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListLockTopUnlockedImage.rawValue, { theme in
            return generateImage(CGSize(width: 7.0, height: 6.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(theme.rootController.navigationBar.primaryTextColor.cgColor)
                context.setStrokeColor(theme.rootController.navigationBar.primaryTextColor.cgColor)
                context.setLineWidth(1.5)
                context.addPath(UIBezierPath(roundedRect: CGRect(x: 0.75, y: 0.75, width: 5.5, height: 12.0), cornerRadius: 2.5).cgPath)
                context.strokePath()
                context.setBlendMode(.clear)
                context.setFillColor(UIColor.clear.cgColor)
                context.fill(CGRect(x: 4.0, y: 5.33, width: 3.0, height: 2.0))
            })
        })
    }
    
    public static func lockBottomUnlockedImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListLockBottomUnlockedImage.rawValue, { theme in
            return generateImage(CGSize(width: 10.0, height: 8.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(theme.rootController.navigationBar.primaryTextColor.cgColor)
                context.addPath(UIBezierPath(roundedRect: CGRect(x: 0.0, y: 0.0, width: 10.0, height: 8.0), cornerRadius: 1.5).cgPath)
                context.fillPath()
            })
        })
    }
    
    public static func recentStatusOnlineIcon(_ theme: PresentationTheme, state: RecentStatusOnlineIconState, voiceChat: Bool = false) -> UIImage? {
        let key: PresentationResourceKey
        switch state {
            case .regular:
                key = voiceChat ? PresentationResourceKey.chatListRecentStatusVoiceChatIcon : PresentationResourceKey.chatListRecentStatusOnlineIcon
            case .highlighted:
                key = voiceChat ? PresentationResourceKey.chatListRecentStatusVoiceChatHighlightedIcon : PresentationResourceKey.chatListRecentStatusOnlineHighlightedIcon
            case .pinned:
                key = voiceChat ? PresentationResourceKey.chatListRecentStatusVoiceChatPinnedIcon : PresentationResourceKey.chatListRecentStatusOnlinePinnedIcon
            case .panel:
                key = voiceChat ? PresentationResourceKey.chatListRecentStatusVoiceChatPanelIcon : PresentationResourceKey.chatListRecentStatusOnlinePanelIcon
        }
        return theme.image(key.rawValue, { theme in
            let size: CGFloat = voiceChat ? 22.0 : 14.0
            return generateImage(CGSize(width: size, height: size), rotatedContext: { size, context in
                let bounds = CGRect(origin: CGPoint(), size: size)
                context.clear(bounds)
                switch state {
                    case .regular:
                        context.setFillColor(theme.chatList.itemBackgroundColor.cgColor)
                    case .highlighted:
                        context.setFillColor(theme.chatList.itemHighlightedBackgroundColor.cgColor)
                    case .pinned:
                        context.setFillColor(theme.chatList.pinnedItemBackgroundColor.cgColor)
                    case .panel:
                        context.setFillColor(theme.actionSheet.itemBackgroundColor.withAlphaComponent(1.0).cgColor)
                }
                
                context.fillEllipse(in: bounds)
                context.setFillColor(theme.chatList.onlineDotColor.cgColor)
                context.fillEllipse(in: bounds.insetBy(dx: 2.0, dy: 2.0))
            })
        })
    }
    
    public static func badgeBackgroundActive(_ theme: PresentationTheme, diameter: CGFloat) -> UIImage? {
        return theme.image(PresentationResourceParameterKey.chatListBadgeBackgroundActive(diameter), { theme in
            return generateBadgeBackgroundImage(theme: theme, diameter: diameter, active: true, reaction: false)
        })
    }
    
    public static func badgeBackgroundInactive(_ theme: PresentationTheme, diameter: CGFloat) -> UIImage? {
        return theme.image(PresentationResourceParameterKey.chatListBadgeBackgroundInactive(diameter), { theme in
            return generateBadgeBackgroundImage(theme: theme, diameter: diameter, active: false, reaction: false)
        })
    }
    
    public static func badgeBackgroundMention(_ theme: PresentationTheme, diameter: CGFloat) -> UIImage? {
        return theme.image(PresentationResourceParameterKey.chatListBadgeBackgroundMention(diameter), { theme in
            return generateBadgeBackgroundImage(theme: theme, diameter: diameter, active: true, reaction: false, icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/MentionBadgeIcon"), color: theme.chatList.unreadBadgeActiveTextColor))
        })
    }
    
    public static func badgeBackgroundInactiveMention(_ theme: PresentationTheme, diameter: CGFloat) -> UIImage? {
        return theme.image(PresentationResourceParameterKey.chatListBadgeBackgroundInactiveMention(diameter), { theme in
            return generateBadgeBackgroundImage(theme: theme, diameter: diameter, active: false, reaction: false, icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/MentionBadgeIcon"), color: theme.chatList.unreadBadgeInactiveTextColor))
        })
    }
    
    public static func badgeBackgroundReactions(_ theme: PresentationTheme, diameter: CGFloat) -> UIImage? {
        return theme.image(PresentationResourceParameterKey.badgeBackgroundReactions(diameter), { theme in
            return generateBadgeBackgroundImage(theme: theme, diameter: diameter, active: true, reaction: true, icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/ReactionsBadgeIcon"), color: theme.chatList.unreadBadgeActiveTextColor))
        })
    }
    
    public static func badgeBackgroundInactiveReactions(_ theme: PresentationTheme, diameter: CGFloat) -> UIImage? {
        return theme.image(PresentationResourceParameterKey.badgeBackgroundInactiveReactions(diameter), { theme in
            return generateBadgeBackgroundImage(theme: theme, diameter: diameter, active: false, reaction: false, icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/ReactionsBadgeIcon"), color: theme.chatList.unreadBadgeInactiveTextColor))
        })
    }
    
    public static func badgeBackgroundPinned(_ theme: PresentationTheme, diameter: CGFloat) -> UIImage? {
        return theme.image(PresentationResourceParameterKey.chatListBadgeBackgroundPinned(diameter), { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/PeerPinnedIcon"), color: theme.chatList.pinnedBadgeColor)
        })
    }
    
    public static func mutedIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListMutedIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/PeerMutedIcon"), color: theme.chatList.muteIconColor)
        })
    }
    
    public static func verifiedIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListVerifiedIcon.rawValue, { theme in
            if let backgroundImage = UIImage(bundleImageName: "Chat List/PeerVerifiedIconBackground"), let foregroundImage = UIImage(bundleImageName: "Chat List/PeerVerifiedIconForeground") {
                return generateImage(backgroundImage.size, contextGenerator: { size, context in
                    if let backgroundCgImage = backgroundImage.cgImage, let foregroundCgImage = foregroundImage.cgImage {
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.saveGState()
                        context.clip(to: CGRect(origin: .zero, size: size), mask: backgroundCgImage)

                        context.setFillColor(theme.list.itemCheckColors.fillColor.cgColor)
                        context.fill(CGRect(origin: CGPoint(), size: size))
                        context.restoreGState()
                        
                        context.clip(to: CGRect(origin: .zero, size: size), mask: foregroundCgImage)
                        context.setFillColor(theme.list.itemCheckColors.foregroundColor.cgColor)
                        context.fill(CGRect(origin: CGPoint(), size: size))
                    }
                }, opaque: false)
            } else {
                return nil
            }
        })
    }
    
    public static func premiumIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListPremiumIcon.rawValue, { theme in
            if let image = UIImage(bundleImageName: "Chat List/PeerPremiumIcon") {
                return generateImage(image.size, contextGenerator: { size, context in
                    if let cgImage = image.cgImage {
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.clip(to: CGRect(origin: .zero, size: size), mask: cgImage)

                        context.setFillColor(theme.list.itemCheckColors.fillColor.cgColor)
                        context.fill(CGRect(origin: CGPoint(), size: size))
                    }
                }, opaque: false)
            } else {
                return nil
            }
        })
    }

    public static func scamIcon(_ theme: PresentationTheme, strings: PresentationStrings, type: ScamIconType) -> UIImage? {
        let key: PresentationResourceKey
        let color: UIColor
        switch type {
            case .regular:
                key = PresentationResourceKey.chatListScamRegularIcon
                color = theme.chat.message.incoming.scamColor
            case .outgoing:
                key = PresentationResourceKey.chatListScamOutgoingIcon
                color = theme.chat.message.outgoing.scamColor
            case .service:
                key = PresentationResourceKey.chatListScamServiceIcon
                color = theme.chat.serviceMessage.components.withDefaultWallpaper.scam
        }
        return theme.image(key.rawValue, { theme in
            let titleString = NSAttributedString(string: strings.Message_ScamAccount.uppercased(), font: Font.bold(10.0), textColor: color, paragraphAlignment: .center)
            let stringRect = titleString.boundingRect(with: CGSize(width: 100.0, height: 16.0), options: .usesLineFragmentOrigin, context: nil)
            
            return generateImage(CGSize(width: floor(stringRect.width) + 11.0, height: 16.0), contextGenerator: { size, context in
                let bounds = CGRect(origin: CGPoint(), size: size)
                context.clear(bounds)
                
                context.setFillColor(color.cgColor)
                context.setStrokeColor(color.cgColor)
                context.setLineWidth(1.0)
                
                context.addPath(UIBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 2.0).cgPath)
                context.strokePath()
                
                let titlePath = CGMutablePath()
                titlePath.addRect(bounds.offsetBy(dx: 0.0, dy: -2.0 + UIScreenPixel))
                let titleFramesetter = CTFramesetterCreateWithAttributedString(titleString as CFAttributedString)
                let titleFrame = CTFramesetterCreateFrame(titleFramesetter, CFRangeMake(0, titleString.length), titlePath, nil)
                CTFrameDraw(titleFrame, context)
            })
        })
    }
    
    public static func fakeIcon(_ theme: PresentationTheme, strings: PresentationStrings, type: ScamIconType) -> UIImage? {
        let key: PresentationResourceKey
        let color: UIColor
        switch type {
            case .regular:
                key = PresentationResourceKey.chatListFakeRegularIcon
                color = theme.chat.message.incoming.scamColor
            case .outgoing:
                key = PresentationResourceKey.chatListFakeOutgoingIcon
                color = theme.chat.message.outgoing.scamColor
            case .service:
                key = PresentationResourceKey.chatListFakeServiceIcon
                color = theme.chat.serviceMessage.components.withDefaultWallpaper.scam
        }
        return theme.image(key.rawValue, { theme in
            let titleString = NSAttributedString(string: strings.Message_FakeAccount.uppercased(), font: Font.bold(10.0), textColor: color, paragraphAlignment: .center)
            let stringRect = titleString.boundingRect(with: CGSize(width: 100.0, height: 16.0), options: .usesLineFragmentOrigin, context: nil)
            
            return generateImage(CGSize(width: floor(stringRect.width) + 11.0, height: 16.0), contextGenerator: { size, context in
                let bounds = CGRect(origin: CGPoint(), size: size)
                context.clear(bounds)
                
                context.setFillColor(color.cgColor)
                context.setStrokeColor(color.cgColor)
                context.setLineWidth(1.0)
                
                context.addPath(UIBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 2.0).cgPath)
                context.strokePath()
                
                let titlePath = CGMutablePath()
                titlePath.addRect(bounds.offsetBy(dx: 0.0, dy: -2.0 + UIScreenPixel))
                let titleFramesetter = CTFramesetterCreateWithAttributedString(titleString as CFAttributedString)
                let titleFrame = CTFramesetterCreateFrame(titleFramesetter, CFRangeMake(0, titleString.length), titlePath, nil)
                CTFrameDraw(titleFrame, context)
            })
        })
    }
    
    public static func secretIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListSecretIcon.rawValue, { theme in
            return generateImage(CGSize(width: 9.0, height: 12.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(theme.chatList.secretIconColor.cgColor)
                context.setStrokeColor(theme.chatList.secretIconColor.cgColor)
                context.setLineWidth(1.32)
                
                let _ = try? drawSvgPath(context, path: "M4.5,0.66 C3.11560623,0.66 1.99333333,1.78227289 1.99333333,3.16666667 L1.99333333,7.8047619 C1.99333333,9.18915568 3.11560623,10.3114286 4.5,10.3114286 C5.88439377,10.3114286 7.00666667,9.18915568 7.00666667,7.8047619 L7.00666667,3.16666667 C7.00666667,1.78227289 5.88439377,0.66 4.5,0.66 S ")
                let _ = try? drawSvgPath(context, path: "M1.32,5.48571429 L7.68,5.48571429 C8.40901587,5.48571429 9,6.07669842 9,6.80571429 L9,10.68 C9,11.4090159 8.40901587,12 7.68,12 L1.32,12 C0.59098413,12 8.92786951e-17,11.4090159 0,10.68 L2.22044605e-16,6.80571429 C1.3276591e-16,6.07669842 0.59098413,5.48571429 1.32,5.48571429 Z ")
            })
        })
    }
    
    public static func statusLockIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListStatusLockIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/StatusLockIcon"), color: theme.chatList.unreadBadgeInactiveBackgroundColor)
        })
    }
    
    public static func topicArrowIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListTopicArrowIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/TopicArrowIcon"), color: theme.chatList.titleColor)
        })
    }
}
