import Foundation
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import LegacyComponents

private func importMediaFromMessageData(_ data: Data, basePath: String, copyLocalFiles: inout [(MediaResource, String)], cache: TGCache) {
    if let message = TGMessage(keyValueCoder: PSKeyValueDecoder(data: data)) {
        if let mediaAttachments = message.mediaAttachments {
            importMediaFromMediaList(mediaAttachments, basePath: basePath, copyLocalFiles: &copyLocalFiles, cache: cache)
        }
    }
}

private func importMediaFromMediaData(_ data: Data, basePath: String, copyLocalFiles: inout [(MediaResource, String)], cache: TGCache) {
    if let mediaAttachments = TGMessage.parseMediaAttachments(data) {
        importMediaFromMediaList(mediaAttachments, basePath: basePath, copyLocalFiles: &copyLocalFiles, cache: cache)
    }
}

private func importMediaFromMediaList(_ mediaAttachments: [Any], basePath: String, copyLocalFiles: inout [(MediaResource, String)], cache: TGCache) {
    for media in mediaAttachments {
        if let media = media as? TGDocumentMediaAttachment {
            var fileName = "file"
            if let itemAttributes = media.attributes {
                for attribute in itemAttributes {
                    if let attribute = attribute as? TGDocumentAttributeFilename {
                        fileName = attribute.filename ?? "file"
                    }
                }
            }
            
            if media.documentId != 0 {
                let filePath = pathFromLegacyFile(basePath: basePath, fileId: media.documentId, isLocal: false, fileName: TGDocumentMediaAttachment.safeFileName(forFileName: fileName) ?? "")
                if FileManager.default.fileExists(atPath: filePath) {
                    copyLocalFiles.append((CloudDocumentMediaResource(datacenterId: Int(media.datacenterId), fileId: media.documentId, accessHash: media.accessHash, size: nil, fileReference: nil, fileName: nil), filePath))
                }
            }
        } else if let media = media as? TGVideoMediaAttachment {
            if media.videoId != 0, let videoUrl = media.videoInfo?.url(withQuality: 1, actualQuality: nil, actualSize: nil) {
                if let (id, accessHash, datacenterId, path) = pathFromLegacyVideoUrl(basePath: basePath, url: videoUrl) {
                    copyLocalFiles.append((CloudDocumentMediaResource(datacenterId: Int(datacenterId), fileId: id, accessHash: accessHash, size: nil, fileReference: nil, fileName: nil), path))
                }
            }
        } else if let media = media as? TGImageMediaAttachment {
            if let allSizes = media.imageInfo?.allSizes() as? [String: NSValue] {
                for (imageUrl, _) in allSizes {
                    if let path = cache.path(forCachedData: imageUrl), let resource = resourceFromLegacyImageUrl(imageUrl), FileManager.default.fileExists(atPath: path) {
                        copyLocalFiles.append((resource, path))
                    }
                }
            }
        }
    }
}

private func makeMessageSortKey(tag: Int32, conversationId: Int64, space: Int8, timestamp: Int32, messageId: Int32) -> Data {
    let key = ValueBoxKey(length: 4 + 8 + 1 + 4 + 4)
    key.setInt32(0, value: tag.byteSwapped)
    key.setInt64(4, value: conversationId.byteSwapped)
    key.setInt8(4 + 8, value: space)
    key.setInt32(4 + 8 + 1, value: timestamp)
    key.setInt32(4 + 8 + 1 + 4, value: messageId.byteSwapped)
    return Data(bytes: key.memory, count: key.length)
}

func loadLegacyFiles(account: TemporaryAccount, basePath: String, accountPeerId: PeerId, database: SqliteInterface) -> Signal<Float, NoError> {
    return Signal<Float, NoError> { subscriber in
        let _ = registeredAttachmentParsers
        
        subscriber.putNext(0.0)
        
        var channelIds: [Int64] = []
        database.select("SELECT DISTINCT cid FROM channel_message_tags_v29", { cursor in
            channelIds.append(cursor.getInt64(at: 0))
            return true
        })
        print(database.explain("SELECT DISTINCT cid FROM channel_message_tags_v29"))
        
        var channelMessageIds: [(Int64, Int32)] = []
        
        print(database.explain("SELECT mid FROM channel_message_tags_v29 WHERE tag_sort_key<100 AND tag_sort_key>0 ORDER BY tag_sort_key DESC LIMIT 4000"))
        
        if !channelIds.isEmpty {
            /*
             TGSharedMediaCacheItemTypePhoto = 0,
             TGSharedMediaCacheItemTypeVideo = 1,
             TGSharedMediaCacheItemTypeFile = 2,
             TGSharedMediaCacheItemTypePhotoVideo = 3,
             TGSharedMediaCacheItemTypePhotoVideoFile = 4,
             TGSharedMediaCacheItemTypeAudio = 5,
             TGSharedMediaCacheItemTypeLink = 6,
             TGSharedMediaCacheItemTypeSticker = 7,
             TGSharedMediaCacheItemTypeGif = 8,
             TGSharedMediaCacheItemTypeVoiceVideoMessage = 9
             */
            let tags: [Int32] = [
                2, // File
                5, // Audio
                3, // PhotoVideo
            ]
            database.withStatement("SELECT mid FROM channel_message_tags_v29 WHERE tag_sort_key<? AND tag_sort_key>? ORDER BY tag_sort_key DESC LIMIT 4000", { select in
                for channelId in channelIds {
                    for tag in tags {
                        select([.data(makeMessageSortKey(tag: tag, conversationId: channelId, space: 0, timestamp: Int32.max - 1, messageId: 0)), .data(makeMessageSortKey(tag: tag, conversationId: channelId, space: 0, timestamp: 0, messageId: 0))], { cursor in
                            channelMessageIds.append((channelId, cursor.getInt32(at: 0)))
                            return true
                        })
                        select([.data(makeMessageSortKey(tag: tag, conversationId: channelId, space: 1, timestamp: Int32.max - 1, messageId: 0)), .data(makeMessageSortKey(tag: tag, conversationId: channelId, space: 1, timestamp: 0, messageId: 0))], { cursor in
                            channelMessageIds.append((channelId, cursor.getInt32(at: 0)))
                            return true
                        })
                    }
                }
            })
        }
        
        var chatMessageIds: [Int32] = []
        let mediaTypes: [Int32] = [
            1, // video
            2, // image
            3, // file
        ]
        for type in mediaTypes {
            database.select("SELECT mids FROM media_cache_v29 WHERE media_type=\(type) ORDER BY date DESC LIMIT 32000", { cursor in
                let midsData = cursor.getData(at: 0)
                let reader = LegacyBufferReader(LegacyBuffer(data: midsData))
                while true {
                    if let mid = reader.readInt32() {
                        chatMessageIds.append(mid)
                    } else {
                        break
                    }
                }
                return true
            })
        }
        
        var copyLocalFiles: [(MediaResource, String)] = []
        
        let totalCount = channelMessageIds.count + chatMessageIds.count
        let reportBase = max(1, totalCount / 100)
        
        var itemIndex = -1
        
        let cache = TGCache(cachesPath: basePath + "/Caches")!
        
        if !channelMessageIds.isEmpty {
            database.withStatement("SELECT data FROM channel_messages_v29 WHERE cid=? AND mid=?", { select in
                for (peerId, messageId) in channelMessageIds {
                    itemIndex += 1
                    if itemIndex % reportBase == 0 {
                        subscriber.putNext(Float(itemIndex) / Float(totalCount))
                    }
                    select([.int64(peerId), .int32(messageId)], { cursor in
                        let data = cursor.getData(at: 0)
                        importMediaFromMessageData(data, basePath: basePath, copyLocalFiles: &copyLocalFiles, cache: cache)
                        return true
                    })
                }
            })
        }
        
        if !chatMessageIds.isEmpty {
            database.withStatement("SELECT media FROM messages_v29 WHERE mid=?", { select in
                for messageId in chatMessageIds {
                    itemIndex += 1
                    if itemIndex % reportBase == 0 {
                        subscriber.putNext(Float(itemIndex) / Float(totalCount))
                    }
                    select([.int32(messageId)], { cursor in
                        let data = cursor.getData(at: 0)
                        importMediaFromMediaData(data, basePath: basePath, copyLocalFiles: &copyLocalFiles, cache: cache)
                        return true
                    })
                }
            })
        }
        
        for (resource, path) in copyLocalFiles {
            account.postbox.mediaBox.copyResourceData(resource.id, fromTempPath: path)
        }
        
        subscriber.putCompletion()
        
        return EmptyDisposable
    }
}
