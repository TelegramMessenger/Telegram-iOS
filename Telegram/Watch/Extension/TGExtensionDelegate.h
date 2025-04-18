#import <WatchKit/WatchKit.h>

@class TGNeoChatsController;
@class TGFileCache;

typedef enum
{
    TGContentSizeCategoryXS,
    TGContentSizeCategoryS,
    TGContentSizeCategoryM,
    TGContentSizeCategoryL,
    TGContentSizeCategoryXL,
    TGContentSizeCategoryXXL,
    TGContentSizeCategoryXXXL
} TGContentSizeCategory;

@interface TGExtensionDelegate : NSObject <WKExtensionDelegate>

@property (nonatomic, readonly) TGFileCache *audioCache;
@property (nonatomic, readonly) TGFileCache *imageCache;

@property (nonatomic, readonly) TGNeoChatsController *chatsController;

@property (nonatomic, readonly) TGContentSizeCategory contentSizeCategory;

- (void)setCustomLocalizationFile:(NSURL *)fileUrl;

+ (NSString *)documentsPath;

+ (instancetype)instance;

@end
