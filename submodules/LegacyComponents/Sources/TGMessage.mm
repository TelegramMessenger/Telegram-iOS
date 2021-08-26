#import "TGMessage.h"

#import "LegacyComponentsInternal.h"

#import "PSKeyValueCoder.h"
#import "PSKeyValueEncoder.h"
#import "PSKeyValueDecoder.h"
#import <objc/runtime.h>

#import "TGTextCheckingResult.h"
#import "TGPeerIdAdapter.h"
#import "TGPhoneUtils.h"

#include <unordered_map>

static void *NSTextCheckingResultTelegramHiddenLinkKey = &NSTextCheckingResultTelegramHiddenLinkKey;

@implementation NSTextCheckingResult (TGMessage)

- (void)setIsTelegramHiddenLink:(bool)value {
    objc_setAssociatedObject(self, NSTextCheckingResultTelegramHiddenLinkKey, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (bool)isTelegramHiddenLink {
    return [objc_getAssociatedObject(self, NSTextCheckingResultTelegramHiddenLinkKey) boolValue];
}

@end

static std::unordered_map<int, id<TGMediaAttachmentParser> > mediaAttachmentParsers;

typedef enum {
    TGMessageFlagBroadcast = 1,
    TGMessageFlagLayerMask = 2 | 4 | 8 | 16 | 32,
    TGMessageFlagContainsMention = 64,
    TGMessageFlagForceReply = (1 << 7),
    TGMessageFlagLayerMaskExtended = 0xff << 8,
    TGMessageFlagSilent = (1 << 16),
    TGMessageFlagEdited = (1 << 17),
    TGMessageFlagContainsUnseenMention = (1 << 18)
} TGMessageFlags;


@interface TGMessage () {
    bool _unread;
}

@property (nonatomic) bool hasNoCheckingResults;

@end

@implementation TGMessage

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    TGMessage *object = [[TGMessage alloc] init];
    
    object->_mid = [coder decodeInt32ForCKey:"i"];
    
    [coder decodeBytesForCKey:"sk" value:object->_sortKey.key length:8 + 1 + 4 + 4];
    
    object->_pts = [coder decodeInt32ForCKey:"pts"];
    
    object->_unread = [coder decodeInt32ForCKey:"unr"] != 0;
    object->_outgoing = [coder decodeInt32ForCKey:"out"] != 0;
    object->_deliveryState = (TGMessageDeliveryState)[coder decodeInt32ForCKey:"ds"];
    object->_fromUid = [coder decodeInt64ForCKey:"fi"];
    object->_toUid = [coder decodeInt64ForCKey:"ti"];
    object->_cid = [coder decodeInt64ForCKey:"ci"];
    
    object->_text = [coder decodeStringForCKey:"t"];
    object->_date = [coder decodeInt32ForCKey:"d"];
    object.mediaAttachments = [TGMessage parseMediaAttachments:[coder decodeDataCorCKey:"md"]];
    
    object->_realDate = [coder decodeInt32ForCKey:"rd"];
    object->_randomId = [coder decodeInt64ForCKey:"ri"];
    
    object->_messageLifetime = [coder decodeInt32ForCKey:"lt"];
    object->_flags = [coder decodeInt64ForCKey:"f"];
    object->_seqIn = [coder decodeInt32ForCKey:"sqi"];
    object->_seqOut = [coder decodeInt32ForCKey:"sqo"];
    
    object->_contentProperties = [TGMessage parseContentProperties:[coder decodeDataCorCKey:"cpr"]];
    
    return object;
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeInt32:_mid forCKey:"i"];
    
    [coder encodeBytes:_sortKey.key length:8 + 1 + 4 + 4 forCKey:"sk"];
    
    [coder encodeInt32:_pts forCKey:"pts"];
    
    [coder encodeInt32:_unread ? 1 : 0 forCKey:"unr"];
    [coder encodeInt32:_outgoing ? 1 : 0 forCKey:"out"];
    [coder encodeInt32:_deliveryState forCKey:"ds"];
    [coder encodeInt64:_fromUid forCKey:"fi"];
    [coder encodeInt64:_toUid forCKey:"ti"];
    [coder encodeInt64:_cid forCKey:"ci"];
    
    [coder encodeString:_text forCKey:"t"];
    [coder encodeInt32:(int32_t)_date forCKey:"d"];
    [coder encodeData:[self serializeMediaAttachments:true] forCKey:"md"];
    
    [coder encodeInt32:(int32_t)_realDate forCKey:"rd"];
    [coder encodeInt64:_randomId forCKey:"ri"];
    
    [coder encodeInt32:_messageLifetime forCKey:"lt"];
    [coder encodeInt64:_flags forCKey:"f"];
    
    [coder encodeInt32:_seqIn forCKey:"sqi"];
    [coder encodeInt32:_seqOut forCKey:"sqo"];
    
    [coder encodeData:[self serializeContentProperties] forCKey:"cpr"];
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGMessage *copyMessage = [[TGMessage alloc] init];
    
    copyMessage->_hintUnread = _hintUnread;
    
    copyMessage->_mid = _mid;
    copyMessage->_sortKey = _sortKey;
    copyMessage->_pts = _pts;
    copyMessage->_unread = _unread;
    copyMessage->_outgoing = _outgoing;
    copyMessage->_deliveryState = _deliveryState;
    copyMessage->_fromUid = _fromUid;
    copyMessage->_toUid = _toUid;
    copyMessage->_cid = _cid;
    
    copyMessage->_text = _text;
    copyMessage->_date = _date;
    copyMessage->_mediaAttachments = [[NSArray alloc] initWithArray:_mediaAttachments];
    
    copyMessage->_realDate = _realDate;
    copyMessage->_randomId = _randomId;
    
    copyMessage->_actionInfo = _actionInfo;
    
    copyMessage->_textCheckingResults = _textCheckingResults;
    
    copyMessage->_messageLifetime = _messageLifetime;
    copyMessage->_flags = _flags;
    
    copyMessage->_seqIn = _seqIn;
    copyMessage->_seqOut = _seqOut;
    
    copyMessage->_contentProperties = [[NSDictionary alloc] initWithDictionary:_contentProperties];
    
    copyMessage->_hideReplyMarkup = _hideReplyMarkup;
    
    copyMessage->_hole = _hole;
    copyMessage->_group = _group;
    
    return copyMessage;
}

- (TGMessageTransparentSortKey)transparentSortKey
{
    return TGMessageTransparentSortKeyMake(TGMessageSortKeyPeerId(_sortKey), TGMessageSortKeyTimestamp(_sortKey), TGMessageSortKeyMid(_sortKey), TGMessageSortKeySpace(_sortKey));
}

- (void)setIsBroadcast:(bool)isBroadcast
{
    if (isBroadcast)
        _flags |= TGMessageFlagBroadcast;
    else
        _flags &= ~TGMessageFlagBroadcast;
}

- (bool)isBroadcast
{
    return _flags & TGMessageFlagBroadcast;
}

- (void)setForceReply:(bool)forceReply
{
    if (forceReply)
        _flags |= TGMessageFlagForceReply;
    else
        _flags &= TGMessageFlagForceReply;
}

- (bool)forceReply
{
    return _flags & TGMessageFlagForceReply;
}

- (void)setIsSilent:(bool)isSilent {
    if (isSilent) {
        _flags |= TGMessageFlagSilent;
    } else {
        _flags &= ~TGMessageFlagSilent;
    }
}

- (bool)isSilent {
    return _flags & TGMessageFlagSilent;
}

- (bool)isEdited {
    return _flags & TGMessageFlagEdited;
}

- (void)setIsEdited:(bool)isEdited {
    if (isEdited) {
        _flags |= TGMessageFlagEdited;
    } else {
        _flags &= ~TGMessageFlagEdited;
    }
}

- (void)setLayer:(NSUInteger)layer
{
    int32_t layerLow = (int32_t)MIN((int32_t)layer, 31);
    int32_t layerHigh = (int32_t)((int32_t)layer - layerLow);
    _flags = (_flags & ~TGMessageFlagLayerMask) | ((layerLow & (1 | 2 | 4 | 8 | 16)) << 1);
    _flags = (_flags & ~TGMessageFlagLayerMaskExtended) | ((layerHigh & 0xff) << 8);
}

- (NSUInteger)layer
{
    if (!TGPeerIdIsSecretChat(self.cid)) {
        return 70;
    }
    NSUInteger value = [TGMessage layerFromFlags:_flags];
    if (value < 1)
        value = 1;
    return value;
}

- (void)setContainsMention:(bool)containsMention
{
    if (containsMention)
        _flags |= TGMessageFlagContainsMention;
    else
        _flags &= (~TGMessageFlagContainsMention);
}

- (bool)containsMention
{
    return _flags & TGMessageFlagContainsMention;
}

- (void)setContainsUnseenMention:(bool)containsUnseenMention
{
    if (containsUnseenMention)
        _flags |= TGMessageFlagContainsUnseenMention;
    else
        _flags &= (~TGMessageFlagContainsUnseenMention);
}

- (bool)containsUnseenMention
{
    return _flags & TGMessageFlagContainsUnseenMention;
}

+ (NSUInteger)layerFromFlags:(int64_t)flags
{
    int32_t layerLow = (int32_t)((flags & TGMessageFlagLayerMask) >> 1);
    int32_t layerHigh = (int32_t)((flags & TGMessageFlagLayerMaskExtended) >> 8);
    int32_t value = layerLow + layerHigh;
    if (value < 1)
        value = 1;
    return value;
}

+ (bool)containsUnseenMention:(int64_t)flags {
    return flags & TGMessageFlagContainsUnseenMention;
}

- (int64_t)forwardPeerId
{
    for (TGMediaAttachment *attachment in _mediaAttachments)
    {
        if (attachment.type == TGForwardedMessageMediaAttachmentType)
        {
            TGForwardedMessageMediaAttachment *forwardedMessageAttachment = (TGForwardedMessageMediaAttachment *)attachment;
            return forwardedMessageAttachment.forwardPeerId;
        }
    }
    
    return 0;
}

- (int64_t)groupedId {
    TGMessageGroupedIdContentProperty *property = _contentProperties[@"groupedId"];
    return property.groupedId;
}

- (void)setGroupedId:(int64_t)groupedId {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:_contentProperties];
    if (groupedId != 0) {
        dict[@"groupedId"] = [[TGMessageGroupedIdContentProperty alloc] initWithGroupedId:groupedId];
    } else {
        [dict removeObjectForKey:@"groupedId"];
    }
    _contentProperties = dict;
}

- (NSTimeInterval)editDate {
    TGMessageEditDateContentProperty *property = _contentProperties[@"editDate"];
    return property.editDate;
}

- (void)setEditDate:(NSTimeInterval)editDate {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:_contentProperties];
    if (editDate > 0) {
        dict[@"editDate"] = [[TGMessageEditDateContentProperty alloc] initWithEditDate:editDate];
    } else {
        [dict removeObjectForKey:@"editDate"];
    }
    _contentProperties = dict;
}

- (TGMessageViewCountContentProperty *)viewCount {
    return _contentProperties[@"viewCount"];
}

- (void)setViewCount:(TGMessageViewCountContentProperty *)viewCount {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:_contentProperties];
    if (viewCount != nil) {
        dict[@"viewCount"] = viewCount;
    } else {
        [dict removeObjectForKey:@"viewCount"];
    }
    _contentProperties = dict;
}

- (void)setText:(NSString *)text
{
    _text = text;
    
    _textCheckingResults = nil;
    _hasNoCheckingResults = false;
}

- (NSArray *)effectiveTextAndEntities {
    NSArray *entities = nil;
    for (id media in self.mediaAttachments) {
        if ([media isKindOfClass:[TGImageMediaAttachment class]]) {
            return @[((TGImageMediaAttachment *)media).caption ?: @"", @[]];
        } else if ([media isKindOfClass:[TGVideoMediaAttachment class]]) {
            return @[((TGImageMediaAttachment *)media).caption ?: @"", @[]];
        } else if ([media isKindOfClass:[TGDocumentMediaAttachment class]]) {
            return @[((TGImageMediaAttachment *)media).caption ?: @"", @[]];
        } else if ([media isKindOfClass:[TGMessageEntitiesAttachment class]]) {
            entities = ((TGMessageEntitiesAttachment *)media).entities;
        }
    }
    return @[_text ?: @"", entities ?: @[]];
}

- (bool)local
{
    return _mid >= TGMessageLocalMidBaseline;
}

+ (NSArray *)textCheckingResultsForText:(NSString *)text highlightMentionsAndTags:(bool)highlightMentionsAndTags highlightCommands:(bool)highlightCommands entities:(NSArray *)entities
{
    return [self textCheckingResultsForText:text highlightMentionsAndTags:highlightMentionsAndTags highlightCommands:highlightCommands entities:entities highlightAsExternalMentionsAndHashtags:false];
}

+ (NSArray *)textCheckingResultsForText:(NSString *)text highlightMentionsAndTags:(bool)highlightMentionsAndTags highlightCommands:(bool)highlightCommands entities:(NSArray *)entities highlightAsExternalMentionsAndHashtags:(bool)highlightAsExternalMentionsAndHashtags
{
    if (entities != nil) {
        NSMutableArray *textCheckingResults = [[NSMutableArray alloc] init];
        
        bool hasPhoneEntities = false;
        for (TGMessageEntity *entity in entities) {
            if (entity.range.location + entity.range.length > text.length) {
                continue;
            }
            
            if ([entity isKindOfClass:[TGMessageEntityBold class]]) {
                [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeBold contents:@""]];
            } else if ([entity isKindOfClass:[TGMessageEntityBotCommand class]]) {
                if (entity.range.length > 1) {
                    [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeCommand contents:[text substringWithRange:NSMakeRange(entity.range.location, entity.range.length)]]];
                }
            } else if ([entity isKindOfClass:[TGMessageEntityCode class]]) {
                [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeCode contents:@""]];
            } else if ([entity isKindOfClass:[TGMessageEntityEmail class]]) {
                NSString *email = [text substringWithRange:entity.range];
                [textCheckingResults addObject:[NSTextCheckingResult linkCheckingResultWithRange:entity.range URL:[NSURL URLWithString:[@"mailto:" stringByAppendingString:email]]]];
            } else if ([entity isKindOfClass:[TGMessageEntityHashtag class]]) {
                if (entity.range.length > 1) {
                    [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeHashtag contents:[text substringWithRange:NSMakeRange(entity.range.location + 1, entity.range.length - 1)]]];
                }
            } else if ([entity isKindOfClass:[TGMessageEntityItalic class]]) {
                [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeItalic contents:@""]];
            } else if ([entity isKindOfClass:[TGMessageEntityMention class]]) {
                if (entity.range.length > 1) {
                    [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeMention contents:[text substringWithRange:NSMakeRange(entity.range.location + 1, entity.range.length - 1)]]];
                }
            } else if ([entity isKindOfClass:[TGMessageEntityMentionName class]]) {
                [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeLink contents:[NSString stringWithFormat:@"tg-user://%d", ((TGMessageEntityMentionName *)entity).userId]]];
            } else if ([entity isKindOfClass:[TGMessageEntityPre class]]) {
                [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeCode contents:@""]];
            } else if ([entity isKindOfClass:[TGMessageEntityTextUrl class]]) {
                NSTextCheckingResult *result = [NSTextCheckingResult linkCheckingResultWithRange:entity.range URL:[NSURL URLWithString:((TGMessageEntityTextUrl *)entity).url]];
                [result setIsTelegramHiddenLink:true];
                [textCheckingResults addObject:result];
            } else if ([entity isKindOfClass:[TGMessageEntityUrl class]]) {
                NSString *link = [text substringWithRange:entity.range];
                NSURL *url = [NSURL URLWithString:link];
                if (url == nil) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    url = [NSURL URLWithString:[link stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
#pragma clang diagnostic pop
                }
                [textCheckingResults addObject:[NSTextCheckingResult linkCheckingResultWithRange:entity.range URL:url]];
            } else if ([entity isKindOfClass:[TGMessageEntityCashtag class]]) {
                if (entity.range.length > 1) {
                    [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeCashtag contents:[text substringWithRange:NSMakeRange(entity.range.location + 1, entity.range.length - 1)]]];
                }
            } else if ([entity isKindOfClass:[TGMessageEntityPhone class]]) {
                NSString *phone = [text substringWithRange:entity.range];
                phone = [TGPhoneUtils cleanInternationalPhone:phone forceInternational:false];
                NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"tel:%@", phone]];
                if (url != nil)
                    [textCheckingResults addObject:[NSTextCheckingResult linkCheckingResultWithRange:entity.range URL:url]];
                
                hasPhoneEntities = true;
            }
        }
        
        if (!hasPhoneEntities)
        {
            SEL sel = @selector(characterAtIndex:);
            int length = (int)text.length;
            unichar (*characterAtIndexImp)(id, SEL, NSUInteger) = (unichar (*)(id, SEL, NSUInteger))[text methodForSelector:sel];
            
            int digitCount = 0;
            for (int i = 0; i < length; i++)
            {
                unichar c = characterAtIndexImp(text, sel, i);
                if (c >= '0' && c <= '9') {
                    digitCount++;
                    if (digitCount == 2) {
                        break;
                    }
                } else {
                    digitCount = 0;
                }
            }
            
            if (digitCount >= 2) {
                NSError *error = nil;
                static NSDataDetector *dataDetector = nil;
                if (dataDetector == nil)
                    dataDetector = [NSDataDetector dataDetectorWithTypes:(int)(NSTextCheckingTypePhoneNumber) error:&error];
                [dataDetector enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *match, __unused NSMatchingFlags flags, __unused BOOL *stop)
                 {
                     NSTextCheckingType type = [match resultType];
                     if (type == NSTextCheckingTypePhoneNumber)
                     {
                         [textCheckingResults addObject:match];
                     }
                 }];
            }
        }
        
        return textCheckingResults;
    }
    
    bool containsSomething = false;
    
    int length = (int)text.length;
    
    int digitsInRow = 0;
    int schemeSequence = 0;
    int dotSequence = 0;
    
    unichar lastChar = 0;
    
    SEL sel = @selector(characterAtIndex:);
    unichar (*characterAtIndexImp)(id, SEL, NSUInteger) = (unichar (*)(id, SEL, NSUInteger))[text methodForSelector:sel];
    
    for (int i = 0; i < length; i++)
    {
        unichar c = characterAtIndexImp(text, sel, i);
        
        if (highlightMentionsAndTags && (c == '@' || c == '#' || c == '$'))
        {
            containsSomething = true;
            break;
        }
        
        if (c >= '0' && c <= '9')
        {
            digitsInRow++;
            if (digitsInRow >= 3)
            {
                containsSomething = true;
                break;
            }
            
            schemeSequence = 0;
            dotSequence = 0;
        }
        else if (!(c != ' ' && digitsInRow > 0))
            digitsInRow = 0;
        
        if (c == ':')
        {
            if (schemeSequence == 0)
                schemeSequence = 1;
            else
                schemeSequence = 0;
        }
        else if (c == '/')
        {
            if (highlightCommands)
            {
                containsSomething = true;
                break;
            }
            
            if (schemeSequence == 2)
            {
                containsSomething = true;
                break;
            }
            
            if (schemeSequence == 1)
                schemeSequence++;
            else
                schemeSequence = 0;
        }
        else if (c == '.')
        {
            if (dotSequence == 0 && lastChar != ' ')
                dotSequence++;
            else
                dotSequence = 0;
        }
        else if (c != ' ' && lastChar == '.' && dotSequence == 1)
        {
            containsSomething = true;
            break;
        }
        else
        {
            dotSequence = 0;
        }
        
        lastChar = c;
    }
    
    if (containsSomething)
    {
        NSError *error = nil;
        static NSDataDetector *dataDetector = nil;
        if (dataDetector == nil)
            dataDetector = [NSDataDetector dataDetectorWithTypes:(int)(NSTextCheckingTypeLink | NSTextCheckingTypePhoneNumber) error:&error];
        
        NSMutableArray *results = [[NSMutableArray alloc] init];
        [dataDetector enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *match, __unused NSMatchingFlags flags, __unused BOOL *stop)
        {
            NSTextCheckingType type = [match resultType];
            if (type == NSTextCheckingTypeLink || type == NSTextCheckingTypePhoneNumber)
            {
                [results addObject:match];
            }
        }];
        
        static NSCharacterSet *characterSet = nil;
        static NSCharacterSet *punctuationSet = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            characterSet = [NSCharacterSet alphanumericCharacterSet];
            punctuationSet = [NSCharacterSet punctuationCharacterSet];
        });
        
        if (containsSomething && (highlightMentionsAndTags || highlightCommands))
        {
            int mentionStart = -1;
            int hashtagStart = -1;
            int cashtagStart = -1;
            int commandStart = -1;
            
            unichar previous = 0;
            for (int i = 0; i < length; i++)
            {
                unichar c = characterAtIndexImp(text, sel, i);
                if (highlightMentionsAndTags && commandStart == -1)
                {
                    if (mentionStart != -1)
                    {
                        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' || c == 0x200C || (highlightAsExternalMentionsAndHashtags && c == '.')))
                        {
                            if (i > mentionStart + 1)
                            {
                                NSRange range = NSMakeRange(mentionStart + 1, i - mentionStart - 1);
                                NSRange mentionRange = NSMakeRange(range.location - 1, range.length + 1);
                                
                                unichar mentionStartChar = [text characterAtIndex:mentionRange.location + 1];
                                if (!(mentionRange.length <= 1 || (mentionStartChar >= '0' && mentionStartChar <= '9')))
                                {
                                    [results addObject:[[TGTextCheckingResult alloc] initWithRange:mentionRange type:TGTextCheckingResultTypeMention contents:[text substringWithRange:range]]];
                                }
                            }
                            mentionStart = -1;
                        }
                    }
                    else if (hashtagStart != -1)
                    {
                        if (c == ' ' || (![characterSet characterIsMember:c] && c != '_' && c != 0x200C))
                        {
                            if (i > hashtagStart + 1)
                            {
                                NSRange range = NSMakeRange(hashtagStart + 1, i - hashtagStart - 1);
                                NSRange hashtagRange = NSMakeRange(range.location - 1, range.length + 1);
                                
                                [results addObject:[[TGTextCheckingResult alloc] initWithRange:hashtagRange type:TGTextCheckingResultTypeHashtag contents:[text substringWithRange:range]]];
                            }
                            hashtagStart = -1;
                        }
                    }
                    else if (cashtagStart != - 1)
                    {
                        if (c == ' ' || !(c >= 'A' && c <= 'Z') || i > cashtagStart + 8)
                        {
                            if (i > cashtagStart + 1)
                            {
                                NSRange range = NSMakeRange(cashtagStart + 1, i - cashtagStart - 1);
                                NSRange cashtagRange = NSMakeRange(range.location - 1, range.length + 1);
                                
                                if (range.length >= 3)
                                {
                                    [results addObject:[[TGTextCheckingResult alloc] initWithRange:cashtagRange type:TGTextCheckingResultTypeCashtag contents:[text substringWithRange:range]]];
                                }
                            }
                            cashtagStart = -1;
                        }
                    }
                    
                    if (c == '@')
                    {
                        if (previous == 0 || previous == ' ' || previous == '\n' || previous == '[' || previous == ']' || previous == '(' || previous == ')' || previous == ':') {
                            mentionStart = i;
                        }
                    }
                    else if (c == '#')
                    {
                        hashtagStart = i;
                    }
                    else if (c == '$')
                    {
                        cashtagStart = i;
                    }
                }
                
                if (highlightCommands && mentionStart == -1 && hashtagStart == -1)
                {
                    if (commandStart != -1 && ![characterSet characterIsMember:c] && c != '@' && c != '_')
                    {
                        if (i - commandStart > 1)
                        {
                            NSRange range = NSMakeRange(commandStart, i - commandStart);
                            [results addObject:[[TGTextCheckingResult alloc] initWithRange:range type:TGTextCheckingResultTypeCommand contents:[text substringWithRange:range]]];
                        }
                        
                        commandStart = -1;
                    }
                    else if (c == '/' && (previous == 0 || previous == ' ' || previous == '\n' || previous == '\t'))
                    {
                        commandStart = i;
                    }
                }
                previous = c;
            }
            
            if (mentionStart != -1 && mentionStart + 1 < length - 1)
            {
                NSRange range = NSMakeRange(mentionStart + 1, length - mentionStart - 1);
                NSRange mentionRange = NSMakeRange(range.location - 1, range.length + 1);
                unichar mentionStartChar = [text characterAtIndex:mentionRange.location + 1];
                if (!(mentionRange.length <= 2 || (mentionStartChar >= '0' && mentionStartChar <= '9')))
                {
                    [results addObject:[[TGTextCheckingResult alloc] initWithRange:mentionRange type:TGTextCheckingResultTypeMention contents:[text substringWithRange:range]]];
                }
            }
            
            if (hashtagStart != -1 && hashtagStart + 1 < length - 1)
            {
                NSRange range = NSMakeRange(hashtagStart + 1, length - hashtagStart - 1);
                NSRange hashtagRange = NSMakeRange(range.location - 1, range.length + 1);
                [results addObject:[[TGTextCheckingResult alloc] initWithRange:hashtagRange type:TGTextCheckingResultTypeHashtag contents:[text substringWithRange:range]]];
            }
            
            if (cashtagStart != -1 && cashtagStart + 1 < length - 1)
            {
                NSRange range = NSMakeRange(cashtagStart + 1, length - cashtagStart - 1);
                NSRange cashtagRange = NSMakeRange(range.location - 1, range.length + 1);
                
                if (range.length >= 3)
                {
                    [results addObject:[[TGTextCheckingResult alloc] initWithRange:cashtagRange type:TGTextCheckingResultTypeCashtag contents:[text substringWithRange:range]]];
                }
            }
            
            if (commandStart != -1 && commandStart + 1 < length)
            {
                NSRange range = NSMakeRange(commandStart, length - commandStart);
                [results addObject:[[TGTextCheckingResult alloc] initWithRange:range type:TGTextCheckingResultTypeCommand contents:[text substringWithRange:range]]];
            }
        }
        
        return results;
    }
    
    return nil;
}

+ (NSArray *)entitiesForMarkedUpText:(NSString *)text resultingText:(__autoreleasing NSString **)resultingText {
    NSMutableArray *entities = [[NSMutableArray alloc] init];
    
    NSMutableString *cleanText = [[NSMutableString alloc] initWithString:text];
    
#ifdef DEBUG    
    while (true)
    {
        NSRange startRange = [cleanText rangeOfString:@"***"];
        if (startRange.location == NSNotFound)
            break;
        
        [cleanText deleteCharactersInRange:startRange];
        
        NSRange endRange = [cleanText rangeOfString:@"***"];
        if (endRange.location == NSNotFound)
            break;
        
        [cleanText deleteCharactersInRange:endRange];
        
        NSRange range = NSMakeRange(startRange.location, endRange.location - startRange.location);
        [entities addObject:[[TGMessageEntityBold alloc] initWithRange:range]];
    }
    
    while (true)
    {
        NSRange startRange = [cleanText rangeOfString:@"%%%"];
        if (startRange.location == NSNotFound)
            break;
        
        [cleanText deleteCharactersInRange:startRange];
        
        NSRange endRange = [cleanText rangeOfString:@"%%%"];
        if (endRange.location == NSNotFound)
            break;
        
        [cleanText deleteCharactersInRange:endRange];
        
        NSRange range = NSMakeRange(startRange.location, endRange.location - startRange.location);
        [entities addObject:[[TGMessageEntityItalic alloc] initWithRange:range]];
    }
    
    while (true)
    {
        NSRange startRange = [cleanText rangeOfString:@"```"];
        if (startRange.location == NSNotFound)
            break;
        
        [cleanText deleteCharactersInRange:startRange];
        
        NSRange endRange = [cleanText rangeOfString:@"```"];
        if (endRange.location == NSNotFound)
            break;
        
        [cleanText deleteCharactersInRange:endRange];
        
        NSRange range = NSMakeRange(startRange.location, endRange.location - startRange.location);
        [entities addObject:[[TGMessageEntityPre alloc] initWithRange:range]];
    }
    
    while (true)
    {
        NSRange startRange = [cleanText rangeOfString:@"[[["];
        if (startRange.location == NSNotFound)
            break;
        
        [cleanText deleteCharactersInRange:startRange];
        
        NSRange endRange = [cleanText rangeOfString:@"]]]"];
        if (endRange.location == NSNotFound)
            break;
        
        [cleanText deleteCharactersInRange:endRange];
        
        NSRange range = NSMakeRange(startRange.location, endRange.location - startRange.location);
        [entities addObject:[[TGMessageEntityTextUrl alloc] initWithRange:range url:@"http://google.com"]];
    }
#endif
    
    if (resultingText != NULL) {
        *resultingText = cleanText;
    }
    
    return entities.count == 0 ? nil : entities;
}

- (NSArray *)textCheckingResults
{
    if (_textCheckingResults != nil) {
        return _textCheckingResults;
    }
    
    NSString *legacyCaption = nil;
    NSArray *legacyTextCheckingResults = nil;
    for (id attachment in self.mediaAttachments) {
        if ([attachment isKindOfClass:[TGImageMediaAttachment class]]) {
            legacyCaption = ((TGImageMediaAttachment *)attachment).caption;
            if (legacyCaption.length > 0)
                legacyTextCheckingResults = ((TGImageMediaAttachment *)attachment).textCheckingResults;
        } else if ([attachment isKindOfClass:[TGVideoMediaAttachment class]]) {
            legacyCaption = ((TGVideoMediaAttachment *)attachment).caption;
            if (legacyCaption.length > 0)
                legacyTextCheckingResults = ((TGVideoMediaAttachment *)attachment).textCheckingResults;
        } else if ([attachment isKindOfClass:[TGDocumentMediaAttachment class]]) {
            legacyCaption = ((TGDocumentMediaAttachment *)attachment).caption;
            if (legacyCaption.length > 0)
                legacyTextCheckingResults = ((TGDocumentMediaAttachment *)attachment).textCheckingResults;
        }
    }
    
    if (legacyTextCheckingResults.count > 0)
        return legacyTextCheckingResults;
    
    if (_mediaAttachments.count != 0) {
        bool hasPhoneEntities = false;
        
        for (TGMediaAttachment *attachment in _mediaAttachments) {
            if (attachment.type == TGMessageEntitiesAttachmentType) {
                NSMutableArray *textCheckingResults = [[NSMutableArray alloc] init];
                
                for (TGMessageEntity *entity in ((TGMessageEntitiesAttachment *)attachment).entities) {
                    if (entity.range.location + entity.range.length > _text.length) {
                        continue;
                    }
                    
                    if ([entity isKindOfClass:[TGMessageEntityBold class]]) {
                        [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeBold contents:@""]];
                    } else if ([entity isKindOfClass:[TGMessageEntityBotCommand class]]) {
                        if (entity.range.length > 1) {
                            [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeCommand contents:[_text substringWithRange:NSMakeRange(entity.range.location, entity.range.length)]]];
                        }
                    } else if ([entity isKindOfClass:[TGMessageEntityCode class]]) {
                        [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeCode contents:@""]];
                    } else if ([entity isKindOfClass:[TGMessageEntityEmail class]]) {
                        NSString *email = [_text substringWithRange:entity.range];
                        [textCheckingResults addObject:[NSTextCheckingResult linkCheckingResultWithRange:entity.range URL:[NSURL URLWithString:[@"mailto:" stringByAppendingString:email]]]];
                    } else if ([entity isKindOfClass:[TGMessageEntityHashtag class]]) {
                        if (entity.range.length > 1) {
                            [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeHashtag contents:[_text substringWithRange:NSMakeRange(entity.range.location + 1, entity.range.length - 1)]]];
                        }
                    } else if ([entity isKindOfClass:[TGMessageEntityItalic class]]) {
                        [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeItalic contents:@""]];
                    } else if ([entity isKindOfClass:[TGMessageEntityMention class]]) {
                        if (entity.range.length > 1) {
                            [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeMention contents:[_text substringWithRange:NSMakeRange(entity.range.location + 1, entity.range.length - 1)]]];
                        }
                    } else if ([entity isKindOfClass:[TGMessageEntityMentionName class]]) {
                        [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeLink contents:[NSString stringWithFormat:@"tg-user://%d", ((TGMessageEntityMentionName *)entity).userId]]];
                    } else if ([entity isKindOfClass:[TGMessageEntityPre class]]) {
                        [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeCode contents:@""]];
                    } else if ([entity isKindOfClass:[TGMessageEntityTextUrl class]]) {
                        //NSTextCheckingResult *result = [NSTextCheckingResult linkCheckingResultWithRange:entity.range URL:[NSURL URLWithString:((TGMessageEntityTextUrl *)entity).url]];
                        TGTextCheckingResult *result = [[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeLink contents:((TGMessageEntityTextUrl *)entity).url value:nil highlightAsLink:true];
                        //[result setIsTelegramHiddenLink:true];
                        [textCheckingResults addObject:result];
                    } else if ([entity isKindOfClass:[TGMessageEntityUrl class]]) {
                        NSString *link = [_text substringWithRange:entity.range];
                        NSURL *url = [NSURL URLWithString:link];
                        if (url == nil) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                            url = [NSURL URLWithString:[link stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
#pragma clang diagnostic pop
                        }
                        [textCheckingResults addObject:[NSTextCheckingResult linkCheckingResultWithRange:entity.range URL:url]];
                    } else if ([entity isKindOfClass:[TGMessageEntityCashtag class]]) {
                        if (entity.range.length > 1) {
                            [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:entity.range type:TGTextCheckingResultTypeCashtag contents:[_text substringWithRange:NSMakeRange(entity.range.location + 1, entity.range.length - 1)]]];
                        }
                    } else if ([entity isKindOfClass:[TGMessageEntityPhone class]]) {
                        NSString *phone = [_text substringWithRange:entity.range];
                        phone = [TGPhoneUtils cleanInternationalPhone:phone forceInternational:false];
                        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"tel:%@", phone]];
                        if (url != nil)
                            [textCheckingResults addObject:[NSTextCheckingResult linkCheckingResultWithRange:entity.range URL:url]];
                        
                        hasPhoneEntities = true;
                    }
                }
                
                if (!hasPhoneEntities)
                {
                    SEL sel = @selector(characterAtIndex:);
                    NSString *text = _text;
                    int length = (int)text.length;
                    unichar (*characterAtIndexImp)(id, SEL, NSUInteger) = (unichar (*)(id, SEL, NSUInteger))[text methodForSelector:sel];
                    
                    int digitCount = 0;
                    for (int i = 0; i < length; i++)
                    {
                        unichar c = characterAtIndexImp(text, sel, i);
                        if (c >= '0' && c <= '9') {
                            digitCount++;
                            if (digitCount == 2) {
                                break;
                            }
                        } else {
                            digitCount = 0;
                        }
                    }
                    
                    if (digitCount >= 2) {
                        static NSDataDetector *dataDetector = nil;
                        static dispatch_once_t onceToken;
                        dispatch_once(&onceToken, ^{
                            NSError *error = nil;
                            dataDetector = [NSDataDetector dataDetectorWithTypes:(int)(NSTextCheckingTypePhoneNumber) error:&error];
                        });
                        [dataDetector enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *match, __unused NSMatchingFlags flags, __unused BOOL *stop)
                         {
                             NSTextCheckingType type = [match resultType];
                             if (type == NSTextCheckingTypePhoneNumber)
                             {
                                 [textCheckingResults addObject:match];
                             }
                         }];
                    }
                }
                
                _textCheckingResults = textCheckingResults;
                return textCheckingResults;
            }
        }
    }
    
    if (_text.length < 2 || _text.length > 1024 * 20)
        return nil;
    
    if (_textCheckingResults == nil && !_hasNoCheckingResults)
    {
        _textCheckingResults = [TGMessage textCheckingResultsForText:_text highlightMentionsAndTags:true highlightCommands:true entities:nil];
        _hasNoCheckingResults = _textCheckingResults == nil;
    }
    
    return _textCheckingResults;
}

- (void)setReplyMarkup:(TGBotReplyMarkup *)replyMarkup
{
    NSMutableArray *array = [[NSMutableArray alloc] initWithArray:_mediaAttachments];
    NSUInteger index = 0;
    for (TGMediaAttachment *attachment in array)
    {
        if (attachment.type == TGReplyMarkupAttachmentType)
        {
            [array removeObjectAtIndex:index];
            break;
        }
        index++;
    }
    TGReplyMarkupAttachment *attachment = [[TGReplyMarkupAttachment alloc] init];
    attachment.replyMarkup = replyMarkup;
    [array addObject:attachment];
    _mediaAttachments = array;
}

- (TGBotReplyMarkup *)replyMarkup
{
    for (TGMediaAttachment *attachment in _mediaAttachments)
    {
        if (attachment.type == TGReplyMarkupAttachmentType)
        {
            return ((TGReplyMarkupAttachment *)attachment).replyMarkup;
        }
    }
    
    return nil;
}

- (void)setEntities:(NSArray *)entities
{
    NSMutableArray *array = [[NSMutableArray alloc] initWithArray:_mediaAttachments];
    NSUInteger index = 0;
    for (TGMediaAttachment *attachment in array)
    {
        if (attachment.type == TGMessageEntitiesAttachmentType)
        {
            [array removeObjectAtIndex:index];
            break;
        }
        index++;
    }
    TGMessageEntitiesAttachment *attachment = [[TGMessageEntitiesAttachment alloc] init];
    attachment.entities = entities;
    [array addObject:attachment];
    _mediaAttachments = array;
}

- (NSArray *)entities
{
    for (TGMediaAttachment *attachment in _mediaAttachments)
    {
        if (attachment.type == TGMessageEntitiesAttachmentType)
        {
            return ((TGMessageEntitiesAttachment *)attachment).entities;
        }
    }
    
    return nil;
}

- (NSString *)authorSignature {
    for (TGMediaAttachment *attachment in _mediaAttachments)
    {
        if (attachment.type == TGAuthorSignatureMediaAttachmentType)
        {
            return ((TGAuthorSignatureMediaAttachment *)attachment).signature;
        }
    }
    
    return nil;
}

- (NSString *)forwardAuthorSignature {
    for (TGMediaAttachment *attachment in _mediaAttachments)
    {
        if (attachment.type == TGForwardedMessageMediaAttachmentType) {
            return ((TGForwardedMessageMediaAttachment *)attachment).forwardAuthorSignature;
        }
    }
    
    return nil;
}

+ (void)registerMediaAttachmentParser:(int)type parser:(id<TGMediaAttachmentParser>)parser
{
    mediaAttachmentParsers.insert(std::pair<int, id<TGMediaAttachmentParser> >(type, parser));
}

- (NSData *)serializeMediaAttachments:(bool)includeMeta
{
    if (_mediaAttachments == nil || _mediaAttachments.count == 0)
        return [NSData data];
    
    NSMutableData *data = [[NSMutableData alloc] init];
    
    int count = 0;
    NSRange countRange = NSMakeRange(data.length, 4);
    [data appendBytes:&count length:4];
    
    for (TGMediaAttachment *attachment in _mediaAttachments)
    {
        if (!includeMeta && attachment.isMeta)
            continue;
        
        int type = attachment.type;
        [data appendBytes:&type length:4];
        
        [attachment serialize:data];
        
        count++;
    }
    
    [data replaceBytesInRange:countRange withBytes:&count];
    
    return data;
}

+ (NSData *)serializeMediaAttachments:(bool)includeMeta attachments:(NSArray *)attachments
{
    if (attachments == nil || attachments.count == 0)
        return [NSData data];
    
    NSMutableData *data = [[NSMutableData alloc] init];
    
    int count = 0;
    NSRange countRange = NSMakeRange(data.length, 4);
    [data appendBytes:&count length:4];
    for (TGMediaAttachment *attachment in attachments)
    {
        if (!includeMeta && attachment.isMeta)
            continue;
        
        int type = attachment.type;
        [data appendBytes:&type length:4];
        
        [attachment serialize:data];
        
        count++;
    }
    
    [data replaceBytesInRange:countRange withBytes:&count];
    
    return data;
}

+ (NSData *)serializeAttachment:(TGMediaAttachment *)attachment
{
    if (attachment == nil)
        return [NSData data];
    
    NSMutableData *data = [[NSMutableData alloc] init];
    
    int count = 1;
    [data appendBytes:&count length:4];

    int type = attachment.type;
    [data appendBytes:&type length:4];
    
    [attachment serialize:data];
    
    return data;
}

- (void)setMediaAttachments:(NSArray *)mediaAttachments
{
    for (TGMediaAttachment *attachment in mediaAttachments)
    {
        if (attachment.type == TGActionMediaAttachmentType) {
            _actionInfo = (TGActionMediaAttachment *)attachment;
        }
    }
    
    _mediaAttachments = mediaAttachments;
}

+ (NSArray *)parseMediaAttachments:(NSData *)data
{
    if (data == nil || data.length == 0)
        return [NSArray array];
    
    NSInputStream *is = [[NSInputStream alloc] initWithData:data];
    [is open];
    
    int count = 0;
    [is read:(uint8_t *)&count maxLength:4];
    NSMutableArray *attachments = [[NSMutableArray alloc] initWithCapacity:count];
    
    for (int i = 0; i < count; i++)
    {
        int type = 0;
        [is read:(uint8_t *)&type maxLength:4];
        
        std::unordered_map<int, id<TGMediaAttachmentParser> >::iterator it = mediaAttachmentParsers.find(type);
        if (it == mediaAttachmentParsers.end())
        {
            TGLegacyLog(@"***** Unknown media attachment type %d", type);
            return [NSArray array];
        }
        
        TGMediaAttachment *attachment = [it->second parseMediaAttachment:is];
        if (attachment != nil)
        {
            [attachments addObject:attachment];
        }
    }
    
    [is close];
    
    return [NSArray arrayWithArray:attachments];
}

- (NSData *)serializeContentProperties
{
    if (_contentProperties.count == 0)
        return nil;
    
    PSKeyValueEncoder *encoder = [[PSKeyValueEncoder alloc] init];
    [_contentProperties enumerateKeysAndObjectsUsingBlock:^(NSString *key, id<PSCoding> value, __unused BOOL *stop)
    {
        [encoder encodeObject:value forKey:key];
    }];
    
    return encoder.data;
}

+ (NSData *)serializeContentProperties:(NSDictionary *)contentProperties
{
    if (contentProperties.count == 0)
        return nil;
    
    PSKeyValueEncoder *encoder = [[PSKeyValueEncoder alloc] init];
    [contentProperties enumerateKeysAndObjectsUsingBlock:^(NSString *key, id<PSCoding> value, __unused BOOL *stop)
    {
        [encoder encodeObject:value forKey:key];
    }];
    
    return encoder.data;
}

+ (NSDictionary *)parseContentProperties:(NSData *)data
{
    if (data.length == 0)
        return nil;
    
    PSKeyValueDecoder *decoder = [[PSKeyValueDecoder alloc] initWithData:data];
    return [decoder decodeObjectsByKeys];
}

- (void)removeReplyAndMarkup {
    if (_mediaAttachments.count != 0) {
        for (NSUInteger i = 0; i < _mediaAttachments.count; i++) {
            if ([_mediaAttachments[i] isKindOfClass:[TGReplyMessageMediaAttachment class]]) {
                NSMutableArray *result = [[NSMutableArray alloc] initWithArray:_mediaAttachments];
                [result removeObjectAtIndex:i];
                _mediaAttachments = result;
                break;
            }
        }
        
        for (NSUInteger i = 0; i < _mediaAttachments.count; i++) {
            if ([_mediaAttachments[i] isKindOfClass:[TGReplyMarkupAttachment class]]) {
                NSMutableArray *result = [[NSMutableArray alloc] initWithArray:_mediaAttachments];
                [result removeObjectAtIndex:i];
                _mediaAttachments = result;
                break;
            }
        }
    }
}

- (void)filterOutExpiredMedia {
    if (self.mediaAttachments.count != 0) {
        NSMutableArray *updatedMedia = [[NSMutableArray alloc] initWithArray:self.mediaAttachments];
        for (NSUInteger index = 0; index < updatedMedia.count; index++) {
            if ([updatedMedia[index] isKindOfClass:[TGImageMediaAttachment class]]) {
                TGImageMediaAttachment *imageMedia = updatedMedia[index];
                TGImageMediaAttachment *updatedImageMedia = [[TGImageMediaAttachment alloc] init];
                updatedImageMedia.caption = imageMedia.caption;
                updatedMedia[index] = updatedImageMedia;
            } else if ([updatedMedia[index] isKindOfClass:[TGVideoMediaAttachment class]]) {
                TGVideoMediaAttachment *videoMedia = updatedMedia[index];
                TGVideoMediaAttachment *updatedVideoMedia = [[TGVideoMediaAttachment alloc] init];
                updatedVideoMedia.caption = videoMedia.caption;
                updatedMedia[index] = updatedVideoMedia;
            } else if ([updatedMedia[index] isKindOfClass:[TGDocumentMediaAttachment class]]) {
                TGDocumentMediaAttachment *documentMedia = updatedMedia[index];
                TGDocumentMediaAttachment *updatedDocumentMedia = [[TGDocumentMediaAttachment alloc] init];
                updatedDocumentMedia.caption = documentMedia.caption;
                updatedMedia[index] = updatedDocumentMedia;
            }
        }
        self.mediaAttachments = updatedMedia;
    }
}

- (bool)hasExpiredMedia {
    for (id media in self.mediaAttachments) {
        if ([media isKindOfClass:[TGImageMediaAttachment class]]) {
            TGImageMediaAttachment *imageMedia = media;
            if (imageMedia.imageId == 0 && imageMedia.localImageId == 0) {
                return true;
            }
        } else if ([media isKindOfClass:[TGVideoMediaAttachment class]]) {
            TGVideoMediaAttachment *videoMedia = media;
            if (videoMedia.videoId == 0 && videoMedia.localVideoId == 0) {
                return true;
            }
        } if ([media isKindOfClass:[TGDocumentMediaAttachment class]]) {
            TGDocumentMediaAttachment *documentMedia = media;
            if (documentMedia.documentId == 0 && documentMedia.localDocumentId == 0) {
                return true;
            }
        }
    }
    return false;
}

- (bool)hasUnreadContent {
    if (self.contentProperties[@"contentsRead"] == nil) {
        for (id media in self.mediaAttachments) {
            if ([media isKindOfClass:[TGDocumentMediaAttachment class]]) {
                TGDocumentMediaAttachment *document = media;
                if ([document isVoice] || [document isRoundVideo]) {
                    return true;
                }
            }
        }
    }
    return false;
}

- (int32_t)actualDate
{
    return self.editDate > 0 ? self.editDate : self.date;
}

- (TGLocationMediaAttachment *)locationAttachment
{
    for (TGMediaAttachment *attachment in _mediaAttachments)
    {
        if (attachment.type == TGLocationMediaAttachmentType)
            return (TGLocationMediaAttachment *)attachment;
    }
    return nil;
}

- (NSString *)caption
{
    bool captionable = false;
    NSString *currentCaption = nil;
    
    for (id attachment in self.mediaAttachments) {
        if ([attachment isKindOfClass:[TGImageMediaAttachment class]]) {
            currentCaption = ((TGImageMediaAttachment *)attachment).caption;
            captionable = true;
        } else if ([attachment isKindOfClass:[TGVideoMediaAttachment class]]) {
            currentCaption = ((TGVideoMediaAttachment *)attachment).caption;
            captionable = true;
        } else if ([attachment isKindOfClass:[TGDocumentMediaAttachment class]]) {
            currentCaption = ((TGDocumentMediaAttachment *)attachment).caption;
            captionable = true;
        }
    }
    
    if (!captionable)
        return nil;
    
    if (currentCaption.length > 0)
        return currentCaption;
    else
        return self.text;
}

@end

@interface TGMediaId ()
{
    int _cachedHash;
}

@end

@implementation TGMediaId

- (id)initWithType:(uint8_t)type itemId:(int64_t)itemId
{
    self = [super init];
    if (self != nil)
    {
        _type = type;
        _itemId = itemId;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGMediaId *copyMediaId = [[TGMediaId alloc] initWithType:_type itemId:_itemId];
    return copyMediaId;
}

- (NSUInteger)hash
{
    if (_cachedHash == 0)
        _cachedHash = (int)((((_itemId >> 32) ^ _itemId) & 0xffffffff) + (int)_type);
    return _cachedHash;
}

- (BOOL)isEqual:(id)anObject
{
    if (![anObject isKindOfClass:[TGMediaId class]])
        return false;
    
    TGMediaId *other = (TGMediaId *)anObject;
    return other.itemId == _itemId && other.type == _type;
}

@end


@implementation TGMessageIndex

+ (instancetype)indexWithPeerId:(int64_t)peerId messageId:(int32_t)messageId
{
    TGMessageIndex *pair = [[TGMessageIndex alloc] init];
    pair->_peerId = peerId;
    pair->_messageId = messageId;
    return pair;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return true;
    
    if (!object || ![object isKindOfClass:[self class]])
        return false;
    
    TGMessageIndex *pair = (TGMessageIndex *)object;
    return (_peerId == pair->_peerId && _messageId == pair->_messageId);
}

@end
