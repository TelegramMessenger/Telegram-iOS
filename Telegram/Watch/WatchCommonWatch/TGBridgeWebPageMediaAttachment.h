#import <WatchCommonWatch/TGBridgeMediaAttachment.h>

#import <CoreGraphics/CoreGraphics.h>

@class TGBridgeImageMediaAttachment;

@interface TGBridgeWebPageMediaAttachment : TGBridgeMediaAttachment

@property (nonatomic, assign) int64_t webPageId;
@property (nonatomic, strong) NSString *url;
@property (nonatomic, strong) NSString *displayUrl;
@property (nonatomic, strong) NSString *pageType;
@property (nonatomic, strong) NSString *siteName;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *pageDescription;
@property (nonatomic, strong) TGBridgeImageMediaAttachment *photo;
@property (nonatomic, strong) NSString *embedUrl;
@property (nonatomic, strong) NSString *embedType;
@property (nonatomic, assign) CGSize embedSize;
@property (nonatomic, strong) NSNumber *duration;
@property (nonatomic, strong) NSString *author;

@end
