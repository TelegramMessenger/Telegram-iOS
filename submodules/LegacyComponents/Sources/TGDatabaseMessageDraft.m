#import "TGDatabaseMessageDraft.h"

#import "LegacyComponentsInternal.h"

#import "PSKeyValueEncoder.h"
#import "PSKeyValueDecoder.h"

@implementation TGDatabaseMessageDraft

- (instancetype)initWithText:(NSString *)text entities:(NSArray<TGMessageEntity *> *)entities disableLinkPreview:(bool)disableLinkPreview replyToMessageId:(int32_t)replyToMessageId date:(int32_t)date {
    self = [super init];
    if (self != nil) {
        _text = text;
        _entities = entities;
        _disableLinkPreview = disableLinkPreview;
        _replyToMessageId = replyToMessageId;
        _date = date;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    return [self initWithText:[coder decodeStringForCKey:"text"] entities:[coder decodeArrayForCKey:"entities"] disableLinkPreview:[coder decodeInt32ForCKey:"disableLinkPreview"] replyToMessageId:[coder decodeInt32ForCKey:"replyToMessageId"] date:[coder decodeInt32ForCKey:"date"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeString:_text forCKey:"text"];
    [coder encodeArray:_entities forCKey:"entities"];
    [coder encodeInt32:_disableLinkPreview ? 1 : 0 forCKey:"disableLinkPreview"];
    [coder encodeInt32:_replyToMessageId forCKey:"replyToMessageId"];
    [coder encodeInt32:_date forCKey:"date"];
}

- (bool)isEqual:(id)object {
    return [object isKindOfClass:[TGDatabaseMessageDraft class]] && TGStringCompare(((TGDatabaseMessageDraft *)object)->_text, _text) && TGObjectCompare(((TGDatabaseMessageDraft *)object)->_entities, _entities) && ((TGDatabaseMessageDraft *)object)->_disableLinkPreview == _disableLinkPreview && ((TGDatabaseMessageDraft *)object)->_replyToMessageId == _replyToMessageId && ((TGDatabaseMessageDraft *)object)->_date == _date;
}

- (bool)isEmpty {
    return _text.length == 0 && _replyToMessageId == 0;
}

- (TGDatabaseMessageDraft *)updateDate:(int32_t)date {
    return [[TGDatabaseMessageDraft alloc] initWithText:_text entities:_entities disableLinkPreview:_disableLinkPreview replyToMessageId:_replyToMessageId date:date];
}

@end
