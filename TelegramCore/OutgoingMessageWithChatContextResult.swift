import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

private func aspectFitSize(_ size: CGSize, to: CGSize) -> CGSize {
    let scale = min(to.width / max(1.0, size.width), to.height / max(1.0, size.height))
    return CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
}

/*
if ([result isKindOfClass:[TGBotContextMediaResult class]]) {
    TGBotContextMediaResult *concreteResult = (TGBotContextMediaResult *)result;
    if ([concreteResult.type isEqualToString:@"game"]) {
        TGGameMediaAttachment *gameMedia = [[TGGameMediaAttachment alloc] initWithGameId:0 accessHash:0 shortName:nil title:concreteResult.title gameDescription:concreteResult.resultDescription photo:concreteResult.photo document:concreteResult.document];
        [strongSelf->_companion controllerWantsToSendGame:gameMedia asReplyToMessageId:[strongSelf currentReplyMessageId] botContextResult:botContextResult botReplyMarkup:concreteMessage.replyMarkup];
        [strongSelf->_inputTextPanel.inputField setText:@"" animated:true];
    } else if (concreteResult.document != nil) {
        TGDocumentAttributeVideo *video = nil;
        bool isAnimated = false;
        for (id attribute in concreteResult.document.attributes) {
            if ([attribute isKindOfClass:[TGDocumentAttributeVideo class]]) {
                video = attribute;
            } else if ([attribute isKindOfClass:[TGDocumentAttributeAnimated class]]) {
                isAnimated = true;
            }
        }
        
        if (video != nil && !isAnimated) {
            TGVideoMediaAttachment *videoMedia = [[TGVideoMediaAttachment alloc] init];
            videoMedia = [[TGVideoMediaAttachment alloc] init];
            videoMedia.videoId = concreteResult.document.documentId;
            videoMedia.accessHash = concreteResult.document.accessHash;
            videoMedia.duration = video.duration;
            videoMedia.dimensions = video.size;
            videoMedia.thumbnailInfo = concreteResult.document.thumbnailInfo;
            TGVideoInfo *videoInfo = [[TGVideoInfo alloc] init];
            [videoInfo addVideoWithQuality:1 url:[[NSString alloc] initWithFormat:@"video:%lld:%lld:%d:%d", videoMedia.videoId, videoMedia.accessHash, concreteResult.document.datacenterId, concreteResult.document.size] size:concreteResult.document.size];
            videoMedia.videoInfo = videoInfo;
            [strongSelf->_companion controllerWantsToSendRemoteVideoWithMedia:videoMedia asReplyToMessageId:[strongSelf currentReplyMessageId] text:concreteMessage.caption botContextResult:botContextResult botReplyMarkup:concreteMessage.replyMarkup];
        } else {
            [strongSelf->_companion controllerWantsToSendRemoteDocument:concreteResult.document asReplyToMessageId:[strongSelf currentReplyMessageId] text:concreteMessage.caption botContextResult:botContextResult botReplyMarkup:concreteMessage.replyMarkup];
        }
        [strongSelf->_inputTextPanel.inputField setText:@"" animated:true];
    } else if (concreteResult.photo != nil) {
        [strongSelf->_companion controllerWantsToSendRemoteImage:concreteResult.photo text:concreteMessage.caption asReplyToMessageId:[strongSelf currentReplyMessageId] botContextResult:botContextResult botReplyMarkup:concreteMessage.replyMarkup];
        [strongSelf->_inputTextPanel.inputField setText:@"" animated:true];
    }
} else if ([result isKindOfClass:[TGBotContextExternalResult class]]) {
    TGBotContextExternalResult *concreteResult = (TGBotContextExternalResult *)result;
    if ([concreteResult.type isEqualToString:@"gif"]) {
        TGExternalGifSearchResult *externalGifSearchResult = [[TGExternalGifSearchResult alloc] initWithUrl:concreteResult.url originalUrl:concreteResult.originalUrl thumbnailUrl:concreteResult.thumbUrl size:concreteResult.size];
        id description = [strongSelf->_companion documentDescriptionFromExternalGifSearchResult:externalGifSearchResult text:concreteMessage.caption botContextResult:botContextResult];
        if (description != nil) {
            [strongSelf->_companion controllerWantsToSendImagesWithDescriptions:@[description] asReplyToMessageId:[strongSelf currentReplyMessageId] botReplyMarkup:concreteMessage.replyMarkup];
            [strongSelf->_inputTextPanel.inputField setText:@"" animated:true];
            [TGRecentContextBotsSignal addRecentBot:results.userId];
        }
    } else if ([concreteResult.type isEqualToString:@"photo"]) {
        TGExternalImageSearchResult *externalImageSearchResult = [[TGExternalImageSearchResult alloc] initWithUrl:concreteResult.url originalUrl:concreteResult.originalUrl thumbnailUrl:concreteResult.thumbUrl title:concreteResult.title size:concreteResult.size];
        id description = [strongSelf->_companion imageDescriptionFromExternalImageSearchResult:externalImageSearchResult text:concreteMessage.caption botContextResult:botContextResult];
        if (description != nil) {
            [strongSelf->_companion controllerWantsToSendImagesWithDescriptions:@[description] asReplyToMessageId:[strongSelf currentReplyMessageId] botReplyMarkup:concreteMessage.replyMarkup];
            [strongSelf->_inputTextPanel.inputField setText:@"" animated:true];
            [TGRecentContextBotsSignal addRecentBot:results.userId];
        }
    } else if ([concreteResult.type isEqualToString:@"audio"] || [concreteResult.type isEqualToString:@"voice"] || [concreteResult.type isEqualToString:@"file"]) {
        id description = [strongSelf->_companion documentDescriptionFromBotContextResult:concreteResult text:concreteMessage.caption botContextResult:botContextResult];
        if (description != nil) {
            [strongSelf->_companion controllerWantsToSendImagesWithDescriptions:@[description] asReplyToMessageId:[strongSelf currentReplyMessageId] botReplyMarkup:concreteMessage.replyMarkup];
            [strongSelf->_inputTextPanel.inputField setText:@"" animated:true];
            [TGRecentContextBotsSignal addRecentBot:results.userId];
        }
    } else {
        if (![_companion allowMessageForwarding] && !TGAppDelegateInstance.allowSecretWebpages) {
            for (id result in [TGMessage textCheckingResultsForText:concreteMessage.caption highlightMentionsAndTags:false highlightCommands:false entities:nil]) {
                if ([result isKindOfClass:[NSTextCheckingResult class]] && ((NSTextCheckingResult *)result).resultType == NSTextCheckingTypeLink) {
                    [_companion maybeAskForSecretWebpages];
                    return;
                }
            }
        }
        
        [strongSelf->_companion controllerWantsToSendTextMessage:concreteMessage.caption entities:@[] asReplyToMessageId:[strongSelf currentReplyMessageId] withAttachedMessages:[strongSelf currentForwardMessages] disableLinkPreviews:false botContextResult:botContextResult botReplyMarkup:concreteMessage.replyMarkup];
    }
}
} else if ([result.sendMessage isKindOfClass:[TGBotContextResultSendMessageText class]]) {
    TGBotContextResultSendMessageText *concreteMessage = (TGBotContextResultSendMessageText *)result.sendMessage;
    
    if (![_companion allowMessageForwarding] && !TGAppDelegateInstance.allowSecretWebpages) {
        for (id result in [TGMessage textCheckingResultsForText:concreteMessage.message highlightMentionsAndTags:false highlightCommands:false entities:nil]) {
            if ([result isKindOfClass:[NSTextCheckingResult class]] && ((NSTextCheckingResult *)result).resultType == NSTextCheckingTypeLink) {
                [_companion maybeAskForSecretWebpages];
                return;
            }
        }
    }
    
    [strongSelf->_companion controllerWantsToSendTextMessage:concreteMessage.message entities:concreteMessage.entities asReplyToMessageId:[strongSelf currentReplyMessageId] withAttachedMessages:[strongSelf currentForwardMessages] disableLinkPreviews:false botContextResult:botContextResult botReplyMarkup:concreteMessage.replyMarkup];
} else if ([result.sendMessage isKindOfClass:[TGBotContextResultSendMessageGeo class]]) {
    TGBotContextResultSendMessageGeo *concreteMessage = (TGBotContextResultSendMessageGeo *)result.sendMessage;
    [strongSelf->_companion controllerWantsToSendMapWithLatitude:concreteMessage.location.latitude longitude:concreteMessage.location.longitude venue:concreteMessage.location.venue asReplyToMessageId:[strongSelf currentReplyMessageId] botContextResult:botContextResult botReplyMarkup:concreteMessage.replyMarkup];
    [strongSelf->_inputTextPanel.inputField setText:@"" animated:true];
} else if ([result.sendMessage isKindOfClass:[TGBotContextResultSendMessageContact class]]) {
    TGBotContextResultSendMessageContact *concreteMessage = (TGBotContextResultSendMessageContact *)result.sendMessage;
    TGUser *contactUser = [[TGUser alloc] init];
    contactUser.firstName = concreteMessage.contact.firstName;
    contactUser.lastName = concreteMessage.contact.lastName;
    contactUser.phoneNumber = concreteMessage.contact.phoneNumber;
    [strongSelf->_companion controllerWantsToSendContact:contactUser asReplyToMessageId:[strongSelf currentReplyMessageId] botContextResult:botContextResult botReplyMarkup:concreteMessage.replyMarkup];
    [strongSelf->_inputTextPanel.inputField setText:@"" animated:true];
}
}*/

public func outgoingMessageWithChatContextResult(_ results: ChatContextResultCollection, _ result: ChatContextResult) -> EnqueueMessage? {
    var attributes: [MessageAttribute] = []
    attributes.append(OutgoingChatContextResultMessageAttribute(queryId: results.queryId, id: result.id))
    attributes.append(InlineBotMessageAttribute(peerId: results.botId))
    
    switch result.message {
        case let .auto(caption, replyMarkup):
            if let replyMarkup = replyMarkup {
                attributes.append(replyMarkup)
            }
            switch result {
                case let .internalReference(id, type, title, description, image, file, message):
                    if let image = image {
                        return .message(text: caption, attributes: attributes, media: image, replyToMessageId: nil)
                    } else if let file = file {
                        return .message(text: caption, attributes: attributes, media: file, replyToMessageId: nil)
                    } else {
                        return nil
                    }
                case let .externalReference(id, type, title, description, url, thumbnailUrl, contentUrl, contentType, dimensions, duration, message):
                    if type == "photo" {
                        if let thumbnailUrl = thumbnailUrl {
                            var randomId: Int64 = 0
                            arc4random_buf(&randomId, 8)
                            let thumbnailResource = HttpReferenceMediaResource(url: thumbnailUrl, size: nil)
                            let imageDimensions = dimensions ?? CGSize(width: 128.0, height: 128.0)
                            let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: randomId), representations: [TelegramMediaImageRepresentation(dimensions: aspectFitSize(imageDimensions, to: CGSize(width: 90.0, height: 90.0)), resource: thumbnailResource), TelegramMediaImageRepresentation(dimensions: imageDimensions, resource: EmptyMediaResource())])
                            return .message(text: caption, attributes: attributes, media: tmpImage, replyToMessageId: nil)
                        } else {
                            return .message(text: caption, attributes: attributes, media: nil, replyToMessageId: nil)
                        }
                    } else if type == "document" || type == "gif" || type == "audio" || type == "voice" {
                        var previewRepresentations: [TelegramMediaImageRepresentation] = []
                        if let thumbnailUrl = thumbnailUrl {
                            var randomId: Int64 = 0
                            arc4random_buf(&randomId, 8)
                            let thumbnailResource = HttpReferenceMediaResource(url: thumbnailUrl, size: nil)
                            previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: dimensions ?? CGSize(width: 128.0, height: 128.0), resource: thumbnailResource))
                        }
                        var fileName = "file"
                        if let contentUrl = contentUrl, let url = URL(string: contentUrl) {
                            if !url.lastPathComponent.isEmpty {
                                fileName = url.lastPathComponent
                            }
                        }
                        
                        var fileAttributes: [TelegramMediaFileAttribute] = []
                        fileAttributes.append(.FileName(fileName: fileName))
                        
                        if type == "gif" {
                            fileAttributes.append(.Animated)
                        }
                        
                        if let dimensions = dimensions {
                            fileAttributes.append(.ImageSize(size: dimensions))
                        }
                        
                        if type == "audio" || type == "voice" {
                            fileAttributes.append(.Audio(isVoice: type == "voice", duration: Int(Int32(duration ?? 0)), title: title, performer: description, waveform: nil))
                        }
                        
                        var randomId: Int64 = 0
                        arc4random_buf(&randomId, 8)
                        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), resource: EmptyMediaResource(), previewRepresentations: previewRepresentations, mimeType: contentType ?? "application/binary", size: nil, attributes: fileAttributes)
                        return .message(text: caption, attributes: attributes, media: file, replyToMessageId: nil)
                    } else {
                        return .message(text: caption, attributes: attributes, media: nil, replyToMessageId: nil)
                    }
            }
        case let .text(text, entities, disableUrlPreview, replyMarkup):
            if let entities = entities {
                attributes.append(entities)
            }
            if let replyMarkup = replyMarkup {
                attributes.append(replyMarkup)
            }
            return .message(text: text, attributes: attributes, media: nil, replyToMessageId: nil)
        case let .mapLocation(media, replyMarkup):
            if let replyMarkup = replyMarkup {
                attributes.append(replyMarkup)
            }
            return .message(text: "", attributes: attributes, media: media, replyToMessageId: nil)
        case let .contact(media, replyMarkup):
            if let replyMarkup = replyMarkup {
                attributes.append(replyMarkup)
            }
            return .message(text: "", attributes: attributes, media: media, replyToMessageId: nil)
    }
}
