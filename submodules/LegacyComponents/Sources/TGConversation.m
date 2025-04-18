#import "TGConversation.h"

#import "LegacyComponentsInternal.h"
#import "TGStringUtils.h"
#import "TGMessage.h"

#import "PSKeyValueCoder.h"

#import "TGPeerIdAdapter.h"

#import "TGImageInfo.h"
#import "TGMediaOriginInfo.h"

@implementation TGEncryptedConversationData

- (BOOL)isEqualToEncryptedData:(TGEncryptedConversationData *)other
{
    if (_encryptedConversationId != other->_encryptedConversationId || _accessHash != other->_accessHash || _keyFingerprint != other->_keyFingerprint || _handshakeState != other->_handshakeState || _currentRekeyExchangeId != other->_currentRekeyExchangeId)
        return false;
    
    return true;
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGEncryptedConversationData *data = [[TGEncryptedConversationData alloc] init];
    data->_encryptedConversationId = _encryptedConversationId;
    data->_accessHash = _accessHash;
    data->_keyFingerprint = _keyFingerprint;
    data->_handshakeState = _handshakeState;
    data->_currentRekeyExchangeId = _currentRekeyExchangeId;
    data->_currentRekeyIsInitiatedByLocalClient = _currentRekeyIsInitiatedByLocalClient;
    data->_currentRekeyNumber = _currentRekeyNumber;
    data->_currentRekeyKey = _currentRekeyKey;
    data->_currentRekeyKeyId = _currentRekeyKeyId;
    
    return data;
}

- (void)serialize:(NSMutableData *)data
{
    uint8_t version = 3;
    [data appendBytes:&version length:1];
    [data appendBytes:&_encryptedConversationId length:8];
    [data appendBytes:&_accessHash length:8];
    [data appendBytes:&_keyFingerprint length:8];
    [data appendBytes:&_handshakeState length:4];
    [data appendBytes:&_currentRekeyExchangeId length:8];
    uint8_t currentRekeyIsInitiatedByLocalClient = _currentRekeyIsInitiatedByLocalClient ? 1 : 0;
    [data appendBytes:&currentRekeyIsInitiatedByLocalClient length:1];
    int32_t currentRekeyNumberLength = (int32_t)_currentRekeyNumber.length;
    [data appendBytes:&currentRekeyNumberLength length:4];
    if (_currentRekeyNumber != nil)
        [data appendData:_currentRekeyNumber];
    int32_t currentRekeyKeyLength = (int32_t)_currentRekeyKey.length;
    [data appendBytes:&currentRekeyKeyLength length:4];
    if (_currentRekeyKey != nil)
        [data appendData:_currentRekeyKey];
    [data appendBytes:&_currentRekeyKeyId length:8];
}

+ (TGEncryptedConversationData *)deserialize:(NSData *)data ptr:(int *)ptr
{
    uint8_t version = 0;
    [data getBytes:&version range:NSMakeRange(*ptr, 1)];
    (*ptr) += 1;
    
    if (version != 1 && version != 2 && version != 3)
    {
        TGLegacyLog(@"***** Invalid encrypted data version");
        return nil;
    }
    
    TGEncryptedConversationData *encryptedData = [TGEncryptedConversationData new];

    [data getBytes:&encryptedData->_encryptedConversationId range:NSMakeRange(*ptr, 8)];
    (*ptr) += 8;
    
    [data getBytes:&encryptedData->_accessHash range:NSMakeRange(*ptr, 8)];
    (*ptr) += 8;
    
    [data getBytes:&encryptedData->_keyFingerprint range:NSMakeRange(*ptr, 8)];
    (*ptr) += 8;
    
    if (version >= 2)
    {
        [data getBytes:&encryptedData->_handshakeState range:NSMakeRange(*ptr, 4)];
        *ptr += 4;
    }
    
    if (version >= 3)
    {
        [data getBytes:&encryptedData->_currentRekeyExchangeId range:NSMakeRange(*ptr, 8)];
        *ptr += 8;
        
        uint8_t currentRekeyIsInitiatedByLocalClient = 0;
        [data getBytes:&currentRekeyIsInitiatedByLocalClient range:NSMakeRange(*ptr, 1)];
        encryptedData->_currentRekeyIsInitiatedByLocalClient = currentRekeyIsInitiatedByLocalClient;
        *ptr += 1;
        
        int32_t currentRekeyNumberLength = 0;
        [data getBytes:&currentRekeyNumberLength range:NSMakeRange(*ptr, 4)];
        *ptr += 4;
        
        if (currentRekeyNumberLength != 0)
        {
            encryptedData->_currentRekeyNumber = [data subdataWithRange:NSMakeRange(*ptr, currentRekeyNumberLength)];
            *ptr += currentRekeyNumberLength;
        }
        
        int32_t currentRekeyKeyLength = 0;
        [data getBytes:&currentRekeyKeyLength range:NSMakeRange(*ptr, 4)];
        *ptr += 4;
        
        if (currentRekeyKeyLength != 0)
        {
            encryptedData->_currentRekeyKey = [data subdataWithRange:NSMakeRange(*ptr, currentRekeyKeyLength)];
            *ptr += currentRekeyKeyLength;
        }
        
        [data getBytes:&encryptedData->_currentRekeyKeyId range:NSMakeRange(*ptr, 8)];
        *ptr += 8;
    }
    
    return encryptedData;
}

@end

@implementation TGConversationParticipantsData

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        _serializedData = nil;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGConversationParticipantsData *participantsData = [[TGConversationParticipantsData alloc] init];
    
    participantsData.chatAdminId = _chatAdminId;
    participantsData.chatInvitedBy = _chatInvitedBy;
    participantsData.chatInvitedDates = _chatInvitedDates;
    participantsData.chatParticipantUids = _chatParticipantUids;
    participantsData.chatParticipantSecretChatPeerIds = _chatParticipantSecretChatPeerIds;
    participantsData.chatParticipantChatPeerIds = _chatParticipantChatPeerIds;
    participantsData.chatAdminUids = _chatAdminUids;
    participantsData.version = _version;
    participantsData.exportedChatInviteString = _exportedChatInviteString;
    
    return participantsData;
}

- (void)addParticipantWithId:(int32_t)uid invitedBy:(int32_t)invitedBy date:(int32_t)date
{
    NSMutableArray *chatParticipantUids = [[NSMutableArray alloc] initWithArray:_chatParticipantUids];
    if (![chatParticipantUids containsObject:@(uid)])
    {
        [chatParticipantUids addObject:@(uid)];
        _chatParticipantUids = chatParticipantUids;
        
        NSMutableDictionary *chatInvitedBy = [[NSMutableDictionary alloc] initWithDictionary:_chatInvitedBy];
        chatInvitedBy[@(uid)] = @(invitedBy);
        _chatInvitedBy = chatInvitedBy;
        
        NSMutableDictionary *chatInvitedDates = [[NSMutableDictionary alloc] initWithDictionary:_chatInvitedDates];
        chatInvitedDates[@(uid)] = @(date);
        _chatInvitedDates = chatInvitedDates;
    }
}

- (void)removeParticipantWithId:(int32_t)uid
{
    NSMutableArray *chatParticipantUids = [[NSMutableArray alloc] initWithArray:_chatParticipantUids];
    [chatParticipantUids removeObject:@(uid)];
    _chatParticipantUids = chatParticipantUids;
    
    NSMutableDictionary *chatInvitedBy = [[NSMutableDictionary alloc] initWithDictionary:_chatInvitedBy];
    [chatInvitedBy removeObjectForKey:@(uid)];
    _chatInvitedBy = chatInvitedBy;
    
    NSMutableDictionary *chatInvitedDates = [[NSMutableDictionary alloc] initWithDictionary:_chatInvitedDates];
    [chatInvitedDates removeObjectForKey:@(uid)];
    _chatInvitedDates = chatInvitedDates;
    
    NSMutableSet *chatAdminUids = [[NSMutableSet alloc] initWithSet:_chatAdminUids];
    [chatAdminUids removeObject:@(uid)];
    _chatAdminUids = chatAdminUids;
}

- (void)addSecretChatPeerWithId:(int64_t)peerId
{
    NSMutableArray *chatParticipantSecretChatPeerIds = [[NSMutableArray alloc] initWithArray:_chatParticipantSecretChatPeerIds];
    if (![chatParticipantSecretChatPeerIds containsObject:@(peerId)])
    {
        [chatParticipantSecretChatPeerIds addObject:@(peerId)];
        _chatParticipantSecretChatPeerIds = chatParticipantSecretChatPeerIds;
    }
}

- (void)removeSecretChatPeerWithId:(int64_t)peerId
{
    NSMutableArray *chatParticipantSecretChatPeerIds = [[NSMutableArray alloc] initWithArray:_chatParticipantSecretChatPeerIds];
    [chatParticipantSecretChatPeerIds removeObject:@(peerId)];
    _chatParticipantSecretChatPeerIds = chatParticipantSecretChatPeerIds;
}

- (void)addChatPeerWithId:(int64_t)peerId
{
    NSMutableArray *chatParticipantChatPeerIds = [[NSMutableArray alloc] initWithArray:_chatParticipantChatPeerIds];
    if (![chatParticipantChatPeerIds containsObject:@(peerId)])
    {
        [chatParticipantChatPeerIds addObject:@(peerId)];
        _chatParticipantChatPeerIds = chatParticipantChatPeerIds;
    }
}

- (void)removeChatPeerWithId:(int64_t)peerId
{
    NSMutableArray *chatParticipantChatPeerIds = [[NSMutableArray alloc] initWithArray:_chatParticipantChatPeerIds];
    [chatParticipantChatPeerIds removeObject:@(peerId)];
    _chatParticipantChatPeerIds = chatParticipantChatPeerIds;
}

+ (TGConversationParticipantsData *)deserializeData:(NSData *)data
{
    TGConversationParticipantsData *participantsData = [[TGConversationParticipantsData alloc] init];
    
    int length = (int)data.length;
    int ptr = 0;
    if (ptr + 12 > length)
    {
        return nil;
    }
    
    int version = 0;
    [data getBytes:&version range:NSMakeRange(ptr, 4)];
    ptr += 4;
    
    int32_t formatVersion = 0;
    if (version == (int)0xabcdef12)
    {
        [data getBytes:&formatVersion range:NSMakeRange(ptr, 4)];
        ptr += 4;
        
        [data getBytes:&version range:NSMakeRange(ptr, 4)];
        ptr += 4;
    }
    
    int adminId = 0;
    [data getBytes:&adminId range:NSMakeRange(ptr, 4)];
    ptr += 4;
    
    int count = 0;
    [data getBytes:&count range:NSMakeRange(ptr, 4)];
    ptr += 4;
    
    NSMutableArray *uids = [[NSMutableArray alloc] init];
    NSMutableDictionary *invitedBy = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *invitedDates = [[NSMutableDictionary alloc] init];
    
    for (int i = 0; i < count; i++)
    {
        if (ptr + 4 > length)
        {
            TGLegacyLog(@"***** Invalid participants data");
            return nil;
        }
        
        int uid = 0;
        [data getBytes:&uid range:NSMakeRange(ptr, 4)];
        ptr += 4;
        
        if (ptr + 4 > length)
        {
            TGLegacyLog(@"***** Invalid participants data");
            return nil;
        }
        int inviter = 0;
        [data getBytes:&inviter range:NSMakeRange(ptr, 4)];
        ptr += 4;
        
        if (ptr + 4 > length)
        {
            TGLegacyLog(@"***** Invalid participants data");
            return nil;
        }
        int date = 0;
        [data getBytes:&date range:NSMakeRange(ptr, 4)];
        ptr += 4;
        
        NSNumber *nUid = [[NSNumber alloc] initWithInt:uid];
        
        [uids addObject:nUid];
        [invitedBy setObject:[[NSNumber alloc] initWithInt:inviter] forKey:nUid];
        [invitedDates setObject:[[NSNumber alloc] initWithInt:date] forKey:nUid];
    }
    
    NSMutableArray *chatParticipantSecretChatPeerIds = [[NSMutableArray alloc] init];
    
    if (formatVersion >= 1)
    {
        int count = 0;
        [data getBytes:&count range:NSMakeRange(ptr, 4)];
        ptr += 4;
        
        for (int i = 0; i < count; i++)
        {
            if (ptr + 8 > length)
            {
                TGLegacyLog(@"***** Invalid participants data");
                return nil;
            }
            
            int64_t peerId = 0;
            [data getBytes:&peerId range:NSMakeRange(ptr, 8)];
            ptr += 8;
            
            [chatParticipantSecretChatPeerIds addObject:@(peerId)];
        }
    }
    
    NSMutableArray *chatParticipantChatPeerIds = [[NSMutableArray alloc] init];
    
    if (formatVersion >= 2)
    {
        int count = 0;
        [data getBytes:&count range:NSMakeRange(ptr, 4)];
        ptr += 4;
        
        for (int i = 0; i < count; i++)
        {
            if (ptr + 8 > length)
            {
                TGLegacyLog(@"***** Invalid participants data");
                return nil;
            }
            
            int64_t peerId = 0;
            [data getBytes:&peerId range:NSMakeRange(ptr, 8)];
            ptr += 8;
            
            [chatParticipantChatPeerIds addObject:@(peerId)];
        }
    }
    
    if (formatVersion >= 3)
    {
        int32_t length = 0;
        [data getBytes:&length range:NSMakeRange(ptr, 4)];
        ptr += 4;
        
        NSData *linkData = [data subdataWithRange:NSMakeRange(ptr, length)];
        ptr += length;
        
        participantsData.exportedChatInviteString = [[NSString alloc] initWithData:linkData encoding:NSUTF8StringEncoding];
    }
    
    if (formatVersion >= 4) {
        int32_t length = 0;
        [data getBytes:&length range:NSMakeRange(ptr, 4)];
        ptr += 4;
        
        NSMutableSet *chatAdminUids = [[NSMutableSet alloc] init];
        for (int32_t i = 0; i < length; i++) {
            int32_t item = 0;
            [data getBytes:&item range:NSMakeRange(ptr, 4)];
            ptr += 4;
            [chatAdminUids addObject:@(item)];
        }
        
        participantsData.chatAdminUids = chatAdminUids;
    }
    
    participantsData.version = version;
    participantsData.chatAdminId = adminId;
    participantsData.chatParticipantUids = uids;
    participantsData.chatInvitedBy = invitedBy;
    participantsData.chatInvitedDates = invitedDates;
    participantsData.chatParticipantSecretChatPeerIds = chatParticipantSecretChatPeerIds;
    participantsData.chatParticipantChatPeerIds = chatParticipantChatPeerIds;
    
    return participantsData;
}

- (NSData *)serializedData
{
    if (_serializedData == nil)
    {
        NSMutableData *data = [[NSMutableData alloc] init];
        
        int32_t magic = 0xabcdef12;
        [data appendBytes:&magic length:4];
        
        int32_t formatVersion = 4;
        [data appendBytes:&formatVersion length:4];
        
        [data appendBytes:&_version length:4];
        [data appendBytes:&_chatAdminId length:4];
        
        int count = (int)_chatParticipantUids.count;
        [data appendBytes:&count length:4];
        for (NSNumber *nUid in _chatParticipantUids)
        {
            int uid = [nUid intValue];
            [data appendBytes:&uid length:4];
            
            int invitedBy = [[_chatInvitedBy objectForKey:nUid] intValue];
            [data appendBytes:&invitedBy length:4];
            
            int invitedDate = [[_chatInvitedDates objectForKey:nUid] intValue];
            [data appendBytes:&invitedDate length:4];
        }
        
        int32_t chatParticipantSecretChatPeerIdsCount = (int32_t)_chatParticipantSecretChatPeerIds.count;
        [data appendBytes:&chatParticipantSecretChatPeerIdsCount length:4];
        
        for (NSNumber *nPeerId in _chatParticipantSecretChatPeerIds)
        {
            int64_t peerId = [nPeerId longLongValue];
            [data appendBytes:&peerId length:8];
        }
        
        int32_t chatParticipantChatPeerIdsCount = (int32_t)_chatParticipantChatPeerIds.count;
        [data appendBytes:&chatParticipantChatPeerIdsCount length:4];
        
        for (NSNumber *nPeerId in _chatParticipantChatPeerIds)
        {
            int64_t peerId = [nPeerId longLongValue];
            [data appendBytes:&peerId length:8];
        }
        
        int32_t linkLength = (int32_t)_exportedChatInviteString.length;
        [data appendBytes:&linkLength length:4];
        if (linkLength != 0)
            [data appendData:[_exportedChatInviteString dataUsingEncoding:NSUTF8StringEncoding]];
        
        int32_t chatAdminUidsCount = (int32_t)_chatAdminUids.count;
        [data appendBytes:&chatAdminUidsCount length:4];
        for (NSNumber *nUid in _chatAdminUids) {
            int32_t uid = [nUid intValue];
            [data appendBytes:&uid length:4];
        }
        
        _serializedData = data;
    }
    
    return _serializedData;
}

@end

#pragma mark -

@implementation TGConversation

- (instancetype)initWithConversationId:(int64_t)conversationId unreadCount:(int)unreadCount serviceUnreadCount:(int)serviceUnreadCount
{
    self = [super init];
    if (self != nil)
    {
        _conversationId = conversationId;
        _unreadCount = unreadCount;
        _serviceUnreadCount = serviceUnreadCount;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    self = [super init];
    if (self != nil) {
        _conversationId = [coder decodeInt64ForCKey:"i"];
        _accessHash = [coder decodeInt64ForCKey:"ah"];
        _displayVariant = [coder decodeInt32ForCKey:"dv"];
        _kind = (uint8_t)[coder decodeInt32ForCKey:"kind"];
        _pts = [coder decodeInt32ForCKey:"pts"];
        _variantSortKey = TGConversationSortKeyDecode(coder, "vsort");
        _importantSortKey = TGConversationSortKeyDecode(coder, "isort");
        _unimportantSortKey = TGConversationSortKeyDecode(coder, "usort");
        _maxReadMessageId = [coder decodeInt32ForCKey:"mread"];
        _maxOutgoingReadMessageId = [coder decodeInt32ForCKey:"moutread"];
        _maxKnownMessageId = [coder decodeInt32ForCKey:"mknown"];
        _maxLocallyReadMessageId = [coder decodeInt32ForCKey:"mlr"];
        _maxReadDate = [coder decodeInt32ForCKey:"mrd"];
        _maxOutgoingReadDate = [coder decodeInt32ForCKey:"mrod"];
        _about = [coder decodeStringForCKey:"about"];
        _username = [coder decodeStringForCKey:"username"];
        _outgoing = [coder decodeInt32ForCKey:"out"];
        _unread = [coder decodeInt32ForCKey:"unr"];
        _deliveryError = [coder decodeInt32ForCKey:"der"];
        _deliveryState = [coder decodeInt32ForCKey:"ds"];
        _messageDate = [coder decodeInt32ForCKey:"date"];
        _fromUid = [coder decodeInt32ForCKey:"from"];
        _text = [coder decodeStringForCKey:"text"];
        _media = [TGMessage parseMediaAttachments:[coder decodeDataCorCKey:"media"]];
        _unreadCount = [coder decodeInt32ForCKey:"ucount"];
        _serviceUnreadCount = [coder decodeInt32ForCKey:"sucount"];
        _chatTitle = [coder decodeStringForCKey:"ct"];
        _chatPhotoSmall = [coder decodeStringForCKey:"cp.s"];
        _chatPhotoMedium = [coder decodeStringForCKey:"cp.m"];
        _chatPhotoBig = [coder decodeStringForCKey:"cp.l"];
        _chatPhotoFileReferenceSmall = [coder decodeDataCorCKey:"cp.frs"];
        _chatPhotoFileReferenceBig = [coder decodeDataCorCKey:"cp.frb"];
        _chatParticipants = nil;
        _chatParticipantCount = 0;
        _chatVersion = [coder decodeInt32ForCKey:"ver"];
        _chatIsAdmin = [coder decodeInt32ForCKey:"adm"];
        _channelRole = [coder decodeInt32ForCKey:"role"];
        _channelIsReadOnly = [coder decodeInt32ForCKey:"ro"];
        _flags = [coder decodeInt64ForCKey:"flags"];
        _leftChat = [coder decodeInt32ForCKey:"lef"];
        _kickedFromChat = [coder decodeInt32ForCKey:"kk"];
        _isChat = false;
        _isChannel = true;
        _isDeleted = false;
        _encryptedData = nil;
        _isBroadcast = false;
        _migratedToChannelId = [coder decodeInt32ForCKey:"mtci"];
        _migratedToChannelAccessHash = [coder decodeInt64ForCKey:"mtch"];
        _restrictionReason = [coder decodeStringForCKey:"rr"];
        _pinnedMessageId = [coder decodeInt32ForCKey:"pmi"];
        _chatCreationDate = [coder decodeInt32ForCKey:"ccd"];
        _pinnedDate = [coder decodeInt32ForCKey:"pdt"];
        _channelAdminRights = [coder decodeObjectForCKey:"car"];
        _channelBannedRights = [coder decodeObjectForCKey:"cbr"];
        _messageFlags = [coder decodeInt64ForCKey:"mf"];
        
        int32_t feedId = [coder decodeInt32ForCKey:"fi"];
        _feedId = feedId != -1 ? @(feedId) : nil;
        
        _unreadMark = [coder decodeInt32ForCKey:"unrm"];
    }
    return self;
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeInt64:_conversationId forCKey:"i"];
    [coder encodeInt64:_accessHash forCKey:"ah"];
    [coder encodeInt32:_displayVariant forCKey:"dv"];
    [coder encodeInt32:_kind forCKey:"kind"];
    [coder encodeInt32:_pts forCKey:"pts"];
    TGConversationSortKeyEncode(coder, "vsort", _variantSortKey);
    TGConversationSortKeyEncode(coder, "isort", _importantSortKey);
    TGConversationSortKeyEncode(coder, "usort", _unimportantSortKey);
    [coder encodeInt32:_maxReadMessageId forCKey:"mread"];
    [coder encodeInt32:_maxOutgoingReadMessageId forCKey:"moutread"];
    [coder encodeInt32:_maxKnownMessageId forCKey:"mknown"];
    [coder encodeInt32:_maxLocallyReadMessageId forCKey:"mlr"];
    [coder encodeInt32:_maxReadDate forCKey:"mrd"];
    [coder encodeInt32:_maxOutgoingReadDate forCKey:"mrod"];
    [coder encodeString:_about forCKey:"about"];
    [coder encodeString:_username forCKey:"username"];
    [coder encodeInt32:_outgoing ? 1 : 0 forCKey:"out"];
    [coder encodeInt32:_unread ? 1 : 0 forCKey:"unr"];
    [coder encodeInt32:_deliveryError ? 1 : 0 forCKey:"der"];
    [coder encodeInt32:_deliveryState forCKey:"ds"];
    [coder encodeInt32:_messageDate forCKey:"date"];
    [coder encodeInt32:_fromUid forCKey:"from"];
    [coder encodeString:_text forCKey:"text"];
    [coder encodeData:[TGMessage serializeMediaAttachments:true attachments:_media] forCKey:"media"];
    [coder encodeInt32:_unreadCount forCKey:"ucount"];
    [coder encodeInt32:_serviceUnreadCount forCKey:"sucount"];
    [coder encodeString:_chatTitle forCKey:"ct"];
    [coder encodeString:_chatPhotoSmall forCKey:"cp.s"];
    [coder encodeString:_chatPhotoMedium forCKey:"cp.m"];
    [coder encodeString:_chatPhotoBig forCKey:"cp.l"];
    [coder encodeData:_chatPhotoFileReferenceSmall forCKey:"cp.frs"];
    [coder encodeData:_chatPhotoFileReferenceBig forCKey:"cp.frb"];
    [coder encodeInt32:_chatVersion forCKey:"ver"];
    [coder encodeInt32:_chatIsAdmin ? 1 : 0 forCKey:"adm"];
    [coder encodeInt32:_channelRole forCKey:"role"];
    [coder encodeInt32:_channelIsReadOnly ? 1 : 0 forCKey:"ro"];
    [coder encodeInt64:_flags forCKey:"flags"];
    [coder encodeInt32:_leftChat forCKey:"lef"];
    [coder encodeInt32:_kickedFromChat forCKey:"kk"];
    [coder encodeInt32:_migratedToChannelId forCKey:"mtci"];
    [coder encodeInt64:_migratedToChannelAccessHash forCKey:"mtch"];
    [coder encodeString:_restrictionReason forCKey:"rr"];
    [coder encodeInt32:_pinnedMessageId forCKey:"pmi"];
    [coder encodeInt32:_chatCreationDate forCKey:"ccd"];
    [coder encodeObject:_channelAdminRights forCKey:"car"];
    [coder encodeObject:_channelBannedRights forCKey:"cbr"];
    [coder encodeInt64:_messageFlags forCKey:"mf"];
    [coder encodeInt32:_feedId != nil ? _feedId.intValue : -1 forCKey:"fi"];
    [coder encodeInt32:_unreadMark ? 1 : 0 forCKey:"unrm"];
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGConversation *conversation = [[TGConversation alloc] init];
    
    conversation.conversationId = _conversationId;
    conversation.accessHash = _accessHash;
    conversation.displayVariant = _displayVariant;
    conversation->_kind = _kind;
    conversation.pts = _pts;
    conversation.variantSortKey = _variantSortKey;
    conversation.importantSortKey = _importantSortKey;
    conversation.unimportantSortKey = _unimportantSortKey;
    conversation.maxReadMessageId = _maxReadMessageId;
    conversation.maxOutgoingReadMessageId = _maxOutgoingReadMessageId;
    conversation.maxKnownMessageId = _maxKnownMessageId;
    conversation.maxLocallyReadMessageId = _maxLocallyReadMessageId;
    conversation.maxReadDate = _maxReadDate;
    conversation.maxOutgoingReadDate = _maxOutgoingReadDate;
    conversation.about = _about;
    conversation.username = _username;
    conversation.outgoing = _outgoing;
    conversation.unread = _unread;
    conversation.deliveryError = _deliveryError;
    conversation.deliveryState = _deliveryState;
    conversation.messageDate = _messageDate;
    conversation.minMessageDate = _minMessageDate;
    conversation.fromUid = _fromUid;
    conversation.text = _text;
    conversation.media = _media;
    conversation.unreadCount = _unreadCount;
    conversation.serviceUnreadCount = _serviceUnreadCount;
    conversation.chatTitle = _chatTitle;
    conversation.chatPhotoSmall = _chatPhotoSmall;
    conversation.chatPhotoMedium = _chatPhotoMedium;
    conversation.chatPhotoBig = _chatPhotoBig;
    conversation.chatPhotoFileReferenceSmall = _chatPhotoFileReferenceSmall;
    conversation.chatPhotoFileReferenceBig = _chatPhotoFileReferenceBig;
    conversation.chatParticipants = [_chatParticipants copy];
    conversation.chatParticipantCount = _chatParticipantCount;
    conversation.chatVersion = _chatVersion;
    conversation.chatIsAdmin = _chatIsAdmin;
    conversation.channelRole = _channelRole;
    conversation.leftChat = _leftChat;
    conversation.kickedFromChat = _kickedFromChat;
    conversation.dialogListData = _dialogListData;
    conversation.isChat = _isChat;
    conversation.isDeleted = _isDeleted;
    conversation.restrictionReason = _restrictionReason;
    conversation->_chatCreationDate = _chatCreationDate;
    conversation->_unreadMark = _unreadMark;
    
    conversation.encryptedData = _encryptedData == nil ? nil : [_encryptedData copy];
    
    conversation.isBroadcast = _isBroadcast;
    conversation.isChannel = _isChannel;
    conversation.channelIsReadOnly = _channelIsReadOnly;
    conversation.flags = _flags;
    conversation.migratedToChannelId = _migratedToChannelId;
    conversation.migratedToChannelAccessHash = _migratedToChannelAccessHash;
    conversation.pinnedMessageId = _pinnedMessageId;
    
    conversation->_draft = _draft;
    conversation->_unreadMentionCount = _unreadMentionCount;
    conversation.pinnedDate = _pinnedDate;
    
    conversation->_channelAdminRights = _channelAdminRights;
    conversation->_channelBannedRights = _channelBannedRights;
    
    conversation->_messageFlags = _messageFlags;
    
    conversation->_feedId = _feedId;
    
    return conversation;
}

- (void)setKind:(uint8_t)kind {
    if (_kind != kind || kind != TGConversationSortKeyKind(_variantSortKey)) {
        _kind = kind;
        
        _variantSortKey = TGConversationSortKeyUpdateKind(_variantSortKey, kind);
        _importantSortKey = TGConversationSortKeyUpdateKind(_importantSortKey, kind);
        _unimportantSortKey = TGConversationSortKeyUpdateKind(_unimportantSortKey, kind);
    }
}

- (void)setVariantSortKey:(TGConversationSortKey)variantSortKey {
    _variantSortKey = variantSortKey;
    
    _messageDate = TGConversationSortKeyTimestamp(variantSortKey);
}

- (void)mergeMessage:(TGMessage *)message
{
    _outgoing = message.outgoing;
    _messageDate = (int)message.date;
    _fromUid = (int)message.fromUid;
    _text = message.text;
    _media = message.mediaAttachments;
    _unread = [self isMessageUnread:message];
    _deliveryError = message.deliveryState == TGMessageDeliveryStateFailed;
    _deliveryState = message.deliveryState;
    _messageFlags = message.flags;
    if (_maxKnownMessageId > TGMessageLocalMidBaseline)
        _maxKnownMessageId = 0;
    if (message.mid < TGMessageLocalMidBaseline && (message.mid > _maxKnownMessageId))
        _maxKnownMessageId = message.mid;
}

- (void)mergeEmptyMessage {
    _outgoing = false;
    _fromUid = 0;
    _text = nil;
    _media = nil;
    _unread = false;
    _deliveryError = false;
    _deliveryState = TGMessageDeliveryStateDelivered;
    _messageFlags = 0;
}

- (NSData *)mediaData
{
    if (_mediaData != nil)
        return _mediaData;
    
    _mediaData = [TGMessage serializeMediaAttachments:false attachments:_media];
    return _mediaData;
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:[TGConversation class]] && [((TGConversation *)object) isEqualToConversation:self];
}

- (BOOL)isEqualToConversation:(TGConversation *)other
{
    if (_conversationId != other.conversationId || _outgoing != other.outgoing || _messageDate != other.messageDate || _fromUid != other.fromUid || ![_text isEqualToString:other.text] || _unreadCount != other.unreadCount || _serviceUnreadCount != other.serviceUnreadCount || _unread != other.unread || _isChat != other.isChat || _deliveryError != other.deliveryError || _deliveryState != other.deliveryState)
        return false;
    
    if (_media.count != other.media.count)
        return false;
    if (_media != nil && ![self.mediaData isEqualToData:other.mediaData])
        return false;
    
    if (_isChat)
    {
        if (![_chatTitle isEqualToString:other.chatTitle] || _chatVersion != other.chatVersion || _leftChat != other.leftChat || _kickedFromChat != other.kickedFromChat ||
            (((_chatParticipants != nil) != (other.chatParticipants != nil)) || (_chatParticipants != nil && ![_chatParticipants.serializedData isEqualToData:other.chatParticipants.serializedData]))
           )
            return false;
        if ((_chatPhotoSmall != nil) != (other.chatPhotoSmall != nil) || (_chatPhotoSmall != nil && ![_chatPhotoSmall isEqualToString:other.chatPhotoSmall]))
            return false;
        if ((_chatPhotoMedium != nil) != (other.chatPhotoMedium != nil) || (_chatPhotoMedium != nil && ![_chatPhotoMedium isEqualToString:other.chatPhotoMedium]))
            return false;
        if ((_chatPhotoBig != nil) != (other.chatPhotoBig != nil) || (_chatPhotoBig != nil && ![_chatPhotoBig isEqualToString:other.chatPhotoBig]))
            return false;
        
        if (!TGObjectCompare(other.chatPhotoFileReferenceSmall, _chatPhotoFileReferenceSmall) || !TGObjectCompare(other.chatPhotoFileReferenceBig, _chatPhotoFileReferenceBig))
            return false;
    }
    
    if (_encryptedData != nil || other->_encryptedData != nil)
    {
        if ((_encryptedData != nil) != (other->_encryptedData != nil) || (_encryptedData != nil && ![_encryptedData isEqualToEncryptedData:other->_encryptedData]))
            return false;
    }
    
    if (_flags != other->_flags) {
        return false;
    }
    
    if (_pinnedMessageId != other->_pinnedMessageId) {
        return false;
    }
    
    if (!TGStringCompare(_restrictionReason, other->_restrictionReason)) {
        return false;
    }
    
    if (_maxReadDate != other->_maxReadDate) {
        return false;
    }
    
    if (_maxReadMessageId != other->_maxReadMessageId) {
        return false;
    }
    
    if (_maxOutgoingReadDate != other->_maxOutgoingReadDate) {
        return false;
    }
    
    if (_maxOutgoingReadMessageId != other->_maxOutgoingReadMessageId) {
        return false;
    }
    
    if (_maxKnownMessageId != other->_maxKnownMessageId) {
        return false;
    }
    
    if (!TGObjectCompare(_draft, other->_draft)) {
        return false;
    }
    
    if (_unreadMentionCount != other->_unreadMentionCount) {
        return false;
    }
    
    if (_pinnedDate != other->_pinnedDate) {
        return false;
    }
    
    if (!TGObjectCompare(_channelAdminRights, other->_channelAdminRights)) {
        return false;
    }
    
    if (!TGObjectCompare(_channelBannedRights, other->_channelBannedRights)) {
        return false;
    }
        
    return true;
}

- (BOOL)isEqualToConversationIgnoringMessage:(TGConversation *)other
{
    if (_conversationId != other.conversationId || _isChat != other.isChat)
        return false;
    
    if (_isChat)
    {
        if (![_chatTitle isEqualToString:other.chatTitle] || _chatVersion != other.chatVersion || _leftChat != other.leftChat || _kickedFromChat != other.kickedFromChat ||
            (((_chatParticipants != nil) != (other.chatParticipants != nil)) || (_chatParticipants != nil && ![_chatParticipants.serializedData isEqualToData:other.chatParticipants.serializedData]))
            )
            return false;
        if ((_chatPhotoSmall != nil) != (other.chatPhotoSmall != nil) || (_chatPhotoSmall != nil && ![_chatPhotoSmall isEqualToString:other.chatPhotoSmall]))
            return false;
        if ((_chatPhotoMedium != nil) != (other.chatPhotoMedium != nil) || (_chatPhotoMedium != nil && ![_chatPhotoMedium isEqualToString:other.chatPhotoMedium]))
            return false;
        if ((_chatPhotoBig != nil) != (other.chatPhotoBig != nil) || (_chatPhotoBig != nil && ![_chatPhotoBig isEqualToString:other.chatPhotoBig]))
            return false;
        
        if (!TGObjectCompare(other.chatPhotoFileReferenceSmall, _chatPhotoFileReferenceSmall) || !TGObjectCompare(other.chatPhotoFileReferenceBig, _chatPhotoFileReferenceBig))
            return false;
    }
    
    if (_flags != other->_flags) {
        return false;
    }
    
    if (!TGStringCompare(_restrictionReason, other->_restrictionReason)) {
        return false;
    }
    
    if (_maxReadDate != other->_maxReadDate) {
        return false;
    }
    
    if (_maxReadMessageId != other->_maxReadMessageId) {
        return false;
    }
    
    if (_maxOutgoingReadDate != other->_maxOutgoingReadDate) {
        return false;
    }
    
    if (_maxOutgoingReadMessageId != other->_maxOutgoingReadMessageId) {
        return false;
    }
    
    if (_maxKnownMessageId != other->_maxKnownMessageId) {
        return false;
    }
    
    if (!TGObjectCompare(_channelAdminRights, other->_channelAdminRights)) {
        return false;
    }
    
    if (!TGObjectCompare(_channelBannedRights, other->_channelBannedRights)) {
        return false;
    }
    
    return true;
}

- (NSData *)serializeChatPhoto
{
    NSMutableData *data = [[NSMutableData alloc] init];
    
    int32_t magic = 0x7acde441;
    [data appendBytes:&magic length:4];
    int32_t version = 9;
    [data appendBytes:&version length:4];
    
    for (int i = 0; i < 3; i++)
    {
        NSString *value = nil;
        if (i == 0)
            value = _chatPhotoSmall;
        else if (i == 1)
            value = _chatPhotoMedium;
        else if (i == 2)
            value = _chatPhotoBig;
        
        NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
        int length = (int)valueData.length;
        [data appendBytes:&length length:4];
        if (valueData != nil)
            [data appendData:valueData];
    }
    
    int8_t hasEncryptedData = _encryptedData != nil ? 1 : 0;
    [data appendBytes:&hasEncryptedData length:1];
    if (_encryptedData != nil)
        [_encryptedData serialize:data];
    
    [data appendBytes:&_flags length:4];
    
    [data appendBytes:&_migratedToChannelId length:4];
    [data appendBytes:&_migratedToChannelAccessHash length:8];
    
    [data appendBytes:&_maxReadMessageId length:4];
    [data appendBytes:&_maxOutgoingReadMessageId length:4];
    [data appendBytes:&_maxKnownMessageId length:4];
    [data appendBytes:&_maxLocallyReadMessageId length:4];
    
    [data appendBytes:&_maxReadDate length:4];
    [data appendBytes:&_maxOutgoingReadDate length:4];
    
    [data appendBytes:&_messageDate length:4];
    [data appendBytes:&_minMessageDate length:4];
    
    [data appendBytes:&_messageFlags length:8];
    
    {
        int length = (int)_chatPhotoFileReferenceSmall.length;
        [data appendBytes:&length length:4];
        if (_chatPhotoFileReferenceSmall != nil)
            [data appendData:_chatPhotoFileReferenceSmall];
    }
    
    {
        int length = (int)_chatPhotoFileReferenceBig.length;
        [data appendBytes:&length length:4];
        if (_chatPhotoFileReferenceBig != nil)
            [data appendData:_chatPhotoFileReferenceBig];
    }
    
    return data;
}

- (void)deserializeChatPhoto:(NSData *)data
{
    int ptr = 0;
    
    int32_t version = 1;
    if (data.length >= 4) {
        int32_t magic = 0;
        [data getBytes:&magic length:4];
        if (magic == 0x7acde441) {
            ptr += 4;
            
            [data getBytes:&version range:NSMakeRange(ptr, 4)];
            ptr += 4;
        }
    }
    
    for (int i = 0; i < 3; i++)
    {
        int length = 0;
        [data getBytes:&length range:NSMakeRange(ptr, 4)];
        ptr += 4;
        
        uint8_t *valueBytes = malloc(length);
        [data getBytes:valueBytes range:NSMakeRange(ptr, length)];
        ptr += length;
        NSString *value = [[NSString alloc] initWithBytesNoCopy:valueBytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
        
        if (i == 0)
            _chatPhotoSmall = value;
        else if (i == 1)
            _chatPhotoMedium = value;
        else if (i == 2)
            _chatPhotoBig = value;
    }
    
    if (version == 1) {
        if (ptr + 4 <= (int)data.length) {
            _encryptedData = [TGEncryptedConversationData deserialize:data ptr:&ptr];
        }
    } else {
        if (version >= 2) {
            int8_t hasEncryptedData = 0;
            [data getBytes:&hasEncryptedData range:NSMakeRange(ptr, 1)];
            ptr += 1;
            
            if (hasEncryptedData) {
                _encryptedData = [TGEncryptedConversationData deserialize:data ptr:&ptr];
            }
            
            [data getBytes:&_flags range:NSMakeRange(ptr, 4)];
            ptr += 4;
            
            if (version >= 4) {
                [data getBytes:&_migratedToChannelId range:NSMakeRange(ptr, 4)];
                ptr += 4;
                [data getBytes:&_migratedToChannelAccessHash range:NSMakeRange(ptr, 8)];
                ptr += 8;
                
                if (version >= 5) {
                    [data getBytes:&_maxReadMessageId range:NSMakeRange(ptr, 4)];
                    ptr += 4;
                    
                    [data getBytes:&_maxOutgoingReadMessageId range:NSMakeRange(ptr, 4)];
                    ptr += 4;
                    
                    [data getBytes:&_maxKnownMessageId range:NSMakeRange(ptr, 4)];
                    ptr += 4;
                    
                    [data getBytes:&_maxLocallyReadMessageId range:NSMakeRange(ptr, 4)];
                    ptr += 4;
                    
                    [data getBytes:&_maxReadDate range:NSMakeRange(ptr, 4)];
                    ptr += 4;
                    
                    [data getBytes:&_maxOutgoingReadDate range:NSMakeRange(ptr, 4)];
                    ptr += 4;
                    
                    if (version >= 6) {
                        [data getBytes:&_messageDate range:NSMakeRange(ptr, 4)];
                        ptr += 4;
                        
                        if (version >= 7) {
                            [data getBytes:&_minMessageDate range:NSMakeRange(ptr, 4)];
                            ptr += 4;
                        }
                    }
                    
                    if (version >= 8) {
                        [data getBytes:&_messageFlags range:NSMakeRange(ptr, 8)];
                        ptr += 8;
                    }
                    
                    if (version >= 9) {
                        int length = 0;
                        [data getBytes:&length range:NSMakeRange(ptr, 4)];
                        ptr += 4;
                        
                        uint8_t *valueBytes = malloc(length);
                        [data getBytes:valueBytes range:NSMakeRange(ptr, length)];
                        ptr += length;
                        
                        _chatPhotoFileReferenceSmall = [NSData dataWithBytesNoCopy:valueBytes length:length];
                        
                        [data getBytes:&length range:NSMakeRange(ptr, 4)];
                        ptr += 4;
                        
                        valueBytes = malloc(length);
                        [data getBytes:valueBytes range:NSMakeRange(ptr, length)];
                        ptr += length;
                        
                        _chatPhotoFileReferenceBig = [NSData dataWithBytesNoCopy:valueBytes length:length];
                    }
                }
            }
        }
    }
}

- (bool)isEncrypted
{
    return _encryptedData != nil;
}

- (void)mergeConversation:(TGConversation *)conversation {
    self.accessHash = conversation.accessHash;
    self.about = conversation.about;
    self.username = conversation.username;
    self.chatTitle = conversation.chatTitle;
    self.chatPhotoSmall = conversation.chatPhotoSmall;
    self.chatPhotoMedium = conversation.chatPhotoMedium;
    self.chatPhotoBig = conversation.chatPhotoBig;
    self.chatPhotoFileReferenceSmall = conversation.chatPhotoFileReferenceSmall;
    self.chatPhotoFileReferenceBig = conversation.chatPhotoFileReferenceBig;
    self.chatParticipantCount = conversation.chatParticipantCount;
    self.leftChat = conversation.leftChat;
    self.kickedFromChat = conversation.kickedFromChat;
    self.chatVersion = conversation.chatVersion;
    self.chatIsAdmin = conversation.chatIsAdmin;
    self.hasAdmins = conversation.hasAdmins;
    self.isAdmin = conversation.isAdmin;
    self.isVerified = conversation.isVerified;
    if (conversation.chatParticipants != nil) {
        self.chatParticipants = conversation.chatParticipants;
    }
    self.isChat = conversation.isChat;
    self.isDeactivated = conversation.isDeactivated;
    self.isMigrated = conversation.isMigrated;
    self.migratedToChannelId = conversation.migratedToChannelId;
    self.migratedToChannelAccessHash = conversation.migratedToChannelAccessHash;
    self.canNotSetUsername = conversation.canNotSetUsername;
    if (conversation.encryptedData != nil) {
        self.encryptedData = conversation.encryptedData;
    }
    self.channelAdminRights = conversation.channelAdminRights;
    self.channelBannedRights = conversation.channelBannedRights;
    _feedId = conversation->_feedId;
}

- (void)mergeChannel:(TGConversation *)channel {
    _chatTitle = channel.chatTitle;
    _chatVersion = channel.chatVersion;
    _chatPhotoBig = channel.chatPhotoBig;
    _chatPhotoMedium = channel.chatPhotoMedium;
    _chatPhotoSmall = channel.chatPhotoSmall;
    _chatPhotoFileReferenceSmall = channel.chatPhotoFileReferenceSmall;
    _chatPhotoFileReferenceBig = channel.chatPhotoFileReferenceBig;
    _username = channel.username;
    if (!channel.isMin) {
        _chatIsAdmin = channel.chatIsAdmin;
        self.channelRole = channel.channelRole;
        _leftChat = channel.leftChat;
        _kickedFromChat = channel.kickedFromChat;
        self.kind = channel.leftChat || channel.kickedFromChat ? TGConversationKindTemporaryChannel : TGConversationKindPersistentChannel;
        _accessHash = channel.accessHash;
        self.hasExplicitContent = channel.hasExplicitContent;
        self.signaturesEnabled = channel.signaturesEnabled;
        self.restrictionReason = channel.restrictionReason;
        self.channelAdminRights = channel.channelAdminRights;
        self.channelBannedRights = channel.channelBannedRights;
        
        if (channel->_feedId != nil)
            _feedId = channel->_feedId;
    }
    self.everybodyCanAddMembers = channel.everybodyCanAddMembers;
    _channelIsReadOnly = channel.channelIsReadOnly;
    self.isVerified = channel.isVerified;
}

- (void)mergeDraft:(TGDatabaseMessageDraft *)draft {
    _draft = draft;
    
    if (_draft.date > TGConversationSortKeyTimestamp(_variantSortKey)) {
        _variantSortKey = TGConversationSortKeyMake(TGConversationSortKeyKind(_variantSortKey), _draft.date, TGConversationSortKeyMid(_variantSortKey));
    }
}

- (void)setPinnedDate:(int32_t)pinnedDate {
    _pinnedDate = pinnedDate;
    if (pinnedDate > TGConversationSortKeyTimestamp(_variantSortKey)) {
        _variantSortKey = TGConversationSortKeyMake(TGConversationSortKeyKind(_variantSortKey), pinnedDate, TGConversationSortKeyMid(_variantSortKey));
    }
}

- (bool)currentUserCanSendMessages {
    if (self.isChannelGroup) {
        return true;
    }
    
    return (_channelRole == TGChannelRoleCreator || _channelAdminRights.canPostMessages || !_channelIsReadOnly) && !_leftChat && !_kickedFromChat;
}

+ (NSString *)chatTitleForDecoder:(PSKeyValueCoder *)coder {
    return [coder decodeStringForCKey:"ct"];
}

- (bool)postAsChannel {
    return _flags & TGConversationFlagPostAsChannel;
}

- (void)setPostAsChannel:(bool)postAsChannel {
    if (postAsChannel) {
        _flags |= TGConversationFlagPostAsChannel;
    } else {
        _flags &= ~TGConversationFlagPostAsChannel;
    }
}

- (bool)isVerified {
    return _flags & TGConversationFlagVerified;
}

- (void)setIsVerified:(bool)isVerified {
    if (isVerified) {
        _flags |= TGConversationFlagVerified;
    } else {
        _flags &= ~TGConversationFlagVerified;
    }
}

- (bool)hasExplicitContent {
    return _flags & TGConversationFlagHasExplicitContent;
}

- (void)setHasExplicitContent:(bool)hasExplicitContent {
    if (hasExplicitContent) {
        _flags |= TGConversationFlagHasExplicitContent;
    } else {
        _flags &= ~TGConversationFlagHasExplicitContent;
    }
}

- (bool)hasAdmins {
    return _flags & TGConversationFlagHasAdmins;
}

- (void)setHasAdmins:(bool)hasAdmins {
    if (hasAdmins) {
        _flags |= TGConversationFlagHasAdmins;
    } else {
        _flags &= ~TGConversationFlagHasAdmins;
    }
}

- (bool)isAdmin {
    return _flags & TGConversationFlagIsAdmin;
}

- (void)setIsAdmin:(bool)isAdmin {
    if (isAdmin) {
        _flags |= TGConversationFlagIsAdmin;
    } else {
        _flags &= ~TGConversationFlagIsAdmin;
    }
}

- (bool)isCreator {
    return _flags & TGConversationFlagIsCreator;
}

- (void)setIsCreator:(bool)isCreator {
    if (isCreator) {
        _flags |= TGConversationFlagIsCreator;
    } else {
        _flags &= ~TGConversationFlagIsCreator;
    }
}

- (bool)isChannelGroup {
    return _flags & TGConversationFlagIsChannelGroup;
}

- (void)setIsChannelGroup:(bool)isChannelGroup {
    if (isChannelGroup) {
        _flags |= TGConversationFlagIsChannelGroup;
    } else {
        _flags &= ~TGConversationFlagIsChannelGroup;
    }
}

- (bool)everybodyCanAddMembers {
    return _flags & TGConversationFlagEverybodyCanAddMembers;
}

- (void)setEverybodyCanAddMembers:(bool)everybodyCanAddMembers {
    if (everybodyCanAddMembers) {
        _flags |= TGConversationFlagEverybodyCanAddMembers;
    } else {
        _flags &= ~TGConversationFlagEverybodyCanAddMembers;
    }
}

- (bool)isMin {
    return _flags & TGConversationFlagIsMin;
}

- (void)setIsMin:(bool)isMin {
    if (isMin) {
        _flags |= TGConversationFlagIsMin;
    } else {
        _flags &= ~TGConversationFlagIsMin;
    }
}

- (bool)canNotSetUsername {
    return _flags & TGConversationFlagCanNotSetUsername;
}

- (void)setCanNotSetUsername:(bool)canNotSetUsername {
    if (canNotSetUsername) {
        _flags |= TGConversationFlagCanNotSetUsername;
    } else {
        _flags &= ~TGConversationFlagCanNotSetUsername;
    }
}

- (bool)signaturesEnabled {
    return _flags & TGConversationFlagSignaturesEnabled;
}

- (void)setSignaturesEnabled:(bool)signaturesEnabled {
    if (signaturesEnabled) {
        _flags |= TGConversationFlagSignaturesEnabled;
    } else {
        _flags &= ~TGConversationFlagSignaturesEnabled;
    }
}

- (bool)isDeactivated {
    return _flags & TGConversationFlagIsDeactivated;
}

- (void)setIsDeactivated:(bool)isDeactivated {
    if (isDeactivated) {
        _flags |= TGConversationFlagIsDeactivated;
    } else {
        _flags &= ~TGConversationFlagIsDeactivated;
    }
}

- (bool)pinnedMessageHidden {
    return _flags & TGConversationFlagPinnedMessageHidden;
}

- (void)setPinnedMessageHidden:(bool)pinnedMessageHidden {
    if (pinnedMessageHidden) {
        _flags |= TGConversationFlagPinnedMessageHidden;
    } else {
        _flags &= ~TGConversationFlagPinnedMessageHidden;
    }
}

- (bool)isMessageUnread:(TGMessage *)message {
    return [self isMessageUnread:message.mid date:(int32_t)message.date outgoing:message.outgoing];
}

- (bool)isMessageUnread:(int32_t)messageId date:(int32_t)messageDate outgoing:(bool)outgoing {
    if (TGPeerIdIsSecretChat(_conversationId)) {
        if (outgoing) {
            return ((int32_t)messageDate) > _maxOutgoingReadDate;
        } else {
            return ((int32_t)messageDate) > _maxReadDate;
        }
    } else {
        if (TGPeerIdIsChannel(_conversationId) && _kind != TGConversationKindPersistentChannel) {
            return false;
        }
        
        if (outgoing) {
            if (messageId < TGMessageLocalMidBaseline) {
                return messageId > _maxOutgoingReadMessageId;
            } else {
                return true;
            }
        } else {
            if (messageId < TGMessageLocalMidBaseline) {
                return messageId > _maxReadMessageId;
            } else {
                return false;
            }
        }
    }
}

- (int32_t)date {
    return MAX(_pinnedDate, MAX(_minMessageDate, MAX(_draft.date, _messageDate)));
}

- (int32_t)unpinnedDate {
    return MAX(_minMessageDate, MAX(_draft.date, _messageDate));
}

- (bool)pinnedToTop {
    return _pinnedDate >= TGConversationPinnedDateBase;
}

- (int64_t)conversationFeedId {
    if (_feedId.intValue == 0)
        return 0;
    return TGPeerIdFromAdminLogId(_feedId.intValue);
}

- (int32_t)searchMessageId {
    return [self.additionalProperties[@"searchMessageId"] intValue];
}

- (bool)isAd {
    return TGPeerIdIsAd(_conversationId);
}

- (NSString *)chatPhotoFullSmall {
    NSString *finalAvatarUrl = self.chatPhotoSmall;
    if (finalAvatarUrl.length == 0)
        return finalAvatarUrl;
    
    int64_t volumeId = 0;
    int32_t localId = 0;
    if (extractFileUrlComponents(self.chatPhotoSmall, NULL, &volumeId, &localId, NULL))
    {
        NSString *key = [NSString stringWithFormat:@"%lld_%d", volumeId, localId];
        NSDictionary *fileReferences = nil;
        if (self.chatPhotoFileReferenceSmall != nil) {
            fileReferences = @{ key: self.chatPhotoFileReferenceSmall };
        }
        TGMediaOriginInfo *originInfo = [TGMediaOriginInfo mediaOriginInfoWithFileReference:self.chatPhotoFileReferenceSmall fileReferences:fileReferences peerId:_conversationId];
        finalAvatarUrl = [finalAvatarUrl stringByAppendingFormat:@"_o%@", [originInfo stringRepresentation]];
    }
    
    return finalAvatarUrl;
}

- (NSString *)chatPhotoFullBig {
    NSString *finalAvatarUrl = self.chatPhotoBig;
    if (finalAvatarUrl.length == 0)
        return finalAvatarUrl;
    
    int64_t volumeId = 0;
    int32_t localId = 0;
    if (extractFileUrlComponents(self.chatPhotoBig, NULL, &volumeId, &localId, NULL))
    {
        NSString *key = [NSString stringWithFormat:@"%lld_%d", volumeId, localId];
        NSDictionary *fileReferences = nil;
        if (self.chatPhotoFileReferenceBig != nil) {
            fileReferences = @{ key: self.chatPhotoFileReferenceBig };
        }
        TGMediaOriginInfo *originInfo = [TGMediaOriginInfo mediaOriginInfoWithFileReference:self.chatPhotoFileReferenceBig fileReferences:fileReferences peerId:_conversationId];
        finalAvatarUrl = [finalAvatarUrl stringByAppendingFormat:@"_o%@", [originInfo stringRepresentation]];
    }
    
    return finalAvatarUrl;
}

@end
