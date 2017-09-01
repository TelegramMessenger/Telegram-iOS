#import "LegacyComponentsInternal.h"

#import "TGLocalization.h"

#import <UIKit/UIKit.h>

#import <sys/sysctl.h>

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
    if (!initialized)
    {
        switch ([[[UIDevice currentDevice] systemVersion] intValue])
        {
            case 4:
                version = 4;
                break;
            case 5:
                version = 5;
                break;
            case 6:
                version = 6;
                break;
            case 7:
                version = 7;
                break;
            case 8:
                version = 8;
                break;
            case 9:
                version = 9;
                break;
            case 10:
                version = 10;
                break;
            case 11:
                version = 11;
                break;
            default:
                version = 9;
                break;
        }
        
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
        if (range.location != NSNotFound)
            version = [[versionString substringFromIndex:range.location + 1] intValue];
        
        initialized = true;
    }
    return version;
}

NSString *TGEncodeText(NSString *string, int key)
{
    NSMutableString *result = [[NSMutableString alloc] init];
    
    for (int i = 0; i < (int)[string length]; i++)
    {
        unichar c = [string characterAtIndex:i];
        c += key;
        [result appendString:[NSString stringWithCharacters:&c length:1]];
    }
    
    return result;
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

static NSBundle *frameworkBundle() {
    static NSBundle *currentBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        currentBundle = [NSBundle bundleForClass:[LegacyComponentsGlobals class]];
        NSString *updatedPath = [[currentBundle bundlePath] stringByAppendingPathComponent:@"LegacyComponentsResources.bundle"];
        currentBundle = [NSBundle bundleWithPath:updatedPath];
    });
    return currentBundle;
}

UIImage *TGComponentsImageNamed(NSString *name) {
    if (iosMajorVersion() < 8)
        return [UIImage imageNamed:[NSString stringWithFormat:@"LegacyComponentsResources.bundle/%@", name]];
    
    UIImage *image = [UIImage imageNamed:name inBundle:frameworkBundle() compatibleWithTraitCollection:nil];
    if (image == nil) {
        assert(true);
    }
    return image;
}

NSString *TGComponentsPathForResource(NSString *name, NSString *type) {
    return [frameworkBundle() pathForResource:name ofType:type];
}
