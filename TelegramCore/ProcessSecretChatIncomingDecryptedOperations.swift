import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

private enum MessageParsingError: Error {
    case contentParsingError
    case unsupportedLayer
    case invalidChatState
    case alreadyProcessedMessageInSequenceBasedLayer
    case holesInSequenceBasedLayer
    case secretChatCorruption
}

enum SecretChatRekeyServiceAction {
    case pfsRequestKey(rekeySessionId: Int64, gA: MemoryBuffer)
    case pfsAcceptKey(rekeySessionId: Int64, gB: MemoryBuffer, keyFingerprint: Int64)
    case pfsAbortSession(rekeySessionId: Int64)
    case pfsCommitKey(rekeySessionId: Int64, keyFingerprint: Int64)
}

private enum SecretChatServiceAction {
    case deleteMessages(globallyUniqueIds: [Int64])
    case clearHistory
    case reportLayerSupport(Int32)
    case markMessagesContentAsConsumed(globallyUniqueIds: [Int64])
    case setMessageAutoremoveTimeout(Int32)
    case resendOperations(fromSeq: Int32, toSeq: Int32)
    case rekeyAction(SecretChatRekeyServiceAction)
}

private func parsedServiceAction(_ operation: SecretChatIncomingDecryptedOperation) -> SecretChatServiceAction? {
    guard let parsedLayer = SecretChatLayer(rawValue: operation.layer) else {
        return nil
    }
    
    switch parsedLayer {
        case .layer8:
            if let parsedObject = SecretApi8.parse(Buffer(bufferNoCopy: operation.contents)), let apiMessage = parsedObject as? SecretApi8.DecryptedMessage {
                return SecretChatServiceAction(apiMessage)
            }
        case .layer46:
            if let parsedObject = SecretApi46.parse(Buffer(bufferNoCopy: operation.contents)), let apiMessage = parsedObject as? SecretApi46.DecryptedMessage {
                return SecretChatServiceAction(apiMessage)
            }
    }
    return nil
}

struct SecretChatOperationProcessResult {
    let addedMessages: [StoreMessage]
}

func processSecretChatIncomingDecryptedOperations(mediaBox: MediaBox, modifier: Modifier, peerId: PeerId) -> SecretChatOperationProcessResult {
    if let state = modifier.getPeerChatState(peerId) as? SecretChatState, let peer = modifier.getPeer(peerId) as? TelegramSecretChat {
        var removeTagLocalIndices: [Int32] = []
        var addedDecryptedOperations = false
        var updatedState = state
        var couldNotResendRequestedMessages = false
        var maxAcknowledgedCanonicalOperationIndex: Int32?
        var updatedPeer = peer
        var addedMessages: [StoreMessage] = []
        
        modifier.operationLogEnumerateEntries(peerId: peerId, tag: OperationLogTags.SecretIncomingDecrypted, { entry in
            if let operation = entry.contents as? SecretChatIncomingDecryptedOperation, let serviceAction = parsedServiceAction(operation), case let .resendOperations(fromSeq, toSeq) = serviceAction {
                switch updatedState.role {
                    case .creator:
                        if fromSeq < 0 || toSeq < 0 || (fromSeq & 1) == 0 || (toSeq & 1) == 0 {
                            couldNotResendRequestedMessages = true
                            return false
                        }
                    case .participant:
                        if fromSeq < 0 || toSeq < 0 || (fromSeq & 1) != 0 || (toSeq & 1) != 0 {
                            couldNotResendRequestedMessages = true
                            return false
                        }
                }
                switch updatedState.embeddedState {
                    case let .sequenceBasedLayer(sequenceState):
                        let fromOperationIndex = sequenceState.outgoingOperationIndexFromCanonicalOperationIndex(fromSeq / 2)
                        let toOperationIndex = sequenceState.outgoingOperationIndexFromCanonicalOperationIndex(toSeq / 2)
                        if fromOperationIndex <= toOperationIndex {
                            for index in fromOperationIndex ... toOperationIndex {
                                var notFound = false
                                modifier.operationLogUpdateEntry(peerId: peerId, tag: OperationLogTags.SecretOutgoing, tagLocalIndex: index, { entry in
                                    if let entry = entry {                                                        return PeerOperationLogEntryUpdate(mergedIndex: .newAutomatic, contents: .none)
                                    } else {
                                        notFound = true
                                        return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
                                    }
                                })
                                if notFound {
                                    couldNotResendRequestedMessages = true
                                    return false
                                }
                            }
                        }
                    default:
                        break
                }
            }
            return true
        })
        
        if !couldNotResendRequestedMessages {
            modifier.operationLogEnumerateEntries(peerId: peerId, tag: OperationLogTags.SecretIncomingDecrypted, { entry in
                if let operation = entry.contents as? SecretChatIncomingDecryptedOperation {
                    do {
                        var message: StoreMessage?
                        var resources: [(MediaResource, Data)] = []
                        var serviceAction: SecretChatServiceAction?
                        
                        guard let parsedLayer = SecretChatLayer(rawValue: operation.layer) else {
                            throw MessageParsingError.unsupportedLayer
                        }
                        
                        switch parsedLayer {
                            case .layer8:
                                if let parsedObject = SecretApi8.parse(Buffer(bufferNoCopy: operation.contents)), let apiMessage = parsedObject as? SecretApi8.DecryptedMessage {
                                    message = StoreMessage(peerId: peerId, authorId: updatedPeer.regularPeerId, tagLocalIndex: entry.tagLocalIndex, timestamp: operation.timestamp, apiMessage: apiMessage, file: operation.file)
                                    serviceAction = SecretChatServiceAction(apiMessage)
                                } else {
                                    throw MessageParsingError.contentParsingError
                                }
                            case .layer46:
                                if let parsedObject = SecretApi46.parse(Buffer(bufferNoCopy: operation.contents)), let apiMessage = parsedObject as? SecretApi46.DecryptedMessage {
                                    if let (parsedMessage, parsedResources) = parseMessage(peerId: peerId, authorId: updatedPeer.regularPeerId, tagLocalIndex: entry.tagLocalIndex, timestamp: operation.timestamp, apiMessage: apiMessage, file: operation.file, messageIdForGloballyUniqueMessageId: { id in
                                        return modifier.messageIdForGloballyUniqueMessageId(peerId: peerId, id: id)
                                    }) {
                                        message = parsedMessage
                                        resources = parsedResources
                                    }
                                    serviceAction = SecretChatServiceAction(apiMessage)
                                } else {
                                    throw MessageParsingError.contentParsingError
                                }
                        }
                        
                        switch updatedState.embeddedState {
                            case .terminated:
                                throw MessageParsingError.invalidChatState
                            case .handshake:
                                throw MessageParsingError.invalidChatState
                            case .basicLayer:
                                if parsedLayer != .layer8 {
                                    throw MessageParsingError.contentParsingError
                                }
                            case let .sequenceBasedLayer(sequenceState):
                                if let sequenceInfo = operation.sequenceInfo {
                                    let canonicalIncomingIndex = sequenceState.canonicalIncomingOperationIndex(entry.tagLocalIndex)
                                    assert(canonicalIncomingIndex == sequenceInfo.operationIndex)
                                    if let topProcessedCanonicalIncomingOperationIndex = sequenceState.topProcessedCanonicalIncomingOperationIndex {
                                        if canonicalIncomingIndex != topProcessedCanonicalIncomingOperationIndex + 1 {
                                            if canonicalIncomingIndex <= topProcessedCanonicalIncomingOperationIndex {
                                                throw MessageParsingError.alreadyProcessedMessageInSequenceBasedLayer
                                            } else {
                                                throw MessageParsingError.holesInSequenceBasedLayer
                                            }
                                        }
                                    } else {
                                        if canonicalIncomingIndex != 0 {
                                            throw MessageParsingError.holesInSequenceBasedLayer
                                        }
                                    }
                                    
                                    updatedState = updatedState.withUpdatedEmbeddedState(.sequenceBasedLayer(sequenceState.withUpdatedTopProcessedCanonicalIncomingOperationIndex(canonicalIncomingIndex)))
                                } else {
                                    throw MessageParsingError.contentParsingError
                                }
                        }
                        
                        if let serviceAction = serviceAction {
                            switch serviceAction {
                                case let .reportLayerSupport(layerSupport):
                                    switch updatedState.embeddedState {
                                        case .terminated:
                                            throw MessageParsingError.invalidChatState
                                        case .handshake:
                                            throw MessageParsingError.invalidChatState
                                        case .basicLayer:
                                            if layerSupport >= 46 {
                                                let sequenceBasedLayerState = SecretChatSequenceBasedLayerState(layerNegotiationState: SecretChatLayerNegotiationState(activeLayer: 46, locallyRequestedLayer: 46, remotelyRequestedLayer: layerSupport), rekeyState: nil, baseIncomingOperationIndex: entry.tagLocalIndex, baseOutgoingOperationIndex: modifier.operationLogGetNextEntryLocalIndex(peerId: peerId, tag: OperationLogTags.SecretOutgoing), topProcessedCanonicalIncomingOperationIndex: nil)
                                                updatedState = updatedState.withUpdatedEmbeddedState(.sequenceBasedLayer(sequenceBasedLayerState))
                                                updatedState = addSecretChatOutgoingOperation(modifier: modifier, peerId: peerId, operation: .reportLayerSupport(layer: .layer46, actionGloballyUniqueId: arc4random64(), layerSupport: 46), state: updatedState)
                                            } else {
                                                throw MessageParsingError.contentParsingError
                                            }
                                        case let .sequenceBasedLayer(sequenceState):
                                            break
                                    }
                                case let .setMessageAutoremoveTimeout(timeout):
                                    updatedPeer = updatedPeer.withUpdatedMessageAutoremoveTimeout(timeout == 0 ? nil : timeout)
                                    updatedState = updatedState.withUpdatedMessageAutoremoveTimeout(timeout == 0 ? nil : timeout)
                                case let .rekeyAction(action):
                                    updatedState = secretChatAdvanceRekeySessionIfNeeded(modifier: modifier, peerId: peerId, state: updatedState, action: action)
                                case let .deleteMessages(globallyUniqueIds):
                                    var messageIds: [MessageId] = []
                                    for id in globallyUniqueIds {
                                        if let messageId = modifier.messageIdForGloballyUniqueMessageId(peerId: peerId, id: id) {
                                            messageIds.append(messageId)
                                        }
                                    }
                                    if !messageIds.isEmpty {
                                        modifier.deleteMessages(messageIds)
                                    }
                                case .clearHistory:
                                    break
                                case let .markMessagesContentAsConsumed(globallyUniqueIds):
                                    var messageIds: [MessageId] = []
                                    for id in globallyUniqueIds {
                                        if let messageId = modifier.messageIdForGloballyUniqueMessageId(peerId: peerId, id: id) {
                                            messageIds.append(messageId)
                                        }
                                    }
                                    for messageId in messageIds {
                                        markMessageContentAsConsumedRemotely(modifier: modifier, messageId: messageId)
                                    }
                                default:
                                    break
                            }
                        }
                        
                        removeTagLocalIndices.append(entry.tagLocalIndex)
                        
                        if let sequenceInfo = operation.sequenceInfo {
                            if maxAcknowledgedCanonicalOperationIndex == nil || maxAcknowledgedCanonicalOperationIndex! < sequenceInfo.topReceivedOperationIndex {
                                maxAcknowledgedCanonicalOperationIndex = sequenceInfo.topReceivedOperationIndex
                            }
                        }
                        
                        if let message = message {
                            for (resource, data) in resources {
                                mediaBox.storeResourceData(resource.id, data: data)
                            }
                            modifier.addMessages([message], location: .Random)
                            addedMessages.append(message)
                        }
                        if let serviceAction = serviceAction {
                            switch serviceAction {
                                case let .deleteMessages(globallyUniqueIds):
                                    break
                                default:
                                    break
                            }
                        }
                    } catch let error {
                        if let error = error as? MessageParsingError {
                            switch error {
                                case .contentParsingError:
                                    Logger.shared.log("SecretChat", "Couldn't parse secret message payload")
                                    removeTagLocalIndices.append(entry.tagLocalIndex)
                                    return true
                                case .unsupportedLayer:
                                    return false
                                case .invalidChatState:
                                    removeTagLocalIndices.append(entry.tagLocalIndex)
                                    return false
                                case .alreadyProcessedMessageInSequenceBasedLayer:
                                    removeTagLocalIndices.append(entry.tagLocalIndex)
                                    return true
                                case .holesInSequenceBasedLayer:
                                    Logger.shared.log("SecretChat", "Found holes in incoming operation sequence")
                                    return false
                                case .secretChatCorruption:
                                    Logger.shared.log("SecretChat", "Secret chat corrupted")
                                    return false
                            }
                        } else {
                            assertionFailure()
                        }
                    }
                } else {
                    assertionFailure()
                }
                return true
            })
        }
        for index in removeTagLocalIndices {
            let removed = modifier.operationLogRemoveEntry(peerId: peerId, tag: OperationLogTags.SecretIncomingDecrypted, tagLocalIndex: index)
            assert(removed)
        }
        if let maxAcknowledgedCanonicalOperationIndex = maxAcknowledgedCanonicalOperationIndex {
            switch updatedState.embeddedState {
                case let .sequenceBasedLayer(sequenceState):
                    let tagLocalIndex = max(0, sequenceState.outgoingOperationIndexFromCanonicalOperationIndex(maxAcknowledgedCanonicalOperationIndex) - 1)
                    //Logger.shared.log("SecretChat", "peer \(peerId) dropping acknowledged operations <= \(tagLocalIndex)")
                    modifier.operationLogRemoveEntries(peerId: peerId, tag: OperationLogTags.SecretOutgoing, withTagLocalIndicesEqualToOrLowerThan: tagLocalIndex)
                default:
                    break
            }
        }
        if updatedState != state {
            modifier.setPeerChatState(peerId, state: updatedState)
            updatedPeer = peer.withUpdatedEmbeddedState(updatedState.embeddedState.peerState)
        }
        if !peer.isEqual(updatedPeer) {
            updatePeers(modifier: modifier, peers: [updatedPeer], update: { _, updated in
                return updated
            })
        }
        return SecretChatOperationProcessResult(addedMessages: addedMessages)
    } else {
        assertionFailure()
        return SecretChatOperationProcessResult(addedMessages: [])
    }
}

extension SecretChatServiceAction {
    init?(_ apiMessage: SecretApi8.DecryptedMessage) {
        switch apiMessage {
            case .decryptedMessage:
                return nil
            case let .decryptedMessageService(_, _, action):
                switch action {
                    case let .decryptedMessageActionDeleteMessages(randomIds):
                        self = .deleteMessages(globallyUniqueIds: randomIds)
                    case .decryptedMessageActionFlushHistory:
                        self = .clearHistory
                    case let .decryptedMessageActionNotifyLayer(layer):
                        self = .reportLayerSupport(layer)
                    case let .decryptedMessageActionReadMessages(randomIds):
                        self = .markMessagesContentAsConsumed(globallyUniqueIds: randomIds)
                    case .decryptedMessageActionScreenshotMessages:
                        return nil
                    case let .decryptedMessageActionSetMessageTTL(ttlSeconds):
                        self = .setMessageAutoremoveTimeout(ttlSeconds)
                }
        }
    }
}

extension SecretChatServiceAction {
    init?(_ apiMessage: SecretApi46.DecryptedMessage) {
        switch apiMessage {
            case .decryptedMessage:
                return nil
            case let .decryptedMessageService(_, action):
                switch action {
                    case let .decryptedMessageActionDeleteMessages(randomIds):
                        self = .deleteMessages(globallyUniqueIds: randomIds)
                    case .decryptedMessageActionFlushHistory:
                        self = .clearHistory
                    case let .decryptedMessageActionNotifyLayer(layer):
                        self = .reportLayerSupport(layer)
                    case let .decryptedMessageActionReadMessages(randomIds):
                        self = .markMessagesContentAsConsumed(globallyUniqueIds: randomIds)
                    case .decryptedMessageActionScreenshotMessages:
                        return nil
                    case let .decryptedMessageActionSetMessageTTL(ttlSeconds):
                        self = .setMessageAutoremoveTimeout(ttlSeconds)
                    case let .decryptedMessageActionResend(startSeqNo, endSeqNo):
                        self = .resendOperations(fromSeq: startSeqNo, toSeq: endSeqNo)
                    case let .decryptedMessageActionRequestKey(exchangeId, gA):
                        self = .rekeyAction(.pfsRequestKey(rekeySessionId: exchangeId, gA: MemoryBuffer(gA)))
                    case let .decryptedMessageActionAcceptKey(exchangeId, gB, keyFingerprint):
                        self = .rekeyAction(.pfsAcceptKey(rekeySessionId: exchangeId, gB: MemoryBuffer(gB), keyFingerprint: keyFingerprint))
                    case let .decryptedMessageActionCommitKey(exchangeId, keyFingerprint):
                        self = .rekeyAction(.pfsCommitKey(rekeySessionId: exchangeId, keyFingerprint: keyFingerprint))
                    case let .decryptedMessageActionAbortKey(exchangeId):
                        self = .rekeyAction(.pfsAbortSession(rekeySessionId: exchangeId))
                    case .decryptedMessageActionNoop:
                        return nil
                }
        }
    }
}

extension StoreMessage {
    convenience init?(peerId: PeerId, authorId: PeerId, tagLocalIndex: Int32, timestamp: Int32, apiMessage: SecretApi8.DecryptedMessage, file: SecretChatFileReference?) {
        switch apiMessage {
            case let .decryptedMessage(randomId, _, message, media):
                self.init(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: tagLocalIndex), globallyUniqueId: randomId, timestamp: timestamp, flags: [.Incoming], tags: [], forwardInfo: nil, authorId: authorId, text: message, attributes: [], media: [])
            case let .decryptedMessageService(randomId, _, action):
                switch action {
                    case let .decryptedMessageActionDeleteMessages(randomIds):
                        return nil
                    case .decryptedMessageActionFlushHistory:
                        return nil
                    case let .decryptedMessageActionNotifyLayer(layer):
                        return nil
                    case let .decryptedMessageActionReadMessages(randomIds):
                        return nil
                    case .decryptedMessageActionScreenshotMessages:
                        self.init(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: tagLocalIndex), globallyUniqueId: randomId, timestamp: timestamp, flags: [.Incoming], tags: [], forwardInfo: nil, authorId: authorId, text: "", attributes: [], media: [TelegramMediaAction(action: .historyScreenshot)])
                    case let .decryptedMessageActionSetMessageTTL(ttlSeconds):
                        self.init(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: tagLocalIndex), globallyUniqueId: randomId, timestamp: timestamp, flags: [.Incoming], tags: [], forwardInfo: nil, authorId: authorId, text: "", attributes: [], media: [TelegramMediaAction(action: .messageAutoremoveTimeoutUpdated(ttlSeconds))])
                }
        }
    }
}

extension TelegramMediaFileAttribute {
    init?(_ apiAttribute: SecretApi46.DocumentAttribute) {
        switch apiAttribute {
            case .documentAttributeAnimated:
                self = .Animated
            case let .documentAttributeAudio(flags, duration, title, performer, waveform):
                let isVoice = (flags & (1 << 10)) != 0
                var waveformBuffer: MemoryBuffer?
                if let waveform = waveform {
                    let memory = malloc(waveform.size)!
                    memcpy(memory, waveform.data, waveform.size)
                    waveformBuffer = MemoryBuffer(memory: memory, capacity: waveform.size, length: waveform.size, freeWhenDone: true)
                }
                self = .Audio(isVoice: isVoice, duration: Int(duration), title: title, performer: performer, waveform: waveformBuffer)
            case let .documentAttributeFilename(fileName):
                self = .FileName(fileName: fileName)
            case let .documentAttributeImageSize(w, h):
                self = .ImageSize(size: CGSize(width: CGFloat(w), height: CGFloat(h)))
            case let .documentAttributeSticker(alt, stickerset):
                let packReference: StickerPackReference?
                switch stickerset {
                    case .inputStickerSetEmpty:
                        packReference = nil
                    case let .inputStickerSetShortName(shortName):
                        packReference = .name(shortName)
                }
                self = .Sticker(displayText: alt, packReference: packReference)
            case let .documentAttributeVideo(duration, w, h):
                self = .Video(duration: Int(duration), size: CGSize(width: CGFloat(w), height: CGFloat(h)))
            default:
                return nil
        }
    }
}


private func parseMessage(peerId: PeerId, authorId: PeerId, tagLocalIndex: Int32, timestamp: Int32, apiMessage: SecretApi46.DecryptedMessage, file: SecretChatFileReference?, messageIdForGloballyUniqueMessageId: (Int64) -> MessageId?) -> (StoreMessage, [(MediaResource, Data)])? {
    switch apiMessage {
        case let .decryptedMessage(flags, randomId, ttl, message, media, entities, viaBotName, replyToRandomId):
            var text = message
            var parsedMedia: [Media] = []
            var attributes: [MessageAttribute] = []
            var resources: [(MediaResource, Data)] = []
            
            if ttl > 0 {
                attributes.append(AutoremoveTimeoutMessageAttribute(timeout: ttl, countdownBeginTime: nil))
            }
            
            if let media = media {
                switch media {
                    case let .decryptedMessageMediaPhoto(thumb, thumbW, thumbH, w, h, size, key, iv, caption):
                        if !caption.isEmpty {
                            text = caption
                        }
                        if let file = file {
                            var representations: [TelegramMediaImageRepresentation] = []
                            if thumb.size != 0 {
                                let resource = LocalFileMediaResource(fileId: arc4random64())
                                representations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(thumbW), height: CGFloat(thumbH)), resource: resource))
                                resources.append((resource, thumb.makeData()))
                            }
                            representations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), resource: file.resource(key: SecretFileEncryptionKey(aesKey: key.makeData(), aesIv: iv.makeData()), decryptedSize: size)))
                            let image = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudSecretImage, id: file.id), representations: representations)
                            parsedMedia.append(image)
                        }
                    case let .decryptedMessageMediaAudio(duration, mimeType, size, key, iv):
                        if let file = file {
                            let fileMedia = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudSecretFile, id: file.id), resource: file.resource(key: SecretFileEncryptionKey(aesKey: key.makeData(), aesIv: iv.makeData()), decryptedSize: size), previewRepresentations: [], mimeType: mimeType, size: Int(size), attributes: [TelegramMediaFileAttribute.Audio(isVoice: true, duration: Int(duration), title: nil, performer: nil, waveform: nil)])
                            parsedMedia.append(fileMedia)
                        }
                    case let .decryptedMessageMediaDocument(thumb, thumbW, thumbH, mimeType, size, key, iv, attributes, caption):
                        if !caption.isEmpty {
                            text = caption
                        }
                        if let file = file {
                            var parsedAttributes: [TelegramMediaFileAttribute] = []
                            for attribute in attributes {
                                if let parsedAttribute = TelegramMediaFileAttribute(attribute) {
                                    parsedAttributes.append(parsedAttribute)
                                }
                            }
                            var previewRepresentations: [TelegramMediaImageRepresentation] = []
                            if thumb.size != 0 {
                                let resource = LocalFileMediaResource(fileId: arc4random64())
                                previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(thumbW), height: CGFloat(thumbH)), resource: resource))
                                resources.append((resource, thumb.makeData()))
                            }
                            let fileMedia = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudSecretFile, id: file.id), resource: file.resource(key: SecretFileEncryptionKey(aesKey: key.makeData(), aesIv: iv.makeData()), decryptedSize: size), previewRepresentations: previewRepresentations, mimeType: mimeType, size: Int(size), attributes: parsedAttributes)
                            parsedMedia.append(fileMedia)
                        }
                    case let .decryptedMessageMediaVideo(thumb, thumbW, thumbH, duration, mimeType, w, h, size, key, iv, caption):
                        if !caption.isEmpty {
                            text = caption
                        }
                        if let file = file {
                            var parsedAttributes: [TelegramMediaFileAttribute] = [.Video(duration: Int(duration), size: CGSize(width: CGFloat(w), height: CGFloat(h))), .FileName(fileName: "video.mov")]
                            var previewRepresentations: [TelegramMediaImageRepresentation] = []
                            if thumb.size != 0 {
                                let resource = LocalFileMediaResource(fileId: arc4random64())
                                previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(thumbW), height: CGFloat(thumbH)), resource: resource))
                                resources.append((resource, thumb.makeData()))
                            }
                            let fileMedia = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudSecretFile, id: file.id), resource: file.resource(key: SecretFileEncryptionKey(aesKey: key.makeData(), aesIv: iv.makeData()), decryptedSize: size), previewRepresentations: previewRepresentations, mimeType: mimeType, size: Int(size), attributes: parsedAttributes)
                            parsedMedia.append(fileMedia)
                        }
                    case let .decryptedMessageMediaExternalDocument(id, accessHash, date, mimeType, size, thumb, dcId, attributes):
                        var parsedAttributes: [TelegramMediaFileAttribute] = []
                        for attribute in attributes {
                            if let parsedAttribute = TelegramMediaFileAttribute(attribute) {
                                parsedAttributes.append(parsedAttribute)
                            }
                        }
                        let fileMedia = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: id), resource: CloudDocumentMediaResource(datacenterId: Int(dcId), fileId: id, accessHash: accessHash, size: Int(size)), previewRepresentations: [], mimeType: mimeType, size: Int(size), attributes: parsedAttributes)
                        parsedMedia.append(fileMedia)
                    default:
                        break
                }
            }
            if let replyToRandomId = replyToRandomId, let replyMessageId = messageIdForGloballyUniqueMessageId(replyToRandomId) {
                attributes.append(ReplyMessageAttribute(messageId: replyMessageId))
            }
            return (StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: tagLocalIndex), globallyUniqueId: randomId, timestamp: timestamp, flags: [.Incoming], tags: tagsForStoreMessage(parsedMedia), forwardInfo: nil, authorId: authorId, text: text, attributes: attributes, media: parsedMedia), resources)
        case let .decryptedMessageService(randomId, action):
            switch action {
                case let .decryptedMessageActionDeleteMessages(randomIds):
                    return nil
                case .decryptedMessageActionFlushHistory:
                    return nil
                case let .decryptedMessageActionNotifyLayer(layer):
                    return nil
                case let .decryptedMessageActionReadMessages(randomIds):
                    return nil
                case let .decryptedMessageActionScreenshotMessages(randomIds):
                    return (StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: tagLocalIndex), globallyUniqueId: randomId, timestamp: timestamp, flags: [.Incoming], tags: [], forwardInfo: nil, authorId: authorId, text: "", attributes: [], media: [TelegramMediaAction(action: .historyScreenshot)]), [])
                case let .decryptedMessageActionSetMessageTTL(ttlSeconds):
                    return (StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: tagLocalIndex), globallyUniqueId: randomId, timestamp: timestamp, flags: [.Incoming], tags: [], forwardInfo: nil, authorId: authorId, text: "", attributes: [], media: [TelegramMediaAction(action: .messageAutoremoveTimeoutUpdated(ttlSeconds))]), [])
                case let .decryptedMessageActionResend(startSeqNo, endSeqNo):
                    return nil
                case let .decryptedMessageActionRequestKey(exchangeId, gA):
                    return nil
                case let .decryptedMessageActionAcceptKey(exchangeId, gB, keyFingerprint):
                    return nil
                case let .decryptedMessageActionCommitKey(exchangeId, keyFingerprint):
                    return nil
                case let .decryptedMessageActionAbortKey(exchangeId):
                    return nil
                case .decryptedMessageActionNoop:
                    return nil
            }
    }
}
