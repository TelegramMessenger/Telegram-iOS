#import "TGFont.h"

#import "LegacyComponentsInternal.h"
#import "NSObject+TGLock.h"

#import <map>

UIFont *TGSystemFontOfSize(CGFloat size)
{
    static bool useSystem = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        useSystem = iosMajorVersion() >= 7;
    });
    
    if (useSystem)
        return [UIFont systemFontOfSize:size];
    else
        return [UIFont fontWithName:@"HelveticaNeue" size:size];
}

UIFont *TGMediumSystemFontOfSize(CGFloat size)
{
    static bool useSystem = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        useSystem = iosMajorVersion() >= 9;
    });
    
    if (useSystem) {
        return [UIFont systemFontOfSize:size weight:UIFontWeightMedium];
    } else {
        return [UIFont fontWithName:@"HelveticaNeue-Medium" size:size];
    }
}

UIFont *TGSemiboldSystemFontOfSize(CGFloat size)
{
    static bool useSystem = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        useSystem = iosMajorVersion() >= 9;
    });
    
    if (useSystem) {
        return [UIFont systemFontOfSize:size weight:UIFontWeightSemibold];
    } else {
        return [UIFont fontWithName:@"HelveticaNeue-Medium" size:size];
    }
}

UIFont *TGBoldSystemFontOfSize(CGFloat size)
{
    static bool useSystem = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        useSystem = iosMajorVersion() >= 7;
    });
    
    if (useSystem)
        return [UIFont boldSystemFontOfSize:size];
    else
        return [UIFont fontWithName:@"HelveticaNeue-Medium" size:size];
}

UIFont *TGLightSystemFontOfSize(CGFloat size)
{
    static bool useSystem = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        useSystem = iosMajorVersion() >= 9;
    });
    
    if (useSystem) {
        return [UIFont systemFontOfSize:size weight:UIFontWeightLight];
    } else {
        return [UIFont fontWithName:@"HelveticaNeue-Light" size:size];
    }
}

UIFont *TGUltralightSystemFontOfSize(CGFloat size)
{
    if (iosMajorVersion() >= 7)
        return [UIFont fontWithName:@"HelveticaNeue-Thin" size:size];
    else
        return [UIFont fontWithName:@"HelveticaNeue-Light" size:size];
}

UIFont *TGItalicSystemFontOfSize(CGFloat size)
{
    return [UIFont italicSystemFontOfSize:size];
}


UIFont *TGFixedSystemFontOfSize(CGFloat size)
{
    return [UIFont fontWithName:@"Courier" size:size];
}

@implementation TGFont

+ (UIFont *)systemFontOfSize:(CGFloat)size
{
    return TGSystemFontOfSize(size);
}

+ (UIFont *)boldSystemFontOfSize:(CGFloat)size
{
    return TGBoldSystemFontOfSize(size);
}

+ (UIFont *)roundedFontOfSize:(CGFloat)size
{
    if (@available(iOSApplicationExtension 13.0, iOS 13.0, *)) {
        UIFontDescriptor *descriptor = [UIFont boldSystemFontOfSize:size].fontDescriptor;
        descriptor = [descriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
        return [UIFont fontWithDescriptor:descriptor size:size];
    } else {
        return [UIFont fontWithName:@".SFCompactRounded-Semibold" size:size];
    }
}

@end

static std::map<int, CTFontRef> systemFontCache;
static std::map<int, CTFontRef> lightFontCache;
static std::map<int, CTFontRef> mediumFontCache;
static std::map<int, CTFontRef> boldFontCache;
static std::map<int, CTFontRef> fixedFontCache;
static std::map<int, CTFontRef> italicFontCache;
static TG_SYNCHRONIZED_DEFINE(systemFontCache) = PTHREAD_MUTEX_INITIALIZER;

CTFontRef TGCoreTextSystemFontOfSize(CGFloat size)
{
    int key = (int)(size * 2.0f);
    CTFontRef result = NULL;
    
    TG_SYNCHRONIZED_BEGIN(systemFontCache);
    auto it = systemFontCache.find(key);
    if (it != systemFontCache.end())
        result = it->second;
    else
    {
        if (iosMajorVersion() >= 7) {
            result = CTFontCreateWithFontDescriptor((__bridge CTFontDescriptorRef)[TGSystemFontOfSize(size) fontDescriptor], 0.0f, NULL);
        } else {
            UIFont *systemFont = TGSystemFontOfSize(size);
            result = CTFontCreateWithName((__bridge CFStringRef)systemFont.fontName, systemFont.pointSize, nil);
        }
        systemFontCache[key] = result;
    }
    TG_SYNCHRONIZED_END(systemFontCache);
    
    return result;
}

CTFontRef TGCoreTextLightFontOfSize(CGFloat size)
{
    int key = (int)(size * 2.0f);
    CTFontRef result = NULL;
    
    TG_SYNCHRONIZED_BEGIN(systemFontCache);
    auto it = lightFontCache.find(key);
    if (it != lightFontCache.end())
        result = it->second;
    else
    {
        if (iosMajorVersion() >= 7) {
            result = CTFontCreateWithFontDescriptor((__bridge CTFontDescriptorRef)[TGLightSystemFontOfSize(size) fontDescriptor], 0.0f, NULL);
        } else {
            UIFont *systemFont = TGLightSystemFontOfSize(size);
            result = CTFontCreateWithName((__bridge CFStringRef)systemFont.fontName, systemFont.pointSize, nil);
        }
        lightFontCache[key] = result;
    }
    TG_SYNCHRONIZED_END(systemFontCache);
    
    return result;
}

CTFontRef TGCoreTextMediumFontOfSize(CGFloat size)
{
    int key = (int)(size * 2.0f);
    CTFontRef result = NULL;
    
    TG_SYNCHRONIZED_BEGIN(systemFontCache);
    auto it = mediumFontCache.find(key);
    if (it != mediumFontCache.end())
        result = it->second;
    else
    {
        if (iosMajorVersion() >= 7) {
            result = CTFontCreateWithFontDescriptor((__bridge CTFontDescriptorRef)[TGMediumSystemFontOfSize(size) fontDescriptor], 0.0f, NULL);
        } else {
            UIFont *systemFont = TGMediumSystemFontOfSize(size);
            result = CTFontCreateWithName((__bridge CFStringRef)systemFont.fontName, systemFont.pointSize, nil);
        }
        mediumFontCache[key] = result;
    }
    TG_SYNCHRONIZED_END(systemFontCache);
    
    return result;
}

CTFontRef TGCoreTextBoldFontOfSize(CGFloat size)
{
    int key = (int)(size * 2.0f);
    CTFontRef result = NULL;
    
    TG_SYNCHRONIZED_BEGIN(systemFontCache);
    auto it = boldFontCache.find(key);
    if (it != boldFontCache.end())
        result = it->second;
    else
    {
        if (iosMajorVersion() >= 7) {
            result = CTFontCreateWithFontDescriptor((__bridge CTFontDescriptorRef)[TGBoldSystemFontOfSize(size) fontDescriptor], 0.0f, NULL);
        } else {
            UIFont *systemFont = TGBoldSystemFontOfSize(size);
            result = CTFontCreateWithName((__bridge CFStringRef)systemFont.fontName, systemFont.pointSize, nil);
        }
        boldFontCache[key] = result;
    }
    TG_SYNCHRONIZED_END(systemFontCache);
    
    return result;
}

CTFontRef TGCoreTextFixedFontOfSize(CGFloat size)
{
    int key = (int)(size * 2.0f);
    CTFontRef result = NULL;
    
    TG_SYNCHRONIZED_BEGIN(systemFontCache);
    auto it = fixedFontCache.find(key);
    if (it != fixedFontCache.end())
        result = it->second;
    else
    {
        result = CTFontCreateWithName(CFSTR("Courier"), CGFloor(size * 2.0f) / 2.0f, NULL);
        fixedFontCache[key] = result;
    }
    TG_SYNCHRONIZED_END(systemFontCache);
    
    return result;
}

CTFontRef TGCoreTextItalicFontOfSize(CGFloat size)
{
    int key = (int)(size * 2.0f);
    CTFontRef result = NULL;
    
    TG_SYNCHRONIZED_BEGIN(systemFontCache);
    auto it = italicFontCache.find(key);
    if (it != italicFontCache.end())
        result = it->second;
    else
    {
        if (iosMajorVersion() >= 7) {
            result = CTFontCreateWithFontDescriptor((__bridge CTFontDescriptorRef)[TGItalicSystemFontOfSize(size) fontDescriptor], 0.0f, NULL);
        } else {
            UIFont *systemFont = TGItalicSystemFontOfSize(size);
            result = CTFontCreateWithName((__bridge CFStringRef)systemFont.fontName, systemFont.pointSize, nil);
        }
        italicFontCache[key] = result;
    }
    TG_SYNCHRONIZED_END(systemFontCache);
    
    return result;
}
