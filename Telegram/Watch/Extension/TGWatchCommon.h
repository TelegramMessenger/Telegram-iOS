#import <Foundation/Foundation.h>
#import "WKInterface+TGInterface.h"
#import "TGWatchColor.h"

#define TGTick   NSDate *startTime = [NSDate date]
#define TGTock   NSLog(@"%s Time: %f", __func__, -[startTime timeIntervalSinceNow])

#define TGLog(s) NSLog(s)

#ifdef __cplusplus
extern "C" {
#endif
    
extern int TGLocalizedStaticVersion;
    
void TGSetLocalizationFromFile(NSURL *fileUrl);
bool TGIsCustomLocalizationActive();
void TGResetLocalization();
NSString *TGLocalized(NSString *s);
    
static inline void TGDispatchOnMainThread(dispatch_block_t block)
{
    if ([NSThread isMainThread])
        block();
    else
        dispatch_async(dispatch_get_main_queue(), block);
}
    
static inline void TGDispatchAfter(double delay, dispatch_queue_t queue, dispatch_block_t block)
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((delay) * NSEC_PER_SEC)), queue, block);
}

void TGSwizzleMethodImplementation(Class clazz, SEL originalMethod, SEL modifiedMethod);

CGSize TGWatchScreenSize();

typedef NS_ENUM(NSUInteger, TGScreenType)
{
    TGScreenType38mm,
    TGScreenType40mm,
    TGScreenType42mm,
    TGScreenType44mm,
};
    
TGScreenType TGWatchScreenType();
CGSize TGWatchStickerSizeForScreen(TGScreenType screenType);
    
#ifdef __cplusplus
}
#endif

@interface NSNumber (IntegerTypes)

- (int32_t)int32Value;
- (int64_t)int64Value;

@end
