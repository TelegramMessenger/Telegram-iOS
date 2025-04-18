#import "TGBridgeWebPageMediaAttachment.h"
#import "TGBridgeImageMediaAttachment.h"
#import <UIKit/UIKit.h>

const NSInteger TGBridgeWebPageMediaAttachmentType = 0x584197af;

NSString *const TGBridgeWebPageMediaWebPageIdKey = @"webPageId";
NSString *const TGBridgeWebPageMediaUrlKey = @"url";
NSString *const TGBridgeWebPageMediaDisplayUrlKey = @"displayUrl";
NSString *const TGBridgeWebPageMediaPageTypeKey = @"pageType";
NSString *const TGBridgeWebPageMediaSiteNameKey = @"siteName";
NSString *const TGBridgeWebPageMediaTitleKey = @"title";
NSString *const TGBridgeWebPageMediaPageDescriptionKey = @"pageDescription";
NSString *const TGBridgeWebPageMediaPhotoKey = @"photo";
NSString *const TGBridgeWebPageMediaEmbedUrlKey = @"embedUrl";
NSString *const TGBridgeWebPageMediaEmbedTypeKey = @"embedType";
NSString *const TGBridgeWebPageMediaEmbedSizeKey = @"embedSize";
NSString *const TGBridgeWebPageMediaDurationKey = @"duration";
NSString *const TGBridgeWebPageMediaAuthorKey = @"author";

@implementation TGBridgeWebPageMediaAttachment

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _webPageId = [aDecoder decodeInt64ForKey:TGBridgeWebPageMediaWebPageIdKey];
        _url = [aDecoder decodeObjectForKey:TGBridgeWebPageMediaUrlKey];
        _displayUrl = [aDecoder decodeObjectForKey:TGBridgeWebPageMediaDisplayUrlKey];
        _pageType = [aDecoder decodeObjectForKey:TGBridgeWebPageMediaPageTypeKey];
        _siteName = [aDecoder decodeObjectForKey:TGBridgeWebPageMediaSiteNameKey];
        _title = [aDecoder decodeObjectForKey:TGBridgeWebPageMediaTitleKey];
        _pageDescription = [aDecoder decodeObjectForKey:TGBridgeWebPageMediaPageDescriptionKey];
        _photo = [aDecoder decodeObjectForKey:TGBridgeWebPageMediaPhotoKey];
        _embedUrl = [aDecoder decodeObjectForKey:TGBridgeWebPageMediaEmbedUrlKey];
        _embedSize = [aDecoder decodeCGSizeForKey:TGBridgeWebPageMediaEmbedSizeKey];
        _duration = [aDecoder decodeObjectForKey:TGBridgeWebPageMediaDurationKey];
        _author = [aDecoder decodeObjectForKey:TGBridgeWebPageMediaAuthorKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.webPageId forKey:TGBridgeWebPageMediaWebPageIdKey];
    [aCoder encodeObject:self.url forKey:TGBridgeWebPageMediaUrlKey];
    [aCoder encodeObject:self.displayUrl forKey:TGBridgeWebPageMediaDisplayUrlKey];
    [aCoder encodeObject:self.pageType forKey:TGBridgeWebPageMediaPageTypeKey];
    [aCoder encodeObject:self.siteName forKey:TGBridgeWebPageMediaSiteNameKey];
    [aCoder encodeObject:self.title forKey:TGBridgeWebPageMediaTitleKey];
    [aCoder encodeObject:self.pageDescription forKey:TGBridgeWebPageMediaPageDescriptionKey];
    [aCoder encodeObject:self.photo forKey:TGBridgeWebPageMediaPhotoKey];
    [aCoder encodeObject:self.embedUrl forKey:TGBridgeWebPageMediaEmbedUrlKey];
    [aCoder encodeCGSize:self.embedSize forKey:TGBridgeWebPageMediaEmbedSizeKey];
    [aCoder encodeObject:self.duration forKey:TGBridgeWebPageMediaDurationKey];
    [aCoder encodeObject:self.author forKey:TGBridgeWebPageMediaAuthorKey];
}

+ (NSInteger)mediaType
{
    return TGBridgeWebPageMediaAttachmentType;
}

@end
