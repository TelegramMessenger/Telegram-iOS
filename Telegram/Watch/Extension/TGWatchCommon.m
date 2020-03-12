#import "TGWatchCommon.h"
#import "TGExtensionDelegate.h"

#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>

void TGSwizzleMethodImplementation(Class class, SEL originalSelector, SEL modifiedSelector)
{
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method modifiedMethod = class_getInstanceMethod(class, modifiedSelector);
    
    if (class_addMethod(class, originalSelector, method_getImplementation(modifiedMethod), method_getTypeEncoding(modifiedMethod)))
    {
        class_replaceMethod(class, modifiedSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    }
    else
    {
        method_exchangeImplementations(originalMethod, modifiedMethod);
    }
}

CGSize TGWatchScreenSize()
{
    static CGSize size;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        size = [[WKInterfaceDevice currentDevice] screenBounds].size;
    });
    
    return size;
}

TGScreenType TGWatchScreenType()
{
    static TGScreenType type;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        int width = (int)TGWatchScreenSize().width;
        switch (width) {
            case 136:
                type = TGScreenType38mm;
                break;
            case 156:
                type = TGScreenType42mm;
                break;
            case 162:
                type = TGScreenType40mm;
                break;
            case 184:
                type = TGScreenType44mm;
                break;
            default:
                type = TGScreenType42mm;
                break;
        }
    });
    
    return type;
}

CGSize TGWatchStickerSizeForScreen(TGScreenType screenType)
{
    switch (screenType) {
        case TGScreenType38mm:
            return CGSizeMake(72, 72);
        case TGScreenType42mm:
            return CGSizeMake(84, 84);
        case TGScreenType40mm:
            return CGSizeMake(88, 88);
        case TGScreenType44mm:
            return CGSizeMake(100, 100);
        default:
            return CGSizeMake(84, 84);
    }
}

@implementation NSNumber (IntegerTypes)

- (int32_t)int32Value
{
    return (int32_t)[self intValue];
}

- (int64_t)int64Value
{
    return (int64_t)[self longLongValue];
}

@end


int TGLocalizedStaticVersion = 0;

static NSBundle *customLocalizationBundle = nil;

static NSString *customLocalizationBundlePath()
{
    return [[TGExtensionDelegate documentsPath] stringByAppendingPathComponent:@"CustomLocalization.bundle"];
}

void TGSetLocalizationFromFile(NSURL *fileUrl)
{
    TGResetLocalization();
    
    [[NSFileManager defaultManager] createDirectoryAtPath:customLocalizationBundlePath() withIntermediateDirectories:true attributes:nil error:nil];
    
    NSString *stringsFilePath = [customLocalizationBundlePath() stringByAppendingPathComponent:@"Localizable.strings"];
    [[NSFileManager defaultManager] removeItemAtPath:stringsFilePath error:nil];
    
    if ([[NSFileManager defaultManager] copyItemAtURL:fileUrl toURL:[NSURL fileURLWithPath:stringsFilePath] error:nil])
    {
        NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"localiation-%d", (int)arc4random()]];
        [[NSFileManager defaultManager] copyItemAtPath:customLocalizationBundlePath() toPath:tempPath error:nil];
        customLocalizationBundle = [NSBundle bundleWithPath:tempPath];
    }
}

bool TGIsCustomLocalizationActive()
{
    return customLocalizationBundle != nil;
}

void TGResetLocalization()
{
    customLocalizationBundle = nil;
    [[NSFileManager defaultManager] removeItemAtPath:customLocalizationBundlePath() error:nil];
    
    TGLocalizedStaticVersion++;
}

NSString *TGLocalized(NSString *s)
{
    static NSString *untranslatedString = nil;
    
    static dispatch_once_t onceToken1;
    dispatch_once(&onceToken1, ^
    {
        untranslatedString = [[NSString alloc] initWithFormat:@"UNTRANSLATED_%x", (int)arc4random()];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:customLocalizationBundlePath()])
            customLocalizationBundle = [NSBundle bundleWithPath:customLocalizationBundlePath()];
    });
    
    if (customLocalizationBundle != nil)
    {
        NSString *string = [customLocalizationBundle localizedStringForKey:s value:untranslatedString table:nil];
        if (string != nil && ![string isEqualToString:untranslatedString])
            return string;
    }
    
    static NSBundle *localizationBundle = nil;
    static NSBundle *fallbackBundle = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        fallbackBundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"en" ofType:@"lproj"]];
        
        NSString *language = [[NSLocale preferredLanguages] objectAtIndex:0];
        
        if (![[[NSBundle mainBundle] localizations] containsObject:language])
        {
            localizationBundle = fallbackBundle;
            
            if ([language rangeOfString:@"-"].location != NSNotFound)
            {
                NSString *languageWithoutRegion = [language substringToIndex:[language rangeOfString:@"-"].location];
                
                for (NSString *localization in [[NSBundle mainBundle] localizations])
                {
                    if ([languageWithoutRegion isEqualToString:localization])
                    {
                        NSBundle *candidateBundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:localization ofType:@"lproj"]];
                        if (candidateBundle != nil)
                            localizationBundle = candidateBundle;
                        
                        break;
                    }
                }
            }
        }
        else
            localizationBundle = [NSBundle mainBundle];
    });
    
    NSString *string = [localizationBundle localizedStringForKey:s value:untranslatedString table:nil];
    if (string != nil && ![string isEqualToString:untranslatedString])
        return string;
    
    if (localizationBundle != fallbackBundle)
    {
        NSString *string = [fallbackBundle localizedStringForKey:s value:untranslatedString table:nil];
        if (string != nil && ![string isEqualToString:untranslatedString])
            return string;
    }
    
    return s;
}
