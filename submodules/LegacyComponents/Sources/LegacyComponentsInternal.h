#import "LegacyComponentsGlobals.h"

@class TGLocalization;

#ifdef __cplusplus
extern "C" {
#endif
    
TGLocalization *legacyEffectiveLocalization();
NSString *TGLocalized(NSString *s);
bool TGObjectCompare(id obj1, id obj2);
bool TGStringCompare(NSString *s1, NSString *s2);
void TGLegacyLog(NSString *format, ...);
int iosMajorVersion();
int iosMinorVersion();
    
void TGDispatchOnMainThread(dispatch_block_t block);
void TGDispatchAfter(double delay, dispatch_queue_t queue, dispatch_block_t block);
    
int deviceMemorySize();
int cpuCoreCount();
    
#define UIColorRGB(rgb) ([[UIColor alloc] initWithRed:(((rgb >> 16) & 0xff) / 255.0f) green:(((rgb >> 8) & 0xff) / 255.0f) blue:(((rgb) & 0xff) / 255.0f) alpha:1.0f])
#define UIColorRGBA(rgb,a) ([[UIColor alloc] initWithRed:(((rgb >> 16) & 0xff) / 255.0f) green:(((rgb >> 8) & 0xff) / 255.0f) blue:(((rgb) & 0xff) / 255.0f) alpha:a])
    
#define TGRestrictedToMainThread {if(![[NSThread currentThread] isMainThread]) TGLegacyLog(@"***** Warning: main thread-bound operation is running in background! *****");}
    
#define TG_TIMESTAMP_DEFINE(s) CFAbsoluteTime tg_timestamp_##s = CFAbsoluteTimeGetCurrent(); int tg_timestamp_line_##s = __LINE__;
#define TG_TIMESTAMP_MEASURE(s) { CFAbsoluteTime tg_timestamp_current_time = CFAbsoluteTimeGetCurrent(); TGLegacyLog(@"%s %d-%d: %f ms", #s, tg_timestamp_line_##s, __LINE__, (tg_timestamp_current_time - tg_timestamp_##s) * 1000.0); tg_timestamp_##s = tg_timestamp_current_time; tg_timestamp_line_##s = __LINE__; }
    
#ifdef __LP64__
#   define CGFloor floor
#else
#   define CGFloor floorf
#endif
    
#ifdef __LP64__
#   define CGRound round
#   define CGCeil ceil
#   define CGPow pow
#   define CGSin sin
#   define CGCos cos
#   define CGSqrt sqrt
#else
#   define CGRound roundf
#   define CGCeil ceilf
#   define CGPow powf
#   define CGSin sinf
#   define CGCos cosf
#   define CGSqrt sqrtf
#endif
    
#define CGEven(x) ((((int)x) & 1) ? (x + 1) : x)
#define CGOdd(x) ((((int)x) & 1) ? x : (x + 1))
    
#ifdef __cplusplus
}
#endif
