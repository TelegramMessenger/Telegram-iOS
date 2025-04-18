#import "TGActionMediaAttachment.h"

#import "TGImageMediaAttachment.h"

@implementation TGActionMediaAttachment

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGActionMediaAttachmentType;
    }
    return self;
}

- (void)serialize:(NSMutableData *)data
{
    int dataLengthPtr = (int)data.length;
    int zero = 0;
    [data appendBytes:&zero length:4];
    
    int actionType = _actionType;
    [data appendBytes:&actionType length:4];
    
    if (actionType == TGMessageActionChatAddMember || actionType == TGMessageActionChatDeleteMember)
    {
        int uid = [[_actionData objectForKey:@"uid"] intValue];
        [data appendBytes:&uid length:4];
        NSArray *uids = _actionData[@"uids"];
        int32_t uidsCount = (int32_t)uids.count;
        [data appendBytes:&uidsCount length:4];
        for (NSNumber *nUid in uids) {
            int32_t listUid = [nUid intValue];
            [data appendBytes:&listUid length:4];
        }
    }
    else if (actionType == TGMessageActionJoinedByLink)
    {
        int uid = [[_actionData objectForKey:@"inviterId"] intValue];
        [data appendBytes:&uid length:4];
    }
    else if (actionType == TGMessageActionChatEditTitle)
    {
        NSString *title = [_actionData objectForKey:@"title"];
        NSData *titleData = [title dataUsingEncoding:NSUTF8StringEncoding];
        int length = (int)titleData.length;
        [data appendBytes:&length length:4];
        [data appendData:titleData];
    }
    else if (actionType == TGMessageActionCreateChat)
    {
        NSString *title = [_actionData objectForKey:@"title"];
        NSData *titleData = [title dataUsingEncoding:NSUTF8StringEncoding];
        int length = (int)titleData.length;
        [data appendBytes:&length length:4];
        [data appendData:titleData];
        
        NSArray *uids = [_actionData objectForKey:@"uids"];
        int count = (int)uids.count;
        [data appendBytes:&count length:4];
        for (NSNumber *nUid in uids)
        {
            int uid = [nUid intValue];
            [data appendBytes:&uid length:4];
        }
    }
    else if (actionType == TGMessageActionCreateBroadcastList)
    {
        NSString *title = [_actionData objectForKey:@"title"];
        NSData *titleData = [title dataUsingEncoding:NSUTF8StringEncoding];
        int length = (int)titleData.length;
        [data appendBytes:&length length:4];
        [data appendData:titleData];
        
        NSArray *uids = [_actionData objectForKey:@"uids"];
        int count = (int)uids.count;
        [data appendBytes:&count length:4];
        for (NSNumber *nUid in uids)
        {
            int uid = [nUid intValue];
            [data appendBytes:&uid length:4];
        }
    }
    else if (actionType == TGMessageActionChatEditPhoto)
    {
        TGImageMediaAttachment *photo = [_actionData objectForKey:@"photo"];
        if (photo != nil)
        {
            [photo serialize:data];
        }
    }
    else if (actionType == TGMessageActionContactRequest)
    {
        int hasPhone = [[_actionData objectForKey:@"hasPhone"] boolValue] ? 1 : 0;
        [data appendBytes:&hasPhone length:4];
    }
    else if (actionType == TGMessageActionAcceptContactRequest)
    {
    }
    else if (actionType == TGMessageActionContactRegistered)
    {
    }
    else if (actionType == TGMessageActionUserChangedPhoto)
    {
        TGImageMediaAttachment *photo = [_actionData objectForKey:@"photo"];
        if (photo != nil)
        {
            [photo serialize:data];
        }
    }
    else if (actionType == TGMessageActionEncryptedChatRequest)
    {
    }
    else if (actionType == TGMessageActionEncryptedChatAccept)
    {
        
    }
    else if (actionType == TGMessageActionEncryptedChatDecline)
    {
        
    }
    else if (actionType == TGMessageActionEncryptedChatMessageLifetime)
    {
        int32_t messageLifetime = [_actionData[@"messageLifetime"] intValue];
        [data appendBytes:&messageLifetime length:4];
    }
    else if (actionType == TGMessageActionEncryptedChatScreenshot)
    {   
    }
    else if (actionType == TGMessageActionChannelCreated)
    {
        NSString *title = [_actionData objectForKey:@"title"];
        NSData *titleData = [title dataUsingEncoding:NSUTF8StringEncoding];
        int length = (int)titleData.length;
        [data appendBytes:&length length:4];
        [data appendData:titleData];
    }
    else if (actionType == TGMessageActionChannelCommentsStatusChanged) {
        uint8_t enabled = [_actionData[@"enabled"] boolValue];
        [data appendBytes:&enabled length:1];
    } else if (actionType == TGMessageActionChannelInviter) {
        int32_t inviter = [_actionData[@"uid"] intValue];
        [data appendBytes:&inviter length:4];
    } else if (actionType == TGMessageActionGroupMigratedTo) {
        int32_t channelId = [_actionData[@"channelId"] intValue];
        [data appendBytes:&channelId length:4];
    } else if (actionType == TGMessageActionGroupDeactivated) {
        
    } else if (actionType == TGMessageActionGroupActivated) {
        
    } else if (actionType == TGMessageActionChannelMigratedFrom) {
        NSString *title = [_actionData objectForKey:@"title"];
        NSData *titleData = [title dataUsingEncoding:NSUTF8StringEncoding];
        int length = (int)titleData.length;
        [data appendBytes:&length length:4];
        [data appendData:titleData];
        
        int32_t channelId = [_actionData[@"groupId"] intValue];
        [data appendBytes:&channelId length:4];
    } else if (actionType == TGMessageActionPinnedMessage) {
    } else if (actionType == TGMessageActionClearChat) {
    } else if (actionType == TGMessageActionGameScore) {
        int32_t gameId = [_actionData[@"gameId"] intValue];
        [data appendBytes:&gameId length:4];
        int32_t score = [_actionData[@"score"] intValue];
        [data appendBytes:&score length:4];
    } else if (actionType == TGMessageActionPhoneCall) {
        int64_t callId = [_actionData[@"callId"] longLongValue];
        [data appendBytes:&callId length:8];
        int32_t reason = [_actionData[@"reason"] intValue];
        [data appendBytes:&reason length:4];
        int32_t duration = [_actionData[@"duration"] intValue];
        [data appendBytes:&duration length:4];
    } else if (actionType == TGMessageActionPaymentSent) {
        NSString *curreny = _actionData[@"currency"];
        NSData *currencyBytes = [curreny dataUsingEncoding:NSUTF8StringEncoding];
        int32_t currencyLength = (int32_t)currencyBytes.length;
        [data appendBytes:&currencyLength length:4];
        [data appendData:currencyBytes];
        int32_t totalAmount = [_actionData[@"totalAmount"] intValue];
        [data appendBytes:&totalAmount length:4];
    } else if (actionType == TGMessageActionText) {
        NSString *text = _actionData[@"text"];
        NSData *textBytes = [text dataUsingEncoding:NSUTF8StringEncoding];
        int32_t textLength = (int32_t)textBytes.length;
        [data appendBytes:&textLength length:4];
        [data appendData:textBytes];
    } else if (actionType == TGMessageActionBotAllowed) {
        NSString *domain = _actionData[@"domain"];
        NSData *domainBytes = [domain dataUsingEncoding:NSUTF8StringEncoding];
        int32_t domainLength = (int32_t)domainBytes.length;
        [data appendBytes:&domainLength length:4];
        [data appendData:domainBytes];
    } else if (actionType == TGMessageActionSecureValuesSent) {
        NSString *values = _actionData[@"values"];
        NSData *valuesBytes = [values dataUsingEncoding:NSUTF8StringEncoding];
        int32_t valuesLength = (int32_t)valuesBytes.length;
        [data appendBytes:&valuesLength length:4];
        [data appendData:valuesBytes];
    }

    int dataLength = (int)data.length - dataLengthPtr - 4;
    [data replaceBytesInRange:NSMakeRange(dataLengthPtr, 4) withBytes:&dataLength];
}

- (TGMediaAttachment *)parseMediaAttachment:(NSInputStream *)is
{
    int dataLength = 0;
    [is read:(uint8_t *)&dataLength maxLength:4];
    
    TGActionMediaAttachment *actionAttachment = [[TGActionMediaAttachment alloc] init];
    
    int actionType = 0;
    [is read:(uint8_t *)&actionType maxLength:4];
    dataLength -= 4;
    actionAttachment.actionType = (TGMessageAction)actionType;
    
    if (actionType == TGMessageActionChatAddMember || actionType == TGMessageActionChatDeleteMember)
    {
        int uid = 0;
        [is read:(uint8_t *)&uid maxLength:4];
        dataLength -= 4;
        
        NSMutableArray *uids = [[NSMutableArray alloc] init];
        if (dataLength >= 4) {
            int32_t uidsCount = 0;
            [is read:(uint8_t *)&uidsCount maxLength:4];
            dataLength -= 4;
            
            for (int32_t i = 0; dataLength > 0 && i < uidsCount; i++) {
                int32_t listUid = 0;
                [is read:(uint8_t *)&listUid maxLength:4];
                [uids addObject:@(listUid)];
                dataLength -= 4;
            }
        }
        
        if (uids.count != 0) {
            actionAttachment.actionData = @{@"uid": @(uid), @"uids": uids};
        } else {
            actionAttachment.actionData = @{@"uid": @(uid)};
        }
    }
    else if (actionType == TGMessageActionJoinedByLink)
    {
        int uid = 0;
        [is read:(uint8_t *)&uid maxLength:4];
        actionAttachment.actionData = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:uid] forKey:@"inviterId"];
    }
    else if (actionType == TGMessageActionChatEditTitle)
    {
        int length = 0;
        [is read:(uint8_t *)&length maxLength:4];
        uint8_t *titleBytes = malloc(length);
        [is read:titleBytes maxLength:length];
        NSString *title = [[NSString alloc] initWithBytesNoCopy:titleBytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
        actionAttachment.actionData = [NSDictionary dictionaryWithObject:(title == nil ? @"" : title) forKey:@"title"];
    }
    else if (actionType == TGMessageActionCreateChat)
    {
        int length = 0;
        [is read:(uint8_t *)&length maxLength:4];
        uint8_t *titleBytes = malloc(length);
        [is read:titleBytes maxLength:length];
        NSString *title = [[NSString alloc] initWithBytesNoCopy:titleBytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
        
        int count = 0;
        [is read:(uint8_t *)&count maxLength:4];
        NSMutableArray *uids = [[NSMutableArray alloc] initWithCapacity:count];
        for (int i = 0; i < count; i++)
        {
            int uid = 0;
            [is read:(uint8_t *)&uid maxLength:4];
            if (uid != 0)
                [uids addObject:[[NSNumber alloc] initWithInt:uid]];
        }
        
        actionAttachment.actionData = [[NSDictionary alloc] initWithObjectsAndKeys:(title == nil ? @"" : title), @"title", uids, @"uids", nil];
    }
    else if (actionType == TGMessageActionCreateBroadcastList)
    {
        int length = 0;
        [is read:(uint8_t *)&length maxLength:4];
        uint8_t *titleBytes = malloc(length);
        [is read:titleBytes maxLength:length];
        NSString *title = [[NSString alloc] initWithBytesNoCopy:titleBytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
        
        int count = 0;
        [is read:(uint8_t *)&count maxLength:4];
        NSMutableArray *uids = [[NSMutableArray alloc] initWithCapacity:count];
        for (int i = 0; i < count; i++)
        {
            int uid = 0;
            [is read:(uint8_t *)&uid maxLength:4];
            if (uid != 0)
                [uids addObject:[[NSNumber alloc] initWithInt:uid]];
        }
        
        actionAttachment.actionData = [[NSDictionary alloc] initWithObjectsAndKeys:(title == nil ? @"" : title), @"title", uids, @"uids", nil];
    }
    else if (actionType == TGMessageActionChatEditPhoto)
    {
        TGImageMediaAttachment *photo = (TGImageMediaAttachment *)[[[TGImageMediaAttachment alloc] init] parseMediaAttachment:is];
        if (photo != nil)
            actionAttachment.actionData = [[NSDictionary alloc] initWithObjectsAndKeys:photo, @"photo", nil];
    }
    else if (actionType == TGMessageActionContactRequest)
    {
        int hasPhone = 0;
        [is read:(uint8_t *)&hasPhone maxLength:4];
        actionAttachment.actionData = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithBool:hasPhone != 0], @"hasPhone", nil];
    }
    else if (actionType == TGMessageActionAcceptContactRequest)
    {
    }
    else if (actionType == TGMessageActionContactRegistered)
    {
    }
    else if (actionType == TGMessageActionUserChangedPhoto)
    {
        TGImageMediaAttachment *photo = (TGImageMediaAttachment *)[[[TGImageMediaAttachment alloc] init] parseMediaAttachment:is];
        if (photo != nil)
            actionAttachment.actionData = [[NSDictionary alloc] initWithObjectsAndKeys:photo, @"photo", nil];
    }
    else if (actionType == TGMessageActionEncryptedChatRequest)
    {
    }
    else if (actionType == TGMessageActionEncryptedChatAccept)
    {
    }
    else if (actionType == TGMessageActionEncryptedChatDecline)
    {   
    }
    else if (actionType == TGMessageActionEncryptedChatMessageLifetime)
    {
        int32_t messageLifetime = 0;
        [is read:(uint8_t *)&messageLifetime maxLength:4];
        actionAttachment.actionData = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithInt:messageLifetime], @"messageLifetime", nil];
    }
    else if (actionType == TGMessageActionEncryptedChatScreenshot)
    {
    }
    else if (actionType == TGMessageActionChannelCreated)
    {
        int length = 0;
        [is read:(uint8_t *)&length maxLength:4];
        uint8_t *titleBytes = malloc(length);
        [is read:titleBytes maxLength:length];
        NSString *title = [[NSString alloc] initWithBytesNoCopy:titleBytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
        actionAttachment.actionData = [NSDictionary dictionaryWithObject:(title == nil ? @"" : title) forKey:@"title"];
    }
    else if (actionType == TGMessageActionChannelCommentsStatusChanged) {
        uint8_t enabled = 0;
        [is read:(uint8_t *)&enabled maxLength:1];
        actionAttachment.actionData = @{@"enabled": @(enabled != 0)};
    } else if (actionType == TGMessageActionChannelInviter) {
        int32_t uid = 0;
        [is read:(uint8_t *)&uid maxLength:4];
        actionAttachment.actionData = @{@"uid": @(uid)};
    } else if (actionType == TGMessageActionGroupMigratedTo) {
        int32_t channelId = 0;
        [is read:(uint8_t *)&channelId maxLength:4];
        actionAttachment.actionData = @{@"channelId": @(channelId)};
    } else if (actionType == TGMessageActionChannelMigratedFrom) {
        int length = 0;
        [is read:(uint8_t *)&length maxLength:4];
        uint8_t *titleBytes = malloc(length);
        [is read:titleBytes maxLength:length];
        NSString *title = [[NSString alloc] initWithBytesNoCopy:titleBytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
        
        int32_t groupId = 0;
        [is read:(uint8_t *)&groupId maxLength:4];
        
        actionAttachment.actionData = @{@"groupId": @(groupId), @"title": title};
    } else if (actionType == TGMessageActionPinnedMessage) {
    } else if (actionType == TGMessageActionClearChat) {
    } else if (actionType == TGMessageActionGameScore) {
        int gameId = 0;
        [is read:(uint8_t *)&gameId maxLength:4];
        int score = 0;
        [is read:(uint8_t *)&score maxLength:4];
        actionAttachment.actionData = @{@"gameId": @(gameId), @"score": @(score)};
    } else if (actionType == TGMessageActionPhoneCall) {
        int64_t callId = 0;
        [is read:(uint8_t *)&callId maxLength:8];
        int32_t reason = 0;
        [is read:(uint8_t *)&reason maxLength:4];
        int32_t duration = 0;
        [is read:(uint8_t *)&duration maxLength:4];
        actionAttachment.actionData = @{@"callId": @(callId), @"reason": @(reason), @"duration": @(duration)};
    } else if (actionType == TGMessageActionPaymentSent) {
        int32_t currencyLength = 0;
        [is read:(uint8_t *)&currencyLength maxLength:4];
        uint8_t *titleBytes = malloc(currencyLength);
        [is read:titleBytes maxLength:currencyLength];
        NSString *title = [[NSString alloc] initWithBytesNoCopy:titleBytes length:currencyLength encoding:NSUTF8StringEncoding freeWhenDone:true];
        int32_t totalAmount = 0;
        [is read:(uint8_t *)&totalAmount maxLength:4];
        actionAttachment.actionData = @{@"currency": title, @"totalAmount": @(totalAmount)};
    } else if (actionType == TGMessageActionText) {
        int32_t textLength = 0;
        [is read:(uint8_t *)&textLength maxLength:4];
        uint8_t *titleBytes = malloc(textLength);
        [is read:titleBytes maxLength:textLength];
        NSString *title = [[NSString alloc] initWithBytesNoCopy:titleBytes length:textLength encoding:NSUTF8StringEncoding freeWhenDone:true];
        actionAttachment.actionData = @{@"text": title};
    } else if (actionType == TGMessageActionBotAllowed) {
        int32_t domainLength = 0;
        [is read:(uint8_t *)&domainLength maxLength:4];
        uint8_t *domainBytes = malloc(domainLength);
        [is read:domainBytes maxLength:domainLength];
        NSString *domain = [[NSString alloc] initWithBytesNoCopy:domainBytes length:domainLength encoding:NSUTF8StringEncoding freeWhenDone:true];
        if (domain == nil)
            domain = @"";
        actionAttachment.actionData = @{@"domain": domain};
    } else if (actionType == TGMessageActionSecureValuesSent) {
        int32_t valuesLength = 0;
        [is read:(uint8_t *)&valuesLength maxLength:4];
        uint8_t *valuesBytes = malloc(valuesLength);
        [is read:valuesBytes maxLength:valuesLength];
        NSString *values = [[NSString alloc] initWithBytesNoCopy:valuesBytes length:valuesLength encoding:NSUTF8StringEncoding freeWhenDone:true];
        if (values == nil)
            values = @"";
        actionAttachment.actionData = @{@"values": values};
    }
    
    return actionAttachment;
}

@end
