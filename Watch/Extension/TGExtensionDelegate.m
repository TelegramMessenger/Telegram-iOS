#import "TGExtensionDelegate.h"
#import "TGWatchCommon.h"
#import "TGFileCache.h"
#import "TGBridgeClient.h"
#import "TGDateUtils.h"
#import "TGNeoChatsController.h"

@interface TGExtensionDelegate ()
{
    NSString *_cachedContentSize;
    TGContentSizeCategory _sizeCategory;
}
@end

@implementation TGExtensionDelegate

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        TGLog(@"Extension initialization start");
        [TGBridgeClient instance];
        
        _audioCache = [[TGFileCache alloc] initWithName:@"audio" useMemoryCache:false];
        _audioCache.defaultFileExtension = @"m4a";
        
        _imageCache = [[TGFileCache alloc] initWithName:@"images" useMemoryCache:true];
    }
    return self;
}

- (TGNeoChatsController *)chatsController
{
    return (TGNeoChatsController *)[WKExtension sharedExtension].rootInterfaceController;
}

- (void)applicationDidBecomeActive
{
    [[TGBridgeClient instance] handleDidBecomeActive];
}

- (void)applicationWillResignActive
{
    [[TGBridgeClient instance] handleWillResignActive];
}

- (void)didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    
}

- (void)didReceiveLocalNotification:(UILocalNotification *)notification
{
    
}

- (void)setCustomLocalizationFile:(NSURL *)fileUrl
{
    if (fileUrl == nil)
        TGResetLocalization();
    else
        TGSetLocalizationFromFile(fileUrl);
    
    [TGDateUtils reset];
    [[self chatsController] resetLocalization];
}

- (TGContentSizeCategory)contentSizeCategory
{    
    NSString *contentSize = [WKInterfaceDevice currentDevice].preferredContentSizeCategory;
    if (![_cachedContentSize isEqualToString:contentSize])
    {
        _cachedContentSize = contentSize;
        _sizeCategory = [TGExtensionDelegate contentSizeCategoryForString:contentSize];
    }
    
    return _sizeCategory;
}

+ (TGContentSizeCategory)contentSizeCategoryForString:(NSString *)string
{
    if ([string isEqualToString:@"UICTContentSizeCategoryXS"])
        return TGContentSizeCategoryXS;
    else if ([string isEqualToString:@"UICTContentSizeCategoryS"])
        return TGContentSizeCategoryS;
    else if ([string isEqualToString:@"UICTContentSizeCategoryM"])
        return TGContentSizeCategoryM;
    else if ([string isEqualToString:@"UICTContentSizeCategoryL"])
        return TGContentSizeCategoryL;
    else if ([string isEqualToString:@"UICTContentSizeCategoryXL"])
        return TGContentSizeCategoryXL;
    else if ([string isEqualToString:@"UICTContentSizeCategoryXXL"])
        return TGContentSizeCategoryXXL;
    else if ([string isEqualToString:@"UICTContentSizeCategoryXXXL"])
        return TGContentSizeCategoryXXXL;
    
    return TGContentSizeCategoryL;
}

+ (NSString *)documentsPath
{
    static dispatch_once_t onceToken;
    static NSString *path;
    dispatch_once(&onceToken, ^
    {
        path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0];
    });
    return path;
}

+ (instancetype)instance
{
    return (TGExtensionDelegate *)[[WKExtension sharedExtension] delegate];
}

@end
