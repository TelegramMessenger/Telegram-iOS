import Foundation
import Display

private func generateLineImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 2.0, height: 3.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: 2.0, height: 2.0)))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 1.0), size: CGSize(width: 2.0, height: 2.0)))
    })?.stretchableImage(withLeftCapWidth: 0, topCapHeight: 1)
}

private func generateInstantVideoBackground(fillColor: UIColor, strokeColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 214.0, height: 214.0), rotatedContext: { size, context in
        let lineWidth: CGFloat = 0.5
        
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(strokeColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        context.setFillColor(fillColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: lineWidth, y: lineWidth), size: CGSize(width: size.width - lineWidth * 2.0, height: size.height - lineWidth * 2.0)))
    })
}

private func generateInputPanelButtonBackgroundImage(fillColor: UIColor, strokeColor: UIColor) -> UIImage? {
    let radius: CGFloat = 5.0
    let shadowSize: CGFloat = 1.0
    return generateImage(CGSize(width: radius * 2.0, height: radius * 2.0 + shadowSize), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(strokeColor.cgColor)
        context.fillEllipse(in: CGRect(x: 0.0, y: 0.0, width: radius * 2.0, height: radius * 2.0))
        context.setFillColor(fillColor.cgColor)
        context.fillEllipse(in: CGRect(x: 0.0, y: shadowSize, width: radius * 2.0, height: radius * 2.0))
    })?.stretchableImage(withLeftCapWidth: Int(radius), topCapHeight: Int(radius))
}

struct PresentationResourcesChat {
    static func principalGraphics(_ theme: PresentationTheme) -> PrincipalThemeEssentialGraphics {
        return theme.object(PresentationResourceKey.chatPrincipalThemeEssentialGraphics.rawValue, { theme in
            return PrincipalThemeEssentialGraphics(theme.chat)
        }) as! PrincipalThemeEssentialGraphics
    }
    
    static func chatBubbleVerticalLineIncomingImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatBubbleVerticalLineIncomingImage.rawValue, { theme in
            return generateLineImage(color: theme.chat.bubble.incomingAccentColor)
        })
    }
    
    static func chatBubbleVerticalLineOutgoingImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatBubbleVerticalLineOutgoingImage.rawValue, { theme in
            return generateLineImage(color: theme.chat.bubble.outgoingAccentColor)
        })
    }
    
    static func chatBubbleRadialIndicatorFileIconIncoming(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatBubbleRadialIndicatorFileIconIncoming.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/RadialProgressIconDocumentIncoming"), color: theme.chat.bubble.incomingFillColor)
        })
    }
    
    static func chatBubbleRadialIndicatorFileIconOutgoing(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatBubbleRadialIndicatorFileIconOutgoing.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/RadialProgressIconDocumentIncoming"), color: theme.chat.bubble.outgoingFillColor)
        })
    }
    
    static func chatBubbleConsumableContentIncomingIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatBubbleConsumableContentIncomingIcon.rawValue, { theme in
            return generateFilledCircleImage(diameter: 4.0, color: theme.chat.bubble.incomingAccentColor)
        })
    }
    
    static func chatBubbleConsumableContentOutgoingIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatBubbleConsumableContentOutgoingIcon.rawValue, { theme in
            return generateFilledCircleImage(diameter: 4.0, color: theme.chat.bubble.outgoingAccentColor)
        })
    }
    
    static func chatBubbleShareButtonImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatBubbleShareButtonImage.rawValue, { theme in
            return generateImage(CGSize(width: 29.0, height: 29.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(theme.chat.bubble.shareButtonFillColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                
                if let image = UIImage(bundleImageName: "Chat/Message/ShareIcon") {
                    let imageRect = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
                    
                    context.translateBy(x: imageRect.midX, y: imageRect.midY)
                    context.scaleBy(x: 1.0, y: -1.0)
                    context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
                    context.clip(to: imageRect, mask: image.cgImage!)
                    context.setFillColor(theme.chat.bubble.shareButtonForegroundColor.cgColor)
                    context.fill(imageRect)
                }
            })
        })
    }
    
    static func chatServiceBubbleFillImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatServiceBubbleFillImage.rawValue, { theme in
            return generateImage(CGSize(width: 20.0, height: 20.0), contextGenerator: { size, context -> Void in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(theme.chat.serviceMessage.serviceMessageFillColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            })?.stretchableImage(withLeftCapWidth: 8, topCapHeight: 8)
        })
    }
    
    static func chatBubbleSecretMediaIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatBubbleSecretMediaIcon.rawValue, { theme in
            generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/SecretMediaIcon"), color: theme.chat.bubble.mediaOverlayControlForegroundColor)
        })
    }
    
    static func chatFreeformContentAdditionalInfoBackgroundImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatFreeformContentAdditionalInfoBackgroundImage.rawValue, { theme in
            return generateStretchableFilledCircleImage(radius: 4.0, color: theme.chat.serviceMessage.serviceMessageFillColor)
        })
    }
    
    static func chatInstantVideoBackgroundImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInstantVideoBackgroundImage.rawValue, { theme in
            return generateInstantVideoBackground(fillColor: theme.chat.bubble.freeformFillColor, strokeColor: theme.chat.bubble.freeformStrokeColor)
        })
    }
    
    static func chatUnreadBarBackgroundImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatUnreadBarBackgroundImage.rawValue, { theme in
            return generateImage(CGSize(width: 1.0, height: 8.0), contextGenerator: { size, context -> Void in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(theme.chat.serviceMessage.unreadBarStrokeColor.cgColor)
                context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: UIScreenPixel)))
                context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
                context.setFillColor(theme.chat.serviceMessage.unreadBarFillColor.cgColor)
                context.fill(CGRect(x: 0.0, y: UIScreenPixel, width: size.width, height: size.height - UIScreenPixel - UIScreenPixel))
            })?.stretchableImage(withLeftCapWidth: 1, topCapHeight: 4)
        })
    }
    
    static func chatBubbleActionButtonMiddleImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatBubbleActionButtonMiddleImage.rawValue, { theme in
            return messageBubbleActionButtonImage(color: theme.chat.bubble.actionButtonsFillColor, position: .middle)
        })
    }
    
    static func chatBubbleActionButtonBottomLeftImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatBubbleActionButtonBottomLeftImage.rawValue, { theme in
            return messageBubbleActionButtonImage(color: theme.chat.bubble.actionButtonsFillColor, position: .bottomLeft)
        })
    }
    
    static func chatBubbleActionButtonBottomRightImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatBubbleActionButtonBottomRightImage.rawValue, { theme in
            return messageBubbleActionButtonImage(color: theme.chat.bubble.actionButtonsFillColor, position: .bottomRight)
        })
    }
    
    static func chatBubbleActionButtonBottomSingleImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatBubbleActionButtonBottomSingleImage.rawValue, { theme in
            return messageBubbleActionButtonImage(color: theme.chat.bubble.actionButtonsFillColor, position: .bottomSingle)
        })
    }
    
    static func chatInfoItemBackgroundImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInfoItemBackgroundImage.rawValue, { theme in
            return messageSingleBubbleLikeImage(fillColor: theme.chat.bubble.infoFillColor, strokeColor: theme.chat.bubble.infoStrokeColor)
        })
    }
    
    static func chatEmptyItemBackgroundImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatEmptyItemBackgroundImage.rawValue, { theme in
            return generateStretchableFilledCircleImage(radius: 14.0, color: theme.chat.serviceMessage.serviceMessageFillColor)
        })
    }
    
    static func chatEmptyItemIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatEmptyItemIconImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/EmptyChatIcon"), color: theme.chat.serviceMessage.serviceMessagePrimaryTextColor)
        })
    }
    
    static func chatInputPanelCloseIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputPanelCloseIconImage.rawValue, { theme in
            return generateImage(CGSize(width: 12.0, height: 12.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setStrokeColor(theme.chat.inputPanel.panelControlColor.cgColor)
                context.setLineWidth(2.0)
                context.setLineCap(.round)
                context.move(to: CGPoint(x: 1.0, y: 1.0))
                context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - 1.0))
                context.strokePath()
                context.move(to: CGPoint(x: size.width - 1.0, y: 1.0))
                context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
                context.strokePath()
            })
        })
    }
    
    static func chatInputPanelVerticalSeparatorLineImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputPanelVerticalSeparatorLineImage.rawValue, { theme in
            return generateVerticallyStretchableFilledCircleImage(radius: 1.0, color: theme.chat.inputPanel.panelControlAccentColor)
        })
    }
    
    static func chatMediaInputPanelHighlightedIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatMediaInputPanelHighlightedIconImage.rawValue, { theme in
            return generateStretchableFilledCircleImage(radius: 9.0, color: theme.chat.inputMediaPanel.panelHighlightedIconBackgroundColor)
        })
    }
    
    static func chatInputMediaPanelSavedStickersIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputMediaPanelSavedStickersIconImage.rawValue, { theme in
            return generateImage(CGSize(width: 26.0, height: 26.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                if let image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/SavedStickersTabIcon"), color: theme.chat.inputMediaPanel.panelIconColor) {
                    context.draw(image.cgImage!, in: CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size))
                }
            })
        })
    }
    
    static func chatInputMediaPanelRecentStickersIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputMediaPanelRecentStickersIconImage.rawValue, { theme in
            return generateImage(CGSize(width: 26.0, height: 26.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setStrokeColor(theme.chat.inputMediaPanel.panelIconColor.cgColor)
                context.setLineWidth(2.0)
                context.setLineCap(.round)
                let diameter: CGFloat = 22.0
                context.strokeEllipse(in: CGRect(origin: CGPoint(x: floor((size.width - diameter) / 2.0), y: floor((size.width - diameter) / 2.0)), size: CGSize(width: diameter, height: diameter)))
                context.translateBy(x: 1.5, y: 2.5)
                context.move(to: CGPoint(x: 11.0, y: 5.5))
                context.addLine(to: CGPoint(x: 11.0, y: 11.0))
                context.addLine(to: CGPoint(x: 14.5, y: 14.5))
                context.strokePath()
            })
        })
    }
    
    static func chatInputMediaPanelRecentGifsIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputMediaPanelRecentGifsIconImage.rawValue, { theme in
            return generateImage(CGSize(width: 26.0, height: 26.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setStrokeColor(theme.chat.inputMediaPanel.panelIconColor.cgColor)
                context.setLineWidth(2.0)
                context.setLineCap(.round)
                let diameter: CGFloat = 22.0
                context.strokeEllipse(in: CGRect(origin: CGPoint(x: floor((size.width - diameter) / 2.0), y: floor((size.width - diameter) / 2.0)), size: CGSize(width: diameter, height: diameter)))
                context.setFillColor(theme.chat.inputMediaPanel.panelIconColor.cgColor)
                UIGraphicsPushContext(context)
                
                context.setTextDrawingMode(.stroke)
                context.setLineWidth(0.65)
                
                ("GIF" as NSString).draw(in: CGRect(origin: CGPoint(x: 6.0, y: 8.0), size: size), withAttributes: [NSFontAttributeName: Font.regular(8.0), NSForegroundColorAttributeName: theme.chat.inputMediaPanel.panelIconColor])
                
                context.setTextDrawingMode(.fill)
                context.setLineWidth(0.8)
                
                ("GIF" as NSString).draw(in: CGRect(origin: CGPoint(x: 6.0, y: 8.0), size: size), withAttributes: [NSFontAttributeName: Font.regular(8.0), NSForegroundColorAttributeName: theme.chat.inputMediaPanel.panelIconColor])
                UIGraphicsPopContext()
            })
        })
    }
    
    static func chatInputButtonPanelButtonImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputButtonPanelButtonImage.rawValue, { theme in
            return generateInputPanelButtonBackgroundImage(fillColor: theme.chat.inputButtonPanel.buttonFillColor, strokeColor: theme.chat.inputButtonPanel.buttonStrokeColor)
        })
    }
    
    static func chatInputButtonPanelButtonHighlightedImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputButtonPanelButtonHighlightedImage.rawValue, { theme in
            return generateInputPanelButtonBackgroundImage(fillColor: theme.chat.inputButtonPanel.buttonHighlightedFillColor, strokeColor: theme.chat.inputButtonPanel.buttonHighlightedStrokeColor)
        })
    }
    
    static func chatInputTextFieldBackgroundImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputTextFieldBackgroundImage.rawValue, { theme in
            let diameter: CGFloat = 35.0
            UIGraphicsBeginImageContextWithOptions(CGSize(width: diameter, height: diameter), true, 0.0)
            let context = UIGraphicsGetCurrentContext()!
            context.setFillColor(theme.chat.inputPanel.panelBackgroundColor.cgColor)
            context.fill(CGRect(x: 0.0, y: 0.0, width: diameter, height: diameter))
            context.setFillColor(theme.chat.inputPanel.inputBackgroundColor.cgColor)
            context.fillEllipse(in: CGRect(x: 0.0, y: 0.0, width: diameter, height: diameter))
            context.setStrokeColor(theme.chat.inputPanel.inputStrokeColor.cgColor)
            let strokeWidth: CGFloat = 0.5
            context.setLineWidth(strokeWidth)
            context.strokeEllipse(in: CGRect(x: strokeWidth / 2.0, y: strokeWidth / 2.0, width: diameter - strokeWidth, height: diameter - strokeWidth))
            let image = UIGraphicsGetImageFromCurrentImageContext()!.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
            UIGraphicsEndImageContext()
            
            return image
        })
    }
    
    static func chatInputTextFieldClearImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputTextFieldClearImage.rawValue, { theme in
            return generateImage(CGSize(width: 14.0, height: 14.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(theme.chat.inputPanel.inputControlColor.cgColor)
                context.setStrokeColor(theme.chat.inputPanel.inputBackgroundColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                
                context.setLineWidth(1.5)
                context.setLineCap(.round)
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.rotate(by: CGFloat.pi / 4.0)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                
                let lineHeight: CGFloat = 7.0
                
                context.beginPath()
                context.move(to: CGPoint(x: size.width / 2.0, y: (size.width - lineHeight) / 2.0))
                context.addLine(to: CGPoint(x: size.width / 2.0, y: (size.width - lineHeight) / 2.0 + lineHeight))
                context.strokePath()
                
                context.beginPath()
                context.move(to: CGPoint(x: (size.width - lineHeight) / 2.0, y: size.width / 2.0))
                context.addLine(to: CGPoint(x: (size.width - lineHeight) / 2.0 + lineHeight, y: size.width / 2.0))
                context.strokePath()
            })
        })
    }
    
    static func chatInputPanelSendButtonImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputPanelSendButtonImage.rawValue, { theme in
            return UIImage(bundleImageName: "Chat/Input/Text/IconSend")
        })
    }
    
    static func chatInputPanelVoiceButtonImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputPanelVoiceButtonImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Text/IconMicrophone"), color: theme.chat.inputPanel.panelControlColor)
        })
    }
    
    static func chatInputPanelAttachmentButtonImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputPanelAttachmentButtonImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Text/IconAttachment"), color: theme.chat.inputPanel.panelControlColor)
        })
    }
    
    static func chatInputPanelMediaRecordingDotImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputPanelMediaRecordingDotImage.rawValue, { theme in
            return generateFilledCircleImage(diameter: 9.0, color: theme.chat.inputPanel.mediaRecordingDotColor)
        })
    }
    
    static func chatInputPanelMediaRecordingCancelArrowImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputPanelMediaRecordingCancelArrowImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Text/AudioRecordingCancelArrow"), color: theme.chat.inputPanel.panelControlColor)
        })
    }
    
    static func chatInputTextFieldStickersImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputTextFieldStickersImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Text/AccessoryIconStickers"), color: theme.chat.inputPanel.inputControlColor)
        })
    }
    
    static func chatInputTextFieldInputButtonsImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputTextFieldInputButtonsImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Text/AccessoryIconInputButtons"), color: theme.chat.inputPanel.inputControlColor)
        })
    }
    
    static func chatInputTextFieldKeyboardImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputTextFieldKeyboardImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Text/AccessoryIconKeyboard"), color: theme.chat.inputPanel.inputControlColor)
        })
    }
    
    static func chatInputTextFieldTimerImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputTextFieldTimerImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Text/AccessoryIconTimer"), color: theme.chat.inputPanel.inputControlColor)
        })
    }
    
    static func chatHistoryNavigationButtonImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatHistoryNavigationButtonImage.rawValue, { theme in
            return generateImage(CGSize(width: 38.0, height: 38.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(theme.chat.historyNavigation.fillColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: size.width - 1.0, height: size.height - 1.0)))
                context.setLineWidth(0.5)
                context.setStrokeColor(theme.chat.historyNavigation.strokeColor.cgColor)
                context.strokeEllipse(in: CGRect(origin: CGPoint(x: 0.25, y: 0.25), size: CGSize(width: size.width - 0.5, height: size.height - 0.5)))
                context.setStrokeColor(theme.chat.historyNavigation.foregroundColor.cgColor)
                context.setLineWidth(1.5)
                
                let position = CGPoint(x: 9.0 - 0.5, y: 23.0)
                context.move(to: CGPoint(x: position.x + 1.0, y: position.y - 1.0))
                context.addLine(to: CGPoint(x: position.x + 10.0, y: position.y - 10.0))
                context.addLine(to: CGPoint(x: position.x + 19.0, y: position.y - 1.0))
                context.strokePath()
            })
        })
    }
    
    static func chatHistoryMentionsButtonImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatHistoryMentionsButtonImage.rawValue, { theme in
            return generateImage(CGSize(width: 38.0, height: 38.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(theme.chat.historyNavigation.fillColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: size.width - 1.0, height: size.height - 1.0)))
                context.setLineWidth(0.5)
                context.setStrokeColor(theme.chat.historyNavigation.strokeColor.cgColor)
                context.strokeEllipse(in: CGRect(origin: CGPoint(x: 0.25, y: 0.25), size: CGSize(width: size.width - 0.5, height: size.height - 0.5)))
                
                if let image = generateTintedImage(image: UIImage(bundleImageName: "Chat/NavigateToMentions"), color: theme.chat.historyNavigation.foregroundColor), let cgImage = image.cgImage {
                    context.draw(cgImage, in: CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size))
                }
            })
        })
    }
    
    static func chatHistoryNavigationButtonBadgeImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatHistoryNavigationButtonBadgeImage.rawValue, { theme in
            return generateStretchableFilledCircleImage(diameter: 18.0, color: theme.chat.historyNavigation.badgeBackgroundColor, backgroundColor: nil)
        })
    }
    
    static func sharedMediaFileDownloadStartIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.sharedMediaFileDownloadStartIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "List Menu/ListDownloadStartIcon"), color: theme.list.itemAccentColor)
        })
    }
    
    static func sharedMediaFileDownloadPauseIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.sharedMediaFileDownloadPauseIcon.rawValue, { theme in
            return generateImage(CGSize(width: 11.0, height: 11.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                
                context.setFillColor(theme.list.itemAccentColor.cgColor)
                
                context.fill(CGRect(x: 2.0, y: 0.0, width: 2.0, height: 11.0 - 1.0))
                context.fill(CGRect(x: 2.0 + 2.0 + 2.0, y: 0.0, width: 2.0, height: 11.0 - 1.0))
            })
        })
    }
    
    static func chatInfoCallButtonImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInfoCallButtonImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Info/CallButton"), color: theme.list.itemAccentColor)
        })
    }
    
    static func chatInstantMessageMuteIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInstantMessageMuteIconImage.rawValue, { theme in
            return generateImage(CGSize(width: 24.0, height: 24.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(theme.chat.bubble.mediaDateAndStatusFillColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                
                if let image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/InstantVideoMute"), color: .white, backgroundColor: nil) {
                    context.draw(image.cgImage!, in: CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size))
                }
            })
        })
    }
    
    static func chatBubbleIncomingCallButtonImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatBubbleIncomingCallButtonImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Info/CallButton"), color: theme.chat.bubble.incomingAccentColor)
        })
    }
    
    static func chatBubbleOutgoingCallButtonImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatBubbleOutgoingCallButtonImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Info/CallButton"), color: theme.chat.bubble.outgoingAccentColor)
        })
    }
    
    static func chatInputSearchPanelUpImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputSearchPanelUpImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Search/UpButton"), color: theme.chat.inputPanel.panelControlAccentColor)
        })
    }
    
    static func chatInputSearchPanelUpDisabledImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputSearchPanelUpDisabledImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Search/UpButton"), color: theme.chat.inputPanel.panelControlDisabledColor)
        })
    }
    
    static func chatInputSearchPanelDownImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputSearchPanelDownImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Search/DownButton"), color: theme.chat.inputPanel.panelControlAccentColor)
        })
    }
    
    static func chatInputSearchPanelDownDisabledImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputSearchPanelDownDisabledImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Search/DownButton"), color: theme.chat.inputPanel.panelControlDisabledColor)
        })
    }
    
    static func chatInputSearchPanelCalendarImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatInputSearchPanelCalendarImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Search/Calendar"), color: theme.chat.inputPanel.panelControlAccentColor)
        })
    }
    
    /*
     case chatTitlePanelSearchImage
     case chatTitlePanelMuteImage
     case chatTitlePanelUnmuteImage
     case chatTitlePanelCallImage
     */
    
    static func chatTitlePanelInfoImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatTitlePanelInfoImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Title Panels/InfoIcon"), color: theme.chat.inputPanel.panelControlAccentColor)
        })
    }
    
    static func chatTitlePanelSearchImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatTitlePanelSearchImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Title Panels/SearchIcon"), color: theme.chat.inputPanel.panelControlAccentColor)
        })
    }
    
    static func chatTitlePanelMuteImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatTitlePanelMuteImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/RevealActionMuteIcon"), color: theme.chat.inputPanel.panelControlAccentColor)
        })
    }
    
    static func chatTitlePanelUnmuteImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatTitlePanelUnmuteImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/RevealActionMuteIcon"), color: theme.chat.inputPanel.panelControlAccentColor)
        })
    }
    
    static func chatTitlePanelCallImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatTitlePanelCallImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/Tabs/IconCalls"), color: theme.chat.inputPanel.panelControlAccentColor)
        })
    }
    
    static func chatTitlePanelReportImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatTitlePanelReportImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Title Panels/ReportIcon"), color: theme.chat.inputPanel.panelControlAccentColor)
        })
    }
    
    static func chatMessageAttachedContentButtonIncoming(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatMessageAttachedContentButtonIncoming.rawValue, { theme in
            return generateStretchableFilledCircleImage(diameter: 8.0, color: nil, strokeColor: theme.chat.bubble.incomingAccentColor, strokeWidth: 1.0, backgroundColor: nil)
        })
    }
    
    static func chatMessageAttachedContentHighlightedButtonIncoming(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatMessageAttachedContentHighlightedButtonIncoming.rawValue, { theme in
            return generateStretchableFilledCircleImage(diameter: 8.0, color: theme.chat.bubble.incomingAccentColor)
        })
    }
    
    static func chatMessageAttachedContentButtonOutgoing(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatMessageAttachedContentButtonOutgoing.rawValue, { theme in
            return generateStretchableFilledCircleImage(diameter: 8.0, color: nil, strokeColor: theme.chat.bubble.outgoingAccentColor, strokeWidth: 1.0, backgroundColor: nil)
        })
    }
    
    static func chatMessageAttachedContentHighlightedButtonOutgoing(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatMessageAttachedContentHighlightedButtonOutgoing.rawValue, { theme in
            return generateStretchableFilledCircleImage(diameter: 8.0, color: theme.chat.bubble.outgoingAccentColor)
        })
    }
}
