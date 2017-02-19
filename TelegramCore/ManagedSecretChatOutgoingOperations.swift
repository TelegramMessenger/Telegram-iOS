import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

func addSecretChatOutgoingOperation(modifier: Modifier, peerId: PeerId, operation: SecretChatOutgoingOperationContents, state: SecretChatState) -> SecretChatState {
    var updatedState = state
    switch updatedState.embeddedState {
        case let .sequenceBasedLayer(sequenceState):
            let keyValidityOperationIndex = modifier.operationLogGetNextEntryLocalIndex(peerId: peerId, tag: OperationLogTags.SecretOutgoing)
            let keyValidityOperationCanonicalIndex = sequenceState.canonicalIncomingOperationIndex(keyValidityOperationIndex)
            if let key = state.keychain.latestKey(validForSequenceBasedCanonicalIndex: keyValidityOperationCanonicalIndex) {
                updatedState = updatedState.withUpdatedKeychain(updatedState.keychain.withUpdatedKey(fingerprint: key.fingerprint, { key in
                    return key?.withIncrementedUseCount()
                }))
            }
        default:
            break
    }
    modifier.operationLogAddEntry(peerId: peerId, tag: OperationLogTags.SecretOutgoing, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SecretChatOutgoingOperation(contents: operation, mutable: true, delivered: false))
    return secretChatInitiateRekeySessionIfNeeded(modifier: modifier, peerId: peerId, state: updatedState)
}

private final class ManagedSecretChatOutgoingOperationsHelper {
    var operationDisposables: [Int32: Disposable] = [:]
    
    func update(_ entries: [PeerMergedOperationLogEntry]) -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)] = []
        
        var hasRunningOperationForPeerId = Set<PeerId>()
        var validMergedIndices = Set<Int32>()
        for entry in entries {
            if !hasRunningOperationForPeerId.contains(entry.peerId) {
                hasRunningOperationForPeerId.insert(entry.peerId)
                validMergedIndices.insert(entry.mergedIndex)
                
                if self.operationDisposables[entry.mergedIndex] == nil {
                    let disposable = MetaDisposable()
                    beginOperations.append((entry, disposable))
                    self.operationDisposables[entry.mergedIndex] = disposable
                }
            }
        }
        
        var removeMergedIndices: [Int32] = []
        for (mergedIndex, disposable) in self.operationDisposables {
            if !validMergedIndices.contains(mergedIndex) {
                removeMergedIndices.append(mergedIndex)
                disposeOperations.append(disposable)
            }
        }
        
        for mergedIndex in removeMergedIndices {
            self.operationDisposables.removeValue(forKey: mergedIndex)
        }
        
        return (disposeOperations, beginOperations)
    }
    
    func reset() -> [Disposable] {
        let disposables = Array(self.operationDisposables.values)
        self.operationDisposables.removeAll()
        return disposables
    }
}

private func takenImmutableOperation(postbox: Postbox, peerId: PeerId, tagLocalIndex: Int32) -> Signal<PeerMergedOperationLogEntry?, NoError> {
    return postbox.modify { modifier -> PeerMergedOperationLogEntry? in
        var result: PeerMergedOperationLogEntry?
        modifier.operationLogUpdateEntry(peerId: peerId, tag: OperationLogTags.SecretOutgoing, tagLocalIndex: tagLocalIndex, { entry in
            if let entry = entry, let _ = entry.mergedIndex, let operation = entry.contents as? SecretChatOutgoingOperation {
                if operation.mutable {
                    let updatedContents = SecretChatOutgoingOperation(contents: operation.contents, mutable: false, delivered: operation.delivered)
                    result = entry.withUpdatedContents(updatedContents).mergedEntry!
                    return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .update(updatedContents))
                } else {
                    result = entry.mergedEntry!
                }
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            } else {
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            }
        })
        return result
    }
}

func managedSecretChatOutgoingOperations(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic<ManagedSecretChatOutgoingOperationsHelper>(value: ManagedSecretChatOutgoingOperationsHelper())
        
        let disposable = postbox.mergedOperationLogView(tag: OperationLogTags.SecretOutgoing, limit: 10).start(next: { view in
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) in
                return helper.update(view.entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = takenImmutableOperation(postbox: postbox, peerId: entry.peerId, tagLocalIndex: entry.tagLocalIndex)
                    |> mapToSignal { entry -> Signal<Void, NoError> in
                        if let entry = entry {
                            if let operation = entry.contents as? SecretChatOutgoingOperation {
                                switch operation.contents {
                                    case let .initialHandshakeAccept(gA, accessHash, b):
                                        return initialHandshakeAccept(postbox: postbox, network: network, peerId: entry.peerId, accessHash: accessHash, gA: gA, b: b, tagLocalIndex: entry.tagLocalIndex)
                                    case let .sendMessage(layer, id, file):
                                        return sendMessage(postbox: postbox, network: network, messageId: id, file: file, tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered, layer: layer)
                                    case let .reportLayerSupport(layer, actionGloballyUniqueId, layerSupport):
                                        return sendServiceActionMessage(postbox: postbox, network: network, peerId: entry.peerId, action: .reportLayerSupport(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, layerSupport: layerSupport), tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                    case let .deleteMessages(layer, actionGloballyUniqueId, globallyUniqueIds):
                                        return sendServiceActionMessage(postbox: postbox, network: network, peerId: entry.peerId, action: .deleteMessages(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, globallyUniqueIds: globallyUniqueIds), tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                    case let .pfsRequestKey(layer, actionGloballyUniqueId, rekeySessionId, a):
                                        return pfsRequestKey(postbox: postbox, network: network, peerId: entry.peerId, layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, rekeySessionId: rekeySessionId, a: a, tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                    case let .pfsCommitKey(layer, actionGloballyUniqueId, rekeySessionId, keyFingerprint):
                                        return sendServiceActionMessage(postbox: postbox, network: network, peerId: entry.peerId, action: .pfsCommitKey(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, rekeySessionId: rekeySessionId, keyFingerprint: keyFingerprint), tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                    case let .pfsAcceptKey(layer, actionGloballyUniqueId, rekeySessionId, gA, b):
                                        return pfsAcceptKey(postbox: postbox, network: network, peerId: entry.peerId, layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, rekeySessionId: rekeySessionId, gA: gA, b: b, tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                    case let .pfsAbortSession(layer, actionGloballyUniqueId, rekeySessionId):
                                        return sendServiceActionMessage(postbox: postbox, network: network, peerId: entry.peerId, action: .pfsAbortSession(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, rekeySessionId: rekeySessionId), tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                    case let .noop(layer, actionGloballyUniqueId):
                                        return sendServiceActionMessage(postbox: postbox, network: network, peerId: entry.peerId, action: .noop(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId), tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                    case let .readMessagesContent(layer, actionGloballyUniqueId, globallyUniqueIds):
                                        return sendServiceActionMessage(postbox: postbox, network: network, peerId: entry.peerId, action: .readMessageContents(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, globallyUniqueIds: globallyUniqueIds), tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                    case let .setMessageAutoremoveTimeout(layer, actionGloballyUniqueId, timeout):
                                        return sendServiceActionMessage(postbox: postbox, network: network, peerId: entry.peerId, action: .setMessageAutoremoveTimeout(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, timeout: timeout), tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                    default:
                                        assertionFailure()
                                }
                            } else {
                                assertionFailure()
                            }
                        }
                        return .complete()
                    }
                disposable.set(signal.start())
            }
        })
        
        return ActionDisposable {
            let disposables = helper.with { helper -> [Disposable] in
                return helper.reset()
            }
            for disposable in disposables {
                disposable.dispose()
            }
        }
    }
}

private func initialHandshakeAccept(postbox: Postbox, network: Network, peerId: PeerId, accessHash: Int64, gA: MemoryBuffer, b: MemoryBuffer, tagLocalIndex: Int32) -> Signal<Void, NoError> {
    return validatedEncryptionConfig(postbox: postbox, network: network)
        |> mapToSignal { config -> Signal<Void, NoError> in
            var gValue: Int32 = config.g.byteSwapped
            let g = Data(bytes: &gValue, count: 4)
            let p = config.p.makeData()
            
            let bData = b.makeData()
            
            let gb = MTExp(g, bData, p)!
            
            var key = MTExp(gA.makeData(), bData, p)!
            
            if key.count > 256 {
                key.count = 256
            } else  {
                while key.count < 256 {
                    key.insert(0, at: 0)
                }
            }
            
            let keyHash = MTSha1(key)!
            
            var keyFingerprint: Int64 = 0
            keyHash.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                memcpy(&keyFingerprint, bytes.advanced(by: keyHash.count - 8), 8)
            }
            
            let result = network.request(Api.functions.messages.acceptEncryption(peer: .inputEncryptedChat(chatId: peerId.id, accessHash: accessHash), gB: Buffer(data: gb), keyFingerprint: keyFingerprint))
            
            let response = result
                |> map { result -> Api.EncryptedChat? in
                    return result
                }
                |> `catch` { error -> Signal<Api.EncryptedChat?, NoError> in
                    return .single(nil)
                }
            
            return response
                |> mapToSignal { result -> Signal<Void, NoError> in
                    return postbox.modify { modifier -> Void in
                        let removed = modifier.operationLogRemoveEntry(peerId: peerId, tag: OperationLogTags.SecretOutgoing, tagLocalIndex: tagLocalIndex)
                        assert(removed)
                        if let state = modifier.getPeerChatState(peerId) as? SecretChatState {
                            modifier.setPeerChatState(peerId, state: state.withUpdatedKeychain(SecretChatKeychain(keys: [SecretChatKey(fingerprint: keyFingerprint, key: MemoryBuffer(data: key), validity: .indefinite, useCount: 0)])).withUpdatedEmbeddedState(.basicLayer))
                        } else {
                            assertionFailure()
                        }
                    }
                }
        }
}

private func pfsRequestKey(postbox: Postbox, network: Network, peerId: PeerId, layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64, a: MemoryBuffer, tagLocalIndex: Int32, wasDelivered: Bool) -> Signal<Void, NoError> {
    return validatedEncryptionConfig(postbox: postbox, network: network)
        |> mapToSignal { config -> Signal<Void, NoError> in
            var gValue: Int32 = config.g.byteSwapped
            let g = Data(bytes: &gValue, count: 4)
            let p = config.p.makeData()
            
            let aData = a.makeData()
            let ga = MTExp(g, aData, p)!
            
            return postbox.modify { modifier -> Signal<Void, NoError> in
                if let state = modifier.getPeerChatState(peerId) as? SecretChatState {
                    switch state.embeddedState {
                        case let .sequenceBasedLayer(sequenceState):
                            if let rekeyState = sequenceState.rekeyState, case .requesting = rekeyState.data {
                                modifier.setPeerChatState(peerId, state: state.withUpdatedEmbeddedState(.sequenceBasedLayer(sequenceState.withUpdatedRekeyState(SecretChatRekeySessionState(id: rekeyState.id, data: .requested(a: a, config: config))))))
                            }
                        default:
                            break
                    }
                }
                return sendServiceActionMessage(postbox: postbox, network: network, peerId: peerId, action: .pfsRequestKey(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, rekeySessionId:rekeySessionId, gA: MemoryBuffer(data: ga)), tagLocalIndex: tagLocalIndex, wasDelivered: wasDelivered)
            } |> switchToLatest
    }
}

private func pfsAcceptKey(postbox: Postbox, network: Network, peerId: PeerId, layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64, gA: MemoryBuffer, b: MemoryBuffer, tagLocalIndex: Int32, wasDelivered: Bool) -> Signal<Void, NoError> {
    return validatedEncryptionConfig(postbox: postbox, network: network)
        |> mapToSignal { config -> Signal<Void, NoError> in
            var gValue: Int32 = config.g.byteSwapped
            let g = Data(bytes: &gValue, count: 4)
            let p = config.p.makeData()
            
            let bData = b.makeData()
            
            let gb = MTExp(g, bData, p)!
            
            var key = MTExp(gA.makeData(), bData, p)!
            
            if key.count > 256 {
                key.count = 256
            } else  {
                while key.count < 256 {
                    key.insert(0, at: 0)
                }
            }
            
            let keyHash = MTSha1(key)!
            
            var keyFingerprint: Int64 = 0
            keyHash.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                memcpy(&keyFingerprint, bytes.advanced(by: keyHash.count - 8), 8)
            }
            
            return postbox.modify { modifier -> Signal<Void, NoError> in
                if let state = modifier.getPeerChatState(peerId) as? SecretChatState {
                    switch state.embeddedState {
                    case let .sequenceBasedLayer(sequenceState):
                        if let rekeyState = sequenceState.rekeyState, case .accepting = rekeyState.data {
                            modifier.setPeerChatState(peerId, state: state.withUpdatedEmbeddedState(.sequenceBasedLayer(sequenceState.withUpdatedRekeyState(SecretChatRekeySessionState(id: rekeyState.id, data: .accepted(key: MemoryBuffer(data: key), keyFingerprint: keyFingerprint))))))
                        }
                    default:
                        break
                    }
                }
                return sendServiceActionMessage(postbox: postbox, network: network, peerId: peerId, action: .pfsAcceptKey(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, rekeySessionId:rekeySessionId, gB: MemoryBuffer(data: gb), keyFingerprint: keyFingerprint), tagLocalIndex: tagLocalIndex, wasDelivered: wasDelivered)
                } |> switchToLatest
    }
}

private enum BoxedDecryptedMessage {
    case layer8(SecretApi8.DecryptedMessage)
    case layer46(SecretApi46.DecryptedMessage)
    
    func serialize(_ buffer: Buffer, role: SecretChatRole, sequenceInfo: SecretChatOperationSequenceInfo?) {
        switch self {
            case let .layer8(message):
                message.serialize(buffer, true)
            case let .layer46(message):
                //decryptedMessageLayer#1be31789 random_bytes:bytes layer:int in_seq_no:int out_seq_no:int message:DecryptedMessage = DecryptedMessageLayer;
                buffer.appendInt32(0x1be31789)
                let randomBytes = malloc(15)!
                arc4random_buf(randomBytes, 15)
                serializeBytes(Buffer(memory: randomBytes, size: 15, capacity: 15, freeWhenDone: false), buffer: buffer, boxed: false)
                free(randomBytes)
                buffer.appendInt32(46)
                
                if let sequenceInfo = sequenceInfo {
                    let inSeqNo = sequenceInfo.topReceivedOperationIndex * 2 + (role == .creator ? 0 : 1)
                    let outSeqNo = sequenceInfo.operationIndex * 2 + (role == .creator ? 1 : 0)
                    buffer.appendInt32(inSeqNo)
                    buffer.appendInt32(outSeqNo)
                } else {
                    buffer.appendInt32(0)
                    buffer.appendInt32(0)
                    assertionFailure()
                }
                
                message.serialize(buffer, true)
        }
    }
}

private enum SecretMessageAction {
    case deleteMessages(layer: SecretChatLayer, actionGloballyUniqueId: Int64, globallyUniqueIds: [Int64])
    case clearHistory(layer: SecretChatLayer, actionGloballyUniqueId: Int64)
    case resendOperations(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, fromSeqNo: Int32, toSeqNo: Int32)
    case reportLayerSupport(layer: SecretChatLayer, actionGloballyUniqueId: Int64, layerSupport: Int32)
    case pfsRequestKey(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64, gA: MemoryBuffer)
    case pfsAcceptKey(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64, gB: MemoryBuffer, keyFingerprint: Int64)
    case pfsAbortSession(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64)
    case pfsCommitKey(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64, keyFingerprint: Int64)
    case noop(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64)
    case readMessageContents(layer: SecretChatLayer, actionGloballyUniqueId: Int64, globallyUniqueIds: [Int64])
    case setMessageAutoremoveTimeout(layer: SecretChatLayer, actionGloballyUniqueId: Int64, timeout: Int32)
    
    var globallyUniqueId: Int64 {
        switch self {
            case let .deleteMessages(_, actionGloballyUniqueId, _):
                return actionGloballyUniqueId
            case let .clearHistory(_, actionGloballyUniqueId):
                return actionGloballyUniqueId
            case let .resendOperations(_, actionGloballyUniqueId, _, _):
                return actionGloballyUniqueId
            case let .reportLayerSupport(_, actionGloballyUniqueId, _):
                return actionGloballyUniqueId
            case let .pfsRequestKey(_, actionGloballyUniqueId, _, _):
                return actionGloballyUniqueId
            case let .pfsAcceptKey(_, actionGloballyUniqueId, _, _, _):
                return actionGloballyUniqueId
            case let .pfsAbortSession(_, actionGloballyUniqueId, _):
                return actionGloballyUniqueId
            case let .pfsCommitKey(_, actionGloballyUniqueId, _, _):
                return actionGloballyUniqueId
            case let .noop(_, actionGloballyUniqueId):
                return actionGloballyUniqueId
            case let .readMessageContents(_, actionGloballyUniqueId, _):
                return actionGloballyUniqueId
            case let .setMessageAutoremoveTimeout(_, actionGloballyUniqueId, _):
                return actionGloballyUniqueId
        }
    }
}

private func decryptedAttributes46(_ attributes: [TelegramMediaFileAttribute]) -> [SecretApi46.DocumentAttribute] {
    var result: [SecretApi46.DocumentAttribute] = []
    for attribute in attributes {
        switch attribute {
            case let .FileName(fileName):
                result.append(.documentAttributeFilename(fileName: fileName))
            case .Animated:
                result.append(.documentAttributeAnimated)
            case let .Sticker(displayText):
                result.append(.documentAttributeSticker(alt: displayText, stickerset: SecretApi46.InputStickerSet.inputStickerSetEmpty))
            case let .ImageSize(size):
                result.append(.documentAttributeImageSize(w: Int32(size.width), h: Int32(size.height)))
            case let .Video(duration, size):
                result.append(.documentAttributeVideo(duration: Int32(duration), w: Int32(size.width), h: Int32(size.height)))
            case let .Audio(isVoice, duration, title, performer, waveform):
                var flags: Int32 = 0
                if isVoice {
                    flags |= (1 << 10)
                }
                if let _ = title {
                    flags |= Int32(1 << 0)
                }
                if let _ = performer {
                    flags |= Int32(1 << 1)
                }
                var waveformBuffer: Buffer?
                if let waveform = waveform {
                    flags |= Int32(1 << 2)
                    waveformBuffer = Buffer(data: waveform.makeData())
                }
                result.append(.documentAttributeAudio(flags: flags, duration: Int32(duration), title: title, performer: performer, waveform: waveformBuffer))
            case .HasLinkedStickers:
                break
        }
    }
    return result
}

private func boxedDecryptedMessage(message: Message, globallyUniqueId: Int64, uploadedFile: SecretChatOutgoingFile?, layer: SecretChatLayer) -> BoxedDecryptedMessage {
    var media: Media? = message.media.first
    var messageAutoremoveTimeout: Int32 = 0
    for attribute in message.attributes {
        if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
            messageAutoremoveTimeout = attribute.timeout
        }
    }
    
    if let media = media {
        if let image = media as? TelegramMediaImage, let uploadedFile = uploadedFile, let largestRepresentation = largestImageRepresentation(image.representations) {
            switch layer {
                case .layer8:
                    let randomBytesData = malloc(15)!
                    arc4random_buf(randomBytesData, 15)
                    let randomBytes = Buffer(memory: randomBytesData, size: 15, capacity: 15, freeWhenDone: true)
                    
                    let decryptedMedia = SecretApi8.DecryptedMessageMedia.decryptedMessageMediaPhoto(thumb: Buffer(), thumbW: 90, thumbH: 90, w: Int32(largestRepresentation.dimensions.width), h: Int32(largestRepresentation.dimensions.height), size: uploadedFile.size, key: Buffer(data: uploadedFile.key.aesKey), iv: Buffer(data: uploadedFile.key.aesIv))
                    
                    return .layer8(.decryptedMessage(randomId: globallyUniqueId, randomBytes: randomBytes, message: message.text, media: decryptedMedia))
                case .layer46:
                    let decryptedMedia = SecretApi46.DecryptedMessageMedia.decryptedMessageMediaPhoto(thumb: Buffer(), thumbW: 90, thumbH: 90, w: Int32(largestRepresentation.dimensions.width), h: Int32(largestRepresentation.dimensions.height), size: uploadedFile.size, key: Buffer(data: uploadedFile.key.aesKey), iv: Buffer(data: uploadedFile.key.aesIv), caption: "")
                    
                    return .layer46(.decryptedMessage(flags: (1 << 9), randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: decryptedMedia, entities: nil, viaBotName: nil, replyToRandomId: nil))
            }
        } else if let file = media as? TelegramMediaFile {
            switch layer {
                case .layer8:
                    if let uploadedFile = uploadedFile {
                        let randomBytesData = malloc(15)!
                        arc4random_buf(randomBytesData, 15)
                        let randomBytes = Buffer(memory: randomBytesData, size: 15, capacity: 15, freeWhenDone: true)
                        
                        let decryptedMedia = SecretApi8.DecryptedMessageMedia.decryptedMessageMediaDocument(thumb: Buffer(), thumbW: 0, thumbH: 0, fileName: file.fileName ?? "file", mimeType: file.mimeType, size: uploadedFile.size, key: Buffer(data: uploadedFile.key.aesKey), iv: Buffer(data: uploadedFile.key.aesIv))
                    
                        return .layer8(.decryptedMessage(randomId: globallyUniqueId, randomBytes: randomBytes, message: message.text, media: decryptedMedia))
                    }
                case .layer46:
                    var decryptedMedia: SecretApi46.DecryptedMessageMedia?
                    
                    if let uploadedFile = uploadedFile {
                        var voiceDuration: Int32?
                        for attribute in file.attributes {
                            if case let .Audio(isVoice, duration, _, _, _) = attribute {
                                if isVoice {
                                    voiceDuration = Int32(duration)
                                }
                                break
                            }
                        }
                        
                        if let voiceDuration = voiceDuration {
                            decryptedMedia = SecretApi46.DecryptedMessageMedia.decryptedMessageMediaAudio(duration: voiceDuration, mimeType: file.mimeType, size: uploadedFile.size, key: Buffer(data: uploadedFile.key.aesKey), iv: Buffer(data: uploadedFile.key.aesIv))
                        } else {
                            decryptedMedia = SecretApi46.DecryptedMessageMedia.decryptedMessageMediaDocument(thumb: Buffer(), thumbW: 0, thumbH: 0, mimeType: file.mimeType, size: uploadedFile.size, key: Buffer(data: uploadedFile.key.aesKey), iv: Buffer(data: uploadedFile.key.aesIv), attributes: decryptedAttributes46(file.attributes), caption: "")
                        }
                    } else {
                        if let resource = file.resource as? CloudDocumentMediaResource, let size = file.size {
                            decryptedMedia = SecretApi46.DecryptedMessageMedia.decryptedMessageMediaExternalDocument(id: resource.fileId, accessHash: resource.accessHash, date: 0, mimeType: file.mimeType, size: Int32(size), thumb: SecretApi46.PhotoSize.photoSizeEmpty(type: "s"), dcId: Int32(resource.datacenterId), attributes: decryptedAttributes46(file.attributes))
                        }
                    }
                    
                    if let decryptedMedia = decryptedMedia {
                        return .layer46(.decryptedMessage(flags: (1 << 9), randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: decryptedMedia, entities: nil, viaBotName: nil, replyToRandomId: nil))
                    }
            }
        }
    }

    switch layer {
        case .layer8:
            let randomBytesData = malloc(15)!
            arc4random_buf(randomBytesData, 15)
            let randomBytes = Buffer(memory: randomBytesData, size: 15, capacity: 15, freeWhenDone: true)
            
            return .layer8(.decryptedMessage(randomId: globallyUniqueId, randomBytes: randomBytes, message: message.text, media: .decryptedMessageMediaEmpty))
        case .layer46:
            return .layer46(.decryptedMessage(flags: 0, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: .decryptedMessageMediaEmpty, entities: nil, viaBotName: nil, replyToRandomId: nil))
    }
}

private func boxedDecryptedSecretMessageAction(action: SecretMessageAction) -> BoxedDecryptedMessage {
    switch action {
        case let .deleteMessages(layer, actionGloballyUniqueId, globallyUniqueIds):
            switch layer {
                case .layer8:
                    let randomBytesData = malloc(15)!
                    arc4random_buf(randomBytesData, 15)
                    let randomBytes = Buffer(memory: randomBytesData, size: 15, capacity: 15, freeWhenDone: true)
                    
                    return .layer8(.decryptedMessageService(randomId: actionGloballyUniqueId, randomBytes: randomBytes, action: .decryptedMessageActionDeleteMessages(randomIds: globallyUniqueIds)))
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionDeleteMessages(randomIds: globallyUniqueIds)))
            }
        case let .clearHistory(layer, actionGloballyUniqueId):
            switch layer {
                case .layer8:
                    let randomBytesData = malloc(15)!
                    arc4random_buf(randomBytesData, 15)
                    let randomBytes = Buffer(memory: randomBytesData, size: 15, capacity: 15, freeWhenDone: true)
                    return .layer8(.decryptedMessageService(randomId: actionGloballyUniqueId, randomBytes: randomBytes, action: .decryptedMessageActionFlushHistory))
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionFlushHistory))
            }
        case let .resendOperations(layer, actionGloballyUniqueId, fromSeqNo, toSeqNo):
            switch layer {
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionResend(startSeqNo: fromSeqNo, endSeqNo: toSeqNo)))
            }
        case let .reportLayerSupport(layer, actionGloballyUniqueId, layerSupport):
            switch layer {
                case .layer8:
                    let randomBytesData = malloc(15)!
                    arc4random_buf(randomBytesData, 15)
                    let randomBytes = Buffer(memory: randomBytesData, size: 15, capacity: 15, freeWhenDone: true)
                    
                    return .layer8(.decryptedMessageService(randomId: actionGloballyUniqueId, randomBytes: randomBytes, action: .decryptedMessageActionNotifyLayer(layer: layerSupport)))
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionNotifyLayer(layer: layerSupport)))
            }
        case let .pfsRequestKey(layer, actionGloballyUniqueId, rekeySessionId, gA):
            switch layer {
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionRequestKey(exchangeId: rekeySessionId, gA: Buffer(buffer: gA))))
            }
        case let .pfsAcceptKey(layer, actionGloballyUniqueId, rekeySessionId, gB, keyFingerprint):
            switch layer {
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionAcceptKey(exchangeId: rekeySessionId, gB: Buffer(buffer: gB), keyFingerprint: keyFingerprint)))
            }
        case let .pfsAbortSession(layer, actionGloballyUniqueId, rekeySessionId):
            switch layer {
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionAbortKey(exchangeId: rekeySessionId)))
            }
        case let .pfsCommitKey(layer, actionGloballyUniqueId, rekeySessionId, keyFingerprint):
            switch layer {
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionCommitKey(exchangeId: rekeySessionId, keyFingerprint: keyFingerprint)))
            }
        case let .noop(layer, actionGloballyUniqueId):
            switch layer {
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionNoop))
            }
        case let .readMessageContents(layer, actionGloballyUniqueId, globallyUniqueIds):
            switch layer {
                case .layer8:
                    let randomBytesData = malloc(15)!
                    arc4random_buf(randomBytesData, 15)
                    let randomBytes = Buffer(memory: randomBytesData, size: 15, capacity: 15, freeWhenDone: true)
                    
                    return .layer8(.decryptedMessageService(randomId: actionGloballyUniqueId, randomBytes: randomBytes, action: .decryptedMessageActionReadMessages(randomIds: globallyUniqueIds)))
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionReadMessages(randomIds: globallyUniqueIds)))
            }
        case let .setMessageAutoremoveTimeout(layer, actionGloballyUniqueId, timeout):
            switch layer {
                case .layer8:
                    let randomBytesData = malloc(15)!
                    arc4random_buf(randomBytesData, 15)
                    let randomBytes = Buffer(memory: randomBytesData, size: 15, capacity: 15, freeWhenDone: true)
                    
                    return .layer8(.decryptedMessageService(randomId: actionGloballyUniqueId, randomBytes: randomBytes, action: .decryptedMessageActionSetMessageTTL(ttlSeconds: timeout)))
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionSetMessageTTL(ttlSeconds: timeout)))
            }
    }
}

private func markOutgoingOperationAsCompleted(modifier: Modifier, peerId: PeerId, tagLocalIndex: Int32) {
    var removeFromTagMergedIndexOnly = false
    if let state = modifier.getPeerChatState(peerId) as? SecretChatState {
        switch state.embeddedState {
            case let .sequenceBasedLayer(sequenceState):
                if tagLocalIndex >= sequenceState.baseOutgoingOperationIndex {
                    removeFromTagMergedIndexOnly = true
                }
            default:
                break
        }
    }
    if removeFromTagMergedIndexOnly {
        modifier.operationLogUpdateEntry(peerId: peerId, tag: OperationLogTags.SecretOutgoing, tagLocalIndex: tagLocalIndex, { entry in
            if let operation = entry?.contents as? SecretChatOutgoingOperation {
                return PeerOperationLogEntryUpdate(mergedIndex: .remove, contents: .update(operation.withUpdatedDelivered(true)))
            } else {
                assertionFailure()
                return PeerOperationLogEntryUpdate(mergedIndex: .remove, contents: .none)
            }
        })
    } else {
        modifier.operationLogRemoveEntry(peerId: peerId, tag: OperationLogTags.SecretOutgoing, tagLocalIndex: tagLocalIndex)
    }
}

private func sendMessage(postbox: Postbox, network: Network, messageId: MessageId, file: SecretChatOutgoingFile?, tagLocalIndex: Int32, wasDelivered: Bool, layer: SecretChatLayer) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Signal<Void, NoError> in
        if let state = modifier.getPeerChatState(messageId.peerId) as? SecretChatState, let peer = modifier.getPeer(messageId.peerId) as? TelegramSecretChat {
            if let message = modifier.getMessage(messageId), let globallyUniqueId = message.globallyUniqueId {
                let decryptedMessage = boxedDecryptedMessage(message: message, globallyUniqueId: globallyUniqueId, uploadedFile: file, layer: layer)
                return sendBoxedDecryptedMessage(postbox: postbox, network: network, peer: peer, state: state, operationIndex: tagLocalIndex, decryptedMessage: decryptedMessage, globallyUniqueId: globallyUniqueId, file: file, asService: false, wasDelivered: wasDelivered)
                    |> mapToSignal { result in
                        return postbox.modify { modifier -> Void in
                            markOutgoingOperationAsCompleted(modifier: modifier, peerId: messageId.peerId, tagLocalIndex: tagLocalIndex)
                            modifier.updateMessage(message.id, update: { currentMessage in
                                var flags = StoreMessageFlags(currentMessage.flags)
                                var timestamp = message.timestamp
                                if let result = result {
                                    switch result {
                                        case let .sentEncryptedMessage(date):
                                            timestamp = date
                                        case let .sentEncryptedFile(date, file):
                                            timestamp = date
                                    }
                                    flags.remove(.Unsent)
                                    flags.remove(.Sending)
                                } else {
                                    flags = [.Failed]
                                }
                                var storeForwardInfo: StoreMessageForwardInfo?
                                if let forwardInfo = currentMessage.forwardInfo {
                                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date)
                                }
                                return StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, timestamp: timestamp, flags: flags, tags: currentMessage.tags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media)
                            })
                        }
                }
            } else {
                assertionFailure()
                return .never()
            }
            return .complete()
        } else {
            return .complete()
        }
    } |> switchToLatest
}

private func sendServiceActionMessage(postbox: Postbox, network: Network, peerId: PeerId, action: SecretMessageAction, tagLocalIndex: Int32, wasDelivered: Bool) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Signal<Void, NoError> in
        if let state = modifier.getPeerChatState(peerId) as? SecretChatState, let peer = modifier.getPeer(peerId) as? TelegramSecretChat {
            let decryptedMessage = boxedDecryptedSecretMessageAction(action: action)
            return sendBoxedDecryptedMessage(postbox: postbox, network: network, peer: peer, state: state, operationIndex: tagLocalIndex, decryptedMessage: decryptedMessage, globallyUniqueId: action.globallyUniqueId, file: nil, asService: true, wasDelivered: wasDelivered)
                |> mapToSignal { result in
                    return postbox.modify { modifier -> Void in
                        markOutgoingOperationAsCompleted(modifier: modifier, peerId: peerId, tagLocalIndex: tagLocalIndex)
                    }
                }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

private func sendBoxedDecryptedMessage(postbox: Postbox, network: Network, peer: TelegramSecretChat, state: SecretChatState, operationIndex: Int32, decryptedMessage: BoxedDecryptedMessage, globallyUniqueId: Int64, file: SecretChatOutgoingFile?, asService: Bool, wasDelivered: Bool) -> Signal<Api.messages.SentEncryptedMessage?, NoError> {
    let payload = Buffer()
    var sequenceInfo: SecretChatOperationSequenceInfo?
    var maybeKey: SecretChatKey?
    switch state.embeddedState {
        case .terminated, .handshake:
            break
        case .basicLayer:
            maybeKey = state.keychain.indefinitelyValidKey()
        case let .sequenceBasedLayer(sequenceState):
            let topReceivedOperationIndex: Int32
            if let topProcessedCanonicalIncomingOperationIndex = sequenceState.topProcessedCanonicalIncomingOperationIndex {
                topReceivedOperationIndex = topProcessedCanonicalIncomingOperationIndex
            } else {
                topReceivedOperationIndex = -1
            }
            let canonicalOperationIndex = sequenceState.canonicalOutgoingOperationIndex(operationIndex)
            maybeKey = state.keychain.latestKey(validForSequenceBasedCanonicalIndex: canonicalOperationIndex)
            Logger.shared.log("SecretChat", "sending message with index \(canonicalOperationIndex) key \(maybeKey?.fingerprint)")
            sequenceInfo = SecretChatOperationSequenceInfo(topReceivedOperationIndex: topReceivedOperationIndex, operationIndex: canonicalOperationIndex)
    }
    
    guard let key = maybeKey else {
        Logger.shared.log("SecretChat", "no valid key found")
        return .single(nil)
    }
    
    decryptedMessage.serialize(payload, role: state.role, sequenceInfo: sequenceInfo)
    let encryptedPayload = encryptedMessageContents(key: key, data: MemoryBuffer(payload))
    let sendMessage: Signal<Api.messages.SentEncryptedMessage, MTRpcError>
    let inputPeer = Api.InputEncryptedChat.inputEncryptedChat(chatId: peer.id.id, accessHash: peer.accessHash)
    
    /*if !wasDelivered && arc4random_uniform(100) < 20 {
        let timestamp = Int32(network.context.globalTime())
        sendMessage = .single(Api.messages.SentEncryptedMessage.sentEncryptedMessage(date: timestamp))
        print("dropping secret message")
    } else */if asService {
        sendMessage = network.request(Api.functions.messages.sendEncryptedService(peer: inputPeer, randomId: globallyUniqueId, data: Buffer(data: encryptedPayload)))
    } else {
        if let file = file {
            sendMessage = network.request(Api.functions.messages.sendEncryptedFile(peer: inputPeer, randomId: globallyUniqueId, data: Buffer(data: encryptedPayload), file: file.reference.apiInputFile))
        } else {
            sendMessage = network.request(Api.functions.messages.sendEncrypted(peer: inputPeer, randomId: globallyUniqueId, data: Buffer(data: encryptedPayload)))
        }
    }
    return sendMessage
        |> map { next -> Api.messages.SentEncryptedMessage? in
            return next
        }
        |> `catch`{ _ in
            return .single(nil)
        }
}
