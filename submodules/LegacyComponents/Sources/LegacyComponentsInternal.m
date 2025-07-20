#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGLocalization.h>

#import <UIKit/UIKit.h>

#import <sys/sysctl.h>

#import <AppBundle/AppBundle.h>

TGLocalization *legacyEffectiveLocalization() {
    return [[LegacyComponentsGlobals provider] effectiveLocalization];
}

NSString *TGLocalized(NSString *s) {
    return [legacyEffectiveLocalization() get:s];
}

bool TGObjectCompare(id obj1, id obj2) {
    if (obj1 == nil && obj2 == nil)
        return true;
    
    return [obj1 isEqual:obj2];
}

bool TGStringCompare(NSString *s1, NSString *s2) {
    if (s1.length == 0 && s2.length == 0)
        return true;
    
    if ((s1 == nil) != (s2 == nil))
        return false;
    
    return s1 == nil || [s1 isEqualToString:s2];
}

void TGLegacyLog(NSString *format, ...)
{
    va_list L;
    va_start(L, format);
    NSString *string = [[NSString alloc] initWithFormat:format arguments:L];
    va_end(L);
    [[LegacyComponentsGlobals provider] log:string];
}

int iosMajorVersion()
{
    static bool initialized = false;
    static int version = 7;
    if (!initialized) {
        version = [[[UIDevice currentDevice] systemVersion] intValue];
        initialized = true;
    }
    return version;
}

int iosMinorVersion()
{
    static bool initialized = false;
    static int version = 0;
    if (!initialized)
    {
        NSString *versionString = [[UIDevice currentDevice] systemVersion];
        NSRange range = [versionString rangeOfString:@"."];
        if (range.location != NSNotFound) {
            version = [[versionString substringFromIndex:range.location + 1] intValue];
        }
        
        initialized = true;
    }
    return version;
}

int deviceMemorySize()
{
    static int memorySize = 0;
    if (memorySize == 0)
    {
        size_t len;
        __int64_t nmem;
        
        len = sizeof(nmem);
        sysctlbyname("hw.memsize", &nmem, &len, NULL, 0);
        memorySize = (int)(nmem / (1024 * 1024));
    }
    return memorySize;
}

int cpuCoreCount()
{
    static int count = 0;
    if (count == 0)
    {
        size_t len;
        unsigned int ncpu;
        
        len = sizeof(ncpu);
        sysctlbyname("hw.ncpu", &ncpu, &len, NULL, 0);
        count = ncpu;
    }
    
    return count;
}


void TGDispatchOnMainThread(dispatch_block_t block)
{
    if ([NSThread isMainThread])
        block();
    else
        dispatch_async(dispatch_get_main_queue(), block);
}

void TGDispatchAfter(double delay, dispatch_queue_t queue, dispatch_block_t block)
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((delay) * NSEC_PER_SEC)), queue, block);
}

static NSBundle *resourcesBundle() {
    static NSBundle *currentBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        currentBundle = getAppBundle();
        NSString *updatedPath = [[currentBundle bundlePath] stringByAppendingPathComponent:@"LegacyComponentsResources.bundle"];
        currentBundle = [NSBundle bundleWithPath:updatedPath];
    });
    return currentBundle;
}

UIImage *TGComponentsImageNamed(NSString *name) {
    if (iosMajorVersion() < 8)
        return [UIImage imageNamed:[NSString stringWithFormat:@"LegacyComponentsResources.bundle/%@", name]];
    
    UIImage *image = [UIImage imageNamed:name inBundle:resourcesBundle() compatibleWithTraitCollection:nil];
    if (image == nil) {
        assert(true);
    }
    return image;
}

NSString *TGComponentsPathForResource(NSString *name, NSString *type) {
    NSBundle *bundle = resourcesBundle();
    if (bundle == nil) {
        bundle = getAppBundle();
    }
    return [bundle pathForResource:name ofType:type];
}

@implementation UIColor (Int32)

- (int32_t)int32Value {
    CGFloat red, green, blue, alpha;
    if (![self getRed:&red green:&green blue:&blue alpha:&alpha]) {
        if ([self getWhite:&red alpha:&alpha]) {
            green = red;
            blue = red;
        } else {
            red = green = blue = alpha = 1.0;
        }
    }

    int8_t r = (int8_t)(red * 255);
    int8_t g = (int8_t)(green * 255);
    int8_t b = (int8_t)(blue * 255);
    int8_t a = (int8_t)(alpha * 255);

    int32_t intValue = (a << 24) | (r << 16) | (g << 8) | b;
    return intValue;
}

@end
