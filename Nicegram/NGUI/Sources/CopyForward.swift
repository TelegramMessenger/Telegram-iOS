//
//  CopyForward.swift
//  NGUI
//
//  Created by Sergey on 19.09.2020.
//

import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore
import SyncCore


public var MessagesToCopy: [EnqueueMessage] = []
public var MessagesToCopyDict: [MessageId:EnqueueMessage] = [:]
// public var SelectedMessagesToCopy: [Message] = []

public func convertMessagesForEnqueue(_ messages: [Message]) -> [EnqueueMessage] {
    var messagesToC: [EnqueueMessage] = []
    for m in messages {
        var media: AnyMediaReference?
        if !m.media.isEmpty {
            media = .standalone(media: m.media[0])
        }
        let enqMsg: EnqueueMessage = .message(text: m.text, attributes: m.attributes, mediaReference: media, replyToMessageId: nil, localGroupingKey: m.groupingKey)
        messagesToC.append(enqMsg)
    }
    return messagesToC
}

public func convertMessagesForEnqueueDict(_ messages: [Message]) -> [MessageId:EnqueueMessage] {
    var messagesToC: [MessageId:EnqueueMessage] = [:]
    for m in messages {
        var media: AnyMediaReference?
        if !m.media.isEmpty {
            media = .standalone(media: m.media[0])
        }
        let enqMsg: EnqueueMessage = .message(text: m.text, attributes: m.attributes, mediaReference: media, replyToMessageId: nil, localGroupingKey: m.groupingKey)
        messagesToC[m.id] = enqMsg
    }
    return messagesToC
}
