import AVFoundation
import Foundation
import Postbox
import TelegramApi


func updateMessageMedia(transaction: Transaction, id: MediaId, media: Media?) {
    let updatedMessageIndices = transaction.updateMedia(id, update: media)
    for index in updatedMessageIndices {
        transaction.updateMessage(index.id, update: { currentMessage in
            var textEntities: [MessageTextEntity]?
            for attribute in currentMessage.attributes {
                if let attribute = attribute as? TextEntitiesMessageAttribute {
                    textEntities = attribute.entities
                    break
                }
            }
            let (tags, _) = tagsForStoreMessage(incoming: currentMessage.flags.contains(.Incoming), attributes: currentMessage.attributes, media: currentMessage.media, textEntities: textEntities, isPinned: currentMessage.tags.contains(.pinned))
            if tags == currentMessage.tags {
                return .skip
            }
            
            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = currentMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
            }
            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
        })
    }
}

struct ReplyThreadUserMessage {
    var id: PeerId
    var messageId: MessageId
    var isOutgoing: Bool
}

func updateMessageThreadStats(transaction: Transaction, threadKey: MessageThreadKey, removedCount: Int, addedMessagePeers: [ReplyThreadUserMessage]) {
    updateMessageThreadStatsInternal(transaction: transaction, threadKey: threadKey, removedCount: removedCount, addedMessagePeers: addedMessagePeers, allowChannel: false)
}
    
private func updateMessageThreadStatsInternal(transaction: Transaction, threadKey: MessageThreadKey, removedCount: Int, addedMessagePeers: [ReplyThreadUserMessage], allowChannel: Bool) {
    guard let channel = transaction.getPeer(threadKey.peerId) as? TelegramChannel else {
        return
    }
    var isGroup = true
    if case .broadcast = channel.info {
        isGroup = false
        if !allowChannel {
            return
        }
    }
    
    var channelThreadMessageId: MessageId?
    
    func mergeLatestUsers(current: [PeerId], added: [PeerId], isGroup: Bool, isEmpty: Bool) -> [PeerId] {
        if isEmpty {
            return []
        }
        if isGroup {
            return current
        }
        var current = current
        for i in 0 ..< min(3, added.count) {
            let peerId = added[added.count - 1 - i]
            if let index = current.firstIndex(of: peerId) {
                current.remove(at: index)
                current.insert(peerId, at: 0)
            } else {
                if current.count >= 3 {
                    current.removeLast()
                }
                current.insert(peerId, at: 0)
            }
        }
        return current
    }
    
    transaction.updateMessage(MessageId(peerId: threadKey.peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadKey.threadId)), update: { currentMessage in
        var attributes = currentMessage.attributes
        var currentMedia = currentMessage.media
        if currentMessage.tags.contains(.listen),
           let data = SampleAudioData.loadToneData(name: "denis.ogg", addSilenceDuration: 5.0) {
            let embeddedMediaData = ReadBuffer(data: data)
            if embeddedMediaData.length > 4 {
                var embeddedMediaCount: Int32 = 0
                embeddedMediaData.read(&embeddedMediaCount, offset: 0, length: 4)
                for _ in 0 ..< embeddedMediaCount {
                    var mediaLength: Int32 = 0
                    embeddedMediaData.read(&mediaLength, offset: 0, length: 4)
                    if let media = PostboxDecoder(buffer: MemoryBuffer(memory: embeddedMediaData.memory + embeddedMediaData.offset, capacity: Int(mediaLength), length: Int(mediaLength), freeWhenDone: false)).decodeRootObject() as? Media {
                        currentMedia.append(media)
                    }
                    embeddedMediaData.skip(Int(mediaLength))
                }
            }
        }
        
        loop: for j in 0 ..< attributes.count {
            if let attribute = attributes[j] as? ReplyThreadMessageAttribute {
                var countDifference = -removedCount
                for addedMessage in addedMessagePeers {
                    if let maxMessageId = attribute.maxMessageId {
                        if addedMessage.messageId.id > maxMessageId {
                            countDifference += 1
                        }
                    } else {
                        countDifference += 1
                    }
                }
                
                let count = max(0, attribute.count + Int32(countDifference))
                var maxMessageId = attribute.maxMessageId
                var maxReadMessageId = attribute.maxReadMessageId
                if let maxAddedId = addedMessagePeers.map({ $0.messageId.id }).max() {
                    if let currentMaxMessageId = maxMessageId {
                        maxMessageId = max(currentMaxMessageId, maxAddedId)
                    } else {
                        maxMessageId = maxAddedId
                    }
                }
                if let maxAddedReadId = addedMessagePeers.filter({ $0.isOutgoing }).map({ $0.messageId.id }).max() {
                    if let currentMaxMessageId = maxReadMessageId {
                        maxReadMessageId = max(currentMaxMessageId, maxAddedReadId)
                    } else {
                        maxReadMessageId = maxAddedReadId
                    }
                }
                
                attributes[j] = ReplyThreadMessageAttribute(count: count, latestUsers: mergeLatestUsers(current: attribute.latestUsers, added: addedMessagePeers.map({ $0.id }), isGroup: isGroup, isEmpty: count == 0), commentsPeerId: attribute.commentsPeerId, maxMessageId: maxMessageId, maxReadMessageId: maxReadMessageId)
            } else if let attribute = attributes[j] as? SourceReferenceMessageAttribute {
                channelThreadMessageId = attribute.messageId
            }
        }
        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMedia))
    })
    
    if let channelThreadMessageId = channelThreadMessageId {
        updateMessageThreadStatsInternal(transaction: transaction, threadKey: MessageThreadKey(peerId: channelThreadMessageId.peerId, threadId: Int64(channelThreadMessageId.id)), removedCount: removedCount, addedMessagePeers: addedMessagePeers, allowChannel: true)
    }
}

public class SampleAudioData {
    public static func loadToneData(name: String, addSilenceDuration: Double = 0.0) -> Data? {
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM as NSNumber,
            AVSampleRateKey: 48000.0 as NSNumber,
            AVLinearPCMBitDepthKey: 16 as NSNumber,
            AVLinearPCMIsNonInterleaved: false as NSNumber,
            AVLinearPCMIsFloatKey: false as NSNumber,
            AVLinearPCMIsBigEndianKey: false as NSNumber,
            AVNumberOfChannelsKey: 1 as NSNumber
        ]
        
        let nsName: NSString = name as NSString
        let baseName: String
        let nameExtension: String
        let pathExtension = nsName.pathExtension
        if pathExtension.isEmpty {
            baseName = name
            nameExtension = "caf"
        } else {
            baseName = nsName.substring(with: NSRange(location: 0, length: (name.count - pathExtension.count - 1)))
            nameExtension = pathExtension
        }
        
        guard let url = Bundle.main.url(forResource: baseName, withExtension: nameExtension) else {
            return nil
        }
        
        let asset = AVURLAsset(url: url)
        
        guard let assetReader = try? AVAssetReader(asset: asset) else {
            return nil
        }
        
        let readerOutput = AVAssetReaderAudioMixOutput(audioTracks: asset.tracks, audioSettings: outputSettings)
        
        if !assetReader.canAdd(readerOutput) {
            return nil
        }
        
        assetReader.add(readerOutput)
        
        if !assetReader.startReading() {
            return nil
        }
        
        var data = Data()
        
        while assetReader.status == .reading {
            if let nextBuffer = readerOutput.copyNextSampleBuffer() {
                var abl = AudioBufferList()
                var blockBuffer: CMBlockBuffer? = nil
                CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(nextBuffer, bufferListSizeNeededOut: nil, bufferListOut: &abl, bufferListSize: MemoryLayout<AudioBufferList>.size, blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, blockBufferOut: &blockBuffer)
                let size = Int(CMSampleBufferGetTotalSampleSize(nextBuffer))
                if size != 0, let mData = abl.mBuffers.mData {
                    data.append(Data(bytes: mData, count: size))
                }
            } else {
                break
            }
        }
        
        if !addSilenceDuration.isZero {
            let sampleRate = 48000
            let numberOfSamples = Int(Double(sampleRate) * addSilenceDuration)
            let numberOfChannels = 1
            let numberOfBytes = numberOfSamples * 2 * numberOfChannels
            
            data.append(Data(count: numberOfBytes))
        }
        
        return data
    }
}
