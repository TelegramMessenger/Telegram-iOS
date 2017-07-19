#import "TGGameMediaAttachment.h"

#import "LegacyComponentsInternal.h"

#import "NSInputStream+TL.h"

#import "TGWebPageMediaAttachment.h"

@implementation TGGameMediaAttachment

- (instancetype)initWithGameId:(int64_t)gameId accessHash:(int64_t)accessHash shortName:(NSString *)shortName title:(NSString *)title gameDescription:(NSString *)gameDescription photo:(TGImageMediaAttachment *)photo document:(TGDocumentMediaAttachment *)document {
    self = [super init];
    if (self != nil) {
        self.type = TGGameAttachmentType;
        
        _gameId = gameId;
        _accessHash = accessHash;
        _shortName = shortName;
        _title = title;
        _gameDescription = gameDescription;
        _photo = photo;
        _document = document;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithGameId:[aDecoder decodeInt64ForKey:@"gameId"] accessHash:[aDecoder decodeInt64ForKey:@"accessHash"] shortName:[aDecoder decodeObjectForKey:@"shortName"] title:[aDecoder decodeObjectForKey:@"title"] gameDescription:[aDecoder decodeObjectForKey:@"gameDescription"] photo:[aDecoder decodeObjectForKey:@"photo"] document:[aDecoder decodeObjectForKey:@"document"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt64:_gameId forKey:@"gameId"];
    [aCoder encodeInt64:_accessHash forKey:@"accessHash"];
    [aCoder encodeObject:_shortName forKey:@"shortName"];
    [aCoder encodeObject:_title forKey:@"title"];
    [aCoder encodeObject:_gameDescription forKey:@"gameDescription"];
    [aCoder encodeObject:_photo forKey:@"photo"];
    [aCoder encodeObject:_document forKey:@"document"];
}

- (void)serialize:(NSMutableData *)data
{
    NSData *serializedData = [NSKeyedArchiver archivedDataWithRootObject:self];
    int32_t length = (int32_t)serializedData.length;
    [data appendBytes:&length length:4];
    [data appendData:serializedData];
}

- (TGMediaAttachment *)parseMediaAttachment:(NSInputStream *)is
{
    int32_t length = [is readInt32];
    NSData *data = [is readData:length];
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

- (TGWebPageMediaAttachment *)webPageWithText:(NSString *)text entities:(NSArray *)entities {
    TGWebPageMediaAttachment *webPage = [[TGWebPageMediaAttachment alloc] init];
    webPage.siteName = self.title;
    webPage.pageDescription = (text.length == 0 || [text isEqualToString:@" "]) ? self.gameDescription : text;
    
    webPage.photo = self.photo;
    webPage.document = self.document;
    webPage.pageType = @"game";
    webPage.pageDescriptionEntities = (text.length == 0 || [text isEqualToString:@" "]) ? nil : entities;
    return webPage;
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:[TGGameMediaAttachment class]] && ((TGGameMediaAttachment *)object)->_gameId == _gameId && ((TGGameMediaAttachment *)object)->_accessHash == _accessHash && TGStringCompare(((TGGameMediaAttachment *)object)->_title, _title) && TGStringCompare(((TGGameMediaAttachment *)object)->_gameDescription, _gameDescription) && TGStringCompare(((TGGameMediaAttachment *)object)->_shortName, _shortName);
}

@end
