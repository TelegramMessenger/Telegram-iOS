// Automatically-generated file, do not edit

#import <PresentationStrings/PresentationStrings.h>
#import <PresentationStrings/StringPluralization.h>

@implementation _FormattedStringRange

- (instancetype _Nonnull)initWithIndex:(NSInteger)index range:(NSRange)range {
    self = [super init];
    if (self != nil) {
        _index = index;
        _range = range;
    }
    return self;
}

@end


@implementation _FormattedString

- (instancetype _Nonnull)initWithString:(NSString * _Nonnull)string
    ranges:(NSArray<_FormattedStringRange *> * _Nonnull)ranges {
    self = [super init];
    if (self != nil) {
        _string = string;
        _ranges = ranges;
    }
    return self;
}

@end

@implementation _PresentationStringsComponent

- (instancetype _Nonnull)initWithLanguageCode:(NSString * _Nonnull)languageCode
    localizedName:(NSString * _Nonnull)localizedName
    pluralizationRulesCode:(NSString * _Nullable)pluralizationRulesCode
    dict:(NSDictionary<NSString *, NSString *> * _Nonnull)dict {
    self = [super init];
    if (self != nil) {
        _languageCode = languageCode;
        _localizedName = localizedName;
        _pluralizationRulesCode = pluralizationRulesCode;
        _dict = dict;
    }
    return self;
}

@end

@interface _PresentationStrings () {
    @public
    NSDictionary<NSNumber *, NSString *> *_idToKey;
}

@end

static NSArray<_FormattedStringRange *> * _Nonnull extractArgumentRanges(NSString * _Nonnull string) {
    static NSRegularExpression *argumentRegex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        argumentRegex = [NSRegularExpression regularExpressionWithPattern:@"%(((\\d+)\\$)?)([@df])"
            options:0 error:nil];
    });
    
    NSMutableArray<_FormattedStringRange *> *result = [[NSMutableArray alloc] init];
    NSArray<NSTextCheckingResult *> *matches = [argumentRegex matchesInString:string
        options:0 range:NSMakeRange(0, string.length)];
    int index = 0;
    for (NSTextCheckingResult *match in matches) {
        int currentIndex = index;
        NSRange matchRange = [match rangeAtIndex:3]; 
        if (matchRange.location != NSNotFound) {
            currentIndex = [[string substringWithRange:matchRange] intValue] - 1;
        }
        [result addObject:[[_FormattedStringRange alloc] initWithIndex:currentIndex range:[match rangeAtIndex:0]]];
        index += 1;
    }
    
    //sort?
    
    return result;
}

static _FormattedString * _Nonnull formatWithArgumentRanges(
    NSString * _Nonnull string,
    NSArray<_FormattedStringRange *> * _Nonnull ranges,
    NSArray<NSString *> * _Nonnull arguments
) {
    NSMutableArray<_FormattedStringRange *> *resultingRanges = [[NSMutableArray alloc] init];
    NSMutableString *result = [[NSMutableString alloc] init];
    NSUInteger currentLocation = 0;
    
    for (_FormattedStringRange *range in ranges) {
        if (currentLocation < range.range.location) {
            [result appendString:[string substringWithRange:
                NSMakeRange(currentLocation, range.range.location - currentLocation)]];
        }
        [resultingRanges addObject:[[_FormattedStringRange alloc] initWithIndex:range.index
            range:NSMakeRange(result.length, arguments[range.index].length)]];
        [result appendString:arguments[range.index]];
        currentLocation = range.range.location + range.range.length;
    }
    
    if (currentLocation != string.length) {
        [result appendString:[string substringWithRange:NSMakeRange(currentLocation, string.length - currentLocation)]];
    }
    
    return [[_FormattedString alloc] initWithString:result ranges:resultingRanges];
}

static NSString * _Nonnull getPluralizationSuffix(_PresentationStrings * _Nonnull strings, int32_t value) {
    StringPluralizationForm pluralizationForm = getStringPluralizationForm(strings.lc, value);
    switch (pluralizationForm) {
        case StringPluralizationFormZero: {
            return @"_0";
        }
        case StringPluralizationFormOne: {
            return @"_1";
        }
        case StringPluralizationFormTwo: {
            return @"_2";
        }
        case StringPluralizationFormFew: {
            return @"_3_10";
        }
        case StringPluralizationFormMany: {
            return @"_many";
        }
        default: {
            return @"_any";
        }
    }
}

static NSString * _Nonnull getSingle(_PresentationStrings * _Nonnull strings, NSString * _Nonnull key) {
    NSString *result = strings.primaryComponent.dict[key];
    if (!result) {
        result = strings.secondaryComponent.dict[key];
    }
    if (!result) {
        static NSDictionary<NSString *, NSString *> *fallbackDict = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSString *lprojPath = [[NSBundle mainBundle] pathForResource:@"en" ofType:@"lproj"];
            if (!lprojPath) {
                return;
            }
            NSBundle *bundle = [NSBundle bundleWithPath:lprojPath];
            if (!bundle) {
                return;
            }
            NSString *stringsPath = [bundle pathForResource:@"Localizable" ofType:@"strings"];
            if (!stringsPath) {
                return;
            }
            fallbackDict = [NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:stringsPath]];
        });
        result = fallbackDict[key]; 
    }
    if (!result) {
        result = key;
    }
    return result;
}

static NSString * _Nonnull getSingleIndirect(_PresentationStrings * _Nonnull strings, uint32_t keyId) {
    return getSingle(strings, strings->_idToKey[@(keyId)]);
}

static NSString * _Nonnull getPluralized(_PresentationStrings * _Nonnull strings, NSString * _Nonnull key,
    int32_t value) {
    NSString *parsedKey = [[NSString alloc] initWithFormat:@"%@%@", key, getPluralizationSuffix(strings, value)];
    NSString *formatString = getSingle(strings, parsedKey);
    NSString *stringValue =  [[NSString alloc] initWithFormat:@"%d", (int)value];
    NSString *result = [[NSString alloc] initWithFormat:formatString, stringValue];
    return result;
}

static NSString * _Nonnull getPluralizedIndirect(_PresentationStrings * _Nonnull strings, uint32_t keyId,
    int32_t value) {
    return getPluralized(strings, strings->_idToKey[@(keyId)], value);
}
static _FormattedString * _Nonnull getFormatted1(_PresentationStrings * _Nonnull strings,
    uint32_t keyId, id arg0) {
    NSString *formatString = getSingle(strings, strings->_idToKey[@(keyId)]);
    NSArray<_FormattedStringRange *> *argumentRanges = extractArgumentRanges(formatString);
    return formatWithArgumentRanges(formatString, argumentRanges, @[arg0]);
}

static _FormattedString * _Nonnull getFormatted2(_PresentationStrings * _Nonnull strings,
    uint32_t keyId, id arg0, id arg1) {
    NSString *formatString = getSingle(strings, strings->_idToKey[@(keyId)]);
    NSArray<_FormattedStringRange *> *argumentRanges = extractArgumentRanges(formatString);
    return formatWithArgumentRanges(formatString, argumentRanges, @[arg0, arg1]);
}

static _FormattedString * _Nonnull getFormatted3(_PresentationStrings * _Nonnull strings,
    uint32_t keyId, id arg0, id arg1, id arg2) {
    NSString *formatString = getSingle(strings, strings->_idToKey[@(keyId)]);
    NSArray<_FormattedStringRange *> *argumentRanges = extractArgumentRanges(formatString);
    return formatWithArgumentRanges(formatString, argumentRanges, @[arg0, arg1, arg2]);
}

static _FormattedString * _Nonnull getFormatted4(_PresentationStrings * _Nonnull strings,
    uint32_t keyId, id arg0, id arg1, id arg2, id arg3) {
    NSString *formatString = getSingle(strings, strings->_idToKey[@(keyId)]);
    NSArray<_FormattedStringRange *> *argumentRanges = extractArgumentRanges(formatString);
    return formatWithArgumentRanges(formatString, argumentRanges, @[arg0, arg1, arg2, arg3]);
}

static _FormattedString * _Nonnull getFormatted5(_PresentationStrings * _Nonnull strings,
    uint32_t keyId, id arg0, id arg1, id arg2, id arg3, id arg4) {
    NSString *formatString = getSingle(strings, strings->_idToKey[@(keyId)]);
    NSArray<_FormattedStringRange *> *argumentRanges = extractArgumentRanges(formatString);
    return formatWithArgumentRanges(formatString, argumentRanges, @[arg0, arg1, arg2, arg3, arg4]);
}

static _FormattedString * _Nonnull getFormatted6(_PresentationStrings * _Nonnull strings,
    uint32_t keyId, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5) {
    NSString *formatString = getSingle(strings, strings->_idToKey[@(keyId)]);
    NSArray<_FormattedStringRange *> *argumentRanges = extractArgumentRanges(formatString);
    return formatWithArgumentRanges(formatString, argumentRanges, @[arg0, arg1, arg2, arg3, arg4, arg5]);
}

@implementation _PresentationStrings

- (instancetype _Nonnull)initWithPrimaryComponent:(_PresentationStringsComponent * _Nonnull)primaryComponent
    secondaryComponent:(_PresentationStringsComponent * _Nullable)secondaryComponent
    groupingSeparator:(NSString * _Nullable)groupingSeparator {
    self = [super init];
    if (self != nil) {
        static NSDictionary<NSNumber *, NSString *> *idToKey = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSString *dataPath = [[NSBundle mainBundle] pathForResource:@"PresentationStrings" ofType:@"data"];
            if (!dataPath) {
                assert(false);
                return;
            }
            NSData *data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:dataPath]];
            if (!data) {
                assert(false);
                return;
            }
            if (data.length < 4) {
                assert(false);
                return;
            }
            
            NSMutableDictionary<NSNumber *, NSString *> *result = [[NSMutableDictionary alloc] init]; 
            
            uint32_t entryCount = 0;
            [data getBytes:&entryCount range:NSMakeRange(0, 4)];
            
            NSInteger offset = 4;
            for (uint32_t i = 0; i < entryCount; i++) {
                uint8_t stringLength = 0;
                [data getBytes:&stringLength range:NSMakeRange(offset, 1)];
                offset += 1;
                
                NSData *stringData = [data subdataWithRange:NSMakeRange(offset, stringLength)];
                offset += stringLength;
                
                result[@(i)] = [[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding];
            }
            idToKey = result;
        });
        _idToKey = idToKey;
    
        _primaryComponent = primaryComponent;
        _secondaryComponent = secondaryComponent;
        _groupingSeparator = groupingSeparator;
        
        if (secondaryComponent) {
            _baseLanguageCode = secondaryComponent.languageCode;
        } else {
            _baseLanguageCode = primaryComponent.languageCode;
        }
        
        NSString *languageCode = nil;
        if (primaryComponent.pluralizationRulesCode) {
            languageCode = primaryComponent.pluralizationRulesCode;
        } else {
            languageCode = primaryComponent.languageCode;
        }
        
        NSString *rawCode = languageCode;
        
        NSRange range = [languageCode rangeOfString:@"_"];
        if (range.location != NSNotFound) {
            rawCode = [rawCode substringWithRange:NSMakeRange(0, range.location)];
        }
        range = [languageCode rangeOfString:@"-"];
        if (range.location != NSNotFound) {
            rawCode = [rawCode substringWithRange:NSMakeRange(0, range.location)];
        }
        
        rawCode = [rawCode lowercaseString];
        
        uint32_t lc = 0;
        for (NSInteger i = 0; i < rawCode.length; i++) {
            lc = (lc << 8) + (uint32_t)[rawCode characterAtIndex:i];
        }
        _lc = lc;
    }
    return self;
}

@end


// AccentColor.Title
NSString * _Nonnull _La(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 0);
}
// AccessDenied.CallMicrophone
NSString * _Nonnull _Lb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1);
}
// AccessDenied.Camera
NSString * _Nonnull _Lc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2);
}
// AccessDenied.CameraDisabled
NSString * _Nonnull _Ld(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3);
}
// AccessDenied.CameraRestricted
NSString * _Nonnull _Le(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4);
}
// AccessDenied.Contacts
NSString * _Nonnull _Lf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 5);
}
// AccessDenied.LocationAlwaysDenied
NSString * _Nonnull _Lg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 6);
}
// AccessDenied.LocationDenied
NSString * _Nonnull _Lh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 7);
}
// AccessDenied.LocationDisabled
NSString * _Nonnull _Li(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 8);
}
// AccessDenied.LocationTracking
NSString * _Nonnull _Lj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 9);
}
// AccessDenied.MicrophoneRestricted
NSString * _Nonnull _Lk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 10);
}
// AccessDenied.PhotosAndVideos
NSString * _Nonnull _Ll(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 11);
}
// AccessDenied.PhotosRestricted
NSString * _Nonnull _Lm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 12);
}
// AccessDenied.SaveMedia
NSString * _Nonnull _Ln(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 13);
}
// AccessDenied.Settings
NSString * _Nonnull _Lo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 14);
}
// AccessDenied.Title
NSString * _Nonnull _Lp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 15);
}
// AccessDenied.VideoCallCamera
NSString * _Nonnull _Lq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 16);
}
// AccessDenied.VideoMessageCamera
NSString * _Nonnull _Lr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 17);
}
// AccessDenied.VideoMessageMicrophone
NSString * _Nonnull _Ls(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 18);
}
// AccessDenied.VideoMicrophone
NSString * _Nonnull _Lt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 19);
}
// AccessDenied.VoiceMicrophone
NSString * _Nonnull _Lu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 20);
}
// AccessDenied.Wallpapers
NSString * _Nonnull _Lv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 21);
}
// Activity.PlayingGame
NSString * _Nonnull _Lw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 22);
}
// Activity.RecordingAudio
NSString * _Nonnull _Lx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 23);
}
// Activity.RecordingVideoMessage
NSString * _Nonnull _Ly(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 24);
}
// Activity.RemindAboutChannel
_FormattedString * _Nonnull _Lz(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 25, _0);
}
// Activity.RemindAboutGroup
_FormattedString * _Nonnull _LA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 26, _0);
}
// Activity.RemindAboutUser
_FormattedString * _Nonnull _LB(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 27, _0);
}
// Activity.UploadingDocument
NSString * _Nonnull _LC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 28);
}
// Activity.UploadingPhoto
NSString * _Nonnull _LD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 29);
}
// Activity.UploadingVideo
NSString * _Nonnull _LE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 30);
}
// Activity.UploadingVideoMessage
NSString * _Nonnull _LF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 31);
}
// AddContact.ContactWillBeSharedAfterMutual
_FormattedString * _Nonnull _LG(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 32, _0);
}
// AddContact.SharedContactException
NSString * _Nonnull _LH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 33);
}
// AddContact.SharedContactExceptionInfo
_FormattedString * _Nonnull _LI(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 34, _0);
}
// AddContact.StatusSuccess
_FormattedString * _Nonnull _LJ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 35, _0);
}
// AppUpgrade.Running
NSString * _Nonnull _LK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 36);
}
// Appearance.AccentColor
NSString * _Nonnull _LL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 37);
}
// Appearance.Animations
NSString * _Nonnull _LM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 38);
}
// Appearance.AppIcon
NSString * _Nonnull _LN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 39);
}
// Appearance.AppIconClassic
NSString * _Nonnull _LO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 40);
}
// Appearance.AppIconClassicX
NSString * _Nonnull _LP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 41);
}
// Appearance.AppIconDefault
NSString * _Nonnull _LQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 42);
}
// Appearance.AppIconDefaultX
NSString * _Nonnull _LR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 43);
}
// Appearance.AppIconFilled
NSString * _Nonnull _LS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 44);
}
// Appearance.AppIconFilledX
NSString * _Nonnull _LT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 45);
}
// Appearance.AppIconNew1
NSString * _Nonnull _LU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 46);
}
// Appearance.AppIconNew2
NSString * _Nonnull _LV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 47);
}
// Appearance.AutoNightTheme
NSString * _Nonnull _LW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 48);
}
// Appearance.AutoNightThemeDisabled
NSString * _Nonnull _LX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 49);
}
// Appearance.BubbleCorners.AdjustAdjacent
NSString * _Nonnull _LY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 50);
}
// Appearance.BubbleCorners.Apply
NSString * _Nonnull _LZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 51);
}
// Appearance.BubbleCorners.Title
NSString * _Nonnull _Laa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 52);
}
// Appearance.BubbleCornersSetting
NSString * _Nonnull _Lab(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 53);
}
// Appearance.ColorTheme
NSString * _Nonnull _Lac(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 54);
}
// Appearance.ColorThemeNight
NSString * _Nonnull _Lad(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 55);
}
// Appearance.CreateTheme
NSString * _Nonnull _Lae(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 56);
}
// Appearance.EditTheme
NSString * _Nonnull _Laf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 57);
}
// Appearance.LargeEmoji
NSString * _Nonnull _Lag(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 58);
}
// Appearance.Other
NSString * _Nonnull _Lah(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 59);
}
// Appearance.PickAccentColor
NSString * _Nonnull _Lai(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 60);
}
// Appearance.Preview
NSString * _Nonnull _Laj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 61);
}
// Appearance.PreviewIncomingText
NSString * _Nonnull _Lak(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 62);
}
// Appearance.PreviewOutgoingText
NSString * _Nonnull _Lal(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 63);
}
// Appearance.PreviewReplyAuthor
NSString * _Nonnull _Lam(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 64);
}
// Appearance.PreviewReplyText
NSString * _Nonnull _Lan(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 65);
}
// Appearance.ReduceMotion
NSString * _Nonnull _Lao(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 66);
}
// Appearance.ReduceMotionInfo
NSString * _Nonnull _Lap(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 67);
}
// Appearance.RemoveTheme
NSString * _Nonnull _Laq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 68);
}
// Appearance.RemoveThemeColor
NSString * _Nonnull _Lar(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 69);
}
// Appearance.RemoveThemeColorConfirmation
NSString * _Nonnull _Las(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 70);
}
// Appearance.RemoveThemeConfirmation
NSString * _Nonnull _Lat(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 71);
}
// Appearance.ShareTheme
NSString * _Nonnull _Lau(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 72);
}
// Appearance.ShareThemeColor
NSString * _Nonnull _Lav(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 73);
}
// Appearance.TextSize.Apply
NSString * _Nonnull _Law(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 74);
}
// Appearance.TextSize.Automatic
NSString * _Nonnull _Lax(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 75);
}
// Appearance.TextSize.Title
NSString * _Nonnull _Lay(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 76);
}
// Appearance.TextSize.UseSystem
NSString * _Nonnull _Laz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 77);
}
// Appearance.TextSizeSetting
NSString * _Nonnull _LaA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 78);
}
// Appearance.ThemeCarouselClassic
NSString * _Nonnull _LaB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 79);
}
// Appearance.ThemeCarouselDay
NSString * _Nonnull _LaC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 80);
}
// Appearance.ThemeCarouselNewNight
NSString * _Nonnull _LaD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 81);
}
// Appearance.ThemeCarouselNight
NSString * _Nonnull _LaE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 82);
}
// Appearance.ThemeCarouselNightBlue
NSString * _Nonnull _LaF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 83);
}
// Appearance.ThemeCarouselTintedNight
NSString * _Nonnull _LaG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 84);
}
// Appearance.ThemeDay
NSString * _Nonnull _LaH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 85);
}
// Appearance.ThemeDayClassic
NSString * _Nonnull _LaI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 86);
}
// Appearance.ThemeNight
NSString * _Nonnull _LaJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 87);
}
// Appearance.ThemeNightBlue
NSString * _Nonnull _LaK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 88);
}
// Appearance.ThemePreview.Chat.1.Text
NSString * _Nonnull _LaL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 89);
}
// Appearance.ThemePreview.Chat.2.ReplyName
NSString * _Nonnull _LaM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 90);
}
// Appearance.ThemePreview.Chat.2.Text
NSString * _Nonnull _LaN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 91);
}
// Appearance.ThemePreview.Chat.3.Text
NSString * _Nonnull _LaO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 92);
}
// Appearance.ThemePreview.Chat.3.TextWithLink
NSString * _Nonnull _LaP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 93);
}
// Appearance.ThemePreview.Chat.4.Text
NSString * _Nonnull _LaQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 94);
}
// Appearance.ThemePreview.Chat.5.Text
NSString * _Nonnull _LaR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 95);
}
// Appearance.ThemePreview.Chat.6.Text
NSString * _Nonnull _LaS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 96);
}
// Appearance.ThemePreview.Chat.7.Text
NSString * _Nonnull _LaT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 97);
}
// Appearance.ThemePreview.ChatList.1.Name
NSString * _Nonnull _LaU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 98);
}
// Appearance.ThemePreview.ChatList.1.Text
NSString * _Nonnull _LaV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 99);
}
// Appearance.ThemePreview.ChatList.2.Name
NSString * _Nonnull _LaW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 100);
}
// Appearance.ThemePreview.ChatList.2.Text
NSString * _Nonnull _LaX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 101);
}
// Appearance.ThemePreview.ChatList.3.AuthorName
NSString * _Nonnull _LaY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 102);
}
// Appearance.ThemePreview.ChatList.3.Name
NSString * _Nonnull _LaZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 103);
}
// Appearance.ThemePreview.ChatList.3.Text
NSString * _Nonnull _Lba(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 104);
}
// Appearance.ThemePreview.ChatList.4.Name
NSString * _Nonnull _Lbb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 105);
}
// Appearance.ThemePreview.ChatList.4.Text
NSString * _Nonnull _Lbc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 106);
}
// Appearance.ThemePreview.ChatList.5.Name
NSString * _Nonnull _Lbd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 107);
}
// Appearance.ThemePreview.ChatList.5.Text
NSString * _Nonnull _Lbe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 108);
}
// Appearance.ThemePreview.ChatList.6.Name
NSString * _Nonnull _Lbf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 109);
}
// Appearance.ThemePreview.ChatList.6.Text
NSString * _Nonnull _Lbg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 110);
}
// Appearance.ThemePreview.ChatList.7.Name
NSString * _Nonnull _Lbh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 111);
}
// Appearance.ThemePreview.ChatList.7.Text
NSString * _Nonnull _Lbi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 112);
}
// Appearance.TintAllColors
NSString * _Nonnull _Lbj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 113);
}
// Appearance.Title
NSString * _Nonnull _Lbk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 114);
}
// AppleWatch.ReplyPresets
NSString * _Nonnull _Lbl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 115);
}
// AppleWatch.ReplyPresetsHelp
NSString * _Nonnull _Lbm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 116);
}
// AppleWatch.Title
NSString * _Nonnull _Lbn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 117);
}
// Application.Name
NSString * _Nonnull _Lbo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 118);
}
// Application.Update
NSString * _Nonnull _Lbp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 119);
}
// ApplyLanguage.ApplyLanguageAction
NSString * _Nonnull _Lbq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 120);
}
// ApplyLanguage.ApplySuccess
NSString * _Nonnull _Lbr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 121);
}
// ApplyLanguage.ChangeLanguageAction
NSString * _Nonnull _Lbs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 122);
}
// ApplyLanguage.ChangeLanguageAlreadyActive
_FormattedString * _Nonnull _Lbt(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 123, _0);
}
// ApplyLanguage.ChangeLanguageOfficialText
_FormattedString * _Nonnull _Lbu(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 124, _0);
}
// ApplyLanguage.ChangeLanguageTitle
NSString * _Nonnull _Lbv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 125);
}
// ApplyLanguage.ChangeLanguageUnofficialText
_FormattedString * _Nonnull _Lbw(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 126, _0, _1);
}
// ApplyLanguage.LanguageNotSupportedError
NSString * _Nonnull _Lbx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 127);
}
// ApplyLanguage.UnsufficientDataText
_FormattedString * _Nonnull _Lby(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 128, _0);
}
// ApplyLanguage.UnsufficientDataTitle
NSString * _Nonnull _Lbz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 129);
}
// ArchivedChats.IntroText1
NSString * _Nonnull _LbA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 130);
}
// ArchivedChats.IntroText2
NSString * _Nonnull _LbB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 131);
}
// ArchivedChats.IntroText3
NSString * _Nonnull _LbC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 132);
}
// ArchivedChats.IntroTitle1
NSString * _Nonnull _LbD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 133);
}
// ArchivedChats.IntroTitle2
NSString * _Nonnull _LbE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 134);
}
// ArchivedChats.IntroTitle3
NSString * _Nonnull _LbF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 135);
}
// ArchivedPacksAlert.Title
NSString * _Nonnull _LbG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 136);
}
// AttachmentMenu.File
NSString * _Nonnull _LbH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 137);
}
// AttachmentMenu.PhotoOrVideo
NSString * _Nonnull _LbI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 138);
}
// AttachmentMenu.Poll
NSString * _Nonnull _LbJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 139);
}
// AttachmentMenu.SendAsFile
NSString * _Nonnull _LbK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 140);
}
// AttachmentMenu.SendAsFiles
NSString * _Nonnull _LbL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 141);
}
// AttachmentMenu.SendGif
NSString * _Nonnull _LbM(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 142, value);
}
// AttachmentMenu.SendItem
NSString * _Nonnull _LbN(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 143, value);
}
// AttachmentMenu.SendPhoto
NSString * _Nonnull _LbO(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 144, value);
}
// AttachmentMenu.SendVideo
NSString * _Nonnull _LbP(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 145, value);
}
// AttachmentMenu.WebSearch
NSString * _Nonnull _LbQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 146);
}
// AuthCode.Alert
_FormattedString * _Nonnull _LbR(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 147, _0);
}
// AuthSessions.AddDevice
NSString * _Nonnull _LbS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 148);
}
// AuthSessions.AddDevice.InvalidQRCode
NSString * _Nonnull _LbT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 149);
}
// AuthSessions.AddDevice.ScanInfo
NSString * _Nonnull _LbU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 150);
}
// AuthSessions.AddDevice.ScanTitle
NSString * _Nonnull _LbV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 151);
}
// AuthSessions.AddDevice.UrlLoginHint
NSString * _Nonnull _LbW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 152);
}
// AuthSessions.AddDeviceIntro.Action
NSString * _Nonnull _LbX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 153);
}
// AuthSessions.AddDeviceIntro.Text1
NSString * _Nonnull _LbY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 154);
}
// AuthSessions.AddDeviceIntro.Text2
NSString * _Nonnull _LbZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 155);
}
// AuthSessions.AddDeviceIntro.Text3
NSString * _Nonnull _Lca(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 156);
}
// AuthSessions.AddDeviceIntro.Title
NSString * _Nonnull _Lcb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 157);
}
// AuthSessions.AddedDeviceTerminate
NSString * _Nonnull _Lcc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 158);
}
// AuthSessions.AddedDeviceTitle
NSString * _Nonnull _Lcd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 159);
}
// AuthSessions.AppUnofficial
_FormattedString * _Nonnull _Lce(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 160, _0);
}
// AuthSessions.CurrentSession
NSString * _Nonnull _Lcf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 161);
}
// AuthSessions.DevicesTitle
NSString * _Nonnull _Lcg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 162);
}
// AuthSessions.EmptyText
NSString * _Nonnull _Lch(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 163);
}
// AuthSessions.EmptyTitle
NSString * _Nonnull _Lci(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 164);
}
// AuthSessions.IncompleteAttempts
NSString * _Nonnull _Lcj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 165);
}
// AuthSessions.IncompleteAttemptsInfo
NSString * _Nonnull _Lck(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 166);
}
// AuthSessions.LogOut
NSString * _Nonnull _Lcl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 167);
}
// AuthSessions.LogOutApplications
NSString * _Nonnull _Lcm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 168);
}
// AuthSessions.LogOutApplicationsHelp
NSString * _Nonnull _Lcn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 169);
}
// AuthSessions.LoggedIn
NSString * _Nonnull _Lco(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 170);
}
// AuthSessions.LoggedInWithTelegram
NSString * _Nonnull _Lcp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 171);
}
// AuthSessions.Message
_FormattedString * _Nonnull _Lcq(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 172, _0);
}
// AuthSessions.OtherDevices
NSString * _Nonnull _Lcr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 173);
}
// AuthSessions.OtherSessions
NSString * _Nonnull _Lcs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 174);
}
// AuthSessions.Sessions
NSString * _Nonnull _Lct(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 175);
}
// AuthSessions.Terminate
NSString * _Nonnull _Lcu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 176);
}
// AuthSessions.TerminateOtherSessions
NSString * _Nonnull _Lcv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 177);
}
// AuthSessions.TerminateOtherSessionsHelp
NSString * _Nonnull _Lcw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 178);
}
// AuthSessions.TerminateSession
NSString * _Nonnull _Lcx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 179);
}
// AuthSessions.Title
NSString * _Nonnull _Lcy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 180);
}
// AutoDownloadSettings.AutoDownload
NSString * _Nonnull _Lcz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 181);
}
// AutoDownloadSettings.AutodownloadFiles
NSString * _Nonnull _LcA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 182);
}
// AutoDownloadSettings.AutodownloadPhotos
NSString * _Nonnull _LcB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 183);
}
// AutoDownloadSettings.AutodownloadVideos
NSString * _Nonnull _LcC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 184);
}
// AutoDownloadSettings.Cellular
NSString * _Nonnull _LcD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 185);
}
// AutoDownloadSettings.CellularTitle
NSString * _Nonnull _LcE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 186);
}
// AutoDownloadSettings.Channels
NSString * _Nonnull _LcF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 187);
}
// AutoDownloadSettings.Contacts
NSString * _Nonnull _LcG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 188);
}
// AutoDownloadSettings.DataUsage
NSString * _Nonnull _LcH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 189);
}
// AutoDownloadSettings.DataUsageCustom
NSString * _Nonnull _LcI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 190);
}
// AutoDownloadSettings.DataUsageHigh
NSString * _Nonnull _LcJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 191);
}
// AutoDownloadSettings.DataUsageLow
NSString * _Nonnull _LcK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 192);
}
// AutoDownloadSettings.DataUsageMedium
NSString * _Nonnull _LcL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 193);
}
// AutoDownloadSettings.Delimeter
NSString * _Nonnull _LcM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 194);
}
// AutoDownloadSettings.DocumentsTitle
NSString * _Nonnull _LcN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 195);
}
// AutoDownloadSettings.Files
NSString * _Nonnull _LcO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 196);
}
// AutoDownloadSettings.GroupChats
NSString * _Nonnull _LcP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 197);
}
// AutoDownloadSettings.LastDelimeter
NSString * _Nonnull _LcQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 198);
}
// AutoDownloadSettings.LimitBySize
NSString * _Nonnull _LcR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 199);
}
// AutoDownloadSettings.MaxFileSize
NSString * _Nonnull _LcS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 200);
}
// AutoDownloadSettings.MaxVideoSize
NSString * _Nonnull _LcT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 201);
}
// AutoDownloadSettings.MediaTypes
NSString * _Nonnull _LcU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 202);
}
// AutoDownloadSettings.OffForAll
NSString * _Nonnull _LcV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 203);
}
// AutoDownloadSettings.OnFor
_FormattedString * _Nonnull _LcW(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 204, _0);
}
// AutoDownloadSettings.OnForAll
NSString * _Nonnull _LcX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 205);
}
// AutoDownloadSettings.Photos
NSString * _Nonnull _LcY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 206);
}
// AutoDownloadSettings.PhotosTitle
NSString * _Nonnull _LcZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 207);
}
// AutoDownloadSettings.PreloadVideo
NSString * _Nonnull _Lda(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 208);
}
// AutoDownloadSettings.PreloadVideoInfo
_FormattedString * _Nonnull _Ldb(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 209, _0);
}
// AutoDownloadSettings.PrivateChats
NSString * _Nonnull _Ldc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 210);
}
// AutoDownloadSettings.Reset
NSString * _Nonnull _Ldd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 211);
}
// AutoDownloadSettings.ResetHelp
NSString * _Nonnull _Lde(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 212);
}
// AutoDownloadSettings.ResetSettings
NSString * _Nonnull _Ldf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 213);
}
// AutoDownloadSettings.Title
NSString * _Nonnull _Ldg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 214);
}
// AutoDownloadSettings.TypeChannels
NSString * _Nonnull _Ldh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 215);
}
// AutoDownloadSettings.TypeContacts
NSString * _Nonnull _Ldi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 216);
}
// AutoDownloadSettings.TypeGroupChats
NSString * _Nonnull _Ldj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 217);
}
// AutoDownloadSettings.TypePrivateChats
NSString * _Nonnull _Ldk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 218);
}
// AutoDownloadSettings.Unlimited
NSString * _Nonnull _Ldl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 219);
}
// AutoDownloadSettings.UpTo
_FormattedString * _Nonnull _Ldm(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 220, _0);
}
// AutoDownloadSettings.UpToFor
_FormattedString * _Nonnull _Ldn(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 221, _0, _1);
}
// AutoDownloadSettings.UpToForAll
_FormattedString * _Nonnull _Ldo(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 222, _0);
}
// AutoDownloadSettings.VideoMessagesTitle
NSString * _Nonnull _Ldp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 223);
}
// AutoDownloadSettings.Videos
NSString * _Nonnull _Ldq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 224);
}
// AutoDownloadSettings.VideosTitle
NSString * _Nonnull _Ldr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 225);
}
// AutoDownloadSettings.VoiceMessagesInfo
NSString * _Nonnull _Lds(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 226);
}
// AutoDownloadSettings.VoiceMessagesTitle
NSString * _Nonnull _Ldt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 227);
}
// AutoDownloadSettings.WiFi
NSString * _Nonnull _Ldu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 228);
}
// AutoDownloadSettings.WifiTitle
NSString * _Nonnull _Ldv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 229);
}
// AutoNightTheme.Automatic
NSString * _Nonnull _Ldw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 230);
}
// AutoNightTheme.AutomaticHelp
_FormattedString * _Nonnull _Ldx(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 231, _0);
}
// AutoNightTheme.AutomaticSection
NSString * _Nonnull _Ldy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 232);
}
// AutoNightTheme.Disabled
NSString * _Nonnull _Ldz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 233);
}
// AutoNightTheme.LocationHelp
_FormattedString * _Nonnull _LdA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 234, _0, _1);
}
// AutoNightTheme.NotAvailable
NSString * _Nonnull _LdB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 235);
}
// AutoNightTheme.PreferredTheme
NSString * _Nonnull _LdC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 236);
}
// AutoNightTheme.ScheduleSection
NSString * _Nonnull _LdD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 237);
}
// AutoNightTheme.Scheduled
NSString * _Nonnull _LdE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 238);
}
// AutoNightTheme.ScheduledFrom
NSString * _Nonnull _LdF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 239);
}
// AutoNightTheme.ScheduledTo
NSString * _Nonnull _LdG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 240);
}
// AutoNightTheme.System
NSString * _Nonnull _LdH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 241);
}
// AutoNightTheme.Title
NSString * _Nonnull _LdI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 242);
}
// AutoNightTheme.UpdateLocation
NSString * _Nonnull _LdJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 243);
}
// AutoNightTheme.UseSunsetSunrise
NSString * _Nonnull _LdK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 244);
}
// AutoremoveSetup.TimeSectionHeader
NSString * _Nonnull _LdL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 245);
}
// AutoremoveSetup.TimerInfoChannel
NSString * _Nonnull _LdM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 246);
}
// AutoremoveSetup.TimerInfoChat
NSString * _Nonnull _LdN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 247);
}
// AutoremoveSetup.TimerValueAfter
_FormattedString * _Nonnull _LdO(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 248, _0);
}
// AutoremoveSetup.TimerValueNever
NSString * _Nonnull _LdP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 249);
}
// AutoremoveSetup.Title
NSString * _Nonnull _LdQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 250);
}
// BlockedUsers.AddNew
NSString * _Nonnull _LdR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 251);
}
// BlockedUsers.BlockTitle
NSString * _Nonnull _LdS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 252);
}
// BlockedUsers.BlockUser
NSString * _Nonnull _LdT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 253);
}
// BlockedUsers.Info
NSString * _Nonnull _LdU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 254);
}
// BlockedUsers.LeavePrefix
NSString * _Nonnull _LdV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 255);
}
// BlockedUsers.SelectUserTitle
NSString * _Nonnull _LdW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 256);
}
// BlockedUsers.Title
NSString * _Nonnull _LdX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 257);
}
// BlockedUsers.Unblock
NSString * _Nonnull _LdY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 258);
}
// Bot.DescriptionTitle
NSString * _Nonnull _LdZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 259);
}
// Bot.GenericBotStatus
NSString * _Nonnull _Lea(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 260);
}
// Bot.GenericSupportStatus
NSString * _Nonnull _Leb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 261);
}
// Bot.GroupStatusDoesNotReadHistory
NSString * _Nonnull _Lec(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 262);
}
// Bot.GroupStatusReadsHistory
NSString * _Nonnull _Led(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 263);
}
// Bot.Start
NSString * _Nonnull _Lee(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 264);
}
// Bot.Stop
NSString * _Nonnull _Lef(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 265);
}
// Bot.Unblock
NSString * _Nonnull _Leg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 266);
}
// Broadcast.AdminLog.EmptyText
NSString * _Nonnull _Leh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 267);
}
// BroadcastGroups.Cancel
NSString * _Nonnull _Lei(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 268);
}
// BroadcastGroups.ConfirmationAlert.Convert
NSString * _Nonnull _Lej(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 269);
}
// BroadcastGroups.ConfirmationAlert.Text
NSString * _Nonnull _Lek(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 270);
}
// BroadcastGroups.ConfirmationAlert.Title
NSString * _Nonnull _Lel(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 271);
}
// BroadcastGroups.Convert
NSString * _Nonnull _Lem(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 272);
}
// BroadcastGroups.IntroText
NSString * _Nonnull _Len(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 273);
}
// BroadcastGroups.IntroTitle
NSString * _Nonnull _Leo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 274);
}
// BroadcastGroups.LimitAlert.LearnMore
NSString * _Nonnull _Lep(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 275);
}
// BroadcastGroups.LimitAlert.SettingsTip
NSString * _Nonnull _Leq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 276);
}
// BroadcastGroups.LimitAlert.Text
_FormattedString * _Nonnull _Ler(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 277, _0);
}
// BroadcastGroups.LimitAlert.Title
NSString * _Nonnull _Les(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 278);
}
// BroadcastGroups.Success
_FormattedString * _Nonnull _Let(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 279, _0);
}
// BroadcastListInfo.AddRecipient
NSString * _Nonnull _Leu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 280);
}
// CHAT_MESSAGE_INVOICE
_FormattedString * _Nonnull _Lev(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 281, _0, _1, _2);
}
// Cache.ByPeerHeader
NSString * _Nonnull _Lew(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 282);
}
// Cache.Clear
_FormattedString * _Nonnull _Lex(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 283, _0);
}
// Cache.ClearCache
NSString * _Nonnull _Ley(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 284);
}
// Cache.ClearEmpty
NSString * _Nonnull _Lez(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 285);
}
// Cache.ClearNone
NSString * _Nonnull _LeA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 286);
}
// Cache.ClearProgress
NSString * _Nonnull _LeB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 287);
}
// Cache.Files
NSString * _Nonnull _LeC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 288);
}
// Cache.Help
NSString * _Nonnull _LeD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 289);
}
// Cache.Indexing
NSString * _Nonnull _LeE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 290);
}
// Cache.KeepMedia
NSString * _Nonnull _LeF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 291);
}
// Cache.KeepMediaHelp
NSString * _Nonnull _LeG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 292);
}
// Cache.LowDiskSpaceText
NSString * _Nonnull _LeH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 293);
}
// Cache.MaximumCacheSize
NSString * _Nonnull _LeI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 294);
}
// Cache.MaximumCacheSizeHelp
NSString * _Nonnull _LeJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 295);
}
// Cache.Music
NSString * _Nonnull _LeK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 296);
}
// Cache.NoLimit
NSString * _Nonnull _LeL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 297);
}
// Cache.Photos
NSString * _Nonnull _LeM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 298);
}
// Cache.ServiceFiles
NSString * _Nonnull _LeN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 299);
}
// Cache.Title
NSString * _Nonnull _LeO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 300);
}
// Cache.Videos
NSString * _Nonnull _LeP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 301);
}
// Call.Accept
NSString * _Nonnull _LeQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 302);
}
// Call.AccountIsLoggedOnCurrentDevice
_FormattedString * _Nonnull _LeR(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 303, _0);
}
// Call.AnsweringWithAccount
_FormattedString * _Nonnull _LeS(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 304, _0);
}
// Call.Audio
NSString * _Nonnull _LeT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 305);
}
// Call.AudioRouteHeadphones
NSString * _Nonnull _LeU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 306);
}
// Call.AudioRouteHide
NSString * _Nonnull _LeV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 307);
}
// Call.AudioRouteMute
NSString * _Nonnull _LeW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 308);
}
// Call.AudioRouteSpeaker
NSString * _Nonnull _LeX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 309);
}
// Call.BatteryLow
_FormattedString * _Nonnull _LeY(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 310, _0);
}
// Call.CallAgain
NSString * _Nonnull _LeZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 311);
}
// Call.CallInProgressMessage
_FormattedString * _Nonnull _Lfa(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 312, _0, _1);
}
// Call.CallInProgressTitle
NSString * _Nonnull _Lfb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 313);
}
// Call.CallInProgressVoiceChatMessage
_FormattedString * _Nonnull _Lfc(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 314, _0, _1);
}
// Call.Camera
NSString * _Nonnull _Lfd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 315);
}
// Call.CameraConfirmationConfirm
NSString * _Nonnull _Lfe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 316);
}
// Call.CameraConfirmationText
NSString * _Nonnull _Lff(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 317);
}
// Call.CameraOff
_FormattedString * _Nonnull _Lfg(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 318, _0);
}
// Call.CameraTooltip
NSString * _Nonnull _Lfh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 319);
}
// Call.ConnectionErrorMessage
NSString * _Nonnull _Lfi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 320);
}
// Call.ConnectionErrorTitle
NSString * _Nonnull _Lfj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 321);
}
// Call.Days
NSString * _Nonnull _Lfk(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 322, value);
}
// Call.Decline
NSString * _Nonnull _Lfl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 323);
}
// Call.EmojiDescription
_FormattedString * _Nonnull _Lfm(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 324, _0);
}
// Call.EncryptionKey.Title
NSString * _Nonnull _Lfn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 325);
}
// Call.End
NSString * _Nonnull _Lfo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 326);
}
// Call.ExternalCallInProgressMessage
NSString * _Nonnull _Lfp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 327);
}
// Call.Flip
NSString * _Nonnull _Lfq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 328);
}
// Call.GroupFormat
_FormattedString * _Nonnull _Lfr(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 329, _0, _1);
}
// Call.Hours
NSString * _Nonnull _Lfs(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 330, value);
}
// Call.IncomingVideoCall
NSString * _Nonnull _Lft(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 331);
}
// Call.IncomingVoiceCall
NSString * _Nonnull _Lfu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 332);
}
// Call.Message
NSString * _Nonnull _Lfv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 333);
}
// Call.MicrophoneOff
_FormattedString * _Nonnull _Lfw(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 334, _0);
}
// Call.Minutes
NSString * _Nonnull _Lfx(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 335, value);
}
// Call.Mute
NSString * _Nonnull _Lfy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 336);
}
// Call.ParticipantVersionOutdatedError
_FormattedString * _Nonnull _Lfz(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 337, _0);
}
// Call.ParticipantVideoVersionOutdatedError
_FormattedString * _Nonnull _LfA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 338, _0);
}
// Call.PhoneCallInProgressMessage
NSString * _Nonnull _LfB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 339);
}
// Call.PrivacyErrorMessage
_FormattedString * _Nonnull _LfC(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 340, _0);
}
// Call.RateCall
NSString * _Nonnull _LfD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 341);
}
// Call.RecordingDisabledMessage
NSString * _Nonnull _LfE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 342);
}
// Call.RemoteVideoPaused
_FormattedString * _Nonnull _LfF(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 343, _0);
}
// Call.ReportIncludeLog
NSString * _Nonnull _LfG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 344);
}
// Call.ReportIncludeLogDescription
NSString * _Nonnull _LfH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 345);
}
// Call.ReportPlaceholder
NSString * _Nonnull _LfI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 346);
}
// Call.ReportSend
NSString * _Nonnull _LfJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 347);
}
// Call.ReportSkip
NSString * _Nonnull _LfK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 348);
}
// Call.Seconds
NSString * _Nonnull _LfL(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 349, value);
}
// Call.ShareStats
NSString * _Nonnull _LfM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 350);
}
// Call.ShortMinutes
NSString * _Nonnull _LfN(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 351, value);
}
// Call.ShortSeconds
NSString * _Nonnull _LfO(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 352, value);
}
// Call.Speaker
NSString * _Nonnull _LfP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 353);
}
// Call.StatusBar
_FormattedString * _Nonnull _LfQ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 354, _0);
}
// Call.StatusBusy
NSString * _Nonnull _LfR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 355);
}
// Call.StatusConnecting
NSString * _Nonnull _LfS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 356);
}
// Call.StatusEnded
NSString * _Nonnull _LfT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 357);
}
// Call.StatusFailed
NSString * _Nonnull _LfU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 358);
}
// Call.StatusIncoming
NSString * _Nonnull _LfV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 359);
}
// Call.StatusNoAnswer
NSString * _Nonnull _LfW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 360);
}
// Call.StatusOngoing
_FormattedString * _Nonnull _LfX(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 361, _0);
}
// Call.StatusRequesting
NSString * _Nonnull _LfY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 362);
}
// Call.StatusRinging
NSString * _Nonnull _LfZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 363);
}
// Call.StatusWaiting
NSString * _Nonnull _Lga(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 364);
}
// Call.VoiceChatInProgressCallMessage
_FormattedString * _Nonnull _Lgb(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 365, _0, _1);
}
// Call.VoiceChatInProgressMessage
_FormattedString * _Nonnull _Lgc(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 366, _0, _1);
}
// Call.VoiceChatInProgressMessageCall
_FormattedString * _Nonnull _Lgd(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 367, _0, _1);
}
// Call.VoiceChatInProgressTitle
NSString * _Nonnull _Lge(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 368);
}
// Call.VoiceOver.VideoCallCanceled
NSString * _Nonnull _Lgf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 369);
}
// Call.VoiceOver.VideoCallIncoming
NSString * _Nonnull _Lgg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 370);
}
// Call.VoiceOver.VideoCallMissed
NSString * _Nonnull _Lgh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 371);
}
// Call.VoiceOver.VideoCallOutgoing
NSString * _Nonnull _Lgi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 372);
}
// Call.VoiceOver.VoiceCallCanceled
NSString * _Nonnull _Lgj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 373);
}
// Call.VoiceOver.VoiceCallIncoming
NSString * _Nonnull _Lgk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 374);
}
// Call.VoiceOver.VoiceCallMissed
NSString * _Nonnull _Lgl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 375);
}
// Call.VoiceOver.VoiceCallOutgoing
NSString * _Nonnull _Lgm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 376);
}
// Call.YourMicrophoneOff
NSString * _Nonnull _Lgn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 377);
}
// CallFeedback.AddComment
NSString * _Nonnull _Lgo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 378);
}
// CallFeedback.IncludeLogs
NSString * _Nonnull _Lgp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 379);
}
// CallFeedback.IncludeLogsInfo
NSString * _Nonnull _Lgq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 380);
}
// CallFeedback.ReasonDistortedSpeech
NSString * _Nonnull _Lgr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 381);
}
// CallFeedback.ReasonDropped
NSString * _Nonnull _Lgs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 382);
}
// CallFeedback.ReasonEcho
NSString * _Nonnull _Lgt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 383);
}
// CallFeedback.ReasonInterruption
NSString * _Nonnull _Lgu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 384);
}
// CallFeedback.ReasonNoise
NSString * _Nonnull _Lgv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 385);
}
// CallFeedback.ReasonSilentLocal
NSString * _Nonnull _Lgw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 386);
}
// CallFeedback.ReasonSilentRemote
NSString * _Nonnull _Lgx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 387);
}
// CallFeedback.Send
NSString * _Nonnull _Lgy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 388);
}
// CallFeedback.Success
NSString * _Nonnull _Lgz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 389);
}
// CallFeedback.Title
NSString * _Nonnull _LgA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 390);
}
// CallFeedback.VideoReasonDistorted
NSString * _Nonnull _LgB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 391);
}
// CallFeedback.VideoReasonLowQuality
NSString * _Nonnull _LgC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 392);
}
// CallFeedback.WhatWentWrong
NSString * _Nonnull _LgD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 393);
}
// CallList.ActiveVoiceChatsHeader
NSString * _Nonnull _LgE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 394);
}
// CallList.DeleteAllForEveryone
NSString * _Nonnull _LgF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 395);
}
// CallList.DeleteAllForMe
NSString * _Nonnull _LgG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 396);
}
// CallList.RecentCallsHeader
NSString * _Nonnull _LgH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 397);
}
// CallSettings.Always
NSString * _Nonnull _LgI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 398);
}
// CallSettings.Never
NSString * _Nonnull _LgJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 399);
}
// CallSettings.OnMobile
NSString * _Nonnull _LgK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 400);
}
// CallSettings.RecentCalls
NSString * _Nonnull _LgL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 401);
}
// CallSettings.TabIcon
NSString * _Nonnull _LgM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 402);
}
// CallSettings.TabIconDescription
NSString * _Nonnull _LgN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 403);
}
// CallSettings.Title
NSString * _Nonnull _LgO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 404);
}
// CallSettings.UseLessData
NSString * _Nonnull _LgP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 405);
}
// CallSettings.UseLessDataLongDescription
NSString * _Nonnull _LgQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 406);
}
// Calls.AddTab
NSString * _Nonnull _LgR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 407);
}
// Calls.All
NSString * _Nonnull _LgS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 408);
}
// Calls.CallTabDescription
NSString * _Nonnull _LgT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 409);
}
// Calls.CallTabTitle
NSString * _Nonnull _LgU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 410);
}
// Calls.Missed
NSString * _Nonnull _LgV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 411);
}
// Calls.NewCall
NSString * _Nonnull _LgW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 412);
}
// Calls.NoCallsPlaceholder
NSString * _Nonnull _LgX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 413);
}
// Calls.NoMissedCallsPlacehoder
NSString * _Nonnull _LgY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 414);
}
// Calls.NoVoiceAndVideoCallsPlaceholder
NSString * _Nonnull _LgZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 415);
}
// Calls.NotNow
NSString * _Nonnull _Lha(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 416);
}
// Calls.RatingFeedback
NSString * _Nonnull _Lhb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 417);
}
// Calls.RatingTitle
NSString * _Nonnull _Lhc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 418);
}
// Calls.StartNewCall
NSString * _Nonnull _Lhd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 419);
}
// Calls.SubmitRating
NSString * _Nonnull _Lhe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 420);
}
// Calls.TabTitle
NSString * _Nonnull _Lhf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 421);
}
// Camera.Discard
NSString * _Nonnull _Lhg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 422);
}
// Camera.FlashAuto
NSString * _Nonnull _Lhh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 423);
}
// Camera.FlashOff
NSString * _Nonnull _Lhi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 424);
}
// Camera.FlashOn
NSString * _Nonnull _Lhj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 425);
}
// Camera.PhotoMode
NSString * _Nonnull _Lhk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 426);
}
// Camera.Retake
NSString * _Nonnull _Lhl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 427);
}
// Camera.SquareMode
NSString * _Nonnull _Lhm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 428);
}
// Camera.TapAndHoldForVideo
NSString * _Nonnull _Lhn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 429);
}
// Camera.Title
NSString * _Nonnull _Lho(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 430);
}
// Camera.VideoMode
NSString * _Nonnull _Lhp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 431);
}
// CancelResetAccount.Success
_FormattedString * _Nonnull _Lhq(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 432, _0);
}
// CancelResetAccount.TextSMS
_FormattedString * _Nonnull _Lhr(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 433, _0);
}
// CancelResetAccount.Title
NSString * _Nonnull _Lhs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 434);
}
// ChangePhone.ErrorOccupied
_FormattedString * _Nonnull _Lht(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 435, _0);
}
// ChangePhoneNumberCode.CallTimer
_FormattedString * _Nonnull _Lhu(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 436, _0);
}
// ChangePhoneNumberCode.Called
NSString * _Nonnull _Lhv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 437);
}
// ChangePhoneNumberCode.Code
NSString * _Nonnull _Lhw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 438);
}
// ChangePhoneNumberCode.CodePlaceholder
NSString * _Nonnull _Lhx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 439);
}
// ChangePhoneNumberCode.Help
NSString * _Nonnull _Lhy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 440);
}
// ChangePhoneNumberCode.RequestingACall
NSString * _Nonnull _Lhz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 441);
}
// ChangePhoneNumberNumber.Help
NSString * _Nonnull _LhA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 442);
}
// ChangePhoneNumberNumber.NewNumber
NSString * _Nonnull _LhB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 443);
}
// ChangePhoneNumberNumber.NumberPlaceholder
NSString * _Nonnull _LhC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 444);
}
// ChangePhoneNumberNumber.Title
NSString * _Nonnull _LhD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 445);
}
// Channel.About.Help
NSString * _Nonnull _LhE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 446);
}
// Channel.About.Placeholder
NSString * _Nonnull _LhF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 447);
}
// Channel.About.Title
NSString * _Nonnull _LhG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 448);
}
// Channel.AboutItem
NSString * _Nonnull _LhH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 449);
}
// Channel.AddBotAsAdmin
NSString * _Nonnull _LhI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 450);
}
// Channel.AddBotErrorHaveRights
NSString * _Nonnull _LhJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 451);
}
// Channel.AddBotErrorNoRights
NSString * _Nonnull _LhK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 452);
}
// Channel.AddUserLeftError
NSString * _Nonnull _LhL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 453);
}
// Channel.AdminLog.AddMembers
NSString * _Nonnull _LhM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 454);
}
// Channel.AdminLog.AllowedNewMembersToSpeak
_FormattedString * _Nonnull _LhN(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 455, _0);
}
// Channel.AdminLog.BanEmbedLinks
NSString * _Nonnull _LhO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 456);
}
// Channel.AdminLog.BanReadMessages
NSString * _Nonnull _LhP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 457);
}
// Channel.AdminLog.BanSendMedia
NSString * _Nonnull _LhQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 458);
}
// Channel.AdminLog.BanSendMessages
NSString * _Nonnull _LhR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 459);
}
// Channel.AdminLog.BanSendStickersAndGifs
NSString * _Nonnull _LhS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 460);
}
// Channel.AdminLog.CanAddAdmins
NSString * _Nonnull _LhT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 461);
}
// Channel.AdminLog.CanBanUsers
NSString * _Nonnull _LhU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 462);
}
// Channel.AdminLog.CanBeAnonymous
NSString * _Nonnull _LhV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 463);
}
// Channel.AdminLog.CanChangeInfo
NSString * _Nonnull _LhW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 464);
}
// Channel.AdminLog.CanDeleteMessages
NSString * _Nonnull _LhX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 465);
}
// Channel.AdminLog.CanDeleteMessagesOfOthers
NSString * _Nonnull _LhY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 466);
}
// Channel.AdminLog.CanEditMessages
NSString * _Nonnull _LhZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 467);
}
// Channel.AdminLog.CanInviteUsers
NSString * _Nonnull _Lia(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 468);
}
// Channel.AdminLog.CanInviteUsersViaLink
NSString * _Nonnull _Lib(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 469);
}
// Channel.AdminLog.CanManageCalls
NSString * _Nonnull _Lic(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 470);
}
// Channel.AdminLog.CanPinMessages
NSString * _Nonnull _Lid(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 471);
}
// Channel.AdminLog.CanSendMessages
NSString * _Nonnull _Lie(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 472);
}
// Channel.AdminLog.CaptionEdited
_FormattedString * _Nonnull _Lif(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 473, _0);
}
// Channel.AdminLog.ChangeInfo
NSString * _Nonnull _Lig(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 474);
}
// Channel.AdminLog.ChannelEmptyText
NSString * _Nonnull _Lih(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 475);
}
// Channel.AdminLog.CreatedInviteLink
_FormattedString * _Nonnull _Lii(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 476, _0, _1);
}
// Channel.AdminLog.DefaultRestrictionsUpdated
NSString * _Nonnull _Lij(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 477);
}
// Channel.AdminLog.DeletedInviteLink
_FormattedString * _Nonnull _Lik(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 478, _0, _1);
}
// Channel.AdminLog.DisabledSlowmode
_FormattedString * _Nonnull _Lil(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 479, _0);
}
// Channel.AdminLog.EditedInviteLink
_FormattedString * _Nonnull _Lim(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 480, _0, _1);
}
// Channel.AdminLog.EmptyFilterQueryText
_FormattedString * _Nonnull _Lin(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 481, _0);
}
// Channel.AdminLog.EmptyFilterText
NSString * _Nonnull _Lio(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 482);
}
// Channel.AdminLog.EmptyFilterTitle
NSString * _Nonnull _Lip(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 483);
}
// Channel.AdminLog.EmptyMessageText
NSString * _Nonnull _Liq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 484);
}
// Channel.AdminLog.EmptyText
NSString * _Nonnull _Lir(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 485);
}
// Channel.AdminLog.EmptyTitle
NSString * _Nonnull _Lis(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 486);
}
// Channel.AdminLog.EndedVoiceChat
_FormattedString * _Nonnull _Lit(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 487, _0);
}
// Channel.AdminLog.InfoPanelAlertText
NSString * _Nonnull _Liu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 488);
}
// Channel.AdminLog.InfoPanelAlertTitle
NSString * _Nonnull _Liv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 489);
}
// Channel.AdminLog.InfoPanelChannelAlertText
NSString * _Nonnull _Liw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 490);
}
// Channel.AdminLog.InfoPanelTitle
NSString * _Nonnull _Lix(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 491);
}
// Channel.AdminLog.JoinedViaInviteLink
_FormattedString * _Nonnull _Liy(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 492, _0, _1);
}
// Channel.AdminLog.MessageAddedAdminName
_FormattedString * _Nonnull _Liz(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 493, _0);
}
// Channel.AdminLog.MessageAddedAdminNameUsername
_FormattedString * _Nonnull _LiA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 494, _0, _1);
}
// Channel.AdminLog.MessageAdmin
_FormattedString * _Nonnull _LiB(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 495, _0, _1, _2);
}
// Channel.AdminLog.MessageChangedAutoremoveTimeoutRemove
_FormattedString * _Nonnull _LiC(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 496, _0);
}
// Channel.AdminLog.MessageChangedAutoremoveTimeoutSet
_FormattedString * _Nonnull _LiD(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 497, _0, _1);
}
// Channel.AdminLog.MessageChangedChannelAbout
_FormattedString * _Nonnull _LiE(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 498, _0);
}
// Channel.AdminLog.MessageChangedChannelUsername
_FormattedString * _Nonnull _LiF(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 499, _0);
}
// Channel.AdminLog.MessageChangedGroupAbout
_FormattedString * _Nonnull _LiG(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 500, _0);
}
// Channel.AdminLog.MessageChangedGroupGeoLocation
_FormattedString * _Nonnull _LiH(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 501, _0);
}
// Channel.AdminLog.MessageChangedGroupStickerPack
_FormattedString * _Nonnull _LiI(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 502, _0);
}
// Channel.AdminLog.MessageChangedGroupUsername
_FormattedString * _Nonnull _LiJ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 503, _0);
}
// Channel.AdminLog.MessageChangedLinkedChannel
_FormattedString * _Nonnull _LiK(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 504, _0, _1);
}
// Channel.AdminLog.MessageChangedLinkedGroup
_FormattedString * _Nonnull _LiL(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 505, _0, _1);
}
// Channel.AdminLog.MessageChangedUnlinkedChannel
_FormattedString * _Nonnull _LiM(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 506, _0, _1);
}
// Channel.AdminLog.MessageChangedUnlinkedGroup
_FormattedString * _Nonnull _LiN(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 507, _0, _1);
}
// Channel.AdminLog.MessageDeleted
_FormattedString * _Nonnull _LiO(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 508, _0);
}
// Channel.AdminLog.MessageEdited
_FormattedString * _Nonnull _LiP(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 509, _0);
}
// Channel.AdminLog.MessageGroupPreHistoryHidden
_FormattedString * _Nonnull _LiQ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 510, _0);
}
// Channel.AdminLog.MessageGroupPreHistoryVisible
_FormattedString * _Nonnull _LiR(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 511, _0);
}
// Channel.AdminLog.MessageInvitedName
_FormattedString * _Nonnull _LiS(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 512, _0);
}
// Channel.AdminLog.MessageInvitedNameUsername
_FormattedString * _Nonnull _LiT(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 513, _0, _1);
}
// Channel.AdminLog.MessageKickedName
_FormattedString * _Nonnull _LiU(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 514, _0);
}
// Channel.AdminLog.MessageKickedNameUsername
_FormattedString * _Nonnull _LiV(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 515, _0, _1);
}
// Channel.AdminLog.MessagePinned
_FormattedString * _Nonnull _LiW(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 516, _0);
}
// Channel.AdminLog.MessagePreviousCaption
NSString * _Nonnull _LiX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 517);
}
// Channel.AdminLog.MessagePreviousDescription
NSString * _Nonnull _LiY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 518);
}
// Channel.AdminLog.MessagePreviousLink
NSString * _Nonnull _LiZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 519);
}
// Channel.AdminLog.MessagePreviousMessage
NSString * _Nonnull _Lja(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 520);
}
// Channel.AdminLog.MessagePromotedName
_FormattedString * _Nonnull _Ljb(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 521, _0);
}
// Channel.AdminLog.MessagePromotedNameUsername
_FormattedString * _Nonnull _Ljc(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 522, _0, _1);
}
// Channel.AdminLog.MessageRank
_FormattedString * _Nonnull _Ljd(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 523, _0);
}
// Channel.AdminLog.MessageRankName
_FormattedString * _Nonnull _Lje(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 524, _0, _1);
}
// Channel.AdminLog.MessageRankUsername
_FormattedString * _Nonnull _Ljf(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 525, _0, _1, _2);
}
// Channel.AdminLog.MessageRemovedAdminName
_FormattedString * _Nonnull _Ljg(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 526, _0);
}
// Channel.AdminLog.MessageRemovedAdminNameUsername
_FormattedString * _Nonnull _Ljh(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 527, _0, _1);
}
// Channel.AdminLog.MessageRemovedChannelUsername
_FormattedString * _Nonnull _Lji(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 528, _0);
}
// Channel.AdminLog.MessageRemovedGroupStickerPack
_FormattedString * _Nonnull _Ljj(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 529, _0);
}
// Channel.AdminLog.MessageRemovedGroupUsername
_FormattedString * _Nonnull _Ljk(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 530, _0);
}
// Channel.AdminLog.MessageRestricted
_FormattedString * _Nonnull _Ljl(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 531, _0, _1, _2);
}
// Channel.AdminLog.MessageRestrictedForever
NSString * _Nonnull _Ljm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 532);
}
// Channel.AdminLog.MessageRestrictedName
_FormattedString * _Nonnull _Ljn(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 533, _0);
}
// Channel.AdminLog.MessageRestrictedNameUsername
_FormattedString * _Nonnull _Ljo(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 534, _0, _1);
}
// Channel.AdminLog.MessageRestrictedNewSetting
_FormattedString * _Nonnull _Ljp(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 535, _0);
}
// Channel.AdminLog.MessageRestrictedUntil
_FormattedString * _Nonnull _Ljq(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 536, _0);
}
// Channel.AdminLog.MessageToggleInvitesOff
_FormattedString * _Nonnull _Ljr(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 537, _0);
}
// Channel.AdminLog.MessageToggleInvitesOn
_FormattedString * _Nonnull _Ljs(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 538, _0);
}
// Channel.AdminLog.MessageToggleSignaturesOff
_FormattedString * _Nonnull _Ljt(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 539, _0);
}
// Channel.AdminLog.MessageToggleSignaturesOn
_FormattedString * _Nonnull _Lju(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 540, _0);
}
// Channel.AdminLog.MessageTransferedName
_FormattedString * _Nonnull _Ljv(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 541, _0);
}
// Channel.AdminLog.MessageTransferedNameUsername
_FormattedString * _Nonnull _Ljw(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 542, _0, _1);
}
// Channel.AdminLog.MessageUnkickedName
_FormattedString * _Nonnull _Ljx(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 543, _0);
}
// Channel.AdminLog.MessageUnkickedNameUsername
_FormattedString * _Nonnull _Ljy(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 544, _0, _1);
}
// Channel.AdminLog.MessageUnpinned
_FormattedString * _Nonnull _Ljz(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 545, _0);
}
// Channel.AdminLog.MutedNewMembers
_FormattedString * _Nonnull _LjA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 546, _0);
}
// Channel.AdminLog.MutedParticipant
_FormattedString * _Nonnull _LjB(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 547, _0, _1);
}
// Channel.AdminLog.PinMessages
NSString * _Nonnull _LjC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 548);
}
// Channel.AdminLog.PollStopped
_FormattedString * _Nonnull _LjD(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 549, _0);
}
// Channel.AdminLog.RevokedInviteLink
_FormattedString * _Nonnull _LjE(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 550, _0, _1);
}
// Channel.AdminLog.SendPolls
NSString * _Nonnull _LjF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 551);
}
// Channel.AdminLog.SetSlowmode
_FormattedString * _Nonnull _LjG(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 552, _0, _1);
}
// Channel.AdminLog.StartedVoiceChat
_FormattedString * _Nonnull _LjH(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 553, _0);
}
// Channel.AdminLog.TitleAllEvents
NSString * _Nonnull _LjI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 554);
}
// Channel.AdminLog.TitleSelectedEvents
NSString * _Nonnull _LjJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 555);
}
// Channel.AdminLog.UnmutedMutedParticipant
_FormattedString * _Nonnull _LjK(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 556, _0, _1);
}
// Channel.AdminLog.UpdatedParticipantVolume
_FormattedString * _Nonnull _LjL(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 557, _0, _1, _2);
}
// Channel.AdminLogFilter.AdminsAll
NSString * _Nonnull _LjM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 558);
}
// Channel.AdminLogFilter.AdminsTitle
NSString * _Nonnull _LjN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 559);
}
// Channel.AdminLogFilter.ChannelEventsInfo
NSString * _Nonnull _LjO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 560);
}
// Channel.AdminLogFilter.EventsAdmins
NSString * _Nonnull _LjP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 561);
}
// Channel.AdminLogFilter.EventsAll
NSString * _Nonnull _LjQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 562);
}
// Channel.AdminLogFilter.EventsCalls
NSString * _Nonnull _LjR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 563);
}
// Channel.AdminLogFilter.EventsDeletedMessages
NSString * _Nonnull _LjS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 564);
}
// Channel.AdminLogFilter.EventsEditedMessages
NSString * _Nonnull _LjT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 565);
}
// Channel.AdminLogFilter.EventsInfo
NSString * _Nonnull _LjU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 566);
}
// Channel.AdminLogFilter.EventsInviteLinks
NSString * _Nonnull _LjV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 567);
}
// Channel.AdminLogFilter.EventsLeaving
NSString * _Nonnull _LjW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 568);
}
// Channel.AdminLogFilter.EventsLeavingSubscribers
NSString * _Nonnull _LjX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 569);
}
// Channel.AdminLogFilter.EventsNewMembers
NSString * _Nonnull _LjY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 570);
}
// Channel.AdminLogFilter.EventsNewSubscribers
NSString * _Nonnull _LjZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 571);
}
// Channel.AdminLogFilter.EventsPinned
NSString * _Nonnull _Lka(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 572);
}
// Channel.AdminLogFilter.EventsRestrictions
NSString * _Nonnull _Lkb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 573);
}
// Channel.AdminLogFilter.EventsTitle
NSString * _Nonnull _Lkc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 574);
}
// Channel.AdminLogFilter.Title
NSString * _Nonnull _Lkd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 575);
}
// Channel.BanList.BlockedTitle
NSString * _Nonnull _Lke(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 576);
}
// Channel.BanList.RestrictedTitle
NSString * _Nonnull _Lkf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 577);
}
// Channel.BanUser.BlockFor
NSString * _Nonnull _Lkg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 578);
}
// Channel.BanUser.PermissionAddMembers
NSString * _Nonnull _Lkh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 579);
}
// Channel.BanUser.PermissionChangeGroupInfo
NSString * _Nonnull _Lki(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 580);
}
// Channel.BanUser.PermissionEmbedLinks
NSString * _Nonnull _Lkj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 581);
}
// Channel.BanUser.PermissionReadMessages
NSString * _Nonnull _Lkk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 582);
}
// Channel.BanUser.PermissionSendMedia
NSString * _Nonnull _Lkl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 583);
}
// Channel.BanUser.PermissionSendMessages
NSString * _Nonnull _Lkm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 584);
}
// Channel.BanUser.PermissionSendPolls
NSString * _Nonnull _Lkn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 585);
}
// Channel.BanUser.PermissionSendStickersAndGifs
NSString * _Nonnull _Lko(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 586);
}
// Channel.BanUser.PermissionsHeader
NSString * _Nonnull _Lkp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 587);
}
// Channel.BanUser.Title
NSString * _Nonnull _Lkq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 588);
}
// Channel.BanUser.Unban
NSString * _Nonnull _Lkr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 589);
}
// Channel.BlackList.Title
NSString * _Nonnull _Lks(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 590);
}
// Channel.BotDoesntSupportGroups
NSString * _Nonnull _Lkt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 591);
}
// Channel.CommentsGroup.Header
NSString * _Nonnull _Lku(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 592);
}
// Channel.CommentsGroup.HeaderGroupSet
_FormattedString * _Nonnull _Lkv(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 593, _0);
}
// Channel.CommentsGroup.HeaderSet
_FormattedString * _Nonnull _Lkw(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 594, _0);
}
// Channel.DiscussionGroup
NSString * _Nonnull _Lkx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 595);
}
// Channel.DiscussionGroup.Create
NSString * _Nonnull _Lky(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 596);
}
// Channel.DiscussionGroup.Header
NSString * _Nonnull _Lkz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 597);
}
// Channel.DiscussionGroup.HeaderGroupSet
_FormattedString * _Nonnull _LkA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 598, _0);
}
// Channel.DiscussionGroup.HeaderLabel
NSString * _Nonnull _LkB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 599);
}
// Channel.DiscussionGroup.HeaderSet
_FormattedString * _Nonnull _LkC(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 600, _0);
}
// Channel.DiscussionGroup.Info
NSString * _Nonnull _LkD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 601);
}
// Channel.DiscussionGroup.LinkGroup
NSString * _Nonnull _LkE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 602);
}
// Channel.DiscussionGroup.MakeHistoryPublic
NSString * _Nonnull _LkF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 603);
}
// Channel.DiscussionGroup.MakeHistoryPublicProceed
NSString * _Nonnull _LkG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 604);
}
// Channel.DiscussionGroup.PrivateChannel
NSString * _Nonnull _LkH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 605);
}
// Channel.DiscussionGroup.PrivateChannelLink
_FormattedString * _Nonnull _LkI(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 606, _0, _1);
}
// Channel.DiscussionGroup.PrivateGroup
NSString * _Nonnull _LkJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 607);
}
// Channel.DiscussionGroup.PublicChannelLink
_FormattedString * _Nonnull _LkK(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 608, _0, _1);
}
// Channel.DiscussionGroup.SearchPlaceholder
NSString * _Nonnull _LkL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 609);
}
// Channel.DiscussionGroup.UnlinkChannel
NSString * _Nonnull _LkM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 610);
}
// Channel.DiscussionGroup.UnlinkGroup
NSString * _Nonnull _LkN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 611);
}
// Channel.DiscussionGroupAdd
NSString * _Nonnull _LkO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 612);
}
// Channel.DiscussionGroupInfo
NSString * _Nonnull _LkP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 613);
}
// Channel.DiscussionMessageUnavailable
NSString * _Nonnull _LkQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 614);
}
// Channel.Edit.AboutItem
NSString * _Nonnull _LkR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 615);
}
// Channel.Edit.LinkItem
NSString * _Nonnull _LkS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 616);
}
// Channel.Edit.PrivatePublicLinkAlert
NSString * _Nonnull _LkT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 617);
}
// Channel.EditAdmin.CannotEdit
NSString * _Nonnull _LkU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 618);
}
// Channel.EditAdmin.PermissinAddAdminOff
NSString * _Nonnull _LkV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 619);
}
// Channel.EditAdmin.PermissinAddAdminOn
NSString * _Nonnull _LkW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 620);
}
// Channel.EditAdmin.PermissionAddAdmins
NSString * _Nonnull _LkX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 621);
}
// Channel.EditAdmin.PermissionBanUsers
NSString * _Nonnull _LkY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 622);
}
// Channel.EditAdmin.PermissionChangeInfo
NSString * _Nonnull _LkZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 623);
}
// Channel.EditAdmin.PermissionDeleteMessages
NSString * _Nonnull _Lla(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 624);
}
// Channel.EditAdmin.PermissionDeleteMessagesOfOthers
NSString * _Nonnull _Llb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 625);
}
// Channel.EditAdmin.PermissionEditMessages
NSString * _Nonnull _Llc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 626);
}
// Channel.EditAdmin.PermissionEnabledByDefault
NSString * _Nonnull _Lld(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 627);
}
// Channel.EditAdmin.PermissionInviteMembers
NSString * _Nonnull _Lle(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 628);
}
// Channel.EditAdmin.PermissionInviteSubscribers
NSString * _Nonnull _Llf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 629);
}
// Channel.EditAdmin.PermissionInviteViaLink
NSString * _Nonnull _Llg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 630);
}
// Channel.EditAdmin.PermissionPinMessages
NSString * _Nonnull _Llh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 631);
}
// Channel.EditAdmin.PermissionPostMessages
NSString * _Nonnull _Lli(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 632);
}
// Channel.EditAdmin.PermissionsHeader
NSString * _Nonnull _Llj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 633);
}
// Channel.EditAdmin.TransferOwnership
NSString * _Nonnull _Llk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 634);
}
// Channel.EditMessageErrorGeneric
NSString * _Nonnull _Lll(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 635);
}
// Channel.ErrorAccessDenied
NSString * _Nonnull _Llm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 636);
}
// Channel.ErrorAddBlocked
NSString * _Nonnull _Lln(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 637);
}
// Channel.ErrorAddTooMuch
NSString * _Nonnull _Llo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 638);
}
// Channel.ErrorAdminsTooMuch
NSString * _Nonnull _Llp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 639);
}
// Channel.Info.Banned
NSString * _Nonnull _Llq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 640);
}
// Channel.Info.BlackList
NSString * _Nonnull _Llr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 641);
}
// Channel.Info.Description
NSString * _Nonnull _Lls(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 642);
}
// Channel.Info.Management
NSString * _Nonnull _Llt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 643);
}
// Channel.Info.Members
NSString * _Nonnull _Llu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 644);
}
// Channel.Info.Stickers
NSString * _Nonnull _Llv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 645);
}
// Channel.Info.Subscribers
NSString * _Nonnull _Llw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 646);
}
// Channel.JoinChannel
NSString * _Nonnull _Llx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 647);
}
// Channel.LeaveChannel
NSString * _Nonnull _Lly(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 648);
}
// Channel.LinkItem
NSString * _Nonnull _Llz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 649);
}
// Channel.Management.AddModerator
NSString * _Nonnull _LlA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 650);
}
// Channel.Management.AddModeratorHelp
NSString * _Nonnull _LlB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 651);
}
// Channel.Management.ErrorNotMember
_FormattedString * _Nonnull _LlC(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 652, _0);
}
// Channel.Management.LabelAdministrator
NSString * _Nonnull _LlD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 653);
}
// Channel.Management.LabelCreator
NSString * _Nonnull _LlE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 654);
}
// Channel.Management.LabelEditor
NSString * _Nonnull _LlF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 655);
}
// Channel.Management.LabelOwner
NSString * _Nonnull _LlG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 656);
}
// Channel.Management.PromotedBy
_FormattedString * _Nonnull _LlH(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 657, _0);
}
// Channel.Management.RemovedBy
_FormattedString * _Nonnull _LlI(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 658, _0);
}
// Channel.Management.RestrictedBy
_FormattedString * _Nonnull _LlJ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 659, _0);
}
// Channel.Management.Title
NSString * _Nonnull _LlK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 660);
}
// Channel.Members.AddAdminErrorBlacklisted
NSString * _Nonnull _LlL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 661);
}
// Channel.Members.AddAdminErrorNotAMember
NSString * _Nonnull _LlM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 662);
}
// Channel.Members.AddBannedErrorAdmin
NSString * _Nonnull _LlN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 663);
}
// Channel.Members.AddMembers
NSString * _Nonnull _LlO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 664);
}
// Channel.Members.AddMembersHelp
NSString * _Nonnull _LlP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 665);
}
// Channel.Members.InviteLink
NSString * _Nonnull _LlQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 666);
}
// Channel.Members.Title
NSString * _Nonnull _LlR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 667);
}
// Channel.MessagePhotoRemoved
NSString * _Nonnull _LlS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 668);
}
// Channel.MessagePhotoUpdated
NSString * _Nonnull _LlT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 669);
}
// Channel.MessageTitleUpdated
_FormattedString * _Nonnull _LlU(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 670, _0);
}
// Channel.MessageVideoUpdated
NSString * _Nonnull _LlV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 671);
}
// Channel.Moderator.AccessLevelRevoke
NSString * _Nonnull _LlW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 672);
}
// Channel.Moderator.Title
NSString * _Nonnull _LlX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 673);
}
// Channel.NotificationLoading
NSString * _Nonnull _LlY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 674);
}
// Channel.OwnershipTransfer.ChangeOwner
NSString * _Nonnull _LlZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 675);
}
// Channel.OwnershipTransfer.DescriptionInfo
_FormattedString * _Nonnull _Lma(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 676, _0, _1);
}
// Channel.OwnershipTransfer.EnterPassword
NSString * _Nonnull _Lmb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 677);
}
// Channel.OwnershipTransfer.EnterPasswordText
NSString * _Nonnull _Lmc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 678);
}
// Channel.OwnershipTransfer.ErrorAdminsTooMuch
NSString * _Nonnull _Lmd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 679);
}
// Channel.OwnershipTransfer.ErrorPrivacyRestricted
NSString * _Nonnull _Lme(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 680);
}
// Channel.OwnershipTransfer.ErrorPublicChannelsTooMuch
NSString * _Nonnull _Lmf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 681);
}
// Channel.OwnershipTransfer.PasswordPlaceholder
NSString * _Nonnull _Lmg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 682);
}
// Channel.OwnershipTransfer.Title
NSString * _Nonnull _Lmh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 683);
}
// Channel.OwnershipTransfer.TransferCompleted
_FormattedString * _Nonnull _Lmi(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 684, _0, _1);
}
// Channel.Setup.LinkTypePrivate
NSString * _Nonnull _Lmj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 685);
}
// Channel.Setup.LinkTypePublic
NSString * _Nonnull _Lmk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 686);
}
// Channel.Setup.PublicNoLink
NSString * _Nonnull _Lml(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 687);
}
// Channel.Setup.Title
NSString * _Nonnull _Lmm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 688);
}
// Channel.Setup.TypeHeader
NSString * _Nonnull _Lmn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 689);
}
// Channel.Setup.TypePrivate
NSString * _Nonnull _Lmo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 690);
}
// Channel.Setup.TypePrivateHelp
NSString * _Nonnull _Lmp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 691);
}
// Channel.Setup.TypePublic
NSString * _Nonnull _Lmq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 692);
}
// Channel.Setup.TypePublicHelp
NSString * _Nonnull _Lmr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 693);
}
// Channel.SignMessages
NSString * _Nonnull _Lms(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 694);
}
// Channel.SignMessages.Help
NSString * _Nonnull _Lmt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 695);
}
// Channel.Status
NSString * _Nonnull _Lmu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 696);
}
// Channel.Stickers.CreateYourOwn
NSString * _Nonnull _Lmv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 697);
}
// Channel.Stickers.NotFound
NSString * _Nonnull _Lmw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 698);
}
// Channel.Stickers.NotFoundHelp
NSString * _Nonnull _Lmx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 699);
}
// Channel.Stickers.Placeholder
NSString * _Nonnull _Lmy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 700);
}
// Channel.Stickers.Searching
NSString * _Nonnull _Lmz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 701);
}
// Channel.Stickers.YourStickers
NSString * _Nonnull _LmA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 702);
}
// Channel.Subscribers.Title
NSString * _Nonnull _LmB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 703);
}
// Channel.TitleInfo
NSString * _Nonnull _LmC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 704);
}
// Channel.TooMuchBots
NSString * _Nonnull _LmD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 705);
}
// Channel.TypeSetup.Title
NSString * _Nonnull _LmE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 706);
}
// Channel.UpdatePhotoItem
NSString * _Nonnull _LmF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 707);
}
// Channel.Username.CheckingUsername
NSString * _Nonnull _LmG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 708);
}
// Channel.Username.CreatePrivateLinkHelp
NSString * _Nonnull _LmH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 709);
}
// Channel.Username.CreatePublicLinkHelp
NSString * _Nonnull _LmI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 710);
}
// Channel.Username.Help
NSString * _Nonnull _LmJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 711);
}
// Channel.Username.InvalidCharacters
NSString * _Nonnull _LmK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 712);
}
// Channel.Username.InvalidStartsWithNumber
NSString * _Nonnull _LmL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 713);
}
// Channel.Username.InvalidTaken
NSString * _Nonnull _LmM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 714);
}
// Channel.Username.InvalidTooShort
NSString * _Nonnull _LmN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 715);
}
// Channel.Username.LinkHint
_FormattedString * _Nonnull _LmO(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 716, _0);
}
// Channel.Username.RevokeExistingUsernamesInfo
NSString * _Nonnull _LmP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 717);
}
// Channel.Username.Title
NSString * _Nonnull _LmQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 718);
}
// Channel.Username.UsernameIsAvailable
_FormattedString * _Nonnull _LmR(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 719, _0);
}
// ChannelInfo.AddParticipantConfirmation
_FormattedString * _Nonnull _LmS(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 720, _0);
}
// ChannelInfo.ChannelForbidden
_FormattedString * _Nonnull _LmT(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 721, _0);
}
// ChannelInfo.ConfirmLeave
NSString * _Nonnull _LmU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 722);
}
// ChannelInfo.CreateVoiceChat
NSString * _Nonnull _LmV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 723);
}
// ChannelInfo.DeleteChannel
NSString * _Nonnull _LmW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 724);
}
// ChannelInfo.DeleteChannelConfirmation
NSString * _Nonnull _LmX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 725);
}
// ChannelInfo.DeleteGroup
NSString * _Nonnull _LmY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 726);
}
// ChannelInfo.DeleteGroupConfirmation
NSString * _Nonnull _LmZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 727);
}
// ChannelInfo.FakeChannelWarning
NSString * _Nonnull _Lna(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 728);
}
// ChannelInfo.InviteLink.RevokeAlert.Text
NSString * _Nonnull _Lnb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 729);
}
// ChannelInfo.ScamChannelWarning
NSString * _Nonnull _Lnc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 730);
}
// ChannelInfo.ScheduleVoiceChat
NSString * _Nonnull _Lnd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 731);
}
// ChannelInfo.Stats
NSString * _Nonnull _Lne(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 732);
}
// ChannelIntro.CreateChannel
NSString * _Nonnull _Lnf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 733);
}
// ChannelIntro.Text
NSString * _Nonnull _Lng(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 734);
}
// ChannelIntro.Title
NSString * _Nonnull _Lnh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 735);
}
// ChannelMembers.ChannelAdminsTitle
NSString * _Nonnull _Lni(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 736);
}
// ChannelMembers.GroupAdminsTitle
NSString * _Nonnull _Lnj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 737);
}
// ChannelMembers.WhoCanAddMembers
NSString * _Nonnull _Lnk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 738);
}
// ChannelMembers.WhoCanAddMembers.Admins
NSString * _Nonnull _Lnl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 739);
}
// ChannelMembers.WhoCanAddMembers.AllMembers
NSString * _Nonnull _Lnm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 740);
}
// ChannelMembers.WhoCanAddMembersAdminsHelp
NSString * _Nonnull _Lnn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 741);
}
// ChannelMembers.WhoCanAddMembersAllHelp
NSString * _Nonnull _Lno(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 742);
}
// ChannelRemoved.RemoveInfo
NSString * _Nonnull _Lnp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 743);
}
// Chat.AttachmentLimitReached
NSString * _Nonnull _Lnq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 744);
}
// Chat.AttachmentMultipleFilesDisabled
NSString * _Nonnull _Lnr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 745);
}
// Chat.AttachmentMultipleForwardDisabled
NSString * _Nonnull _Lns(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 746);
}
// Chat.DeleteMessagesConfirmation
NSString * _Nonnull _Lnt(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 747, value);
}
// Chat.GenericPsaTooltip
NSString * _Nonnull _Lnu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 748);
}
// Chat.Gifs.SavedSectionHeader
NSString * _Nonnull _Lnv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 749);
}
// Chat.Gifs.TrendingSectionHeader
NSString * _Nonnull _Lnw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 750);
}
// Chat.MessagesUnpinned
NSString * _Nonnull _Lnx(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 751, value);
}
// Chat.MultipleTextMessagesDisabled
NSString * _Nonnull _Lny(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 752);
}
// Chat.PanelHidePinnedMessages
NSString * _Nonnull _Lnz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 753);
}
// Chat.PanelUnpinAllMessages
NSString * _Nonnull _LnA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 754);
}
// Chat.PinnedListPreview.HidePinnedMessages
NSString * _Nonnull _LnB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 755);
}
// Chat.PinnedListPreview.ShowAllMessages
NSString * _Nonnull _LnC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 756);
}
// Chat.PinnedListPreview.UnpinAllMessages
NSString * _Nonnull _LnD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 757);
}
// Chat.PinnedMessagesHiddenText
NSString * _Nonnull _LnE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 758);
}
// Chat.PinnedMessagesHiddenTitle
NSString * _Nonnull _LnF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 759);
}
// Chat.PsaTooltip.covid
NSString * _Nonnull _LnG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 760);
}
// Chat.SlowmodeAttachmentLimitReached
NSString * _Nonnull _LnH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 761);
}
// Chat.SlowmodeSendError
NSString * _Nonnull _LnI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 762);
}
// Chat.SlowmodeTooltip
_FormattedString * _Nonnull _LnJ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 763, _0);
}
// Chat.SlowmodeTooltipPending
NSString * _Nonnull _LnK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 764);
}
// Chat.TitlePinnedMessages
NSString * _Nonnull _LnL(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 765, value);
}
// Chat.UnsendMyMessages
NSString * _Nonnull _LnM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 766);
}
// Chat.UnsendMyMessagesAlertTitle
_FormattedString * _Nonnull _LnN(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 767, _0);
}
// ChatAdmins.AdminLabel
NSString * _Nonnull _LnO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 768);
}
// ChatAdmins.AllMembersAreAdmins
NSString * _Nonnull _LnP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 769);
}
// ChatAdmins.AllMembersAreAdminsOffHelp
NSString * _Nonnull _LnQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 770);
}
// ChatAdmins.AllMembersAreAdminsOnHelp
NSString * _Nonnull _LnR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 771);
}
// ChatAdmins.Title
NSString * _Nonnull _LnS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 772);
}
// ChatContextMenu.TextSelectionTip
NSString * _Nonnull _LnT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 773);
}
// ChatImport.CreateGroupAlertImportAction
NSString * _Nonnull _LnU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 774);
}
// ChatImport.CreateGroupAlertText
_FormattedString * _Nonnull _LnV(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 775, _0);
}
// ChatImport.CreateGroupAlertTitle
NSString * _Nonnull _LnW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 776);
}
// ChatImport.SelectionConfirmationAlertImportAction
NSString * _Nonnull _LnX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 777);
}
// ChatImport.SelectionConfirmationAlertTitle
NSString * _Nonnull _LnY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 778);
}
// ChatImport.SelectionConfirmationGroupWithTitle
_FormattedString * _Nonnull _LnZ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 779, _0, _1);
}
// ChatImport.SelectionConfirmationGroupWithoutTitle
_FormattedString * _Nonnull _Loa(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 780, _0);
}
// ChatImport.SelectionConfirmationUserWithTitle
_FormattedString * _Nonnull _Lob(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 781, _0, _1);
}
// ChatImport.SelectionConfirmationUserWithoutTitle
_FormattedString * _Nonnull _Loc(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 782, _0);
}
// ChatImport.SelectionErrorGroupGeneric
NSString * _Nonnull _Lod(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 783);
}
// ChatImport.SelectionErrorNotAdmin
NSString * _Nonnull _Loe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 784);
}
// ChatImport.Title
NSString * _Nonnull _Lof(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 785);
}
// ChatImport.UserErrorNotMutual
NSString * _Nonnull _Log(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 786);
}
// ChatImportActivity.ErrorGeneric
NSString * _Nonnull _Loh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 787);
}
// ChatImportActivity.ErrorInvalidChatType
NSString * _Nonnull _Loi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 788);
}
// ChatImportActivity.ErrorLimitExceeded
NSString * _Nonnull _Loj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 789);
}
// ChatImportActivity.ErrorNotAdmin
NSString * _Nonnull _Lok(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 790);
}
// ChatImportActivity.ErrorUserBlocked
NSString * _Nonnull _Lol(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 791);
}
// ChatImportActivity.InProgress
NSString * _Nonnull _Lom(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 792);
}
// ChatImportActivity.OpenApp
NSString * _Nonnull _Lon(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 793);
}
// ChatImportActivity.Retry
NSString * _Nonnull _Loo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 794);
}
// ChatImportActivity.Success
NSString * _Nonnull _Lop(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 795);
}
// ChatImportActivity.Title
NSString * _Nonnull _Loq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 796);
}
// ChatList.AddChatsToFolder
NSString * _Nonnull _Lor(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 797);
}
// ChatList.AddFolder
NSString * _Nonnull _Los(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 798);
}
// ChatList.AddedToFolderTooltip
_FormattedString * _Nonnull _Lot(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 799, _0, _1);
}
// ChatList.ArchiveAction
NSString * _Nonnull _Lou(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 800);
}
// ChatList.ArchivedChatsTitle
NSString * _Nonnull _Lov(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 801);
}
// ChatList.AutoarchiveSuggestion.OpenSettings
NSString * _Nonnull _Low(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 802);
}
// ChatList.AutoarchiveSuggestion.Text
NSString * _Nonnull _Lox(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 803);
}
// ChatList.AutoarchiveSuggestion.Title
NSString * _Nonnull _Loy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 804);
}
// ChatList.ChatTypesSection
NSString * _Nonnull _Loz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 805);
}
// ChatList.ClearChatConfirmation
_FormattedString * _Nonnull _LoA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 806, _0);
}
// ChatList.Context.AddToContacts
NSString * _Nonnull _LoB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 807);
}
// ChatList.Context.AddToFolder
NSString * _Nonnull _LoC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 808);
}
// ChatList.Context.Archive
NSString * _Nonnull _LoD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 809);
}
// ChatList.Context.Back
NSString * _Nonnull _LoE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 810);
}
// ChatList.Context.Delete
NSString * _Nonnull _LoF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 811);
}
// ChatList.Context.HideArchive
NSString * _Nonnull _LoG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 812);
}
// ChatList.Context.JoinChannel
NSString * _Nonnull _LoH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 813);
}
// ChatList.Context.MarkAllAsRead
NSString * _Nonnull _LoI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 814);
}
// ChatList.Context.MarkAsRead
NSString * _Nonnull _LoJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 815);
}
// ChatList.Context.MarkAsUnread
NSString * _Nonnull _LoK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 816);
}
// ChatList.Context.Mute
NSString * _Nonnull _LoL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 817);
}
// ChatList.Context.Pin
NSString * _Nonnull _LoM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 818);
}
// ChatList.Context.RemoveFromFolder
NSString * _Nonnull _LoN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 819);
}
// ChatList.Context.RemoveFromRecents
NSString * _Nonnull _LoO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 820);
}
// ChatList.Context.Unarchive
NSString * _Nonnull _LoP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 821);
}
// ChatList.Context.UnhideArchive
NSString * _Nonnull _LoQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 822);
}
// ChatList.Context.Unmute
NSString * _Nonnull _LoR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 823);
}
// ChatList.Context.Unpin
NSString * _Nonnull _LoS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 824);
}
// ChatList.DeleteAndLeaveGroupConfirmation
_FormattedString * _Nonnull _LoT(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 825, _0);
}
// ChatList.DeleteChat
NSString * _Nonnull _LoU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 826);
}
// ChatList.DeleteChatConfirmation
_FormattedString * _Nonnull _LoV(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 827, _0);
}
// ChatList.DeleteConfirmation
NSString * _Nonnull _LoW(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 828, value);
}
// ChatList.DeleteForAllMembers
NSString * _Nonnull _LoX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 829);
}
// ChatList.DeleteForAllMembersConfirmationText
NSString * _Nonnull _LoY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 830);
}
// ChatList.DeleteForAllSubscribers
NSString * _Nonnull _LoZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 831);
}
// ChatList.DeleteForAllSubscribersConfirmationText
NSString * _Nonnull _Lpa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 832);
}
// ChatList.DeleteForCurrentUser
NSString * _Nonnull _Lpb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 833);
}
// ChatList.DeleteForEveryone
_FormattedString * _Nonnull _Lpc(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 834, _0);
}
// ChatList.DeleteForEveryoneConfirmationAction
NSString * _Nonnull _Lpd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 835);
}
// ChatList.DeleteForEveryoneConfirmationText
NSString * _Nonnull _Lpe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 836);
}
// ChatList.DeleteForEveryoneConfirmationTitle
NSString * _Nonnull _Lpf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 837);
}
// ChatList.DeleteSavedMessagesConfirmation
NSString * _Nonnull _Lpg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 838);
}
// ChatList.DeleteSavedMessagesConfirmationAction
NSString * _Nonnull _Lph(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 839);
}
// ChatList.DeleteSavedMessagesConfirmationText
NSString * _Nonnull _Lpi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 840);
}
// ChatList.DeleteSavedMessagesConfirmationTitle
NSString * _Nonnull _Lpj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 841);
}
// ChatList.DeleteSecretChatConfirmation
_FormattedString * _Nonnull _Lpk(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 842, _0);
}
// ChatList.DeletedChats
NSString * _Nonnull _Lpl(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 843, value);
}
// ChatList.EditFolder
NSString * _Nonnull _Lpm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 844);
}
// ChatList.EditFolders
NSString * _Nonnull _Lpn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 845);
}
// ChatList.EmptyChatList
NSString * _Nonnull _Lpo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 846);
}
// ChatList.EmptyChatListEditFilter
NSString * _Nonnull _Lpp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 847);
}
// ChatList.EmptyChatListFilterText
NSString * _Nonnull _Lpq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 848);
}
// ChatList.EmptyChatListFilterTitle
NSString * _Nonnull _Lpr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 849);
}
// ChatList.EmptyChatListNewMessage
NSString * _Nonnull _Lps(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 850);
}
// ChatList.FolderAllChats
NSString * _Nonnull _Lpt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 851);
}
// ChatList.GenericPsaAlert
NSString * _Nonnull _Lpu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 852);
}
// ChatList.GenericPsaLabel
NSString * _Nonnull _Lpv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 853);
}
// ChatList.HeaderImportIntoAnExistingGroup
NSString * _Nonnull _Lpw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 854);
}
// ChatList.HideAction
NSString * _Nonnull _Lpx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 855);
}
// ChatList.LeaveGroupConfirmation
_FormattedString * _Nonnull _Lpy(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 856, _0);
}
// ChatList.MessageFiles
NSString * _Nonnull _Lpz(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 857, value);
}
// ChatList.MessageMusic
NSString * _Nonnull _LpA(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 858, value);
}
// ChatList.MessagePhotos
NSString * _Nonnull _LpB(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 859, value);
}
// ChatList.MessageVideos
NSString * _Nonnull _LpC(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 860, value);
}
// ChatList.Mute
NSString * _Nonnull _LpD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 861);
}
// ChatList.PeerTypeBot
NSString * _Nonnull _LpE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 862);
}
// ChatList.PeerTypeChannel
NSString * _Nonnull _LpF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 863);
}
// ChatList.PeerTypeContact
NSString * _Nonnull _LpG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 864);
}
// ChatList.PeerTypeGroup
NSString * _Nonnull _LpH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 865);
}
// ChatList.PeerTypeNonContact
NSString * _Nonnull _LpI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 866);
}
// ChatList.PsaAlert.covid
NSString * _Nonnull _LpJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 867);
}
// ChatList.PsaLabel.covid
NSString * _Nonnull _LpK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 868);
}
// ChatList.Read
NSString * _Nonnull _LpL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 869);
}
// ChatList.ReadAll
NSString * _Nonnull _LpM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 870);
}
// ChatList.RemoveFolder
NSString * _Nonnull _LpN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 871);
}
// ChatList.RemoveFolderAction
NSString * _Nonnull _LpO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 872);
}
// ChatList.RemoveFolderConfirmation
NSString * _Nonnull _LpP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 873);
}
// ChatList.RemovedFromFolderTooltip
_FormattedString * _Nonnull _LpQ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 874, _0, _1);
}
// ChatList.ReorderTabs
NSString * _Nonnull _LpR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 875);
}
// ChatList.Search.FilterChats
NSString * _Nonnull _LpS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 876);
}
// ChatList.Search.FilterFiles
NSString * _Nonnull _LpT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 877);
}
// ChatList.Search.FilterLinks
NSString * _Nonnull _LpU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 878);
}
// ChatList.Search.FilterMedia
NSString * _Nonnull _LpV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 879);
}
// ChatList.Search.FilterMusic
NSString * _Nonnull _LpW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 880);
}
// ChatList.Search.FilterVoice
NSString * _Nonnull _LpX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 881);
}
// ChatList.Search.Messages
NSString * _Nonnull _LpY(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 882, value);
}
// ChatList.Search.NoResults
NSString * _Nonnull _LpZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 883);
}
// ChatList.Search.NoResultsDescription
NSString * _Nonnull _Lqa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 884);
}
// ChatList.Search.NoResultsFilter
NSString * _Nonnull _Lqb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 885);
}
// ChatList.Search.NoResultsFitlerFiles
NSString * _Nonnull _Lqc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 886);
}
// ChatList.Search.NoResultsFitlerLinks
NSString * _Nonnull _Lqd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 887);
}
// ChatList.Search.NoResultsFitlerMedia
NSString * _Nonnull _Lqe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 888);
}
// ChatList.Search.NoResultsFitlerMusic
NSString * _Nonnull _Lqf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 889);
}
// ChatList.Search.NoResultsFitlerVoice
NSString * _Nonnull _Lqg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 890);
}
// ChatList.Search.NoResultsQueryDescription
_FormattedString * _Nonnull _Lqh(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 891, _0);
}
// ChatList.Search.ShowLess
NSString * _Nonnull _Lqi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 892);
}
// ChatList.Search.ShowMore
NSString * _Nonnull _Lqj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 893);
}
// ChatList.SelectedChats
NSString * _Nonnull _Lqk(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 894, value);
}
// ChatList.TabIconFoldersTooltipEmptyFolders
NSString * _Nonnull _Lql(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 895);
}
// ChatList.TabIconFoldersTooltipNonEmptyFolders
NSString * _Nonnull _Lqm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 896);
}
// ChatList.Tabs.All
NSString * _Nonnull _Lqn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 897);
}
// ChatList.Tabs.AllChats
NSString * _Nonnull _Lqo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 898);
}
// ChatList.UnarchiveAction
NSString * _Nonnull _Lqp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 899);
}
// ChatList.UndoArchiveHiddenText
NSString * _Nonnull _Lqq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 900);
}
// ChatList.UndoArchiveHiddenTitle
NSString * _Nonnull _Lqr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 901);
}
// ChatList.UndoArchiveMultipleTitle
NSString * _Nonnull _Lqs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 902);
}
// ChatList.UndoArchiveRevealedText
NSString * _Nonnull _Lqt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 903);
}
// ChatList.UndoArchiveRevealedTitle
NSString * _Nonnull _Lqu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 904);
}
// ChatList.UndoArchiveText1
NSString * _Nonnull _Lqv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 905);
}
// ChatList.UndoArchiveTitle
NSString * _Nonnull _Lqw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 906);
}
// ChatList.UnhideAction
NSString * _Nonnull _Lqx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 907);
}
// ChatList.Unmute
NSString * _Nonnull _Lqy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 908);
}
// ChatListFilter.AddChatsTitle
NSString * _Nonnull _Lqz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 909);
}
// ChatListFilter.ShowMoreChats
NSString * _Nonnull _LqA(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 910, value);
}
// ChatListFolder.AddChats
NSString * _Nonnull _LqB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 911);
}
// ChatListFolder.CategoryArchived
NSString * _Nonnull _LqC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 912);
}
// ChatListFolder.CategoryBots
NSString * _Nonnull _LqD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 913);
}
// ChatListFolder.CategoryChannels
NSString * _Nonnull _LqE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 914);
}
// ChatListFolder.CategoryContacts
NSString * _Nonnull _LqF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 915);
}
// ChatListFolder.CategoryGroups
NSString * _Nonnull _LqG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 916);
}
// ChatListFolder.CategoryMuted
NSString * _Nonnull _LqH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 917);
}
// ChatListFolder.CategoryNonContacts
NSString * _Nonnull _LqI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 918);
}
// ChatListFolder.CategoryRead
NSString * _Nonnull _LqJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 919);
}
// ChatListFolder.DiscardCancel
NSString * _Nonnull _LqK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 920);
}
// ChatListFolder.DiscardConfirmation
NSString * _Nonnull _LqL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 921);
}
// ChatListFolder.DiscardDiscard
NSString * _Nonnull _LqM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 922);
}
// ChatListFolder.ExcludeChatsTitle
NSString * _Nonnull _LqN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 923);
}
// ChatListFolder.ExcludeSectionInfo
NSString * _Nonnull _LqO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 924);
}
// ChatListFolder.ExcludedSectionHeader
NSString * _Nonnull _LqP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 925);
}
// ChatListFolder.IncludeChatsTitle
NSString * _Nonnull _LqQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 926);
}
// ChatListFolder.IncludeSectionInfo
NSString * _Nonnull _LqR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 927);
}
// ChatListFolder.IncludedSectionHeader
NSString * _Nonnull _LqS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 928);
}
// ChatListFolder.NameBots
NSString * _Nonnull _LqT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 929);
}
// ChatListFolder.NameChannels
NSString * _Nonnull _LqU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 930);
}
// ChatListFolder.NameContacts
NSString * _Nonnull _LqV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 931);
}
// ChatListFolder.NameGroups
NSString * _Nonnull _LqW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 932);
}
// ChatListFolder.NameNonContacts
NSString * _Nonnull _LqX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 933);
}
// ChatListFolder.NameNonMuted
NSString * _Nonnull _LqY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 934);
}
// ChatListFolder.NamePlaceholder
NSString * _Nonnull _LqZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 935);
}
// ChatListFolder.NameSectionHeader
NSString * _Nonnull _Lra(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 936);
}
// ChatListFolder.NameUnread
NSString * _Nonnull _Lrb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 937);
}
// ChatListFolder.TitleCreate
NSString * _Nonnull _Lrc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 938);
}
// ChatListFolder.TitleEdit
NSString * _Nonnull _Lrd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 939);
}
// ChatListFolderSettings.AddRecommended
NSString * _Nonnull _Lre(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 940);
}
// ChatListFolderSettings.EditFoldersInfo
NSString * _Nonnull _Lrf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 941);
}
// ChatListFolderSettings.FoldersSection
NSString * _Nonnull _Lrg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 942);
}
// ChatListFolderSettings.Info
NSString * _Nonnull _Lrh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 943);
}
// ChatListFolderSettings.NewFolder
NSString * _Nonnull _Lri(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 944);
}
// ChatListFolderSettings.RecommendedFoldersSection
NSString * _Nonnull _Lrj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 945);
}
// ChatListFolderSettings.RecommendedNewFolder
NSString * _Nonnull _Lrk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 946);
}
// ChatListFolderSettings.Title
NSString * _Nonnull _Lrl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 947);
}
// ChatSearch.ResultsTooltip
NSString * _Nonnull _Lrm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 948);
}
// ChatSearch.SearchPlaceholder
NSString * _Nonnull _Lrn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 949);
}
// ChatSettings.Appearance
NSString * _Nonnull _Lro(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 950);
}
// ChatSettings.AutoDownloadDocuments
NSString * _Nonnull _Lrp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 951);
}
// ChatSettings.AutoDownloadEnabled
NSString * _Nonnull _Lrq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 952);
}
// ChatSettings.AutoDownloadPhotos
NSString * _Nonnull _Lrr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 953);
}
// ChatSettings.AutoDownloadReset
NSString * _Nonnull _Lrs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 954);
}
// ChatSettings.AutoDownloadSettings.Delimeter
NSString * _Nonnull _Lrt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 955);
}
// ChatSettings.AutoDownloadSettings.OffForAll
NSString * _Nonnull _Lru(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 956);
}
// ChatSettings.AutoDownloadSettings.TypeFile
_FormattedString * _Nonnull _Lrv(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 957, _0);
}
// ChatSettings.AutoDownloadSettings.TypePhoto
NSString * _Nonnull _Lrw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 958);
}
// ChatSettings.AutoDownloadSettings.TypeVideo
_FormattedString * _Nonnull _Lrx(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 959, _0);
}
// ChatSettings.AutoDownloadTitle
NSString * _Nonnull _Lry(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 960);
}
// ChatSettings.AutoDownloadUsingCellular
NSString * _Nonnull _Lrz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 961);
}
// ChatSettings.AutoDownloadUsingWiFi
NSString * _Nonnull _LrA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 962);
}
// ChatSettings.AutoDownloadVideoMessages
NSString * _Nonnull _LrB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 963);
}
// ChatSettings.AutoDownloadVideos
NSString * _Nonnull _LrC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 964);
}
// ChatSettings.AutoDownloadVoiceMessages
NSString * _Nonnull _LrD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 965);
}
// ChatSettings.AutoPlayAnimations
NSString * _Nonnull _LrE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 966);
}
// ChatSettings.AutoPlayGifs
NSString * _Nonnull _LrF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 967);
}
// ChatSettings.AutoPlayTitle
NSString * _Nonnull _LrG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 968);
}
// ChatSettings.AutoPlayVideos
NSString * _Nonnull _LrH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 969);
}
// ChatSettings.AutomaticAudioDownload
NSString * _Nonnull _LrI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 970);
}
// ChatSettings.AutomaticPhotoDownload
NSString * _Nonnull _LrJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 971);
}
// ChatSettings.AutomaticVideoMessageDownload
NSString * _Nonnull _LrK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 972);
}
// ChatSettings.Cache
NSString * _Nonnull _LrL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 973);
}
// ChatSettings.ConnectionType.Title
NSString * _Nonnull _LrM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 974);
}
// ChatSettings.ConnectionType.UseProxy
NSString * _Nonnull _LrN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 975);
}
// ChatSettings.ConnectionType.UseSocks5
NSString * _Nonnull _LrO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 976);
}
// ChatSettings.DownloadInBackground
NSString * _Nonnull _LrP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 977);
}
// ChatSettings.DownloadInBackgroundInfo
NSString * _Nonnull _LrQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 978);
}
// ChatSettings.Groups
NSString * _Nonnull _LrR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 979);
}
// ChatSettings.IntentsSettings
NSString * _Nonnull _LrS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 980);
}
// ChatSettings.OpenLinksIn
NSString * _Nonnull _LrT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 981);
}
// ChatSettings.Other
NSString * _Nonnull _LrU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 982);
}
// ChatSettings.PrivateChats
NSString * _Nonnull _LrV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 983);
}
// ChatSettings.Stickers
NSString * _Nonnull _LrW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 984);
}
// ChatSettings.TextSize
NSString * _Nonnull _LrX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 985);
}
// ChatSettings.TextSizeUnits
NSString * _Nonnull _LrY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 986);
}
// ChatSettings.Title
NSString * _Nonnull _LrZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 987);
}
// ChatSettings.WidgetSettings
NSString * _Nonnull _Lsa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 988);
}
// ChatState.Connecting
NSString * _Nonnull _Lsb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 989);
}
// ChatState.ConnectingToProxy
NSString * _Nonnull _Lsc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 990);
}
// ChatState.Updating
NSString * _Nonnull _Lsd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 991);
}
// ChatState.WaitingForNetwork
NSString * _Nonnull _Lse(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 992);
}
// Checkout.Email
NSString * _Nonnull _Lsf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 993);
}
// Checkout.EnterPassword
NSString * _Nonnull _Lsg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 994);
}
// Checkout.ErrorGeneric
NSString * _Nonnull _Lsh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 995);
}
// Checkout.ErrorInvoiceAlreadyPaid
NSString * _Nonnull _Lsi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 996);
}
// Checkout.ErrorPaymentFailed
NSString * _Nonnull _Lsj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 997);
}
// Checkout.ErrorPrecheckoutFailed
NSString * _Nonnull _Lsk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 998);
}
// Checkout.ErrorProviderAccountInvalid
NSString * _Nonnull _Lsl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 999);
}
// Checkout.ErrorProviderAccountTimeout
NSString * _Nonnull _Lsm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1000);
}
// Checkout.LiabilityAlertTitle
NSString * _Nonnull _Lsn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1001);
}
// Checkout.Name
NSString * _Nonnull _Lso(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1002);
}
// Checkout.NewCard.CardholderNamePlaceholder
NSString * _Nonnull _Lsp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1003);
}
// Checkout.NewCard.CardholderNameTitle
NSString * _Nonnull _Lsq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1004);
}
// Checkout.NewCard.PaymentCard
NSString * _Nonnull _Lsr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1005);
}
// Checkout.NewCard.PostcodePlaceholder
NSString * _Nonnull _Lss(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1006);
}
// Checkout.NewCard.PostcodeTitle
NSString * _Nonnull _Lst(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1007);
}
// Checkout.NewCard.SaveInfo
NSString * _Nonnull _Lsu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1008);
}
// Checkout.NewCard.SaveInfoEnableHelp
NSString * _Nonnull _Lsv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1009);
}
// Checkout.NewCard.SaveInfoHelp
NSString * _Nonnull _Lsw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1010);
}
// Checkout.NewCard.Title
NSString * _Nonnull _Lsx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1011);
}
// Checkout.OptionalTipItem
NSString * _Nonnull _Lsy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1012);
}
// Checkout.OptionalTipItemPlaceholder
NSString * _Nonnull _Lsz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1013);
}
// Checkout.PasswordEntry.Pay
NSString * _Nonnull _LsA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1014);
}
// Checkout.PasswordEntry.Text
_FormattedString * _Nonnull _LsB(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1015, _0);
}
// Checkout.PasswordEntry.Title
NSString * _Nonnull _LsC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1016);
}
// Checkout.PayNone
NSString * _Nonnull _LsD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1017);
}
// Checkout.PayPrice
_FormattedString * _Nonnull _LsE(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1018, _0);
}
// Checkout.PayWithFaceId
NSString * _Nonnull _LsF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1019);
}
// Checkout.PayWithTouchId
NSString * _Nonnull _LsG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1020);
}
// Checkout.PaymentLiabilityAlert
NSString * _Nonnull _LsH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1021);
}
// Checkout.PaymentMethod
NSString * _Nonnull _LsI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1022);
}
// Checkout.PaymentMethod.New
NSString * _Nonnull _LsJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1023);
}
// Checkout.PaymentMethod.Title
NSString * _Nonnull _LsK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1024);
}
// Checkout.Phone
NSString * _Nonnull _LsL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1025);
}
// Checkout.Receipt.Title
NSString * _Nonnull _LsM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1026);
}
// Checkout.SavePasswordTimeout
_FormattedString * _Nonnull _LsN(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1027, _0);
}
// Checkout.SavePasswordTimeoutAndFaceId
_FormattedString * _Nonnull _LsO(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1028, _0);
}
// Checkout.SavePasswordTimeoutAndTouchId
_FormattedString * _Nonnull _LsP(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1029, _0);
}
// Checkout.ShippingAddress
NSString * _Nonnull _LsQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1030);
}
// Checkout.ShippingMethod
NSString * _Nonnull _LsR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1031);
}
// Checkout.ShippingOption.Title
NSString * _Nonnull _LsS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1032);
}
// Checkout.SuccessfulTooltip
_FormattedString * _Nonnull _LsT(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1033, _0, _1);
}
// Checkout.TipItem
NSString * _Nonnull _LsU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1034);
}
// Checkout.Title
NSString * _Nonnull _LsV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1035);
}
// Checkout.TotalAmount
NSString * _Nonnull _LsW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1036);
}
// Checkout.TotalPaidAmount
NSString * _Nonnull _LsX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1037);
}
// Checkout.WebConfirmation.Title
NSString * _Nonnull _LsY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1038);
}
// CheckoutInfo.ErrorCityInvalid
NSString * _Nonnull _LsZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1039);
}
// CheckoutInfo.ErrorEmailInvalid
NSString * _Nonnull _Lta(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1040);
}
// CheckoutInfo.ErrorNameInvalid
NSString * _Nonnull _Ltb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1041);
}
// CheckoutInfo.ErrorPhoneInvalid
NSString * _Nonnull _Ltc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1042);
}
// CheckoutInfo.ErrorPostcodeInvalid
NSString * _Nonnull _Ltd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1043);
}
// CheckoutInfo.ErrorShippingNotAvailable
NSString * _Nonnull _Lte(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1044);
}
// CheckoutInfo.ErrorStateInvalid
NSString * _Nonnull _Ltf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1045);
}
// CheckoutInfo.Pay
NSString * _Nonnull _Ltg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1046);
}
// CheckoutInfo.ReceiverInfoEmail
NSString * _Nonnull _Lth(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1047);
}
// CheckoutInfo.ReceiverInfoEmailPlaceholder
NSString * _Nonnull _Lti(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1048);
}
// CheckoutInfo.ReceiverInfoName
NSString * _Nonnull _Ltj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1049);
}
// CheckoutInfo.ReceiverInfoNamePlaceholder
NSString * _Nonnull _Ltk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1050);
}
// CheckoutInfo.ReceiverInfoPhone
NSString * _Nonnull _Ltl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1051);
}
// CheckoutInfo.ReceiverInfoTitle
NSString * _Nonnull _Ltm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1052);
}
// CheckoutInfo.SaveInfo
NSString * _Nonnull _Ltn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1053);
}
// CheckoutInfo.SaveInfoHelp
NSString * _Nonnull _Lto(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1054);
}
// CheckoutInfo.ShippingInfoAddress1
NSString * _Nonnull _Ltp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1055);
}
// CheckoutInfo.ShippingInfoAddress1Placeholder
NSString * _Nonnull _Ltq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1056);
}
// CheckoutInfo.ShippingInfoAddress2
NSString * _Nonnull _Ltr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1057);
}
// CheckoutInfo.ShippingInfoAddress2Placeholder
NSString * _Nonnull _Lts(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1058);
}
// CheckoutInfo.ShippingInfoCity
NSString * _Nonnull _Ltt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1059);
}
// CheckoutInfo.ShippingInfoCityPlaceholder
NSString * _Nonnull _Ltu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1060);
}
// CheckoutInfo.ShippingInfoCountry
NSString * _Nonnull _Ltv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1061);
}
// CheckoutInfo.ShippingInfoCountryPlaceholder
NSString * _Nonnull _Ltw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1062);
}
// CheckoutInfo.ShippingInfoPostcode
NSString * _Nonnull _Ltx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1063);
}
// CheckoutInfo.ShippingInfoPostcodePlaceholder
NSString * _Nonnull _Lty(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1064);
}
// CheckoutInfo.ShippingInfoState
NSString * _Nonnull _Ltz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1065);
}
// CheckoutInfo.ShippingInfoStatePlaceholder
NSString * _Nonnull _LtA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1066);
}
// CheckoutInfo.ShippingInfoTitle
NSString * _Nonnull _LtB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1067);
}
// CheckoutInfo.Title
NSString * _Nonnull _LtC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1068);
}
// ClearCache.Clear
NSString * _Nonnull _LtD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1069);
}
// ClearCache.ClearCache
NSString * _Nonnull _LtE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1070);
}
// ClearCache.Description
NSString * _Nonnull _LtF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1071);
}
// ClearCache.Forever
NSString * _Nonnull _LtG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1072);
}
// ClearCache.FreeSpace
NSString * _Nonnull _LtH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1073);
}
// ClearCache.FreeSpaceDescription
NSString * _Nonnull _LtI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1074);
}
// ClearCache.StorageCache
NSString * _Nonnull _LtJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1075);
}
// ClearCache.StorageFree
NSString * _Nonnull _LtK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1076);
}
// ClearCache.StorageOtherApps
NSString * _Nonnull _LtL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1077);
}
// ClearCache.StorageServiceFiles
NSString * _Nonnull _LtM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1078);
}
// ClearCache.StorageTitle
_FormattedString * _Nonnull _LtN(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1079, _0);
}
// ClearCache.StorageUsage
NSString * _Nonnull _LtO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1080);
}
// ClearCache.Success
_FormattedString * _Nonnull _LtP(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1081, _0, _1);
}
// Clipboard.SendPhoto
NSString * _Nonnull _LtQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1082);
}
// CloudStorage.Title
NSString * _Nonnull _LtR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1083);
}
// CommentsGroup.ErrorAccessDenied
NSString * _Nonnull _LtS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1084);
}
// Common.ActionNotAllowedError
NSString * _Nonnull _LtT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1085);
}
// Common.Back
NSString * _Nonnull _LtU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1086);
}
// Common.Cancel
NSString * _Nonnull _LtV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1087);
}
// Common.ChoosePhoto
NSString * _Nonnull _LtW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1088);
}
// Common.Close
NSString * _Nonnull _LtX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1089);
}
// Common.Create
NSString * _Nonnull _LtY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1090);
}
// Common.Delete
NSString * _Nonnull _LtZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1091);
}
// Common.Done
NSString * _Nonnull _Lua(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1092);
}
// Common.Edit
NSString * _Nonnull _Lub(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1093);
}
// Common.More
NSString * _Nonnull _Luc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1094);
}
// Common.Next
NSString * _Nonnull _Lud(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1095);
}
// Common.No
NSString * _Nonnull _Lue(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1096);
}
// Common.NotNow
NSString * _Nonnull _Luf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1097);
}
// Common.OK
NSString * _Nonnull _Lug(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1098);
}
// Common.Save
NSString * _Nonnull _Luh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1099);
}
// Common.Search
NSString * _Nonnull _Lui(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1100);
}
// Common.Select
NSString * _Nonnull _Luj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1101);
}
// Common.TakePhoto
NSString * _Nonnull _Luk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1102);
}
// Common.TakePhotoOrVideo
NSString * _Nonnull _Lul(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1103);
}
// Common.Yes
NSString * _Nonnull _Lum(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1104);
}
// Common.edit
NSString * _Nonnull _Lun(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1105);
}
// Common.of
NSString * _Nonnull _Luo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1106);
}
// Compatibility.SecretMediaVersionTooLow
_FormattedString * _Nonnull _Lup(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1107, _0, _1);
}
// Compose.ChannelMembers
NSString * _Nonnull _Luq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1108);
}
// Compose.ChannelTokenListPlaceholder
NSString * _Nonnull _Lur(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1109);
}
// Compose.Create
NSString * _Nonnull _Lus(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1110);
}
// Compose.GroupTokenListPlaceholder
NSString * _Nonnull _Lut(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1111);
}
// Compose.NewChannel
NSString * _Nonnull _Luu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1112);
}
// Compose.NewChannel.Members
NSString * _Nonnull _Luv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1113);
}
// Compose.NewEncryptedChat
NSString * _Nonnull _Luw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1114);
}
// Compose.NewEncryptedChatTitle
NSString * _Nonnull _Lux(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1115);
}
// Compose.NewGroup
NSString * _Nonnull _Luy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1116);
}
// Compose.NewGroupTitle
NSString * _Nonnull _Luz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1117);
}
// Compose.NewMessage
NSString * _Nonnull _LuA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1118);
}
// Compose.TokenListPlaceholder
NSString * _Nonnull _LuB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1119);
}
// ContactInfo.BirthdayLabel
NSString * _Nonnull _LuC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1120);
}
// ContactInfo.Job
NSString * _Nonnull _LuD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1121);
}
// ContactInfo.Note
NSString * _Nonnull _LuE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1122);
}
// ContactInfo.PhoneLabelHome
NSString * _Nonnull _LuF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1123);
}
// ContactInfo.PhoneLabelHomeFax
NSString * _Nonnull _LuG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1124);
}
// ContactInfo.PhoneLabelMain
NSString * _Nonnull _LuH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1125);
}
// ContactInfo.PhoneLabelMobile
NSString * _Nonnull _LuI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1126);
}
// ContactInfo.PhoneLabelOther
NSString * _Nonnull _LuJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1127);
}
// ContactInfo.PhoneLabelPager
NSString * _Nonnull _LuK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1128);
}
// ContactInfo.PhoneLabelWork
NSString * _Nonnull _LuL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1129);
}
// ContactInfo.PhoneLabelWorkFax
NSString * _Nonnull _LuM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1130);
}
// ContactInfo.PhoneNumberHidden
NSString * _Nonnull _LuN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1131);
}
// ContactInfo.Title
NSString * _Nonnull _LuO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1132);
}
// ContactInfo.URLLabelHomepage
NSString * _Nonnull _LuP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1133);
}
// ContactList.Context.Call
NSString * _Nonnull _LuQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1134);
}
// ContactList.Context.SendMessage
NSString * _Nonnull _LuR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1135);
}
// ContactList.Context.StartSecretChat
NSString * _Nonnull _LuS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1136);
}
// ContactList.Context.VideoCall
NSString * _Nonnull _LuT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1137);
}
// Contacts.AccessDeniedError
NSString * _Nonnull _LuU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1138);
}
// Contacts.AccessDeniedHelpLandscape
_FormattedString * _Nonnull _LuV(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1139, _0);
}
// Contacts.AccessDeniedHelpON
NSString * _Nonnull _LuW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1140);
}
// Contacts.AccessDeniedHelpPortrait
_FormattedString * _Nonnull _LuX(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1141, _0);
}
// Contacts.AddPeopleNearby
NSString * _Nonnull _LuY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1142);
}
// Contacts.AddPhoneNumber
_FormattedString * _Nonnull _LuZ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1143, _0);
}
// Contacts.DeselectAll
NSString * _Nonnull _Lva(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1144);
}
// Contacts.FailedToSendInvitesMessage
NSString * _Nonnull _Lvb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1145);
}
// Contacts.GlobalSearch
NSString * _Nonnull _Lvc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1146);
}
// Contacts.ImportersCount
NSString * _Nonnull _Lvd(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1147, value);
}
// Contacts.InviteContacts
NSString * _Nonnull _Lve(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1148, value);
}
// Contacts.InviteFriends
NSString * _Nonnull _Lvf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1149);
}
// Contacts.InviteSearchLabel
NSString * _Nonnull _Lvg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1150);
}
// Contacts.InviteToTelegram
NSString * _Nonnull _Lvh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1151);
}
// Contacts.MemberSearchSectionTitleGroup
NSString * _Nonnull _Lvi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1152);
}
// Contacts.NotRegisteredSection
NSString * _Nonnull _Lvj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1153);
}
// Contacts.PermissionsAllow
NSString * _Nonnull _Lvk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1154);
}
// Contacts.PermissionsAllowInSettings
NSString * _Nonnull _Lvl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1155);
}
// Contacts.PermissionsEnable
NSString * _Nonnull _Lvm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1156);
}
// Contacts.PermissionsKeepDisabled
NSString * _Nonnull _Lvn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1157);
}
// Contacts.PermissionsSuppressWarningText
NSString * _Nonnull _Lvo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1158);
}
// Contacts.PermissionsSuppressWarningTitle
NSString * _Nonnull _Lvp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1159);
}
// Contacts.PermissionsText
NSString * _Nonnull _Lvq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1160);
}
// Contacts.PermissionsTitle
NSString * _Nonnull _Lvr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1161);
}
// Contacts.PhoneNumber
NSString * _Nonnull _Lvs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1162);
}
// Contacts.SearchLabel
NSString * _Nonnull _Lvt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1163);
}
// Contacts.SearchUsersAndGroupsLabel
NSString * _Nonnull _Lvu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1164);
}
// Contacts.SelectAll
NSString * _Nonnull _Lvv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1165);
}
// Contacts.ShareTelegram
NSString * _Nonnull _Lvw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1166);
}
// Contacts.SortBy
NSString * _Nonnull _Lvx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1167);
}
// Contacts.SortByName
NSString * _Nonnull _Lvy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1168);
}
// Contacts.SortByPresence
NSString * _Nonnull _Lvz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1169);
}
// Contacts.SortedByName
NSString * _Nonnull _LvA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1170);
}
// Contacts.SortedByPresence
NSString * _Nonnull _LvB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1171);
}
// Contacts.TabTitle
NSString * _Nonnull _LvC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1172);
}
// Contacts.Title
NSString * _Nonnull _LvD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1173);
}
// Contacts.TopSection
NSString * _Nonnull _LvE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1174);
}
// Contacts.VoiceOver.AddContact
NSString * _Nonnull _LvF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1175);
}
// Conversation.AddContact
NSString * _Nonnull _LvG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1176);
}
// Conversation.AddMembers
NSString * _Nonnull _LvH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1177);
}
// Conversation.AddNameToContacts
_FormattedString * _Nonnull _LvI(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1178, _0);
}
// Conversation.AddToContacts
NSString * _Nonnull _LvJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1179);
}
// Conversation.AddToReadingList
NSString * _Nonnull _LvK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1180);
}
// Conversation.Admin
NSString * _Nonnull _LvL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1181);
}
// Conversation.AlsoClearCacheTitle
NSString * _Nonnull _LvM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1182);
}
// Conversation.ApplyLocalization
NSString * _Nonnull _LvN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1183);
}
// Conversation.AudioRateTooltipNormal
NSString * _Nonnull _LvO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1184);
}
// Conversation.AudioRateTooltipSpeedUp
NSString * _Nonnull _LvP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1185);
}
// Conversation.AutoremoveActionEdit
NSString * _Nonnull _LvQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1186);
}
// Conversation.AutoremoveActionEnable
NSString * _Nonnull _LvR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1187);
}
// Conversation.AutoremoveChanged
_FormattedString * _Nonnull _LvS(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1188, _0);
}
// Conversation.AutoremoveOff
NSString * _Nonnull _LvT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1189);
}
// Conversation.AutoremoveRemainingDays
NSString * _Nonnull _LvU(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1190, value);
}
// Conversation.AutoremoveRemainingTime
_FormattedString * _Nonnull _LvV(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1191, _0);
}
// Conversation.AutoremoveTimerRemovedChannel
NSString * _Nonnull _LvW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1192);
}
// Conversation.AutoremoveTimerRemovedGroup
NSString * _Nonnull _LvX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1193);
}
// Conversation.AutoremoveTimerRemovedUser
_FormattedString * _Nonnull _LvY(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1194, _0);
}
// Conversation.AutoremoveTimerRemovedUserYou
NSString * _Nonnull _LvZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1195);
}
// Conversation.AutoremoveTimerSetChannel
_FormattedString * _Nonnull _Lwa(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1196, _0);
}
// Conversation.AutoremoveTimerSetGroup
_FormattedString * _Nonnull _Lwb(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1197, _0);
}
// Conversation.AutoremoveTimerSetToastText
_FormattedString * _Nonnull _Lwc(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1198, _0);
}
// Conversation.AutoremoveTimerSetUser
_FormattedString * _Nonnull _Lwd(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1199, _0, _1);
}
// Conversation.AutoremoveTimerSetUserYou
_FormattedString * _Nonnull _Lwe(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1200, _0);
}
// Conversation.Block
NSString * _Nonnull _Lwf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1201);
}
// Conversation.BlockUser
NSString * _Nonnull _Lwg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1202);
}
// Conversation.BotInteractiveUrlAlert
_FormattedString * _Nonnull _Lwh(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1203, _0);
}
// Conversation.Bytes
_FormattedString * _Nonnull _Lwi(_PresentationStrings * _Nonnull _self, NSInteger _0) {
    return getFormatted1(_self, 1204, @(_0));
}
// Conversation.Call
NSString * _Nonnull _Lwj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1205);
}
// Conversation.CancelForwardCancelForward
NSString * _Nonnull _Lwk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1206);
}
// Conversation.CancelForwardSelectChat
NSString * _Nonnull _Lwl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1207);
}
// Conversation.CancelForwardText
NSString * _Nonnull _Lwm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1208);
}
// Conversation.CancelForwardTitle
NSString * _Nonnull _Lwn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1209);
}
// Conversation.CardNumberCopied
NSString * _Nonnull _Lwo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1210);
}
// Conversation.ChatBackground
NSString * _Nonnull _Lwp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1211);
}
// Conversation.ChecksTooltip.Delivered
NSString * _Nonnull _Lwq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1212);
}
// Conversation.ChecksTooltip.Read
NSString * _Nonnull _Lwr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1213);
}
// Conversation.ClearAll
NSString * _Nonnull _Lws(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1214);
}
// Conversation.ClearCache
NSString * _Nonnull _Lwt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1215);
}
// Conversation.ClearChannel
NSString * _Nonnull _Lwu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1216);
}
// Conversation.ClearChatConfirmation
_FormattedString * _Nonnull _Lwv(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1217, _0);
}
// Conversation.ClearGroupHistory
NSString * _Nonnull _Lww(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1218);
}
// Conversation.ClearPrivateHistory
NSString * _Nonnull _Lwx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1219);
}
// Conversation.ClearSecretHistory
NSString * _Nonnull _Lwy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1220);
}
// Conversation.ClearSelfHistory
NSString * _Nonnull _Lwz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1221);
}
// Conversation.CloudStorage.ChatStatus
NSString * _Nonnull _LwA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1222);
}
// Conversation.CloudStorageInfo.Title
NSString * _Nonnull _LwB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1223);
}
// Conversation.ClousStorageInfo.Description1
NSString * _Nonnull _LwC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1224);
}
// Conversation.ClousStorageInfo.Description2
NSString * _Nonnull _LwD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1225);
}
// Conversation.ClousStorageInfo.Description3
NSString * _Nonnull _LwE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1226);
}
// Conversation.ClousStorageInfo.Description4
NSString * _Nonnull _LwF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1227);
}
// Conversation.Contact
NSString * _Nonnull _LwG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1228);
}
// Conversation.ContextMenuBan
NSString * _Nonnull _LwH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1229);
}
// Conversation.ContextMenuBlock
NSString * _Nonnull _LwI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1230);
}
// Conversation.ContextMenuCancelEditing
NSString * _Nonnull _LwJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1231);
}
// Conversation.ContextMenuCancelSending
NSString * _Nonnull _LwK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1232);
}
// Conversation.ContextMenuCopy
NSString * _Nonnull _LwL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1233);
}
// Conversation.ContextMenuCopyLink
NSString * _Nonnull _LwM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1234);
}
// Conversation.ContextMenuDelete
NSString * _Nonnull _LwN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1235);
}
// Conversation.ContextMenuDiscuss
NSString * _Nonnull _LwO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1236);
}
// Conversation.ContextMenuForward
NSString * _Nonnull _LwP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1237);
}
// Conversation.ContextMenuLookUp
NSString * _Nonnull _LwQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1238);
}
// Conversation.ContextMenuMention
NSString * _Nonnull _LwR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1239);
}
// Conversation.ContextMenuMore
NSString * _Nonnull _LwS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1240);
}
// Conversation.ContextMenuOpenChannel
NSString * _Nonnull _LwT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1241);
}
// Conversation.ContextMenuOpenChannelProfile
NSString * _Nonnull _LwU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1242);
}
// Conversation.ContextMenuOpenProfile
NSString * _Nonnull _LwV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1243);
}
// Conversation.ContextMenuReply
NSString * _Nonnull _LwW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1244);
}
// Conversation.ContextMenuReport
NSString * _Nonnull _LwX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1245);
}
// Conversation.ContextMenuSelect
NSString * _Nonnull _LwY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1246);
}
// Conversation.ContextMenuSelectAll
NSString * _Nonnull _LwZ(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1247, value);
}
// Conversation.ContextMenuSendMessage
NSString * _Nonnull _Lxa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1248);
}
// Conversation.ContextMenuShare
NSString * _Nonnull _Lxb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1249);
}
// Conversation.ContextMenuSpeak
NSString * _Nonnull _Lxc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1250);
}
// Conversation.ContextMenuStickerPackAdd
NSString * _Nonnull _Lxd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1251);
}
// Conversation.ContextMenuStickerPackInfo
NSString * _Nonnull _Lxe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1252);
}
// Conversation.ContextViewReplies
NSString * _Nonnull _Lxf(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1253, value);
}
// Conversation.ContextViewStats
NSString * _Nonnull _Lxg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1254);
}
// Conversation.ContextViewThread
NSString * _Nonnull _Lxh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1255);
}
// Conversation.DefaultRestrictedInline
NSString * _Nonnull _Lxi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1256);
}
// Conversation.DefaultRestrictedMedia
NSString * _Nonnull _Lxj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1257);
}
// Conversation.DefaultRestrictedStickers
NSString * _Nonnull _Lxk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1258);
}
// Conversation.DefaultRestrictedText
NSString * _Nonnull _Lxl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1259);
}
// Conversation.DeleteAllMessagesInChat
_FormattedString * _Nonnull _Lxm(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1260, _0);
}
// Conversation.DeleteManyMessages
NSString * _Nonnull _Lxn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1261);
}
// Conversation.DeleteMessagesFor
_FormattedString * _Nonnull _Lxo(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1262, _0);
}
// Conversation.DeleteMessagesForEveryone
NSString * _Nonnull _Lxp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1263);
}
// Conversation.DeleteMessagesForMe
NSString * _Nonnull _Lxq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1264);
}
// Conversation.DeletedFromContacts
_FormattedString * _Nonnull _Lxr(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1265, _0);
}
// Conversation.Dice.u1F3AF
NSString * _Nonnull _Lxs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1266);
}
// Conversation.Dice.u1F3B0
NSString * _Nonnull _Lxt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1267);
}
// Conversation.Dice.u1F3B2
NSString * _Nonnull _Lxu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1268);
}
// Conversation.Dice.u1F3B3
NSString * _Nonnull _Lxv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1269);
}
// Conversation.Dice.u1F3C0
NSString * _Nonnull _Lxw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1270);
}
// Conversation.Dice.u26BD
NSString * _Nonnull _Lxx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1271);
}
// Conversation.DiscardVoiceMessageAction
NSString * _Nonnull _Lxy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1272);
}
// Conversation.DiscardVoiceMessageDescription
NSString * _Nonnull _Lxz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1273);
}
// Conversation.DiscardVoiceMessageTitle
NSString * _Nonnull _LxA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1274);
}
// Conversation.DiscussionNotStarted
NSString * _Nonnull _LxB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1275);
}
// Conversation.DiscussionStarted
NSString * _Nonnull _LxC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1276);
}
// Conversation.Edit
NSString * _Nonnull _LxD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1277);
}
// Conversation.EditingCaptionPanelTitle
NSString * _Nonnull _LxE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1278);
}
// Conversation.EditingMessageMediaChange
NSString * _Nonnull _LxF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1279);
}
// Conversation.EditingMessageMediaEditCurrentPhoto
NSString * _Nonnull _LxG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1280);
}
// Conversation.EditingMessageMediaEditCurrentVideo
NSString * _Nonnull _LxH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1281);
}
// Conversation.EditingMessagePanelMedia
NSString * _Nonnull _LxI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1282);
}
// Conversation.EditingMessagePanelTitle
NSString * _Nonnull _LxJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1283);
}
// Conversation.EditingPhotoPanelTitle
NSString * _Nonnull _LxK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1284);
}
// Conversation.EmailCopied
NSString * _Nonnull _LxL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1285);
}
// Conversation.EmptyGifPanelPlaceholder
NSString * _Nonnull _LxM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1286);
}
// Conversation.EmptyPlaceholder
NSString * _Nonnull _LxN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1287);
}
// Conversation.EncryptedDescription1
NSString * _Nonnull _LxO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1288);
}
// Conversation.EncryptedDescription2
NSString * _Nonnull _LxP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1289);
}
// Conversation.EncryptedDescription3
NSString * _Nonnull _LxQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1290);
}
// Conversation.EncryptedDescription4
NSString * _Nonnull _LxR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1291);
}
// Conversation.EncryptedDescriptionTitle
NSString * _Nonnull _LxS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1292);
}
// Conversation.EncryptedPlaceholderTitleIncoming
_FormattedString * _Nonnull _LxT(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1293, _0);
}
// Conversation.EncryptedPlaceholderTitleOutgoing
_FormattedString * _Nonnull _LxU(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1294, _0);
}
// Conversation.EncryptionCanceled
NSString * _Nonnull _LxV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1295);
}
// Conversation.EncryptionProcessing
NSString * _Nonnull _LxW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1296);
}
// Conversation.EncryptionWaiting
_FormattedString * _Nonnull _LxX(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1297, _0);
}
// Conversation.ErrorInaccessibleMessage
NSString * _Nonnull _LxY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1298);
}
// Conversation.FileDropbox
NSString * _Nonnull _LxZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1299);
}
// Conversation.FileHowToText
_FormattedString * _Nonnull _Lya(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1300, _0);
}
// Conversation.FileICloudDrive
NSString * _Nonnull _Lyb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1301);
}
// Conversation.FileOpenIn
NSString * _Nonnull _Lyc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1302);
}
// Conversation.FilePhotoOrVideo
NSString * _Nonnull _Lyd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1303);
}
// Conversation.ForwardAuthorHiddenTooltip
NSString * _Nonnull _Lye(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1304);
}
// Conversation.ForwardChats
NSString * _Nonnull _Lyf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1305);
}
// Conversation.ForwardContacts
NSString * _Nonnull _Lyg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1306);
}
// Conversation.ForwardTitle
NSString * _Nonnull _Lyh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1307);
}
// Conversation.ForwardTooltip.Chat.Many
_FormattedString * _Nonnull _Lyi(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1308, _0);
}
// Conversation.ForwardTooltip.Chat.One
_FormattedString * _Nonnull _Lyj(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1309, _0);
}
// Conversation.ForwardTooltip.ManyChats.Many
_FormattedString * _Nonnull _Lyk(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1310, _0, _1);
}
// Conversation.ForwardTooltip.ManyChats.One
_FormattedString * _Nonnull _Lyl(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1311, _0, _1);
}
// Conversation.ForwardTooltip.SavedMessages.Many
NSString * _Nonnull _Lym(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1312);
}
// Conversation.ForwardTooltip.SavedMessages.One
NSString * _Nonnull _Lyn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1313);
}
// Conversation.ForwardTooltip.TwoChats.Many
_FormattedString * _Nonnull _Lyo(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1314, _0, _1);
}
// Conversation.ForwardTooltip.TwoChats.One
_FormattedString * _Nonnull _Lyp(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1315, _0, _1);
}
// Conversation.GifTooltip
NSString * _Nonnull _Lyq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1316);
}
// Conversation.GigagroupDescription
NSString * _Nonnull _Lyr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1317);
}
// Conversation.GreetingText
NSString * _Nonnull _Lys(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1318);
}
// Conversation.HashtagCopied
NSString * _Nonnull _Lyt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1319);
}
// Conversation.HoldForAudio
NSString * _Nonnull _Lyu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1320);
}
// Conversation.HoldForVideo
NSString * _Nonnull _Lyv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1321);
}
// Conversation.ImageCopied
NSString * _Nonnull _Lyw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1322);
}
// Conversation.ImportProgress
_FormattedString * _Nonnull _Lyx(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1323, _0);
}
// Conversation.ImportedMessageHint
NSString * _Nonnull _Lyy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1324);
}
// Conversation.Info
NSString * _Nonnull _Lyz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1325);
}
// Conversation.InfoGroup
NSString * _Nonnull _LyA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1326);
}
// Conversation.InputMenu
NSString * _Nonnull _LyB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1327);
}
// Conversation.InputTextAnonymousPlaceholder
NSString * _Nonnull _LyC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1328);
}
// Conversation.InputTextBroadcastPlaceholder
NSString * _Nonnull _LyD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1329);
}
// Conversation.InputTextCaptionPlaceholder
NSString * _Nonnull _LyE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1330);
}
// Conversation.InputTextPlaceholder
NSString * _Nonnull _LyF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1331);
}
// Conversation.InputTextPlaceholderComment
NSString * _Nonnull _LyG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1332);
}
// Conversation.InputTextPlaceholderReply
NSString * _Nonnull _LyH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1333);
}
// Conversation.InputTextSilentBroadcastPlaceholder
NSString * _Nonnull _LyI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1334);
}
// Conversation.InstantPagePreview
NSString * _Nonnull _LyJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1335);
}
// Conversation.JoinVoiceChat
NSString * _Nonnull _LyK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1336);
}
// Conversation.JoinVoiceChatAsListener
NSString * _Nonnull _LyL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1337);
}
// Conversation.JoinVoiceChatAsSpeaker
NSString * _Nonnull _LyM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1338);
}
// Conversation.JumpToDate
NSString * _Nonnull _LyN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1339);
}
// Conversation.Kilobytes
_FormattedString * _Nonnull _LyO(_PresentationStrings * _Nonnull _self, NSInteger _0) {
    return getFormatted1(_self, 1340, @(_0));
}
// Conversation.LinkCopied
NSString * _Nonnull _LyP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1341);
}
// Conversation.LinkDialogCopy
NSString * _Nonnull _LyQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1342);
}
// Conversation.LinkDialogOpen
NSString * _Nonnull _LyR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1343);
}
// Conversation.LinkDialogSave
NSString * _Nonnull _LyS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1344);
}
// Conversation.LiveLocation
NSString * _Nonnull _LyT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1345);
}
// Conversation.LiveLocationMembersCount
NSString * _Nonnull _LyU(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1346, value);
}
// Conversation.LiveLocationYou
NSString * _Nonnull _LyV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1347);
}
// Conversation.LiveLocationYouAnd
_FormattedString * _Nonnull _LyW(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1348, _0);
}
// Conversation.LiveLocationYouAndOther
_FormattedString * _Nonnull _LyX(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1349, _0);
}
// Conversation.Location
NSString * _Nonnull _LyY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1350);
}
// Conversation.Megabytes
NSString * _Nonnull _LyZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1351);
}
// Conversation.MessageCopied
NSString * _Nonnull _Lza(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1352);
}
// Conversation.MessageDeliveryFailed
NSString * _Nonnull _Lzb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1353);
}
// Conversation.MessageDialogDelete
NSString * _Nonnull _Lzc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1354);
}
// Conversation.MessageDialogEdit
NSString * _Nonnull _Lzd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1355);
}
// Conversation.MessageDialogRetry
NSString * _Nonnull _Lze(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1356);
}
// Conversation.MessageDialogRetryAll
_FormattedString * _Nonnull _Lzf(_PresentationStrings * _Nonnull _self, NSInteger _0) {
    return getFormatted1(_self, 1357, @(_0));
}
// Conversation.MessageDoesntExist
NSString * _Nonnull _Lzg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1358);
}
// Conversation.MessageEditedLabel
NSString * _Nonnull _Lzh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1359);
}
// Conversation.MessageLeaveComment
NSString * _Nonnull _Lzi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1360);
}
// Conversation.MessageLeaveCommentShort
NSString * _Nonnull _Lzj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1361);
}
// Conversation.MessageViaUser
_FormattedString * _Nonnull _Lzk(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1362, _0);
}
// Conversation.MessageViewComments
NSString * _Nonnull _Lzl(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1363, value);
}
// Conversation.MessageViewCommentsFormat
_FormattedString * _Nonnull _Lzm(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1364, _0, _1);
}
// Conversation.Moderate.Ban
NSString * _Nonnull _Lzn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1365);
}
// Conversation.Moderate.Delete
NSString * _Nonnull _Lzo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1366);
}
// Conversation.Moderate.DeleteAllMessages
_FormattedString * _Nonnull _Lzp(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1367, _0);
}
// Conversation.Moderate.Report
NSString * _Nonnull _Lzq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1368);
}
// Conversation.Mute
NSString * _Nonnull _Lzr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1369);
}
// Conversation.NoticeInvitedByInChannel
_FormattedString * _Nonnull _Lzs(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1370, _0);
}
// Conversation.NoticeInvitedByInGroup
_FormattedString * _Nonnull _Lzt(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1371, _0);
}
// Conversation.OpenBotLinkAllowMessages
_FormattedString * _Nonnull _Lzu(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1372, _0);
}
// Conversation.OpenBotLinkLogin
_FormattedString * _Nonnull _Lzv(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1373, _0, _1);
}
// Conversation.OpenBotLinkOpen
NSString * _Nonnull _Lzw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1374);
}
// Conversation.OpenBotLinkText
_FormattedString * _Nonnull _Lzx(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1375, _0);
}
// Conversation.OpenBotLinkTitle
NSString * _Nonnull _Lzy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1376);
}
// Conversation.OpenFile
NSString * _Nonnull _Lzz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1377);
}
// Conversation.Owner
NSString * _Nonnull _LzA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1378);
}
// Conversation.PeerNearbyDistance
_FormattedString * _Nonnull _LzB(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1379, _0, _1);
}
// Conversation.PeerNearbyText
NSString * _Nonnull _LzC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1380);
}
// Conversation.PeerNearbyTitle
_FormattedString * _Nonnull _LzD(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1381, _0, _1);
}
// Conversation.PhoneCopied
NSString * _Nonnull _LzE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1382);
}
// Conversation.Pin
NSString * _Nonnull _LzF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1383);
}
// Conversation.PinMessageAlert.OnlyPin
NSString * _Nonnull _LzG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1384);
}
// Conversation.PinMessageAlert.PinAndNotifyMembers
NSString * _Nonnull _LzH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1385);
}
// Conversation.PinMessageAlertGroup
NSString * _Nonnull _LzI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1386);
}
// Conversation.PinMessageAlertPin
NSString * _Nonnull _LzJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1387);
}
// Conversation.PinMessagesFor
_FormattedString * _Nonnull _LzK(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1388, _0);
}
// Conversation.PinMessagesForMe
NSString * _Nonnull _LzL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1389);
}
// Conversation.PinOlderMessageAlertText
NSString * _Nonnull _LzM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1390);
}
// Conversation.PinOlderMessageAlertTitle
NSString * _Nonnull _LzN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1391);
}
// Conversation.PinnedMessage
NSString * _Nonnull _LzO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1392);
}
// Conversation.PinnedPoll
NSString * _Nonnull _LzP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1393);
}
// Conversation.PinnedPreviousMessage
NSString * _Nonnull _LzQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1394);
}
// Conversation.PinnedQuiz
NSString * _Nonnull _LzR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1395);
}
// Conversation.PressVolumeButtonForSound
NSString * _Nonnull _LzS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1396);
}
// Conversation.PrivateChannelTimeLimitedAlertJoin
NSString * _Nonnull _LzT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1397);
}
// Conversation.PrivateChannelTimeLimitedAlertText
NSString * _Nonnull _LzU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1398);
}
// Conversation.PrivateChannelTimeLimitedAlertTitle
NSString * _Nonnull _LzV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1399);
}
// Conversation.PrivateChannelTooltip
NSString * _Nonnull _LzW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1400);
}
// Conversation.PrivateMessageLinkCopied
NSString * _Nonnull _LzX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1401);
}
// Conversation.PrivateMessageLinkCopiedLong
NSString * _Nonnull _LzY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1402);
}
// Conversation.Processing
NSString * _Nonnull _LzZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1403);
}
// Conversation.Report
NSString * _Nonnull _LAa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1404);
}
// Conversation.ReportGroupLocation
NSString * _Nonnull _LAb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1405);
}
// Conversation.ReportMessages
NSString * _Nonnull _LAc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1406);
}
// Conversation.ReportSpam
NSString * _Nonnull _LAd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1407);
}
// Conversation.ReportSpamAndLeave
NSString * _Nonnull _LAe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1408);
}
// Conversation.ReportSpamChannelConfirmation
NSString * _Nonnull _LAf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1409);
}
// Conversation.ReportSpamConfirmation
NSString * _Nonnull _LAg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1410);
}
// Conversation.ReportSpamGroupConfirmation
NSString * _Nonnull _LAh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1411);
}
// Conversation.RestrictedInline
NSString * _Nonnull _LAi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1412);
}
// Conversation.RestrictedInlineTimed
_FormattedString * _Nonnull _LAj(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1413, _0);
}
// Conversation.RestrictedMedia
NSString * _Nonnull _LAk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1414);
}
// Conversation.RestrictedMediaTimed
_FormattedString * _Nonnull _LAl(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1415, _0);
}
// Conversation.RestrictedStickers
NSString * _Nonnull _LAm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1416);
}
// Conversation.RestrictedStickersTimed
_FormattedString * _Nonnull _LAn(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1417, _0);
}
// Conversation.RestrictedText
NSString * _Nonnull _LAo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1418);
}
// Conversation.RestrictedTextTimed
_FormattedString * _Nonnull _LAp(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1419, _0);
}
// Conversation.SavedMessages
NSString * _Nonnull _LAq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1420);
}
// Conversation.ScamWarning
NSString * _Nonnull _LAr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1421);
}
// Conversation.ScheduleMessage.SendOn
_FormattedString * _Nonnull _LAs(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1422, _0, _1);
}
// Conversation.ScheduleMessage.SendToday
_FormattedString * _Nonnull _LAt(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1423, _0);
}
// Conversation.ScheduleMessage.SendTomorrow
_FormattedString * _Nonnull _LAu(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1424, _0);
}
// Conversation.ScheduleMessage.SendWhenOnline
NSString * _Nonnull _LAv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1425);
}
// Conversation.ScheduleMessage.Title
NSString * _Nonnull _LAw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1426);
}
// Conversation.ScheduledVoiceChat
NSString * _Nonnull _LAx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1427);
}
// Conversation.ScheduledVoiceChatStartsOn
_FormattedString * _Nonnull _LAy(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1428, _0);
}
// Conversation.ScheduledVoiceChatStartsOnShort
_FormattedString * _Nonnull _LAz(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1429, _0);
}
// Conversation.ScheduledVoiceChatStartsToday
_FormattedString * _Nonnull _LAA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1430, _0);
}
// Conversation.ScheduledVoiceChatStartsTodayShort
_FormattedString * _Nonnull _LAB(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1431, _0);
}
// Conversation.ScheduledVoiceChatStartsTomorrow
_FormattedString * _Nonnull _LAC(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1432, _0);
}
// Conversation.ScheduledVoiceChatStartsTomorrowShort
_FormattedString * _Nonnull _LAD(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1433, _0);
}
// Conversation.Search
NSString * _Nonnull _LAE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1434);
}
// Conversation.SearchByName.Placeholder
NSString * _Nonnull _LAF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1435);
}
// Conversation.SearchByName.Prefix
NSString * _Nonnull _LAG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1436);
}
// Conversation.SearchNoResults
NSString * _Nonnull _LAH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1437);
}
// Conversation.SearchPlaceholder
NSString * _Nonnull _LAI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1438);
}
// Conversation.SecretChatContextBotAlert
NSString * _Nonnull _LAJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1439);
}
// Conversation.SecretLinkPreviewAlert
NSString * _Nonnull _LAK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1440);
}
// Conversation.SelectMessages
NSString * _Nonnull _LAL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1441);
}
// Conversation.SelectedMessages
NSString * _Nonnull _LAM(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1442, value);
}
// Conversation.SendDice
NSString * _Nonnull _LAN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1443);
}
// Conversation.SendMessage
NSString * _Nonnull _LAO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1444);
}
// Conversation.SendMessage.ScheduleMessage
NSString * _Nonnull _LAP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1445);
}
// Conversation.SendMessage.SendSilently
NSString * _Nonnull _LAQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1446);
}
// Conversation.SendMessage.SetReminder
NSString * _Nonnull _LAR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1447);
}
// Conversation.SendMessageErrorFlood
NSString * _Nonnull _LAS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1448);
}
// Conversation.SendMessageErrorGroupRestricted
NSString * _Nonnull _LAT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1449);
}
// Conversation.SendMessageErrorTooMuchScheduled
NSString * _Nonnull _LAU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1450);
}
// Conversation.SendingOptionsTooltip
NSString * _Nonnull _LAV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1451);
}
// Conversation.SetReminder.RemindOn
_FormattedString * _Nonnull _LAW(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1452, _0, _1);
}
// Conversation.SetReminder.RemindToday
_FormattedString * _Nonnull _LAX(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1453, _0);
}
// Conversation.SetReminder.RemindTomorrow
_FormattedString * _Nonnull _LAY(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1454, _0);
}
// Conversation.SetReminder.Title
NSString * _Nonnull _LAZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1455);
}
// Conversation.ShareBotContactConfirmation
NSString * _Nonnull _LBa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1456);
}
// Conversation.ShareBotContactConfirmationTitle
NSString * _Nonnull _LBb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1457);
}
// Conversation.ShareBotLocationConfirmation
NSString * _Nonnull _LBc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1458);
}
// Conversation.ShareBotLocationConfirmationTitle
NSString * _Nonnull _LBd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1459);
}
// Conversation.ShareInlineBotLocationConfirmation
NSString * _Nonnull _LBe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1460);
}
// Conversation.ShareMyContactInfo
NSString * _Nonnull _LBf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1461);
}
// Conversation.ShareMyPhoneNumber
NSString * _Nonnull _LBg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1462);
}
// Conversation.ShareMyPhoneNumber.StatusSuccess
_FormattedString * _Nonnull _LBh(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1463, _0);
}
// Conversation.ShareMyPhoneNumberConfirmation
_FormattedString * _Nonnull _LBi(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1464, _0, _1);
}
// Conversation.SilentBroadcastTooltipOff
NSString * _Nonnull _LBj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1465);
}
// Conversation.SilentBroadcastTooltipOn
NSString * _Nonnull _LBk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1466);
}
// Conversation.SlideToCancel
NSString * _Nonnull _LBl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1467);
}
// Conversation.StatusKickedFromChannel
NSString * _Nonnull _LBm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1468);
}
// Conversation.StatusKickedFromGroup
NSString * _Nonnull _LBn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1469);
}
// Conversation.StatusLeftGroup
NSString * _Nonnull _LBo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1470);
}
// Conversation.StatusMembers
NSString * _Nonnull _LBp(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1471, value);
}
// Conversation.StatusOnline
NSString * _Nonnull _LBq(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1472, value);
}
// Conversation.StatusSubscribers
NSString * _Nonnull _LBr(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1473, value);
}
// Conversation.StatusTyping
NSString * _Nonnull _LBs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1474);
}
// Conversation.StickerAddedToFavorites
NSString * _Nonnull _LBt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1475);
}
// Conversation.StickerRemovedFromFavorites
NSString * _Nonnull _LBu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1476);
}
// Conversation.StopLiveLocation
NSString * _Nonnull _LBv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1477);
}
// Conversation.StopPoll
NSString * _Nonnull _LBw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1478);
}
// Conversation.StopPollConfirmation
NSString * _Nonnull _LBx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1479);
}
// Conversation.StopPollConfirmationTitle
NSString * _Nonnull _LBy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1480);
}
// Conversation.StopQuiz
NSString * _Nonnull _LBz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1481);
}
// Conversation.StopQuizConfirmation
NSString * _Nonnull _LBA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1482);
}
// Conversation.StopQuizConfirmationTitle
NSString * _Nonnull _LBB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1483);
}
// Conversation.SwipeToReplyHintText
NSString * _Nonnull _LBC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1484);
}
// Conversation.SwipeToReplyHintTitle
NSString * _Nonnull _LBD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1485);
}
// Conversation.TapAndHoldToRecord
NSString * _Nonnull _LBE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1486);
}
// Conversation.TextCopied
NSString * _Nonnull _LBF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1487);
}
// Conversation.Theme
NSString * _Nonnull _LBG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1488);
}
// Conversation.Timer.Send
NSString * _Nonnull _LBH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1489);
}
// Conversation.Timer.Title
NSString * _Nonnull _LBI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1490);
}
// Conversation.TitleComments
NSString * _Nonnull _LBJ(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1491, value);
}
// Conversation.TitleCommentsEmpty
NSString * _Nonnull _LBK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1492);
}
// Conversation.TitleCommentsFormat
_FormattedString * _Nonnull _LBL(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1493, _0, _1);
}
// Conversation.TitleMute
NSString * _Nonnull _LBM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1494);
}
// Conversation.TitleNoComments
NSString * _Nonnull _LBN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1495);
}
// Conversation.TitleReplies
NSString * _Nonnull _LBO(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1496, value);
}
// Conversation.TitleRepliesEmpty
NSString * _Nonnull _LBP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1497);
}
// Conversation.TitleRepliesFormat
_FormattedString * _Nonnull _LBQ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1498, _0, _1);
}
// Conversation.TitleUnmute
NSString * _Nonnull _LBR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1499);
}
// Conversation.Unarchive
NSString * _Nonnull _LBS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1500);
}
// Conversation.UnarchiveDone
NSString * _Nonnull _LBT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1501);
}
// Conversation.Unblock
NSString * _Nonnull _LBU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1502);
}
// Conversation.UnblockUser
NSString * _Nonnull _LBV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1503);
}
// Conversation.Unmute
NSString * _Nonnull _LBW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1504);
}
// Conversation.Unpin
NSString * _Nonnull _LBX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1505);
}
// Conversation.UnpinMessageAlert
NSString * _Nonnull _LBY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1506);
}
// Conversation.UnreadMessages
NSString * _Nonnull _LBZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1507);
}
// Conversation.UnsupportedMedia
NSString * _Nonnull _LCa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1508);
}
// Conversation.UnsupportedMediaPlaceholder
NSString * _Nonnull _LCb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1509);
}
// Conversation.UnvotePoll
NSString * _Nonnull _LCc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1510);
}
// Conversation.UpdateTelegram
NSString * _Nonnull _LCd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1511);
}
// Conversation.UploadFileTooLarge
NSString * _Nonnull _LCe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1512);
}
// Conversation.UsernameCopied
NSString * _Nonnull _LCf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1513);
}
// Conversation.UsersTooMuchError
NSString * _Nonnull _LCg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1514);
}
// Conversation.ViewBackground
NSString * _Nonnull _LCh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1515);
}
// Conversation.ViewChannel
NSString * _Nonnull _LCi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1516);
}
// Conversation.ViewContactDetails
NSString * _Nonnull _LCj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1517);
}
// Conversation.ViewGroup
NSString * _Nonnull _LCk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1518);
}
// Conversation.ViewMessage
NSString * _Nonnull _LCl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1519);
}
// Conversation.ViewReply
NSString * _Nonnull _LCm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1520);
}
// Conversation.ViewTheme
NSString * _Nonnull _LCn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1521);
}
// Conversation.VoiceChat
NSString * _Nonnull _LCo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1522);
}
// Conversation.VoiceChatMediaRecordingRestricted
NSString * _Nonnull _LCp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1523);
}
// Conversation.typing
NSString * _Nonnull _LCq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1524);
}
// ConversationMedia.Title
NSString * _Nonnull _LCr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1525);
}
// ConversationProfile.ErrorCreatingConversation
NSString * _Nonnull _LCs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1526);
}
// ConversationProfile.LeaveDeleteAndExit
NSString * _Nonnull _LCt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1527);
}
// ConversationProfile.UnknownAddMemberError
NSString * _Nonnull _LCu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1528);
}
// ConversationProfile.UsersTooMuchError
NSString * _Nonnull _LCv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1529);
}
// ConvertToSupergroup.HelpText
NSString * _Nonnull _LCw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1530);
}
// ConvertToSupergroup.HelpTitle
NSString * _Nonnull _LCx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1531);
}
// ConvertToSupergroup.Note
NSString * _Nonnull _LCy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1532);
}
// ConvertToSupergroup.Title
NSString * _Nonnull _LCz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1533);
}
// Core.ServiceUserStatus
NSString * _Nonnull _LCA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1534);
}
// Coub.TapForSound
NSString * _Nonnull _LCB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1535);
}
// CreateGroup.ChannelsTooMuch
NSString * _Nonnull _LCC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1536);
}
// CreateGroup.ErrorLocatedGroupsTooMuch
NSString * _Nonnull _LCD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1537);
}
// CreateGroup.SoftUserLimitAlert
NSString * _Nonnull _LCE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1538);
}
// CreatePoll.AddMoreOptions
NSString * _Nonnull _LCF(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1539, value);
}
// CreatePoll.AddOption
NSString * _Nonnull _LCG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1540);
}
// CreatePoll.AllOptionsAdded
NSString * _Nonnull _LCH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1541);
}
// CreatePoll.Anonymous
NSString * _Nonnull _LCI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1542);
}
// CreatePoll.CancelConfirmation
NSString * _Nonnull _LCJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1543);
}
// CreatePoll.Create
NSString * _Nonnull _LCK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1544);
}
// CreatePoll.Explanation
NSString * _Nonnull _LCL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1545);
}
// CreatePoll.ExplanationHeader
NSString * _Nonnull _LCM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1546);
}
// CreatePoll.ExplanationInfo
NSString * _Nonnull _LCN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1547);
}
// CreatePoll.MultipleChoice
NSString * _Nonnull _LCO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1548);
}
// CreatePoll.MultipleChoiceQuizAlert
NSString * _Nonnull _LCP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1549);
}
// CreatePoll.OptionPlaceholder
NSString * _Nonnull _LCQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1550);
}
// CreatePoll.OptionsHeader
NSString * _Nonnull _LCR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1551);
}
// CreatePoll.Quiz
NSString * _Nonnull _LCS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1552);
}
// CreatePoll.QuizInfo
NSString * _Nonnull _LCT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1553);
}
// CreatePoll.QuizOptionsHeader
NSString * _Nonnull _LCU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1554);
}
// CreatePoll.QuizTip
NSString * _Nonnull _LCV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1555);
}
// CreatePoll.QuizTitle
NSString * _Nonnull _LCW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1556);
}
// CreatePoll.TextHeader
NSString * _Nonnull _LCX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1557);
}
// CreatePoll.TextPlaceholder
NSString * _Nonnull _LCY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1558);
}
// CreatePoll.Title
NSString * _Nonnull _LCZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1559);
}
// Date.ChatDateHeader
_FormattedString * _Nonnull _LDa(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1560, _0, _1);
}
// Date.ChatDateHeaderYear
_FormattedString * _Nonnull _LDb(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 1561, _0, _1, _2);
}
// Date.DialogDateFormat
NSString * _Nonnull _LDc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1562);
}
// DialogList.AdLabel
NSString * _Nonnull _LDd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1563);
}
// DialogList.AdNoticeAlert
NSString * _Nonnull _LDe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1564);
}
// DialogList.AwaitingEncryption
_FormattedString * _Nonnull _LDf(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1565, _0);
}
// DialogList.ClearHistoryConfirmation
NSString * _Nonnull _LDg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1566);
}
// DialogList.DeleteBotConfirmation
NSString * _Nonnull _LDh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1567);
}
// DialogList.DeleteBotConversationConfirmation
NSString * _Nonnull _LDi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1568);
}
// DialogList.DeleteConversationConfirmation
NSString * _Nonnull _LDj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1569);
}
// DialogList.Draft
NSString * _Nonnull _LDk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1570);
}
// DialogList.EncryptedChatStartedIncoming
_FormattedString * _Nonnull _LDl(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1571, _0);
}
// DialogList.EncryptedChatStartedOutgoing
_FormattedString * _Nonnull _LDm(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1572, _0);
}
// DialogList.EncryptionProcessing
NSString * _Nonnull _LDn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1573);
}
// DialogList.EncryptionRejected
NSString * _Nonnull _LDo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1574);
}
// DialogList.LanguageTooltip
NSString * _Nonnull _LDp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1575);
}
// DialogList.LiveLocationChatsCount
NSString * _Nonnull _LDq(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1576, value);
}
// DialogList.LiveLocationSharingTo
_FormattedString * _Nonnull _LDr(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1577, _0);
}
// DialogList.MultipleTyping
_FormattedString * _Nonnull _LDs(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1578, _0, _1);
}
// DialogList.MultipleTypingPair
_FormattedString * _Nonnull _LDt(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1579, _0, _1);
}
// DialogList.MultipleTypingSuffix
_FormattedString * _Nonnull _LDu(_PresentationStrings * _Nonnull _self, NSInteger _0) {
    return getFormatted1(_self, 1580, @(_0));
}
// DialogList.NoMessagesText
NSString * _Nonnull _LDv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1581);
}
// DialogList.NoMessagesTitle
NSString * _Nonnull _LDw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1582);
}
// DialogList.PasscodeLockHelp
NSString * _Nonnull _LDx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1583);
}
// DialogList.Pin
NSString * _Nonnull _LDy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1584);
}
// DialogList.PinLimitError
_FormattedString * _Nonnull _LDz(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1585, _0);
}
// DialogList.ProxyConnectionIssuesTooltip
NSString * _Nonnull _LDA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1586);
}
// DialogList.Read
NSString * _Nonnull _LDB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1587);
}
// DialogList.RecentTitlePeople
NSString * _Nonnull _LDC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1588);
}
// DialogList.Replies
NSString * _Nonnull _LDD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1589);
}
// DialogList.SavedMessages
NSString * _Nonnull _LDE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1590);
}
// DialogList.SavedMessagesHelp
NSString * _Nonnull _LDF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1591);
}
// DialogList.SavedMessagesTooltip
NSString * _Nonnull _LDG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1592);
}
// DialogList.SearchLabel
NSString * _Nonnull _LDH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1593);
}
// DialogList.SearchSectionChats
NSString * _Nonnull _LDI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1594);
}
// DialogList.SearchSectionDialogs
NSString * _Nonnull _LDJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1595);
}
// DialogList.SearchSectionGlobal
NSString * _Nonnull _LDK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1596);
}
// DialogList.SearchSectionMessages
NSString * _Nonnull _LDL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1597);
}
// DialogList.SearchSectionRecent
NSString * _Nonnull _LDM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1598);
}
// DialogList.SearchSubtitleFormat
_FormattedString * _Nonnull _LDN(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1599, _0, _1);
}
// DialogList.SinglePlayingGameSuffix
_FormattedString * _Nonnull _LDO(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1600, _0);
}
// DialogList.SingleRecordingAudioSuffix
_FormattedString * _Nonnull _LDP(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1601, _0);
}
// DialogList.SingleRecordingVideoMessageSuffix
_FormattedString * _Nonnull _LDQ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1602, _0);
}
// DialogList.SingleTypingSuffix
_FormattedString * _Nonnull _LDR(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1603, _0);
}
// DialogList.SingleUploadingFileSuffix
_FormattedString * _Nonnull _LDS(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1604, _0);
}
// DialogList.SingleUploadingPhotoSuffix
_FormattedString * _Nonnull _LDT(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1605, _0);
}
// DialogList.SingleUploadingVideoSuffix
_FormattedString * _Nonnull _LDU(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1606, _0);
}
// DialogList.TabTitle
NSString * _Nonnull _LDV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1607);
}
// DialogList.Title
NSString * _Nonnull _LDW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1608);
}
// DialogList.Typing
NSString * _Nonnull _LDX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1609);
}
// DialogList.UnknownPinLimitError
NSString * _Nonnull _LDY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1610);
}
// DialogList.Unpin
NSString * _Nonnull _LDZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1611);
}
// DialogList.Unread
NSString * _Nonnull _LEa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1612);
}
// DialogList.You
NSString * _Nonnull _LEb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1613);
}
// Document.TargetConfirmationFormat
NSString * _Nonnull _LEc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1614);
}
// DownloadingStatus
_FormattedString * _Nonnull _LEd(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1615, _0, _1);
}
// EditProfile.NameAndPhotoHelp
NSString * _Nonnull _LEe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1616);
}
// EditProfile.NameAndPhotoOrVideoHelp
NSString * _Nonnull _LEf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1617);
}
// EditProfile.Title
NSString * _Nonnull _LEg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1618);
}
// EditTheme.ChangeColors
NSString * _Nonnull _LEh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1619);
}
// EditTheme.Create.BottomInfo
NSString * _Nonnull _LEi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1620);
}
// EditTheme.Create.Preview.IncomingReplyName
NSString * _Nonnull _LEj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1621);
}
// EditTheme.Create.Preview.IncomingReplyText
NSString * _Nonnull _LEk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1622);
}
// EditTheme.Create.Preview.IncomingText
NSString * _Nonnull _LEl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1623);
}
// EditTheme.Create.Preview.OutgoingText
NSString * _Nonnull _LEm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1624);
}
// EditTheme.Create.TopInfo
NSString * _Nonnull _LEn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1625);
}
// EditTheme.CreateTitle
NSString * _Nonnull _LEo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1626);
}
// EditTheme.Edit.BottomInfo
NSString * _Nonnull _LEp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1627);
}
// EditTheme.Edit.Preview.IncomingReplyName
NSString * _Nonnull _LEq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1628);
}
// EditTheme.Edit.Preview.IncomingReplyText
NSString * _Nonnull _LEr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1629);
}
// EditTheme.Edit.Preview.IncomingText
NSString * _Nonnull _LEs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1630);
}
// EditTheme.Edit.Preview.OutgoingText
NSString * _Nonnull _LEt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1631);
}
// EditTheme.Edit.TopInfo
NSString * _Nonnull _LEu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1632);
}
// EditTheme.EditTitle
NSString * _Nonnull _LEv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1633);
}
// EditTheme.ErrorInvalidCharacters
NSString * _Nonnull _LEw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1634);
}
// EditTheme.ErrorLinkTaken
NSString * _Nonnull _LEx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1635);
}
// EditTheme.Expand.BottomInfo
NSString * _Nonnull _LEy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1636);
}
// EditTheme.Expand.Preview.IncomingReplyName
NSString * _Nonnull _LEz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1637);
}
// EditTheme.Expand.Preview.IncomingReplyText
NSString * _Nonnull _LEA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1638);
}
// EditTheme.Expand.Preview.IncomingText
NSString * _Nonnull _LEB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1639);
}
// EditTheme.Expand.Preview.OutgoingText
NSString * _Nonnull _LEC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1640);
}
// EditTheme.Expand.TopInfo
NSString * _Nonnull _LED(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1641);
}
// EditTheme.FileReadError
NSString * _Nonnull _LEE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1642);
}
// EditTheme.Preview
NSString * _Nonnull _LEF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1643);
}
// EditTheme.ShortLink
NSString * _Nonnull _LEG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1644);
}
// EditTheme.ThemeTemplateAlertText
NSString * _Nonnull _LEH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1645);
}
// EditTheme.ThemeTemplateAlertTitle
NSString * _Nonnull _LEI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1646);
}
// EditTheme.Title
NSString * _Nonnull _LEJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1647);
}
// EditTheme.UploadEditedTheme
NSString * _Nonnull _LEK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1648);
}
// EditTheme.UploadNewTheme
NSString * _Nonnull _LEL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1649);
}
// Embed.PlayingInPIP
NSString * _Nonnull _LEM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1650);
}
// EmptyGroupInfo.Line1
_FormattedString * _Nonnull _LEN(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1651, _0);
}
// EmptyGroupInfo.Line2
NSString * _Nonnull _LEO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1652);
}
// EmptyGroupInfo.Line3
NSString * _Nonnull _LEP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1653);
}
// EmptyGroupInfo.Line4
NSString * _Nonnull _LEQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1654);
}
// EmptyGroupInfo.Subtitle
NSString * _Nonnull _LER(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1655);
}
// EmptyGroupInfo.Title
NSString * _Nonnull _LES(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1656);
}
// EncryptionKey.Description
_FormattedString * _Nonnull _LET(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1657, _0, _1);
}
// EncryptionKey.Title
NSString * _Nonnull _LEU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1658);
}
// EnterPasscode.ChangeTitle
NSString * _Nonnull _LEV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1659);
}
// EnterPasscode.EnterCurrentPasscode
NSString * _Nonnull _LEW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1660);
}
// EnterPasscode.EnterNewPasscodeChange
NSString * _Nonnull _LEX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1661);
}
// EnterPasscode.EnterNewPasscodeNew
NSString * _Nonnull _LEY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1662);
}
// EnterPasscode.EnterPasscode
NSString * _Nonnull _LEZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1663);
}
// EnterPasscode.EnterTitle
NSString * _Nonnull _LFa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1664);
}
// EnterPasscode.RepeatNewPasscode
NSString * _Nonnull _LFb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1665);
}
// EnterPasscode.TouchId
NSString * _Nonnull _LFc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1666);
}
// Exceptions.AddToExceptions
NSString * _Nonnull _LFd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1667);
}
// ExplicitContent.AlertChannel
NSString * _Nonnull _LFe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1668);
}
// ExplicitContent.AlertTitle
NSString * _Nonnull _LFf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1669);
}
// External.OpenIn
_FormattedString * _Nonnull _LFg(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1670, _0);
}
// FastTwoStepSetup.EmailHelp
NSString * _Nonnull _LFh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1671);
}
// FastTwoStepSetup.EmailPlaceholder
NSString * _Nonnull _LFi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1672);
}
// FastTwoStepSetup.EmailSection
NSString * _Nonnull _LFj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1673);
}
// FastTwoStepSetup.HintHelp
NSString * _Nonnull _LFk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1674);
}
// FastTwoStepSetup.HintPlaceholder
NSString * _Nonnull _LFl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1675);
}
// FastTwoStepSetup.HintSection
NSString * _Nonnull _LFm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1676);
}
// FastTwoStepSetup.PasswordConfirmationPlaceholder
NSString * _Nonnull _LFn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1677);
}
// FastTwoStepSetup.PasswordHelp
NSString * _Nonnull _LFo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1678);
}
// FastTwoStepSetup.PasswordPlaceholder
NSString * _Nonnull _LFp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1679);
}
// FastTwoStepSetup.PasswordSection
NSString * _Nonnull _LFq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1680);
}
// FastTwoStepSetup.Title
NSString * _Nonnull _LFr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1681);
}
// FeatureDisabled.Oops
NSString * _Nonnull _LFs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1682);
}
// FeaturedStickerPacks.Title
NSString * _Nonnull _LFt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1683);
}
// FeaturedStickers.OtherSection
NSString * _Nonnull _LFu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1684);
}
// FileSize.B
_FormattedString * _Nonnull _LFv(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1685, _0);
}
// FileSize.GB
_FormattedString * _Nonnull _LFw(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1686, _0);
}
// FileSize.KB
_FormattedString * _Nonnull _LFx(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1687, _0);
}
// FileSize.MB
_FormattedString * _Nonnull _LFy(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1688, _0);
}
// Forward.ChannelReadOnly
NSString * _Nonnull _LFz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1689);
}
// Forward.ConfirmMultipleFiles
NSString * _Nonnull _LFA(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1690, value);
}
// Forward.ErrorDisabledForChat
NSString * _Nonnull _LFB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1691);
}
// Forward.ErrorPublicPollDisabledInChannels
NSString * _Nonnull _LFC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1692);
}
// Forward.ErrorPublicQuizDisabledInChannels
NSString * _Nonnull _LFD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1693);
}
// ForwardedAudios
NSString * _Nonnull _LFE(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1694, value);
}
// ForwardedAuthors2
_FormattedString * _Nonnull _LFF(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1695, _0, _1);
}
// ForwardedAuthorsOthers
NSString * _Nonnull _LFG(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1696, value);
}
// ForwardedContacts
NSString * _Nonnull _LFH(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1697, value);
}
// ForwardedFiles
NSString * _Nonnull _LFI(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1698, value);
}
// ForwardedGifs
NSString * _Nonnull _LFJ(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1699, value);
}
// ForwardedLocations
NSString * _Nonnull _LFK(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1700, value);
}
// ForwardedMessages
NSString * _Nonnull _LFL(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1701, value);
}
// ForwardedPhotos
NSString * _Nonnull _LFM(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1702, value);
}
// ForwardedPolls
NSString * _Nonnull _LFN(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1703, value);
}
// ForwardedStickers
NSString * _Nonnull _LFO(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1704, value);
}
// ForwardedVideoMessages
NSString * _Nonnull _LFP(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1705, value);
}
// ForwardedVideos
NSString * _Nonnull _LFQ(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1706, value);
}
// Generic.ErrorMoreInfo
NSString * _Nonnull _LFR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1707);
}
// Generic.OpenHiddenLinkAlert
_FormattedString * _Nonnull _LFS(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1708, _0);
}
// Gif.NoGifsFound
NSString * _Nonnull _LFT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1709);
}
// Gif.NoGifsPlaceholder
NSString * _Nonnull _LFU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1710);
}
// Gif.Search
NSString * _Nonnull _LFV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1711);
}
// Group.About.Help
NSString * _Nonnull _LFW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1712);
}
// Group.AdminLog.EmptyText
NSString * _Nonnull _LFX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1713);
}
// Group.DeleteGroup
NSString * _Nonnull _LFY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1714);
}
// Group.EditAdmin.PermissionChangeInfo
NSString * _Nonnull _LFZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1715);
}
// Group.EditAdmin.RankAdminPlaceholder
NSString * _Nonnull _LGa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1716);
}
// Group.EditAdmin.RankInfo
_FormattedString * _Nonnull _LGb(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1717, _0);
}
// Group.EditAdmin.RankOwnerPlaceholder
NSString * _Nonnull _LGc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1718);
}
// Group.EditAdmin.RankTitle
NSString * _Nonnull _LGd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1719);
}
// Group.EditAdmin.TransferOwnership
NSString * _Nonnull _LGe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1720);
}
// Group.ErrorAccessDenied
NSString * _Nonnull _LGf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1721);
}
// Group.ErrorAddBlocked
NSString * _Nonnull _LGg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1722);
}
// Group.ErrorAddTooMuchAdmins
NSString * _Nonnull _LGh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1723);
}
// Group.ErrorAddTooMuchBots
NSString * _Nonnull _LGi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1724);
}
// Group.ErrorAdminsTooMuch
NSString * _Nonnull _LGj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1725);
}
// Group.ErrorNotMutualContact
NSString * _Nonnull _LGk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1726);
}
// Group.ErrorSendRestrictedMedia
NSString * _Nonnull _LGl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1727);
}
// Group.ErrorSendRestrictedStickers
NSString * _Nonnull _LGm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1728);
}
// Group.ErrorSupergroupConversionNotPossible
NSString * _Nonnull _LGn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1729);
}
// Group.GroupMembersHeader
NSString * _Nonnull _LGo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1730);
}
// Group.Info.AdminLog
NSString * _Nonnull _LGp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1731);
}
// Group.Info.Members
NSString * _Nonnull _LGq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1732);
}
// Group.LeaveGroup
NSString * _Nonnull _LGr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1733);
}
// Group.LinkedChannel
NSString * _Nonnull _LGs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1734);
}
// Group.Location.ChangeLocation
NSString * _Nonnull _LGt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1735);
}
// Group.Location.CreateInThisPlace
NSString * _Nonnull _LGu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1736);
}
// Group.Location.Info
NSString * _Nonnull _LGv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1737);
}
// Group.Location.Title
NSString * _Nonnull _LGw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1738);
}
// Group.Management.AddModeratorHelp
NSString * _Nonnull _LGx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1739);
}
// Group.Members.AddMemberBotErrorNotAllowed
NSString * _Nonnull _LGy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1740);
}
// Group.Members.AddMembers
NSString * _Nonnull _LGz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1741);
}
// Group.Members.AddMembersHelp
NSString * _Nonnull _LGA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1742);
}
// Group.Members.Title
NSString * _Nonnull _LGB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1743);
}
// Group.MessagePhotoRemoved
NSString * _Nonnull _LGC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1744);
}
// Group.MessagePhotoUpdated
NSString * _Nonnull _LGD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1745);
}
// Group.MessageVideoUpdated
NSString * _Nonnull _LGE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1746);
}
// Group.OwnershipTransfer.DescriptionInfo
_FormattedString * _Nonnull _LGF(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1747, _0, _1);
}
// Group.OwnershipTransfer.ErrorAdminsTooMuch
NSString * _Nonnull _LGG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1748);
}
// Group.OwnershipTransfer.ErrorLocatedGroupsTooMuch
NSString * _Nonnull _LGH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1749);
}
// Group.OwnershipTransfer.ErrorPrivacyRestricted
NSString * _Nonnull _LGI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1750);
}
// Group.OwnershipTransfer.Title
NSString * _Nonnull _LGJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1751);
}
// Group.PublicLink.Info
NSString * _Nonnull _LGK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1752);
}
// Group.PublicLink.Placeholder
NSString * _Nonnull _LGL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1753);
}
// Group.PublicLink.Title
NSString * _Nonnull _LGM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1754);
}
// Group.Setup.BasicHistoryHiddenHelp
NSString * _Nonnull _LGN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1755);
}
// Group.Setup.HistoryHeader
NSString * _Nonnull _LGO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1756);
}
// Group.Setup.HistoryHidden
NSString * _Nonnull _LGP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1757);
}
// Group.Setup.HistoryHiddenHelp
NSString * _Nonnull _LGQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1758);
}
// Group.Setup.HistoryTitle
NSString * _Nonnull _LGR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1759);
}
// Group.Setup.HistoryVisible
NSString * _Nonnull _LGS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1760);
}
// Group.Setup.HistoryVisibleHelp
NSString * _Nonnull _LGT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1761);
}
// Group.Setup.TypeHeader
NSString * _Nonnull _LGU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1762);
}
// Group.Setup.TypePrivate
NSString * _Nonnull _LGV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1763);
}
// Group.Setup.TypePrivateHelp
NSString * _Nonnull _LGW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1764);
}
// Group.Setup.TypePublic
NSString * _Nonnull _LGX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1765);
}
// Group.Setup.TypePublicHelp
NSString * _Nonnull _LGY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1766);
}
// Group.Status
NSString * _Nonnull _LGZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1767);
}
// Group.UpgradeConfirmation
NSString * _Nonnull _LHa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1768);
}
// Group.UpgradeNoticeHeader
NSString * _Nonnull _LHb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1769);
}
// Group.UpgradeNoticeText1
NSString * _Nonnull _LHc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1770);
}
// Group.UpgradeNoticeText2
NSString * _Nonnull _LHd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1771);
}
// Group.Username.CreatePrivateLinkHelp
NSString * _Nonnull _LHe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1772);
}
// Group.Username.CreatePublicLinkHelp
NSString * _Nonnull _LHf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1773);
}
// Group.Username.InvalidStartsWithNumber
NSString * _Nonnull _LHg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1774);
}
// Group.Username.InvalidTooShort
NSString * _Nonnull _LHh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1775);
}
// Group.Username.RemoveExistingUsernamesInfo
NSString * _Nonnull _LHi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1776);
}
// Group.Username.RevokeExistingUsernamesInfo
NSString * _Nonnull _LHj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1777);
}
// GroupInfo.ActionPromote
NSString * _Nonnull _LHk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1778);
}
// GroupInfo.ActionRestrict
NSString * _Nonnull _LHl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1779);
}
// GroupInfo.AddParticipant
NSString * _Nonnull _LHm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1780);
}
// GroupInfo.AddParticipantConfirmation
_FormattedString * _Nonnull _LHn(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1781, _0);
}
// GroupInfo.AddParticipantTitle
NSString * _Nonnull _LHo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1782);
}
// GroupInfo.AddUserLeftError
NSString * _Nonnull _LHp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1783);
}
// GroupInfo.Administrators
NSString * _Nonnull _LHq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1784);
}
// GroupInfo.Administrators.Title
NSString * _Nonnull _LHr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1785);
}
// GroupInfo.BroadcastListNamePlaceholder
NSString * _Nonnull _LHs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1786);
}
// GroupInfo.ChannelListNamePlaceholder
NSString * _Nonnull _LHt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1787);
}
// GroupInfo.ChatAdmins
NSString * _Nonnull _LHu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1788);
}
// GroupInfo.ConvertToSupergroup
NSString * _Nonnull _LHv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1789);
}
// GroupInfo.DeactivatedStatus
NSString * _Nonnull _LHw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1790);
}
// GroupInfo.DeleteAndExit
NSString * _Nonnull _LHx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1791);
}
// GroupInfo.DeleteAndExitConfirmation
NSString * _Nonnull _LHy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1792);
}
// GroupInfo.FakeGroupWarning
NSString * _Nonnull _LHz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1793);
}
// GroupInfo.GroupHistory
NSString * _Nonnull _LHA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1794);
}
// GroupInfo.GroupHistoryHidden
NSString * _Nonnull _LHB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1795);
}
// GroupInfo.GroupHistoryShort
NSString * _Nonnull _LHC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1796);
}
// GroupInfo.GroupHistoryVisible
NSString * _Nonnull _LHD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1797);
}
// GroupInfo.GroupNamePlaceholder
NSString * _Nonnull _LHE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1798);
}
// GroupInfo.GroupType
NSString * _Nonnull _LHF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1799);
}
// GroupInfo.InvitationLinkAcceptChannel
_FormattedString * _Nonnull _LHG(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1800, _0);
}
// GroupInfo.InvitationLinkDoesNotExist
NSString * _Nonnull _LHH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1801);
}
// GroupInfo.InvitationLinkGroupFull
NSString * _Nonnull _LHI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1802);
}
// GroupInfo.InviteByLink
NSString * _Nonnull _LHJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1803);
}
// GroupInfo.InviteLink.CopyAlert.Success
NSString * _Nonnull _LHK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1804);
}
// GroupInfo.InviteLink.CopyLink
NSString * _Nonnull _LHL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1805);
}
// GroupInfo.InviteLink.Help
NSString * _Nonnull _LHM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1806);
}
// GroupInfo.InviteLink.LinkSection
NSString * _Nonnull _LHN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1807);
}
// GroupInfo.InviteLink.RevokeAlert.Revoke
NSString * _Nonnull _LHO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1808);
}
// GroupInfo.InviteLink.RevokeAlert.Success
NSString * _Nonnull _LHP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1809);
}
// GroupInfo.InviteLink.RevokeAlert.Text
NSString * _Nonnull _LHQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1810);
}
// GroupInfo.InviteLink.RevokeLink
NSString * _Nonnull _LHR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1811);
}
// GroupInfo.InviteLink.ShareLink
NSString * _Nonnull _LHS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1812);
}
// GroupInfo.InviteLink.Title
NSString * _Nonnull _LHT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1813);
}
// GroupInfo.InviteLinks
NSString * _Nonnull _LHU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1814);
}
// GroupInfo.LabelAdmin
NSString * _Nonnull _LHV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1815);
}
// GroupInfo.LabelOwner
NSString * _Nonnull _LHW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1816);
}
// GroupInfo.LeftStatus
NSString * _Nonnull _LHX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1817);
}
// GroupInfo.Location
NSString * _Nonnull _LHY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1818);
}
// GroupInfo.Notifications
NSString * _Nonnull _LHZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1819);
}
// GroupInfo.ParticipantCount
NSString * _Nonnull _LIa(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1820, value);
}
// GroupInfo.Permissions
NSString * _Nonnull _LIb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1821);
}
// GroupInfo.Permissions.AddException
NSString * _Nonnull _LIc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1822);
}
// GroupInfo.Permissions.BroadcastConvert
NSString * _Nonnull _LId(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1823);
}
// GroupInfo.Permissions.BroadcastConvertInfo
_FormattedString * _Nonnull _LIe(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1824, _0);
}
// GroupInfo.Permissions.BroadcastTitle
NSString * _Nonnull _LIf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1825);
}
// GroupInfo.Permissions.EditingDisabled
NSString * _Nonnull _LIg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1826);
}
// GroupInfo.Permissions.Exceptions
NSString * _Nonnull _LIh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1827);
}
// GroupInfo.Permissions.Removed
NSString * _Nonnull _LIi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1828);
}
// GroupInfo.Permissions.SearchPlaceholder
NSString * _Nonnull _LIj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1829);
}
// GroupInfo.Permissions.SectionTitle
NSString * _Nonnull _LIk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1830);
}
// GroupInfo.Permissions.SlowmodeHeader
NSString * _Nonnull _LIl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1831);
}
// GroupInfo.Permissions.SlowmodeInfo
NSString * _Nonnull _LIm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1832);
}
// GroupInfo.Permissions.SlowmodeValue.Off
NSString * _Nonnull _LIn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1833);
}
// GroupInfo.Permissions.Title
NSString * _Nonnull _LIo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1834);
}
// GroupInfo.PublicLink
NSString * _Nonnull _LIp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1835);
}
// GroupInfo.PublicLinkAdd
NSString * _Nonnull _LIq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1836);
}
// GroupInfo.ScamGroupWarning
NSString * _Nonnull _LIr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1837);
}
// GroupInfo.SetGroupPhoto
NSString * _Nonnull _LIs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1838);
}
// GroupInfo.SetGroupPhotoDelete
NSString * _Nonnull _LIt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1839);
}
// GroupInfo.SetGroupPhotoStop
NSString * _Nonnull _LIu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1840);
}
// GroupInfo.SetSound
NSString * _Nonnull _LIv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1841);
}
// GroupInfo.SharedMedia
NSString * _Nonnull _LIw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1842);
}
// GroupInfo.SharedMediaNone
NSString * _Nonnull _LIx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1843);
}
// GroupInfo.ShowMoreMembers
NSString * _Nonnull _LIy(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1844, value);
}
// GroupInfo.Sound
NSString * _Nonnull _LIz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1845);
}
// GroupInfo.Title
NSString * _Nonnull _LIA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1846);
}
// GroupInfo.UpgradeButton
NSString * _Nonnull _LIB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1847);
}
// GroupPermission.AddMembersNotAvailable
NSString * _Nonnull _LIC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1848);
}
// GroupPermission.AddSuccess
NSString * _Nonnull _LID(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1849);
}
// GroupPermission.AddedInfo
_FormattedString * _Nonnull _LIE(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1850, _0, _1);
}
// GroupPermission.ApplyAlertAction
NSString * _Nonnull _LIF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1851);
}
// GroupPermission.ApplyAlertText
_FormattedString * _Nonnull _LIG(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1852, _0);
}
// GroupPermission.Delete
NSString * _Nonnull _LIH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1853);
}
// GroupPermission.Duration
NSString * _Nonnull _LII(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1854);
}
// GroupPermission.EditingDisabled
NSString * _Nonnull _LIJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1855);
}
// GroupPermission.NewTitle
NSString * _Nonnull _LIK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1856);
}
// GroupPermission.NoAddMembers
NSString * _Nonnull _LIL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1857);
}
// GroupPermission.NoChangeInfo
NSString * _Nonnull _LIM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1858);
}
// GroupPermission.NoPinMessages
NSString * _Nonnull _LIN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1859);
}
// GroupPermission.NoSendGifs
NSString * _Nonnull _LIO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1860);
}
// GroupPermission.NoSendLinks
NSString * _Nonnull _LIP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1861);
}
// GroupPermission.NoSendMedia
NSString * _Nonnull _LIQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1862);
}
// GroupPermission.NoSendMessages
NSString * _Nonnull _LIR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1863);
}
// GroupPermission.NoSendPolls
NSString * _Nonnull _LIS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1864);
}
// GroupPermission.NotAvailableInPublicGroups
NSString * _Nonnull _LIT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1865);
}
// GroupPermission.PermissionDisabledByDefault
NSString * _Nonnull _LIU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1866);
}
// GroupPermission.PermissionGloballyDisabled
NSString * _Nonnull _LIV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1867);
}
// GroupPermission.SectionTitle
NSString * _Nonnull _LIW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1868);
}
// GroupPermission.Title
NSString * _Nonnull _LIX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1869);
}
// GroupRemoved.AddToGroup
NSString * _Nonnull _LIY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1870);
}
// GroupRemoved.DeleteUser
NSString * _Nonnull _LIZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1871);
}
// GroupRemoved.Remove
NSString * _Nonnull _LJa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1872);
}
// GroupRemoved.RemoveInfo
NSString * _Nonnull _LJb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1873);
}
// GroupRemoved.Title
NSString * _Nonnull _LJc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1874);
}
// GroupRemoved.UsersSectionTitle
NSString * _Nonnull _LJd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1875);
}
// GroupRemoved.ViewChannelInfo
NSString * _Nonnull _LJe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1876);
}
// GroupRemoved.ViewUserInfo
NSString * _Nonnull _LJf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1877);
}
// HashtagSearch.AllChats
NSString * _Nonnull _LJg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1878);
}
// ImportStickerPack.AddToExistingStickerSet
NSString * _Nonnull _LJh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1879);
}
// ImportStickerPack.CheckingLink
NSString * _Nonnull _LJi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1880);
}
// ImportStickerPack.ChooseLink
NSString * _Nonnull _LJj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1881);
}
// ImportStickerPack.ChooseLinkDescription
NSString * _Nonnull _LJk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1882);
}
// ImportStickerPack.ChooseName
NSString * _Nonnull _LJl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1883);
}
// ImportStickerPack.ChooseNameDescription
NSString * _Nonnull _LJm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1884);
}
// ImportStickerPack.ChooseStickerSet
NSString * _Nonnull _LJn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1885);
}
// ImportStickerPack.Create
NSString * _Nonnull _LJo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1886);
}
// ImportStickerPack.CreateNewStickerSet
NSString * _Nonnull _LJp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1887);
}
// ImportStickerPack.CreateStickerSet
NSString * _Nonnull _LJq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1888);
}
// ImportStickerPack.GeneratingLink
NSString * _Nonnull _LJr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1889);
}
// ImportStickerPack.ImportingStickers
NSString * _Nonnull _LJs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1890);
}
// ImportStickerPack.InProgress
NSString * _Nonnull _LJt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1891);
}
// ImportStickerPack.LinkAvailable
NSString * _Nonnull _LJu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1892);
}
// ImportStickerPack.LinkTaken
NSString * _Nonnull _LJv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1893);
}
// ImportStickerPack.NamePlaceholder
NSString * _Nonnull _LJw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1894);
}
// ImportStickerPack.Of
_FormattedString * _Nonnull _LJx(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1895, _0, _1);
}
// ImportStickerPack.RemoveFromImport
NSString * _Nonnull _LJy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1896);
}
// ImportStickerPack.StickerCount
NSString * _Nonnull _LJz(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1897, value);
}
// InfoPlist.NSCameraUsageDescription
NSString * _Nonnull _LJA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1898);
}
// InfoPlist.NSContactsUsageDescription
NSString * _Nonnull _LJB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1899);
}
// InfoPlist.NSFaceIDUsageDescription
NSString * _Nonnull _LJC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1900);
}
// InfoPlist.NSLocationAlwaysAndWhenInUseUsageDescription
NSString * _Nonnull _LJD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1901);
}
// InfoPlist.NSLocationAlwaysUsageDescription
NSString * _Nonnull _LJE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1902);
}
// InfoPlist.NSLocationWhenInUseUsageDescription
NSString * _Nonnull _LJF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1903);
}
// InfoPlist.NSMicrophoneUsageDescription
NSString * _Nonnull _LJG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1904);
}
// InfoPlist.NSPhotoLibraryAddUsageDescription
NSString * _Nonnull _LJH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1905);
}
// InfoPlist.NSPhotoLibraryUsageDescription
NSString * _Nonnull _LJI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1906);
}
// InfoPlist.NSSiriUsageDescription
NSString * _Nonnull _LJJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1907);
}
// InstantPage.AuthorAndDateTitle
_FormattedString * _Nonnull _LJK(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1908, _0, _1);
}
// InstantPage.AutoNightTheme
NSString * _Nonnull _LJL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1909);
}
// InstantPage.FeedbackButton
NSString * _Nonnull _LJM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1910);
}
// InstantPage.FeedbackButtonShort
NSString * _Nonnull _LJN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1911);
}
// InstantPage.FontNewYork
NSString * _Nonnull _LJO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1912);
}
// InstantPage.FontSanFrancisco
NSString * _Nonnull _LJP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1913);
}
// InstantPage.OpenInBrowser
_FormattedString * _Nonnull _LJQ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1914, _0);
}
// InstantPage.Reference
NSString * _Nonnull _LJR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1915);
}
// InstantPage.RelatedArticleAuthorAndDateTitle
_FormattedString * _Nonnull _LJS(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1916, _0, _1);
}
// InstantPage.Search
NSString * _Nonnull _LJT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1917);
}
// InstantPage.TapToOpenLink
NSString * _Nonnull _LJU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1918);
}
// InstantPage.Views
NSString * _Nonnull _LJV(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1919, value);
}
// InstantPage.VoiceOver.DecreaseFontSize
NSString * _Nonnull _LJW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1920);
}
// InstantPage.VoiceOver.IncreaseFontSize
NSString * _Nonnull _LJX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1921);
}
// InstantPage.VoiceOver.ResetFontSize
NSString * _Nonnull _LJY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1922);
}
// Intents.ErrorLockedText
NSString * _Nonnull _LJZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1923);
}
// Intents.ErrorLockedTitle
NSString * _Nonnull _LKa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1924);
}
// IntentsSettings.MainAccount
NSString * _Nonnull _LKb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1925);
}
// IntentsSettings.MainAccountInfo
NSString * _Nonnull _LKc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1926);
}
// IntentsSettings.Reset
NSString * _Nonnull _LKd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1927);
}
// IntentsSettings.ResetAll
NSString * _Nonnull _LKe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1928);
}
// IntentsSettings.SuggestBy
NSString * _Nonnull _LKf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1929);
}
// IntentsSettings.SuggestByAll
NSString * _Nonnull _LKg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1930);
}
// IntentsSettings.SuggestByShare
NSString * _Nonnull _LKh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1931);
}
// IntentsSettings.SuggestedAndSpotlightChatsInfo
NSString * _Nonnull _LKi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1932);
}
// IntentsSettings.SuggestedChats
NSString * _Nonnull _LKj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1933);
}
// IntentsSettings.SuggestedChatsContacts
NSString * _Nonnull _LKk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1934);
}
// IntentsSettings.SuggestedChatsGroups
NSString * _Nonnull _LKl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1935);
}
// IntentsSettings.SuggestedChatsInfo
NSString * _Nonnull _LKm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1936);
}
// IntentsSettings.SuggestedChatsPrivateChats
NSString * _Nonnull _LKn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1937);
}
// IntentsSettings.SuggestedChatsSavedMessages
NSString * _Nonnull _LKo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1938);
}
// IntentsSettings.Title
NSString * _Nonnull _LKp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1939);
}
// Invitation.JoinGroup
NSString * _Nonnull _LKq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1940);
}
// Invitation.JoinVoiceChatAsListener
NSString * _Nonnull _LKr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1941);
}
// Invitation.JoinVoiceChatAsSpeaker
NSString * _Nonnull _LKs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1942);
}
// Invitation.Members
NSString * _Nonnull _LKt(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1943, value);
}
// Invite.ChannelsTooMuch
NSString * _Nonnull _LKu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1944);
}
// Invite.LargeRecipientsCountWarning
NSString * _Nonnull _LKv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1945);
}
// InviteLink.AdditionalLinks
NSString * _Nonnull _LKw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1946);
}
// InviteLink.ContextCopy
NSString * _Nonnull _LKx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1947);
}
// InviteLink.ContextDelete
NSString * _Nonnull _LKy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1948);
}
// InviteLink.ContextEdit
NSString * _Nonnull _LKz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1949);
}
// InviteLink.ContextGetQRCode
NSString * _Nonnull _LKA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1950);
}
// InviteLink.ContextRevoke
NSString * _Nonnull _LKB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1951);
}
// InviteLink.ContextShare
NSString * _Nonnull _LKC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1952);
}
// InviteLink.Create
NSString * _Nonnull _LKD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1953);
}
// InviteLink.Create.EditTitle
NSString * _Nonnull _LKE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1954);
}
// InviteLink.Create.Revoke
NSString * _Nonnull _LKF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1955);
}
// InviteLink.Create.TimeLimit
NSString * _Nonnull _LKG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1956);
}
// InviteLink.Create.TimeLimitExpiryDate
NSString * _Nonnull _LKH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1957);
}
// InviteLink.Create.TimeLimitExpiryDateNever
NSString * _Nonnull _LKI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1958);
}
// InviteLink.Create.TimeLimitExpiryTime
NSString * _Nonnull _LKJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1959);
}
// InviteLink.Create.TimeLimitInfo
NSString * _Nonnull _LKK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1960);
}
// InviteLink.Create.TimeLimitNoLimit
NSString * _Nonnull _LKL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1961);
}
// InviteLink.Create.Title
NSString * _Nonnull _LKM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1962);
}
// InviteLink.Create.UsersLimit
NSString * _Nonnull _LKN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1963);
}
// InviteLink.Create.UsersLimitInfo
NSString * _Nonnull _LKO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1964);
}
// InviteLink.Create.UsersLimitNoLimit
NSString * _Nonnull _LKP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1965);
}
// InviteLink.Create.UsersLimitNumberOfUsers
NSString * _Nonnull _LKQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1966);
}
// InviteLink.Create.UsersLimitNumberOfUsersUnlimited
NSString * _Nonnull _LKR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1967);
}
// InviteLink.CreateInfo
NSString * _Nonnull _LKS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1968);
}
// InviteLink.CreatePrivateLinkHelp
NSString * _Nonnull _LKT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1969);
}
// InviteLink.CreatePrivateLinkHelpChannel
NSString * _Nonnull _LKU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1970);
}
// InviteLink.CreatedBy
NSString * _Nonnull _LKV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1971);
}
// InviteLink.DeleteAllRevokedLinks
NSString * _Nonnull _LKW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1972);
}
// InviteLink.DeleteAllRevokedLinksAlert.Action
NSString * _Nonnull _LKX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1973);
}
// InviteLink.DeleteAllRevokedLinksAlert.Text
NSString * _Nonnull _LKY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1974);
}
// InviteLink.DeleteLinkAlert.Action
NSString * _Nonnull _LKZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1975);
}
// InviteLink.DeleteLinkAlert.Text
NSString * _Nonnull _LLa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1976);
}
// InviteLink.Expired
NSString * _Nonnull _LLb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1977);
}
// InviteLink.ExpiredLink
NSString * _Nonnull _LLc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1978);
}
// InviteLink.ExpiredLinkStatus
NSString * _Nonnull _LLd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1979);
}
// InviteLink.ExpiresIn
_FormattedString * _Nonnull _LLe(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 1980, _0);
}
// InviteLink.InviteLink
NSString * _Nonnull _LLf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1981);
}
// InviteLink.InviteLinkCopiedText
NSString * _Nonnull _LLg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1982);
}
// InviteLink.InviteLinkRevoked
NSString * _Nonnull _LLh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1983);
}
// InviteLink.InviteLinks
NSString * _Nonnull _LLi(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1984, value);
}
// InviteLink.Manage
NSString * _Nonnull _LLj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1985);
}
// InviteLink.OtherAdminsLinks
NSString * _Nonnull _LLk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1986);
}
// InviteLink.OtherPermanentLinkInfo
_FormattedString * _Nonnull _LLl(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 1987, _0, _1);
}
// InviteLink.PeopleCanJoin
NSString * _Nonnull _LLm(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1988, value);
}
// InviteLink.PeopleJoined
NSString * _Nonnull _LLn(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1989, value);
}
// InviteLink.PeopleJoinedNone
NSString * _Nonnull _LLo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1990);
}
// InviteLink.PeopleJoinedShort
NSString * _Nonnull _LLp(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1991, value);
}
// InviteLink.PeopleJoinedShortNone
NSString * _Nonnull _LLq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1992);
}
// InviteLink.PeopleJoinedShortNoneExpired
NSString * _Nonnull _LLr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1993);
}
// InviteLink.PeopleRemaining
NSString * _Nonnull _LLs(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 1994, value);
}
// InviteLink.PermanentLink
NSString * _Nonnull _LLt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1995);
}
// InviteLink.PublicLink
NSString * _Nonnull _LLu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1996);
}
// InviteLink.QRCode.Info
NSString * _Nonnull _LLv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1997);
}
// InviteLink.QRCode.InfoChannel
NSString * _Nonnull _LLw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1998);
}
// InviteLink.QRCode.Share
NSString * _Nonnull _LLx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 1999);
}
// InviteLink.QRCode.Title
NSString * _Nonnull _LLy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2000);
}
// InviteLink.ReactivateLink
NSString * _Nonnull _LLz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2001);
}
// InviteLink.Revoked
NSString * _Nonnull _LLA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2002);
}
// InviteLink.RevokedLinks
NSString * _Nonnull _LLB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2003);
}
// InviteLink.Share
NSString * _Nonnull _LLC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2004);
}
// InviteLink.Title
NSString * _Nonnull _LLD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2005);
}
// InviteLink.UsageLimitReached
NSString * _Nonnull _LLE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2006);
}
// InviteLinks.InviteLinkExpired
NSString * _Nonnull _LLF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2007);
}
// InviteText.ContactsCountText
NSString * _Nonnull _LLG(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2008, value);
}
// InviteText.SingleContact
_FormattedString * _Nonnull _LLH(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2009, _0);
}
// InviteText.URL
NSString * _Nonnull _LLI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2010);
}
// Items.NOfM
_FormattedString * _Nonnull _LLJ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2011, _0, _1);
}
// Join.ChannelsTooMuch
NSString * _Nonnull _LLK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2012);
}
// KeyCommand.ChatInfo
NSString * _Nonnull _LLL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2013);
}
// KeyCommand.Find
NSString * _Nonnull _LLM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2014);
}
// KeyCommand.FocusOnInputField
NSString * _Nonnull _LLN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2015);
}
// KeyCommand.JumpToNextChat
NSString * _Nonnull _LLO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2016);
}
// KeyCommand.JumpToNextUnreadChat
NSString * _Nonnull _LLP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2017);
}
// KeyCommand.JumpToPreviousChat
NSString * _Nonnull _LLQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2018);
}
// KeyCommand.JumpToPreviousUnreadChat
NSString * _Nonnull _LLR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2019);
}
// KeyCommand.NewMessage
NSString * _Nonnull _LLS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2020);
}
// KeyCommand.ScrollDown
NSString * _Nonnull _LLT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2021);
}
// KeyCommand.ScrollUp
NSString * _Nonnull _LLU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2022);
}
// KeyCommand.SearchInChat
NSString * _Nonnull _LLV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2023);
}
// KeyCommand.SendMessage
NSString * _Nonnull _LLW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2024);
}
// LOCAL_CHANNEL_MESSAGE_FWDS
_FormattedString * _Nonnull _LLX(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSInteger _1) {
    return getFormatted2(_self, 2025, _0, @(_1));
}
// LOCAL_CHAT_MESSAGE_FWDS
_FormattedString * _Nonnull _LLY(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSInteger _1) {
    return getFormatted2(_self, 2026, _0, @(_1));
}
// LOCAL_MESSAGE_FWDS
_FormattedString * _Nonnull _LLZ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSInteger _1) {
    return getFormatted2(_self, 2027, _0, @(_1));
}
// LastSeen.ALongTimeAgo
NSString * _Nonnull _LMa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2028);
}
// LastSeen.AtDate
_FormattedString * _Nonnull _LMb(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2029, _0);
}
// LastSeen.HoursAgo
NSString * _Nonnull _LMc(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2030, value);
}
// LastSeen.JustNow
NSString * _Nonnull _LMd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2031);
}
// LastSeen.Lately
NSString * _Nonnull _LMe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2032);
}
// LastSeen.MinutesAgo
NSString * _Nonnull _LMf(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2033, value);
}
// LastSeen.Offline
NSString * _Nonnull _LMg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2034);
}
// LastSeen.TodayAt
_FormattedString * _Nonnull _LMh(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2035, _0);
}
// LastSeen.WithinAMonth
NSString * _Nonnull _LMi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2036);
}
// LastSeen.WithinAWeek
NSString * _Nonnull _LMj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2037);
}
// LastSeen.YesterdayAt
_FormattedString * _Nonnull _LMk(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2038, _0);
}
// LiveLocation.MenuChatsCount
NSString * _Nonnull _LMl(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2039, value);
}
// LiveLocation.MenuStopAll
NSString * _Nonnull _LMm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2040);
}
// LiveLocationUpdated.JustNow
NSString * _Nonnull _LMn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2041);
}
// LiveLocationUpdated.MinutesAgo
NSString * _Nonnull _LMo(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2042, value);
}
// LiveLocationUpdated.TodayAt
_FormattedString * _Nonnull _LMp(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2043, _0);
}
// LiveLocationUpdated.YesterdayAt
_FormattedString * _Nonnull _LMq(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2044, _0);
}
// LocalGroup.ButtonTitle
NSString * _Nonnull _LMr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2045);
}
// LocalGroup.IrrelevantWarning
NSString * _Nonnull _LMs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2046);
}
// LocalGroup.Text
NSString * _Nonnull _LMt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2047);
}
// LocalGroup.Title
NSString * _Nonnull _LMu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2048);
}
// Localization.ChooseLanguage
NSString * _Nonnull _LMv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2049);
}
// Localization.EnglishLanguageName
NSString * _Nonnull _LMw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2050);
}
// Localization.LanguageCustom
NSString * _Nonnull _LMx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2051);
}
// Localization.LanguageName
NSString * _Nonnull _LMy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2052);
}
// Localization.LanguageOther
NSString * _Nonnull _LMz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2053);
}
// Location.LiveLocationRequired.Description
NSString * _Nonnull _LMA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2054);
}
// Location.LiveLocationRequired.ShareLocation
NSString * _Nonnull _LMB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2055);
}
// Location.LiveLocationRequired.Title
NSString * _Nonnull _LMC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2056);
}
// Location.ProximityAlertCancelled
NSString * _Nonnull _LMD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2057);
}
// Location.ProximityAlertSetText
_FormattedString * _Nonnull _LME(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2058, _0, _1);
}
// Location.ProximityAlertSetTextGroup
_FormattedString * _Nonnull _LMF(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2059, _0);
}
// Location.ProximityAlertSetTitle
NSString * _Nonnull _LMG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2060);
}
// Location.ProximityGroupTip
NSString * _Nonnull _LMH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2061);
}
// Location.ProximityNotification.AlreadyClose
_FormattedString * _Nonnull _LMI(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2062, _0);
}
// Location.ProximityNotification.DistanceKM
NSString * _Nonnull _LMJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2063);
}
// Location.ProximityNotification.DistanceM
NSString * _Nonnull _LMK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2064);
}
// Location.ProximityNotification.DistanceMI
NSString * _Nonnull _LML(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2065);
}
// Location.ProximityNotification.Notify
_FormattedString * _Nonnull _LMM(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2066, _0);
}
// Location.ProximityNotification.NotifyLong
_FormattedString * _Nonnull _LMN(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2067, _0, _1);
}
// Location.ProximityNotification.Title
NSString * _Nonnull _LMO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2068);
}
// Location.ProximityTip
_FormattedString * _Nonnull _LMP(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2069, _0);
}
// Login.BannedPhoneBody
_FormattedString * _Nonnull _LMQ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2070, _0);
}
// Login.BannedPhoneSubject
_FormattedString * _Nonnull _LMR(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2071, _0);
}
// Login.CallRequestState2
NSString * _Nonnull _LMS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2072);
}
// Login.CallRequestState3
NSString * _Nonnull _LMT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2073);
}
// Login.CancelPhoneVerification
NSString * _Nonnull _LMU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2074);
}
// Login.CancelPhoneVerificationContinue
NSString * _Nonnull _LMV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2075);
}
// Login.CancelPhoneVerificationStop
NSString * _Nonnull _LMW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2076);
}
// Login.CancelSignUpConfirmation
NSString * _Nonnull _LMX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2077);
}
// Login.CheckOtherSessionMessages
NSString * _Nonnull _LMY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2078);
}
// Login.Code
NSString * _Nonnull _LMZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2079);
}
// Login.CodeExpired
NSString * _Nonnull _LNa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2080);
}
// Login.CodeExpiredError
NSString * _Nonnull _LNb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2081);
}
// Login.CodeFloodError
NSString * _Nonnull _LNc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2082);
}
// Login.CodeSentCall
NSString * _Nonnull _LNd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2083);
}
// Login.CodeSentInternal
NSString * _Nonnull _LNe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2084);
}
// Login.CodeSentSms
NSString * _Nonnull _LNf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2085);
}
// Login.ContinueWithLocalization
NSString * _Nonnull _LNg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2086);
}
// Login.CountryCode
NSString * _Nonnull _LNh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2087);
}
// Login.EmailCodeBody
_FormattedString * _Nonnull _LNi(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2088, _0);
}
// Login.EmailCodeSubject
_FormattedString * _Nonnull _LNj(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2089, _0);
}
// Login.EmailNotConfiguredError
NSString * _Nonnull _LNk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2090);
}
// Login.EmailPhoneBody
_FormattedString * _Nonnull _LNl(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 2091, _0, _1, _2);
}
// Login.EmailPhoneSubject
_FormattedString * _Nonnull _LNm(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2092, _0);
}
// Login.HaveNotReceivedCodeInternal
NSString * _Nonnull _LNn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2093);
}
// Login.InfoAvatarAdd
NSString * _Nonnull _LNo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2094);
}
// Login.InfoAvatarPhoto
NSString * _Nonnull _LNp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2095);
}
// Login.InfoDeletePhoto
NSString * _Nonnull _LNq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2096);
}
// Login.InfoFirstNamePlaceholder
NSString * _Nonnull _LNr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2097);
}
// Login.InfoHelp
NSString * _Nonnull _LNs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2098);
}
// Login.InfoLastNamePlaceholder
NSString * _Nonnull _LNt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2099);
}
// Login.InfoTitle
NSString * _Nonnull _LNu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2100);
}
// Login.InvalidCodeError
NSString * _Nonnull _LNv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2101);
}
// Login.InvalidCountryCode
NSString * _Nonnull _LNw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2102);
}
// Login.InvalidFirstNameError
NSString * _Nonnull _LNx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2103);
}
// Login.InvalidLastNameError
NSString * _Nonnull _LNy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2104);
}
// Login.InvalidPhoneEmailBody
_FormattedString * _Nonnull _LNz(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2, NSString * _Nonnull _3, NSString * _Nonnull _4) {
    return getFormatted5(_self, 2105, _0, _1, _2, _3, _4);
}
// Login.InvalidPhoneEmailSubject
_FormattedString * _Nonnull _LNA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2106, _0);
}
// Login.InvalidPhoneError
NSString * _Nonnull _LNB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2107);
}
// Login.NetworkError
NSString * _Nonnull _LNC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2108);
}
// Login.PadPhoneHelp
NSString * _Nonnull _LND(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2109);
}
// Login.PadPhoneHelpTitle
NSString * _Nonnull _LNE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2110);
}
// Login.PhoneAndCountryHelp
NSString * _Nonnull _LNF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2111);
}
// Login.PhoneBannedEmailBody
_FormattedString * _Nonnull _LNG(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2, NSString * _Nonnull _3, NSString * _Nonnull _4) {
    return getFormatted5(_self, 2112, _0, _1, _2, _3, _4);
}
// Login.PhoneBannedEmailSubject
_FormattedString * _Nonnull _LNH(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2113, _0);
}
// Login.PhoneBannedError
NSString * _Nonnull _LNI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2114);
}
// Login.PhoneFloodError
NSString * _Nonnull _LNJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2115);
}
// Login.PhoneGenericEmailBody
_FormattedString * _Nonnull _LNK(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2, NSString * _Nonnull _3, NSString * _Nonnull _4, NSString * _Nonnull _5) {
    return getFormatted6(_self, 2116, _0, _1, _2, _3, _4, _5);
}
// Login.PhoneGenericEmailSubject
_FormattedString * _Nonnull _LNL(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2117, _0);
}
// Login.PhoneNumberAlreadyAuthorized
NSString * _Nonnull _LNM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2118);
}
// Login.PhoneNumberAlreadyAuthorizedSwitch
NSString * _Nonnull _LNN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2119);
}
// Login.PhoneNumberHelp
NSString * _Nonnull _LNP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2120);
}
// Login.PhonePlaceholder
NSString * _Nonnull _LNQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2121);
}
// Login.PhoneTitle
NSString * _Nonnull _LNR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2122);
}
// Login.ResetAccountProtected.LimitExceeded
NSString * _Nonnull _LNS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2123);
}
// Login.ResetAccountProtected.Reset
NSString * _Nonnull _LNT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2124);
}
// Login.ResetAccountProtected.Text
_FormattedString * _Nonnull _LNU(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2125, _0);
}
// Login.ResetAccountProtected.TimerTitle
NSString * _Nonnull _LNV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2126);
}
// Login.ResetAccountProtected.Title
NSString * _Nonnull _LNW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2127);
}
// Login.SelectCountry.Title
NSString * _Nonnull _LNX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2128);
}
// Login.SendCodeViaSms
NSString * _Nonnull _LNY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2129);
}
// Login.SmsRequestState2
NSString * _Nonnull _LNZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2130);
}
// Login.SmsRequestState3
NSString * _Nonnull _LOa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2131);
}
// Login.TermsOfService.ProceedBot
_FormattedString * _Nonnull _LOb(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2132, _0);
}
// Login.TermsOfServiceAgree
NSString * _Nonnull _LOc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2133);
}
// Login.TermsOfServiceDecline
NSString * _Nonnull _LOd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2134);
}
// Login.TermsOfServiceHeader
NSString * _Nonnull _LOe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2135);
}
// Login.TermsOfServiceLabel
NSString * _Nonnull _LOf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2136);
}
// Login.TermsOfServiceSignupDecline
NSString * _Nonnull _LOg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2137);
}
// Login.UnknownError
NSString * _Nonnull _LOh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2138);
}
// Login.WillCallYou
_FormattedString * _Nonnull _LOi(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2139, _0);
}
// Login.WillSendSms
_FormattedString * _Nonnull _LOj(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2140, _0);
}
// LoginPassword.FloodError
NSString * _Nonnull _LOk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2141);
}
// LoginPassword.ForgotPassword
NSString * _Nonnull _LOl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2142);
}
// LoginPassword.InvalidPasswordError
NSString * _Nonnull _LOm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2143);
}
// LoginPassword.PasswordHelp
NSString * _Nonnull _LOn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2144);
}
// LoginPassword.PasswordPlaceholder
NSString * _Nonnull _LOo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2145);
}
// LoginPassword.ResetAccount
NSString * _Nonnull _LOp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2146);
}
// LoginPassword.Title
NSString * _Nonnull _LOq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2147);
}
// LogoutOptions.AddAccountText
NSString * _Nonnull _LOr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2148);
}
// LogoutOptions.AddAccountTitle
NSString * _Nonnull _LOs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2149);
}
// LogoutOptions.AlternativeOptionsSection
NSString * _Nonnull _LOt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2150);
}
// LogoutOptions.ChangePhoneNumberText
NSString * _Nonnull _LOu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2151);
}
// LogoutOptions.ChangePhoneNumberTitle
NSString * _Nonnull _LOv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2152);
}
// LogoutOptions.ClearCacheText
NSString * _Nonnull _LOw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2153);
}
// LogoutOptions.ClearCacheTitle
NSString * _Nonnull _LOx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2154);
}
// LogoutOptions.ContactSupportText
NSString * _Nonnull _LOy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2155);
}
// LogoutOptions.ContactSupportTitle
NSString * _Nonnull _LOz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2156);
}
// LogoutOptions.LogOut
NSString * _Nonnull _LOA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2157);
}
// LogoutOptions.LogOutInfo
NSString * _Nonnull _LOB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2158);
}
// LogoutOptions.SetPasscodeText
NSString * _Nonnull _LOC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2159);
}
// LogoutOptions.SetPasscodeTitle
NSString * _Nonnull _LOD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2160);
}
// LogoutOptions.Title
NSString * _Nonnull _LOE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2161);
}
// MESSAGE_INVOICE
_FormattedString * _Nonnull _LOF(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2162, _0, _1);
}
// Map.AccurateTo
_FormattedString * _Nonnull _LOG(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2163, _0);
}
// Map.AddressOnMap
NSString * _Nonnull _LOH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2164);
}
// Map.ChooseAPlace
NSString * _Nonnull _LOI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2165);
}
// Map.ChooseLocationTitle
NSString * _Nonnull _LOJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2166);
}
// Map.Directions
NSString * _Nonnull _LOK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2167);
}
// Map.DirectionsDriveEta
_FormattedString * _Nonnull _LOL(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2168, _0);
}
// Map.DistanceAway
_FormattedString * _Nonnull _LOM(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2169, _0);
}
// Map.ETAHours
NSString * _Nonnull _LON(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2170, value);
}
// Map.ETAMinutes
NSString * _Nonnull _LOO(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2171, value);
}
// Map.GetDirections
NSString * _Nonnull _LOP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2172);
}
// Map.Home
NSString * _Nonnull _LOQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2173);
}
// Map.HomeAndWorkInfo
NSString * _Nonnull _LOR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2174);
}
// Map.HomeAndWorkTitle
NSString * _Nonnull _LOS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2175);
}
// Map.Hybrid
NSString * _Nonnull _LOT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2176);
}
// Map.LiveLocationFor15Minutes
NSString * _Nonnull _LOU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2177);
}
// Map.LiveLocationFor1Hour
NSString * _Nonnull _LOV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2178);
}
// Map.LiveLocationFor8Hours
NSString * _Nonnull _LOW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2179);
}
// Map.LiveLocationGroupDescription
NSString * _Nonnull _LOX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2180);
}
// Map.LiveLocationPrivateDescription
_FormattedString * _Nonnull _LOY(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2181, _0);
}
// Map.LiveLocationShortHour
_FormattedString * _Nonnull _LOZ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2182, _0);
}
// Map.LiveLocationShowAll
NSString * _Nonnull _LPa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2183);
}
// Map.LiveLocationTitle
NSString * _Nonnull _LPb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2184);
}
// Map.LoadError
NSString * _Nonnull _LPc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2185);
}
// Map.Locating
NSString * _Nonnull _LPd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2186);
}
// Map.LocatingError
NSString * _Nonnull _LPe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2187);
}
// Map.Location
NSString * _Nonnull _LPf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2188);
}
// Map.LocationTitle
NSString * _Nonnull _LPg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2189);
}
// Map.Map
NSString * _Nonnull _LPh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2190);
}
// Map.NoPlacesNearby
NSString * _Nonnull _LPi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2191);
}
// Map.OpenIn
NSString * _Nonnull _LPj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2192);
}
// Map.OpenInGoogleMaps
NSString * _Nonnull _LPk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2193);
}
// Map.OpenInHereMaps
NSString * _Nonnull _LPl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2194);
}
// Map.OpenInMaps
NSString * _Nonnull _LPm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2195);
}
// Map.OpenInWaze
NSString * _Nonnull _LPn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2196);
}
// Map.OpenInYandexMaps
NSString * _Nonnull _LPo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2197);
}
// Map.OpenInYandexNavigator
NSString * _Nonnull _LPp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2198);
}
// Map.PlacesInThisArea
NSString * _Nonnull _LPq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2199);
}
// Map.PlacesNearby
NSString * _Nonnull _LPr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2200);
}
// Map.PullUpForPlaces
NSString * _Nonnull _LPs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2201);
}
// Map.Satellite
NSString * _Nonnull _LPt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2202);
}
// Map.Search
NSString * _Nonnull _LPu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2203);
}
// Map.SearchNoResultsDescription
_FormattedString * _Nonnull _LPv(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2204, _0);
}
// Map.SendMyCurrentLocation
NSString * _Nonnull _LPw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2205);
}
// Map.SendThisLocation
NSString * _Nonnull _LPx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2206);
}
// Map.SendThisPlace
NSString * _Nonnull _LPy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2207);
}
// Map.SetThisLocation
NSString * _Nonnull _LPz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2208);
}
// Map.SetThisPlace
NSString * _Nonnull _LPA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2209);
}
// Map.ShareLiveLocation
NSString * _Nonnull _LPB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2210);
}
// Map.ShareLiveLocationHelp
NSString * _Nonnull _LPC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2211);
}
// Map.ShowPlaces
NSString * _Nonnull _LPD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2212);
}
// Map.StopLiveLocation
NSString * _Nonnull _LPE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2213);
}
// Map.Unknown
NSString * _Nonnull _LPF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2214);
}
// Map.Work
NSString * _Nonnull _LPG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2215);
}
// Map.YouAreHere
NSString * _Nonnull _LPH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2216);
}
// MaskStickerSettings.Info
NSString * _Nonnull _LPI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2217);
}
// MaskStickerSettings.Title
NSString * _Nonnull _LPJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2218);
}
// Media.LimitedAccessChangeSettings
NSString * _Nonnull _LPK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2219);
}
// Media.LimitedAccessManage
NSString * _Nonnull _LPL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2220);
}
// Media.LimitedAccessSelectMore
NSString * _Nonnull _LPM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2221);
}
// Media.LimitedAccessText
NSString * _Nonnull _LPN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2222);
}
// Media.LimitedAccessTitle
NSString * _Nonnull _LPO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2223);
}
// Media.SendWithTimer
NSString * _Nonnull _LPP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2224);
}
// Media.SendingOptionsTooltip
NSString * _Nonnull _LPQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2225);
}
// Media.ShareItem
NSString * _Nonnull _LPR(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2226, value);
}
// Media.SharePhoto
NSString * _Nonnull _LPS(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2227, value);
}
// Media.ShareThisPhoto
NSString * _Nonnull _LPT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2228);
}
// Media.ShareThisVideo
NSString * _Nonnull _LPU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2229);
}
// Media.ShareVideo
NSString * _Nonnull _LPV(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2230, value);
}
// MediaPicker.AddCaption
NSString * _Nonnull _LPW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2231);
}
// MediaPicker.CameraRoll
NSString * _Nonnull _LPX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2232);
}
// MediaPicker.GroupDescription
NSString * _Nonnull _LPY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2233);
}
// MediaPicker.LivePhotoDescription
NSString * _Nonnull _LPZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2234);
}
// MediaPicker.MomentsDateRangeSameMonthYearFormat
NSString * _Nonnull _LQa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2235);
}
// MediaPicker.Nof
_FormattedString * _Nonnull _LQb(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2236, _0);
}
// MediaPicker.Send
NSString * _Nonnull _LQc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2237);
}
// MediaPicker.TapToUngroupDescription
NSString * _Nonnull _LQd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2238);
}
// MediaPicker.TimerTooltip
NSString * _Nonnull _LQe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2239);
}
// MediaPicker.UngroupDescription
NSString * _Nonnull _LQf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2240);
}
// MediaPicker.VideoMuteDescription
NSString * _Nonnull _LQg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2241);
}
// MediaPicker.Videos
NSString * _Nonnull _LQh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2242);
}
// MediaPlayer.UnknownArtist
NSString * _Nonnull _LQi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2243);
}
// MediaPlayer.UnknownTrack
NSString * _Nonnull _LQj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2244);
}
// MemberSearch.BotSection
NSString * _Nonnull _LQk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2245);
}
// Message.Animation
NSString * _Nonnull _LQl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2246);
}
// Message.Audio
NSString * _Nonnull _LQm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2247);
}
// Message.AuthorPinnedGame
_FormattedString * _Nonnull _LQn(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2248, _0);
}
// Message.Contact
NSString * _Nonnull _LQo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2249);
}
// Message.FakeAccount
NSString * _Nonnull _LQp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2250);
}
// Message.File
NSString * _Nonnull _LQq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2251);
}
// Message.ForwardedMessage
_FormattedString * _Nonnull _LQr(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2252, _0);
}
// Message.ForwardedMessageShort
_FormattedString * _Nonnull _LQs(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2253, _0);
}
// Message.ForwardedPsa.covid
_FormattedString * _Nonnull _LQt(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2254, _0);
}
// Message.Game
NSString * _Nonnull _LQu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2255);
}
// Message.GenericForwardedPsa
_FormattedString * _Nonnull _LQv(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2256, _0);
}
// Message.ImageExpired
NSString * _Nonnull _LQw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2257);
}
// Message.ImportedDateFormat
_FormattedString * _Nonnull _LQx(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 2258, _0, _1, _2);
}
// Message.InvoiceLabel
NSString * _Nonnull _LQy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2259);
}
// Message.LiveLocation
NSString * _Nonnull _LQz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2260);
}
// Message.Location
NSString * _Nonnull _LQA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2261);
}
// Message.PaymentSent
_FormattedString * _Nonnull _LQB(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2262, _0);
}
// Message.Photo
NSString * _Nonnull _LQC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2263);
}
// Message.PinnedAnimationMessage
NSString * _Nonnull _LQD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2264);
}
// Message.PinnedAudioMessage
NSString * _Nonnull _LQE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2265);
}
// Message.PinnedContactMessage
NSString * _Nonnull _LQF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2266);
}
// Message.PinnedDocumentMessage
NSString * _Nonnull _LQG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2267);
}
// Message.PinnedGame
NSString * _Nonnull _LQH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2268);
}
// Message.PinnedGenericMessage
_FormattedString * _Nonnull _LQI(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2269, _0);
}
// Message.PinnedInvoice
NSString * _Nonnull _LQJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2270);
}
// Message.PinnedLiveLocationMessage
NSString * _Nonnull _LQK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2271);
}
// Message.PinnedLocationMessage
NSString * _Nonnull _LQL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2272);
}
// Message.PinnedPhotoMessage
NSString * _Nonnull _LQM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2273);
}
// Message.PinnedStickerMessage
NSString * _Nonnull _LQN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2274);
}
// Message.PinnedTextMessage
_FormattedString * _Nonnull _LQO(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2275, _0);
}
// Message.PinnedVideoMessage
NSString * _Nonnull _LQP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2276);
}
// Message.ReplyActionButtonShowReceipt
NSString * _Nonnull _LQQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2277);
}
// Message.ScamAccount
NSString * _Nonnull _LQR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2278);
}
// Message.Sticker
NSString * _Nonnull _LQS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2279);
}
// Message.StickerText
_FormattedString * _Nonnull _LQT(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2280, _0);
}
// Message.Theme
NSString * _Nonnull _LQU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2281);
}
// Message.Video
NSString * _Nonnull _LQV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2282);
}
// Message.VideoExpired
NSString * _Nonnull _LQW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2283);
}
// Message.VideoMessage
NSString * _Nonnull _LQX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2284);
}
// Message.Wallpaper
NSString * _Nonnull _LQY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2285);
}
// MessagePoll.LabelAnonymous
NSString * _Nonnull _LQZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2286);
}
// MessagePoll.LabelAnonymousQuiz
NSString * _Nonnull _LRa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2287);
}
// MessagePoll.LabelClosed
NSString * _Nonnull _LRb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2288);
}
// MessagePoll.LabelPoll
NSString * _Nonnull _LRc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2289);
}
// MessagePoll.LabelQuiz
NSString * _Nonnull _LRd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2290);
}
// MessagePoll.NoVotes
NSString * _Nonnull _LRe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2291);
}
// MessagePoll.QuizCount
NSString * _Nonnull _LRf(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2292, value);
}
// MessagePoll.QuizNoUsers
NSString * _Nonnull _LRg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2293);
}
// MessagePoll.SubmitVote
NSString * _Nonnull _LRh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2294);
}
// MessagePoll.ViewResults
NSString * _Nonnull _LRi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2295);
}
// MessagePoll.VotedCount
NSString * _Nonnull _LRj(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2296, value);
}
// MessageTimer.Custom
NSString * _Nonnull _LRk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2297);
}
// MessageTimer.Days
NSString * _Nonnull _LRl(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2298, value);
}
// MessageTimer.Forever
NSString * _Nonnull _LRm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2299);
}
// MessageTimer.Hours
NSString * _Nonnull _LRn(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2300, value);
}
// MessageTimer.Minutes
NSString * _Nonnull _LRo(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2301, value);
}
// MessageTimer.Months
NSString * _Nonnull _LRp(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2302, value);
}
// MessageTimer.Seconds
NSString * _Nonnull _LRq(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2303, value);
}
// MessageTimer.ShortDays
NSString * _Nonnull _LRr(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2304, value);
}
// MessageTimer.ShortHours
NSString * _Nonnull _LRs(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2305, value);
}
// MessageTimer.ShortMinutes
NSString * _Nonnull _LRt(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2306, value);
}
// MessageTimer.ShortSeconds
NSString * _Nonnull _LRu(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2307, value);
}
// MessageTimer.ShortWeeks
NSString * _Nonnull _LRv(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2308, value);
}
// MessageTimer.Weeks
NSString * _Nonnull _LRw(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2309, value);
}
// MessageTimer.Years
NSString * _Nonnull _LRx(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2310, value);
}
// Month.GenApril
NSString * _Nonnull _LRy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2311);
}
// Month.GenAugust
NSString * _Nonnull _LRz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2312);
}
// Month.GenDecember
NSString * _Nonnull _LRA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2313);
}
// Month.GenFebruary
NSString * _Nonnull _LRB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2314);
}
// Month.GenJanuary
NSString * _Nonnull _LRC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2315);
}
// Month.GenJuly
NSString * _Nonnull _LRD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2316);
}
// Month.GenJune
NSString * _Nonnull _LRE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2317);
}
// Month.GenMarch
NSString * _Nonnull _LRF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2318);
}
// Month.GenMay
NSString * _Nonnull _LRG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2319);
}
// Month.GenNovember
NSString * _Nonnull _LRH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2320);
}
// Month.GenOctober
NSString * _Nonnull _LRI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2321);
}
// Month.GenSeptember
NSString * _Nonnull _LRJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2322);
}
// Month.ShortApril
NSString * _Nonnull _LRK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2323);
}
// Month.ShortAugust
NSString * _Nonnull _LRL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2324);
}
// Month.ShortDecember
NSString * _Nonnull _LRM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2325);
}
// Month.ShortFebruary
NSString * _Nonnull _LRN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2326);
}
// Month.ShortJanuary
NSString * _Nonnull _LRO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2327);
}
// Month.ShortJuly
NSString * _Nonnull _LRP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2328);
}
// Month.ShortJune
NSString * _Nonnull _LRQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2329);
}
// Month.ShortMarch
NSString * _Nonnull _LRR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2330);
}
// Month.ShortMay
NSString * _Nonnull _LRS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2331);
}
// Month.ShortNovember
NSString * _Nonnull _LRT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2332);
}
// Month.ShortOctober
NSString * _Nonnull _LRU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2333);
}
// Month.ShortSeptember
NSString * _Nonnull _LRV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2334);
}
// MusicPlayer.VoiceNote
NSString * _Nonnull _LRW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2335);
}
// MuteExpires.Days
NSString * _Nonnull _LRX(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2336, value);
}
// MuteExpires.Hours
NSString * _Nonnull _LRY(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2337, value);
}
// MuteExpires.Minutes
NSString * _Nonnull _LRZ(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2338, value);
}
// MuteFor.Days
NSString * _Nonnull _LSa(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2339, value);
}
// MuteFor.Forever
NSString * _Nonnull _LSb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2340);
}
// MuteFor.Hours
NSString * _Nonnull _LSc(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2341, value);
}
// NetworkUsageSettings.BytesReceived
NSString * _Nonnull _LSd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2342);
}
// NetworkUsageSettings.BytesSent
NSString * _Nonnull _LSe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2343);
}
// NetworkUsageSettings.CallDataSection
NSString * _Nonnull _LSf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2344);
}
// NetworkUsageSettings.Cellular
NSString * _Nonnull _LSg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2345);
}
// NetworkUsageSettings.CellularUsageSince
_FormattedString * _Nonnull _LSh(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2346, _0);
}
// NetworkUsageSettings.GeneralDataSection
NSString * _Nonnull _LSi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2347);
}
// NetworkUsageSettings.MediaAudioDataSection
NSString * _Nonnull _LSj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2348);
}
// NetworkUsageSettings.MediaDocumentDataSection
NSString * _Nonnull _LSk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2349);
}
// NetworkUsageSettings.MediaImageDataSection
NSString * _Nonnull _LSl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2350);
}
// NetworkUsageSettings.MediaVideoDataSection
NSString * _Nonnull _LSm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2351);
}
// NetworkUsageSettings.ResetStats
NSString * _Nonnull _LSn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2352);
}
// NetworkUsageSettings.ResetStatsConfirmation
NSString * _Nonnull _LSo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2353);
}
// NetworkUsageSettings.Title
NSString * _Nonnull _LSp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2354);
}
// NetworkUsageSettings.TotalSection
NSString * _Nonnull _LSq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2355);
}
// NetworkUsageSettings.Wifi
NSString * _Nonnull _LSr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2356);
}
// NetworkUsageSettings.WifiUsageSince
_FormattedString * _Nonnull _LSs(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2357, _0);
}
// NewContact.Title
NSString * _Nonnull _LSt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2358);
}
// Notification.CallBack
NSString * _Nonnull _LSu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2359);
}
// Notification.CallCanceled
NSString * _Nonnull _LSv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2360);
}
// Notification.CallCanceledShort
NSString * _Nonnull _LSw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2361);
}
// Notification.CallFormat
_FormattedString * _Nonnull _LSx(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2362, _0, _1);
}
// Notification.CallIncoming
NSString * _Nonnull _LSy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2363);
}
// Notification.CallIncomingShort
NSString * _Nonnull _LSz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2364);
}
// Notification.CallMissed
NSString * _Nonnull _LSA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2365);
}
// Notification.CallMissedShort
NSString * _Nonnull _LSB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2366);
}
// Notification.CallOutgoing
NSString * _Nonnull _LSC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2367);
}
// Notification.CallOutgoingShort
NSString * _Nonnull _LSD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2368);
}
// Notification.CallTimeFormat
_FormattedString * _Nonnull _LSE(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2369, _0, _1);
}
// Notification.ChangedGroupName
_FormattedString * _Nonnull _LSF(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2370, _0, _1);
}
// Notification.ChangedGroupPhoto
_FormattedString * _Nonnull _LSG(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2371, _0);
}
// Notification.ChangedGroupVideo
_FormattedString * _Nonnull _LSH(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2372, _0);
}
// Notification.ChannelInviter
_FormattedString * _Nonnull _LSI(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2373, _0);
}
// Notification.ChannelInviterSelf
NSString * _Nonnull _LSJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2374);
}
// Notification.CreatedChannel
NSString * _Nonnull _LSK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2375);
}
// Notification.CreatedChat
_FormattedString * _Nonnull _LSL(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2376, _0);
}
// Notification.CreatedChatWithTitle
_FormattedString * _Nonnull _LSM(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2377, _0, _1);
}
// Notification.CreatedGroup
NSString * _Nonnull _LSN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2378);
}
// Notification.Exceptions.Add
NSString * _Nonnull _LSO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2379);
}
// Notification.Exceptions.AddException
NSString * _Nonnull _LSP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2380);
}
// Notification.Exceptions.AlwaysOff
NSString * _Nonnull _LSQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2381);
}
// Notification.Exceptions.AlwaysOn
NSString * _Nonnull _LSR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2382);
}
// Notification.Exceptions.DeleteAll
NSString * _Nonnull _LSS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2383);
}
// Notification.Exceptions.DeleteAllConfirmation
NSString * _Nonnull _LST(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2384);
}
// Notification.Exceptions.MessagePreviewAlwaysOff
NSString * _Nonnull _LSU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2385);
}
// Notification.Exceptions.MessagePreviewAlwaysOn
NSString * _Nonnull _LSV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2386);
}
// Notification.Exceptions.MutedUntil
_FormattedString * _Nonnull _LSW(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2387, _0);
}
// Notification.Exceptions.NewException
NSString * _Nonnull _LSX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2388);
}
// Notification.Exceptions.NewException.MessagePreviewHeader
NSString * _Nonnull _LSY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2389);
}
// Notification.Exceptions.NewException.NotificationHeader
NSString * _Nonnull _LSZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2390);
}
// Notification.Exceptions.PreviewAlwaysOff
NSString * _Nonnull _LTa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2391);
}
// Notification.Exceptions.PreviewAlwaysOn
NSString * _Nonnull _LTb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2392);
}
// Notification.Exceptions.RemoveFromExceptions
NSString * _Nonnull _LTc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2393);
}
// Notification.Exceptions.Sound
_FormattedString * _Nonnull _LTd(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2394, _0);
}
// Notification.GameScoreExtended
NSString * _Nonnull _LTe(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2395, value);
}
// Notification.GameScoreSelfExtended
NSString * _Nonnull _LTf(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2396, value);
}
// Notification.GameScoreSelfSimple
NSString * _Nonnull _LTg(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2397, value);
}
// Notification.GameScoreSimple
NSString * _Nonnull _LTh(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2398, value);
}
// Notification.GroupActivated
NSString * _Nonnull _LTi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2399);
}
// Notification.GroupInviter
_FormattedString * _Nonnull _LTj(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2400, _0);
}
// Notification.GroupInviterSelf
NSString * _Nonnull _LTk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2401);
}
// Notification.Invited
_FormattedString * _Nonnull _LTl(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2402, _0, _1);
}
// Notification.InvitedMultiple
_FormattedString * _Nonnull _LTm(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2403, _0, _1);
}
// Notification.Joined
_FormattedString * _Nonnull _LTn(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2404, _0);
}
// Notification.JoinedChannel
_FormattedString * _Nonnull _LTo(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2405, _0);
}
// Notification.JoinedChat
_FormattedString * _Nonnull _LTp(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2406, _0);
}
// Notification.JoinedGroupByLink
_FormattedString * _Nonnull _LTq(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2407, _0);
}
// Notification.Kicked
_FormattedString * _Nonnull _LTr(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2408, _0, _1);
}
// Notification.LeftChannel
_FormattedString * _Nonnull _LTs(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2409, _0);
}
// Notification.LeftChat
_FormattedString * _Nonnull _LTt(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2410, _0);
}
// Notification.MessageLifetime1d
NSString * _Nonnull _LTu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2411);
}
// Notification.MessageLifetime1h
NSString * _Nonnull _LTv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2412);
}
// Notification.MessageLifetime1m
NSString * _Nonnull _LTw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2413);
}
// Notification.MessageLifetime1w
NSString * _Nonnull _LTx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2414);
}
// Notification.MessageLifetime2s
NSString * _Nonnull _LTy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2415);
}
// Notification.MessageLifetime5s
NSString * _Nonnull _LTz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2416);
}
// Notification.MessageLifetimeChanged
_FormattedString * _Nonnull _LTA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2417, _0, _1);
}
// Notification.MessageLifetimeChangedOutgoing
_FormattedString * _Nonnull _LTB(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2418, _0);
}
// Notification.MessageLifetimeRemoved
_FormattedString * _Nonnull _LTC(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2419, _0);
}
// Notification.MessageLifetimeRemovedOutgoing
NSString * _Nonnull _LTD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2420);
}
// Notification.Mute1h
NSString * _Nonnull _LTE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2421);
}
// Notification.Mute1hMin
NSString * _Nonnull _LTF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2422);
}
// Notification.NewAuthDetected
_FormattedString * _Nonnull _LTG(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2, NSString * _Nonnull _3, NSString * _Nonnull _4, NSString * _Nonnull _5) {
    return getFormatted6(_self, 2423, _0, _1, _2, _3, _4, _5);
}
// Notification.PassportValueAddress
NSString * _Nonnull _LTH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2424);
}
// Notification.PassportValueEmail
NSString * _Nonnull _LTI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2425);
}
// Notification.PassportValuePersonalDetails
NSString * _Nonnull _LTJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2426);
}
// Notification.PassportValuePhone
NSString * _Nonnull _LTK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2427);
}
// Notification.PassportValueProofOfAddress
NSString * _Nonnull _LTL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2428);
}
// Notification.PassportValueProofOfIdentity
NSString * _Nonnull _LTM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2429);
}
// Notification.PassportValuesSentMessage
_FormattedString * _Nonnull _LTN(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2430, _0, _1);
}
// Notification.PaymentSent
NSString * _Nonnull _LTO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2431);
}
// Notification.PinnedAnimationMessage
_FormattedString * _Nonnull _LTP(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2432, _0);
}
// Notification.PinnedAudioMessage
_FormattedString * _Nonnull _LTQ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2433, _0);
}
// Notification.PinnedContactMessage
_FormattedString * _Nonnull _LTR(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2434, _0);
}
// Notification.PinnedDeletedMessage
_FormattedString * _Nonnull _LTS(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2435, _0);
}
// Notification.PinnedDocumentMessage
_FormattedString * _Nonnull _LTT(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2436, _0);
}
// Notification.PinnedLiveLocationMessage
_FormattedString * _Nonnull _LTU(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2437, _0);
}
// Notification.PinnedLocationMessage
_FormattedString * _Nonnull _LTV(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2438, _0);
}
// Notification.PinnedMessage
NSString * _Nonnull _LTW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2439);
}
// Notification.PinnedPhotoMessage
_FormattedString * _Nonnull _LTX(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2440, _0);
}
// Notification.PinnedPollMessage
_FormattedString * _Nonnull _LTY(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2441, _0);
}
// Notification.PinnedQuizMessage
_FormattedString * _Nonnull _LTZ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2442, _0);
}
// Notification.PinnedRoundMessage
_FormattedString * _Nonnull _LUa(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2443, _0);
}
// Notification.PinnedStickerMessage
_FormattedString * _Nonnull _LUb(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2444, _0);
}
// Notification.PinnedTextMessage
_FormattedString * _Nonnull _LUc(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2445, _0, _1);
}
// Notification.PinnedVideoMessage
_FormattedString * _Nonnull _LUd(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2446, _0);
}
// Notification.ProximityReached
_FormattedString * _Nonnull _LUe(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 2447, _0, _1, _2);
}
// Notification.ProximityReachedYou
_FormattedString * _Nonnull _LUf(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2448, _0, _1);
}
// Notification.ProximityYouReached
_FormattedString * _Nonnull _LUg(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2449, _0, _1);
}
// Notification.RemovedGroupPhoto
_FormattedString * _Nonnull _LUh(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2450, _0);
}
// Notification.RenamedChannel
NSString * _Nonnull _LUi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2451);
}
// Notification.RenamedChat
_FormattedString * _Nonnull _LUj(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2452, _0);
}
// Notification.RenamedGroup
NSString * _Nonnull _LUk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2453);
}
// Notification.Reply
NSString * _Nonnull _LUl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2454);
}
// Notification.SecretChatMessageScreenshot
_FormattedString * _Nonnull _LUm(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2455, _0);
}
// Notification.SecretChatMessageScreenshotSelf
NSString * _Nonnull _LUn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2456);
}
// Notification.SecretChatScreenshot
NSString * _Nonnull _LUo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2457);
}
// Notification.VideoCallCanceled
NSString * _Nonnull _LUp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2458);
}
// Notification.VideoCallIncoming
NSString * _Nonnull _LUq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2459);
}
// Notification.VideoCallMissed
NSString * _Nonnull _LUr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2460);
}
// Notification.VideoCallOutgoing
NSString * _Nonnull _LUs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2461);
}
// Notification.VoiceChatEnded
_FormattedString * _Nonnull _LUt(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2462, _0);
}
// Notification.VoiceChatEndedGroup
_FormattedString * _Nonnull _LUu(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2463, _0, _1);
}
// Notification.VoiceChatInvitation
_FormattedString * _Nonnull _LUv(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2464, _0, _1);
}
// Notification.VoiceChatInvitationForYou
_FormattedString * _Nonnull _LUw(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2465, _0);
}
// Notification.VoiceChatScheduled
_FormattedString * _Nonnull _LUx(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2466, _0, _1);
}
// Notification.VoiceChatScheduledChannel
_FormattedString * _Nonnull _LUy(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2467, _0);
}
// Notification.VoiceChatScheduledToday
_FormattedString * _Nonnull _LUz(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2468, _0, _1);
}
// Notification.VoiceChatScheduledTodayChannel
_FormattedString * _Nonnull _LUA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2469, _0);
}
// Notification.VoiceChatScheduledTomorrow
_FormattedString * _Nonnull _LUB(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2470, _0, _1);
}
// Notification.VoiceChatScheduledTomorrowChannel
_FormattedString * _Nonnull _LUC(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2471, _0);
}
// Notification.VoiceChatStarted
_FormattedString * _Nonnull _LUD(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2472, _0);
}
// Notification.VoiceChatStartedChannel
NSString * _Nonnull _LUE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2473);
}
// NotificationSettings.ContactJoined
NSString * _Nonnull _LUF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2474);
}
// NotificationSettings.ContactJoinedInfo
NSString * _Nonnull _LUG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2475);
}
// NotificationSettings.ShowNotificationsAllAccounts
NSString * _Nonnull _LUH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2476);
}
// NotificationSettings.ShowNotificationsAllAccountsInfoOff
NSString * _Nonnull _LUI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2477);
}
// NotificationSettings.ShowNotificationsAllAccountsInfoOn
NSString * _Nonnull _LUJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2478);
}
// NotificationSettings.ShowNotificationsFromAccountsSection
NSString * _Nonnull _LUK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2479);
}
// Notifications.AddExceptionTitle
NSString * _Nonnull _LUL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2480);
}
// Notifications.AlertTones
NSString * _Nonnull _LUM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2481);
}
// Notifications.Badge
NSString * _Nonnull _LUN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2482);
}
// Notifications.Badge.CountUnreadMessages
NSString * _Nonnull _LUO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2483);
}
// Notifications.Badge.CountUnreadMessages.InfoOff
NSString * _Nonnull _LUP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2484);
}
// Notifications.Badge.CountUnreadMessages.InfoOn
NSString * _Nonnull _LUQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2485);
}
// Notifications.Badge.IncludeChannels
NSString * _Nonnull _LUR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2486);
}
// Notifications.Badge.IncludeMutedChats
NSString * _Nonnull _LUS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2487);
}
// Notifications.Badge.IncludePublicGroups
NSString * _Nonnull _LUT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2488);
}
// Notifications.ChannelNotifications
NSString * _Nonnull _LUU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2489);
}
// Notifications.ChannelNotificationsAlert
NSString * _Nonnull _LUV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2490);
}
// Notifications.ChannelNotificationsExceptionsHelp
NSString * _Nonnull _LUW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2491);
}
// Notifications.ChannelNotificationsHelp
NSString * _Nonnull _LUX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2492);
}
// Notifications.ChannelNotificationsPreview
NSString * _Nonnull _LUY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2493);
}
// Notifications.ChannelNotificationsSound
NSString * _Nonnull _LUZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2494);
}
// Notifications.ClassicTones
NSString * _Nonnull _LVa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2495);
}
// Notifications.DisplayNamesOnLockScreen
NSString * _Nonnull _LVb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2496);
}
// Notifications.DisplayNamesOnLockScreenInfoWithLink
NSString * _Nonnull _LVc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2497);
}
// Notifications.ExceptionMuteExpires.Days
NSString * _Nonnull _LVd(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2498, value);
}
// Notifications.ExceptionMuteExpires.Hours
NSString * _Nonnull _LVe(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2499, value);
}
// Notifications.ExceptionMuteExpires.Minutes
NSString * _Nonnull _LVf(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2500, value);
}
// Notifications.Exceptions
NSString * _Nonnull _LVg(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2501, value);
}
// Notifications.ExceptionsChangeSound
_FormattedString * _Nonnull _LVh(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2502, _0);
}
// Notifications.ExceptionsDefaultSound
NSString * _Nonnull _LVi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2503);
}
// Notifications.ExceptionsGroupPlaceholder
NSString * _Nonnull _LVj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2504);
}
// Notifications.ExceptionsMessagePlaceholder
NSString * _Nonnull _LVk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2505);
}
// Notifications.ExceptionsMuted
NSString * _Nonnull _LVl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2506);
}
// Notifications.ExceptionsNone
NSString * _Nonnull _LVm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2507);
}
// Notifications.ExceptionsResetToDefaults
NSString * _Nonnull _LVn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2508);
}
// Notifications.ExceptionsTitle
NSString * _Nonnull _LVo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2509);
}
// Notifications.ExceptionsUnmuted
NSString * _Nonnull _LVp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2510);
}
// Notifications.GroupNotifications
NSString * _Nonnull _LVq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2511);
}
// Notifications.GroupNotificationsAlert
NSString * _Nonnull _LVr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2512);
}
// Notifications.GroupNotificationsExceptions
NSString * _Nonnull _LVs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2513);
}
// Notifications.GroupNotificationsExceptionsHelp
NSString * _Nonnull _LVt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2514);
}
// Notifications.GroupNotificationsHelp
NSString * _Nonnull _LVu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2515);
}
// Notifications.GroupNotificationsPreview
NSString * _Nonnull _LVv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2516);
}
// Notifications.GroupNotificationsSound
NSString * _Nonnull _LVw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2517);
}
// Notifications.InAppNotifications
NSString * _Nonnull _LVx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2518);
}
// Notifications.InAppNotificationsPreview
NSString * _Nonnull _LVy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2519);
}
// Notifications.InAppNotificationsSounds
NSString * _Nonnull _LVz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2520);
}
// Notifications.InAppNotificationsVibrate
NSString * _Nonnull _LVA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2521);
}
// Notifications.MessageNotifications
NSString * _Nonnull _LVB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2522);
}
// Notifications.MessageNotificationsAlert
NSString * _Nonnull _LVC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2523);
}
// Notifications.MessageNotificationsExceptions
NSString * _Nonnull _LVD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2524);
}
// Notifications.MessageNotificationsExceptionsHelp
NSString * _Nonnull _LVE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2525);
}
// Notifications.MessageNotificationsHelp
NSString * _Nonnull _LVF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2526);
}
// Notifications.MessageNotificationsPreview
NSString * _Nonnull _LVG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2527);
}
// Notifications.MessageNotificationsSound
NSString * _Nonnull _LVH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2528);
}
// Notifications.PermissionsAllow
NSString * _Nonnull _LVI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2529);
}
// Notifications.PermissionsAllowInSettings
NSString * _Nonnull _LVJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2530);
}
// Notifications.PermissionsEnable
NSString * _Nonnull _LVK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2531);
}
// Notifications.PermissionsKeepDisabled
NSString * _Nonnull _LVL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2532);
}
// Notifications.PermissionsOpenSettings
NSString * _Nonnull _LVM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2533);
}
// Notifications.PermissionsSuppressWarningText
NSString * _Nonnull _LVN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2534);
}
// Notifications.PermissionsSuppressWarningTitle
NSString * _Nonnull _LVO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2535);
}
// Notifications.PermissionsText
NSString * _Nonnull _LVP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2536);
}
// Notifications.PermissionsTitle
NSString * _Nonnull _LVQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2537);
}
// Notifications.PermissionsUnreachableText
NSString * _Nonnull _LVR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2538);
}
// Notifications.PermissionsUnreachableTitle
NSString * _Nonnull _LVS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2539);
}
// Notifications.Reset
NSString * _Nonnull _LVT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2540);
}
// Notifications.ResetAllNotifications
NSString * _Nonnull _LVU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2541);
}
// Notifications.ResetAllNotificationsHelp
NSString * _Nonnull _LVV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2542);
}
// Notifications.TextTone
NSString * _Nonnull _LVW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2543);
}
// Notifications.Title
NSString * _Nonnull _LVX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2544);
}
// NotificationsSound.Alert
NSString * _Nonnull _LVY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2545);
}
// NotificationsSound.Aurora
NSString * _Nonnull _LVZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2546);
}
// NotificationsSound.Bamboo
NSString * _Nonnull _LWa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2547);
}
// NotificationsSound.Bell
NSString * _Nonnull _LWb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2548);
}
// NotificationsSound.Calypso
NSString * _Nonnull _LWc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2549);
}
// NotificationsSound.Chime
NSString * _Nonnull _LWd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2550);
}
// NotificationsSound.Chord
NSString * _Nonnull _LWe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2551);
}
// NotificationsSound.Circles
NSString * _Nonnull _LWf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2552);
}
// NotificationsSound.Complete
NSString * _Nonnull _LWg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2553);
}
// NotificationsSound.Glass
NSString * _Nonnull _LWh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2554);
}
// NotificationsSound.Hello
NSString * _Nonnull _LWi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2555);
}
// NotificationsSound.Input
NSString * _Nonnull _LWj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2556);
}
// NotificationsSound.Keys
NSString * _Nonnull _LWk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2557);
}
// NotificationsSound.None
NSString * _Nonnull _LWl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2558);
}
// NotificationsSound.Note
NSString * _Nonnull _LWm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2559);
}
// NotificationsSound.Popcorn
NSString * _Nonnull _LWn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2560);
}
// NotificationsSound.Pulse
NSString * _Nonnull _LWo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2561);
}
// NotificationsSound.Synth
NSString * _Nonnull _LWp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2562);
}
// NotificationsSound.Telegraph
NSString * _Nonnull _LWq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2563);
}
// NotificationsSound.Tremolo
NSString * _Nonnull _LWr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2564);
}
// NotificationsSound.Tritone
NSString * _Nonnull _LWs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2565);
}
// OldChannels.ChannelFormat
NSString * _Nonnull _LWt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2566);
}
// OldChannels.ChannelsHeader
NSString * _Nonnull _LWu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2567);
}
// OldChannels.GroupEmptyFormat
NSString * _Nonnull _LWv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2568);
}
// OldChannels.GroupFormat
NSString * _Nonnull _LWw(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2569, value);
}
// OldChannels.InactiveMonth
NSString * _Nonnull _LWx(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2570, value);
}
// OldChannels.InactiveWeek
NSString * _Nonnull _LWy(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2571, value);
}
// OldChannels.InactiveYear
NSString * _Nonnull _LWz(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2572, value);
}
// OldChannels.Leave
NSString * _Nonnull _LWA(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2573, value);
}
// OldChannels.NoticeCreateText
NSString * _Nonnull _LWB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2574);
}
// OldChannels.NoticeText
NSString * _Nonnull _LWC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2575);
}
// OldChannels.NoticeTitle
NSString * _Nonnull _LWD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2576);
}
// OldChannels.NoticeUpgradeText
NSString * _Nonnull _LWE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2577);
}
// OldChannels.Title
NSString * _Nonnull _LWF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2578);
}
// OpenFile.PotentiallyDangerousContentAlert
NSString * _Nonnull _LWG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2579);
}
// OpenFile.Proceed
NSString * _Nonnull _LWH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2580);
}
// OwnershipTransfer.ComeBackLater
NSString * _Nonnull _LWI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2581);
}
// OwnershipTransfer.SecurityCheck
NSString * _Nonnull _LWJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2582);
}
// OwnershipTransfer.SecurityRequirements
NSString * _Nonnull _LWK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2583);
}
// OwnershipTransfer.SetupTwoStepAuth
NSString * _Nonnull _LWL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2584);
}
// OwnershipTransfer.Transfer
NSString * _Nonnull _LWM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2585);
}
// PINNED_INVOICE
_FormattedString * _Nonnull _LWN(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2586, _0);
}
// PUSH_ALBUM
_FormattedString * _Nonnull _LWO(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2587, _0);
}
// PUSH_AUTH_REGION
_FormattedString * _Nonnull _LWP(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2588, _0, _1);
}
// PUSH_AUTH_UNKNOWN
_FormattedString * _Nonnull _LWQ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2589, _0);
}
// PUSH_CHANNEL_ALBUM
_FormattedString * _Nonnull _LWR(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2590, _0);
}
// PUSH_CHANNEL_MESSAGE
_FormattedString * _Nonnull _LWS(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2591, _0);
}
// PUSH_CHANNEL_MESSAGES
NSString * _Nonnull _LWT(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2592, value);
}
// PUSH_CHANNEL_MESSAGES_TEXT
NSString * _Nonnull _LWU(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2593, value);
}
// PUSH_CHANNEL_MESSAGE_AUDIO
_FormattedString * _Nonnull _LWV(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2594, _0);
}
// PUSH_CHANNEL_MESSAGE_CONTACT
_FormattedString * _Nonnull _LWW(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2595, _0, _1);
}
// PUSH_CHANNEL_MESSAGE_DOC
_FormattedString * _Nonnull _LWX(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2596, _0);
}
// PUSH_CHANNEL_MESSAGE_DOCS
NSString * _Nonnull _LWY(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2597, value);
}
// PUSH_CHANNEL_MESSAGE_DOCS_TEXT
NSString * _Nonnull _LWZ(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2598, value);
}
// PUSH_CHANNEL_MESSAGE_FWD
_FormattedString * _Nonnull _LXa(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2599, _0);
}
// PUSH_CHANNEL_MESSAGE_FWDS
NSString * _Nonnull _LXb(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2600, value);
}
// PUSH_CHANNEL_MESSAGE_GAME
_FormattedString * _Nonnull _LXc(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2601, _0, _1);
}
// PUSH_CHANNEL_MESSAGE_GEO
_FormattedString * _Nonnull _LXd(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2602, _0);
}
// PUSH_CHANNEL_MESSAGE_GEOLIVE
_FormattedString * _Nonnull _LXe(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2603, _0);
}
// PUSH_CHANNEL_MESSAGE_GIF
_FormattedString * _Nonnull _LXf(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2604, _0);
}
// PUSH_CHANNEL_MESSAGE_NOTEXT
_FormattedString * _Nonnull _LXg(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2605, _0);
}
// PUSH_CHANNEL_MESSAGE_PHOTO
_FormattedString * _Nonnull _LXh(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2606, _0);
}
// PUSH_CHANNEL_MESSAGE_PHOTOS
NSString * _Nonnull _LXi(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2607, value);
}
// PUSH_CHANNEL_MESSAGE_PHOTOS_TEXT
NSString * _Nonnull _LXj(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2608, value);
}
// PUSH_CHANNEL_MESSAGE_POLL
_FormattedString * _Nonnull _LXk(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2609, _0, _1);
}
// PUSH_CHANNEL_MESSAGE_QUIZ
_FormattedString * _Nonnull _LXl(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2610, _0, _1);
}
// PUSH_CHANNEL_MESSAGE_ROUND
_FormattedString * _Nonnull _LXm(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2611, _0);
}
// PUSH_CHANNEL_MESSAGE_ROUNDS
NSString * _Nonnull _LXn(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2612, value);
}
// PUSH_CHANNEL_MESSAGE_STICKER
_FormattedString * _Nonnull _LXo(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2613, _0, _1);
}
// PUSH_CHANNEL_MESSAGE_TEXT
_FormattedString * _Nonnull _LXp(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2614, _0, _1);
}
// PUSH_CHANNEL_MESSAGE_VIDEO
_FormattedString * _Nonnull _LXq(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2615, _0);
}
// PUSH_CHANNEL_MESSAGE_VIDEOS
NSString * _Nonnull _LXr(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2616, value);
}
// PUSH_CHANNEL_MESSAGE_VIDEOS_TEXT
NSString * _Nonnull _LXs(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2617, value);
}
// PUSH_CHAT_ADD_MEMBER
_FormattedString * _Nonnull _LXt(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 2618, _0, _1, _2);
}
// PUSH_CHAT_ADD_YOU
_FormattedString * _Nonnull _LXu(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2619, _0, _1);
}
// PUSH_CHAT_ALBUM
_FormattedString * _Nonnull _LXv(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2620, _0, _1);
}
// PUSH_CHAT_CREATED
_FormattedString * _Nonnull _LXw(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2621, _0, _1);
}
// PUSH_CHAT_DELETE_MEMBER
_FormattedString * _Nonnull _LXx(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 2622, _0, _1, _2);
}
// PUSH_CHAT_DELETE_YOU
_FormattedString * _Nonnull _LXy(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2623, _0, _1);
}
// PUSH_CHAT_JOINED
_FormattedString * _Nonnull _LXz(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2624, _0, _1);
}
// PUSH_CHAT_LEFT
_FormattedString * _Nonnull _LXA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2625, _0, _1);
}
// PUSH_CHAT_MESSAGE
_FormattedString * _Nonnull _LXB(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2626, _0, _1);
}
// PUSH_CHAT_MESSAGES
NSString * _Nonnull _LXC(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2627, value);
}
// PUSH_CHAT_MESSAGES_TEXT
NSString * _Nonnull _LXD(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2628, value);
}
// PUSH_CHAT_MESSAGE_AUDIO
_FormattedString * _Nonnull _LXE(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2629, _0, _1);
}
// PUSH_CHAT_MESSAGE_CONTACT
_FormattedString * _Nonnull _LXF(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 2630, _0, _1, _2);
}
// PUSH_CHAT_MESSAGE_DOC
_FormattedString * _Nonnull _LXG(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2631, _0, _1);
}
// PUSH_CHAT_MESSAGE_DOCS_FIX1
NSString * _Nonnull _LXH(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2632, value);
}
// PUSH_CHAT_MESSAGE_DOCS_TEXT
NSString * _Nonnull _LXI(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2633, value);
}
// PUSH_CHAT_MESSAGE_FWD
_FormattedString * _Nonnull _LXJ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2634, _0, _1);
}
// PUSH_CHAT_MESSAGE_FWDS
NSString * _Nonnull _LXK(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2635, value);
}
// PUSH_CHAT_MESSAGE_FWDS_TEXT
NSString * _Nonnull _LXL(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2636, value);
}
// PUSH_CHAT_MESSAGE_GAME
_FormattedString * _Nonnull _LXM(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 2637, _0, _1, _2);
}
// PUSH_CHAT_MESSAGE_GAME_SCORE
_FormattedString * _Nonnull _LXN(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2, NSString * _Nonnull _3) {
    return getFormatted4(_self, 2638, _0, _1, _2, _3);
}
// PUSH_CHAT_MESSAGE_GEO
_FormattedString * _Nonnull _LXO(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2639, _0, _1);
}
// PUSH_CHAT_MESSAGE_GEOLIVE
_FormattedString * _Nonnull _LXP(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2640, _0, _1);
}
// PUSH_CHAT_MESSAGE_GIF
_FormattedString * _Nonnull _LXQ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2641, _0, _1);
}
// PUSH_CHAT_MESSAGE_INVOICE
_FormattedString * _Nonnull _LXR(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 2642, _0, _1, _2);
}
// PUSH_CHAT_MESSAGE_NOTEXT
_FormattedString * _Nonnull _LXS(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2643, _0, _1);
}
// PUSH_CHAT_MESSAGE_PHOTO
_FormattedString * _Nonnull _LXT(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2644, _0, _1);
}
// PUSH_CHAT_MESSAGE_PHOTOS
NSString * _Nonnull _LXU(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2645, value);
}
// PUSH_CHAT_MESSAGE_PHOTOS_TEXT
NSString * _Nonnull _LXV(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2646, value);
}
// PUSH_CHAT_MESSAGE_POLL
_FormattedString * _Nonnull _LXW(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 2647, _0, _1, _2);
}
// PUSH_CHAT_MESSAGE_QUIZ
_FormattedString * _Nonnull _LXX(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 2648, _0, _1, _2);
}
// PUSH_CHAT_MESSAGE_ROUND
_FormattedString * _Nonnull _LXY(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2649, _0, _1);
}
// PUSH_CHAT_MESSAGE_ROUNDS
NSString * _Nonnull _LXZ(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2650, value);
}
// PUSH_CHAT_MESSAGE_STICKER
_FormattedString * _Nonnull _LYa(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 2651, _0, _1, _2);
}
// PUSH_CHAT_MESSAGE_TEXT
_FormattedString * _Nonnull _LYb(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 2652, _0, _1, _2);
}
// PUSH_CHAT_MESSAGE_VIDEO
_FormattedString * _Nonnull _LYc(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2653, _0, _1);
}
// PUSH_CHAT_MESSAGE_VIDEOS
NSString * _Nonnull _LYd(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2654, value);
}
// PUSH_CHAT_MESSAGE_VIDEOS_TEXT
NSString * _Nonnull _LYe(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2655, value);
}
// PUSH_CHAT_PHOTO_EDITED
_FormattedString * _Nonnull _LYf(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2656, _0, _1);
}
// PUSH_CHAT_RETURNED
_FormattedString * _Nonnull _LYg(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2657, _0, _1);
}
// PUSH_CHAT_TITLE_EDITED
_FormattedString * _Nonnull _LYh(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2658, _0, _1);
}
// PUSH_CHAT_VOICECHAT_END
_FormattedString * _Nonnull _LYi(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2659, _0, _1);
}
// PUSH_CHAT_VOICECHAT_INVITE
_FormattedString * _Nonnull _LYj(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 2660, _0, _1, _2);
}
// PUSH_CHAT_VOICECHAT_INVITE_YOU
_FormattedString * _Nonnull _LYk(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2661, _0, _1);
}
// PUSH_CHAT_VOICECHAT_START
_FormattedString * _Nonnull _LYl(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2662, _0, _1);
}
// PUSH_CONTACT_JOINED
_FormattedString * _Nonnull _LYm(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2663, _0);
}
// PUSH_ENCRYPTED_MESSAGE
_FormattedString * _Nonnull _LYn(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2664, _0);
}
// PUSH_ENCRYPTION_ACCEPT
_FormattedString * _Nonnull _LYo(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2665, _0);
}
// PUSH_ENCRYPTION_REQUEST
_FormattedString * _Nonnull _LYp(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2666, _0);
}
// PUSH_LOCKED_MESSAGE
_FormattedString * _Nonnull _LYq(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2667, _0);
}
// PUSH_MESSAGE
_FormattedString * _Nonnull _LYr(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2668, _0);
}
// PUSH_MESSAGES
NSString * _Nonnull _LYs(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2669, value);
}
// PUSH_MESSAGES_TEXT
NSString * _Nonnull _LYt(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2670, value);
}
// PUSH_MESSAGE_AUDIO
_FormattedString * _Nonnull _LYu(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2671, _0);
}
// PUSH_MESSAGE_CHANNEL_MESSAGE_GAME_SCORE
_FormattedString * _Nonnull _LYv(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 2672, _0, _1, _2);
}
// PUSH_MESSAGE_CONTACT
_FormattedString * _Nonnull _LYw(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2673, _0, _1);
}
// PUSH_MESSAGE_DOC
_FormattedString * _Nonnull _LYx(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2674, _0);
}
// PUSH_MESSAGE_FILES
NSString * _Nonnull _LYy(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2675, value);
}
// PUSH_MESSAGE_FILES_TEXT
NSString * _Nonnull _LYz(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2676, value);
}
// PUSH_MESSAGE_FWD
_FormattedString * _Nonnull _LYA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2677, _0);
}
// PUSH_MESSAGE_FWDS
NSString * _Nonnull _LYB(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2678, value);
}
// PUSH_MESSAGE_FWDS_TEXT
NSString * _Nonnull _LYC(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2679, value);
}
// PUSH_MESSAGE_GAME
_FormattedString * _Nonnull _LYD(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2680, _0, _1);
}
// PUSH_MESSAGE_GAME_SCORE
_FormattedString * _Nonnull _LYE(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 2681, _0, _1, _2);
}
// PUSH_MESSAGE_GEO
_FormattedString * _Nonnull _LYF(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2682, _0);
}
// PUSH_MESSAGE_GEOLIVE
_FormattedString * _Nonnull _LYG(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2683, _0);
}
// PUSH_MESSAGE_GIF
_FormattedString * _Nonnull _LYH(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2684, _0);
}
// PUSH_MESSAGE_INVOICE
_FormattedString * _Nonnull _LYI(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2685, _0, _1);
}
// PUSH_MESSAGE_NOTEXT
_FormattedString * _Nonnull _LYJ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2686, _0);
}
// PUSH_MESSAGE_PHOTO
_FormattedString * _Nonnull _LYK(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2687, _0);
}
// PUSH_MESSAGE_PHOTOS
NSString * _Nonnull _LYL(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2688, value);
}
// PUSH_MESSAGE_PHOTOS_TEXT
NSString * _Nonnull _LYM(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2689, value);
}
// PUSH_MESSAGE_PHOTO_SECRET
_FormattedString * _Nonnull _LYN(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2690, _0);
}
// PUSH_MESSAGE_POLL
_FormattedString * _Nonnull _LYO(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2691, _0, _1);
}
// PUSH_MESSAGE_QUIZ
_FormattedString * _Nonnull _LYP(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2692, _0, _1);
}
// PUSH_MESSAGE_ROUND
_FormattedString * _Nonnull _LYQ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2693, _0);
}
// PUSH_MESSAGE_ROUNDS
NSString * _Nonnull _LYR(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2694, value);
}
// PUSH_MESSAGE_SCREENSHOT
_FormattedString * _Nonnull _LYS(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2695, _0);
}
// PUSH_MESSAGE_STICKER
_FormattedString * _Nonnull _LYT(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2696, _0, _1);
}
// PUSH_MESSAGE_TEXT
_FormattedString * _Nonnull _LYU(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2697, _0, _1);
}
// PUSH_MESSAGE_VIDEO
_FormattedString * _Nonnull _LYV(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2698, _0);
}
// PUSH_MESSAGE_VIDEOS
NSString * _Nonnull _LYW(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2699, value);
}
// PUSH_MESSAGE_VIDEOS_TEXT
NSString * _Nonnull _LYX(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2700, value);
}
// PUSH_MESSAGE_VIDEO_SECRET
_FormattedString * _Nonnull _LYY(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2701, _0);
}
// PUSH_PHONE_CALL_MISSED
_FormattedString * _Nonnull _LYZ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2702, _0);
}
// PUSH_PHONE_CALL_REQUEST
_FormattedString * _Nonnull _LZa(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2703, _0);
}
// PUSH_PINNED_AUDIO
_FormattedString * _Nonnull _LZb(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2704, _0);
}
// PUSH_PINNED_CONTACT
_FormattedString * _Nonnull _LZc(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2705, _0, _1);
}
// PUSH_PINNED_DOC
_FormattedString * _Nonnull _LZd(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2706, _0);
}
// PUSH_PINNED_GAME
_FormattedString * _Nonnull _LZe(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2707, _0);
}
// PUSH_PINNED_GAME_SCORE
_FormattedString * _Nonnull _LZf(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2708, _0);
}
// PUSH_PINNED_GEO
_FormattedString * _Nonnull _LZg(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2709, _0);
}
// PUSH_PINNED_GEOLIVE
_FormattedString * _Nonnull _LZh(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2710, _0);
}
// PUSH_PINNED_GIF
_FormattedString * _Nonnull _LZi(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2711, _0);
}
// PUSH_PINNED_INVOICE
_FormattedString * _Nonnull _LZj(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2712, _0);
}
// PUSH_PINNED_NOTEXT
_FormattedString * _Nonnull _LZk(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2713, _0);
}
// PUSH_PINNED_PHOTO
_FormattedString * _Nonnull _LZl(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2714, _0);
}
// PUSH_PINNED_POLL
_FormattedString * _Nonnull _LZm(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2715, _0);
}
// PUSH_PINNED_QUIZ
_FormattedString * _Nonnull _LZn(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2716, _0);
}
// PUSH_PINNED_ROUND
_FormattedString * _Nonnull _LZo(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2717, _0);
}
// PUSH_PINNED_STICKER
_FormattedString * _Nonnull _LZp(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2718, _0, _1);
}
// PUSH_PINNED_TEXT
_FormattedString * _Nonnull _LZq(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2719, _0, _1);
}
// PUSH_PINNED_VIDEO
_FormattedString * _Nonnull _LZr(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2720, _0);
}
// PUSH_REMINDER_TITLE
NSString * _Nonnull _LZs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2721);
}
// PUSH_SENDER_YOU
NSString * _Nonnull _LZt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2722);
}
// PUSH_VIDEO_CALL_MISSED
_FormattedString * _Nonnull _LZu(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2723, _0);
}
// PUSH_VIDEO_CALL_REQUEST
_FormattedString * _Nonnull _LZv(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2724, _0);
}
// Paint.Arrow
NSString * _Nonnull _LZw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2725);
}
// Paint.Clear
NSString * _Nonnull _LZx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2726);
}
// Paint.ClearConfirm
NSString * _Nonnull _LZy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2727);
}
// Paint.Delete
NSString * _Nonnull _LZz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2728);
}
// Paint.Duplicate
NSString * _Nonnull _LZA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2729);
}
// Paint.Edit
NSString * _Nonnull _LZB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2730);
}
// Paint.Framed
NSString * _Nonnull _LZC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2731);
}
// Paint.Marker
NSString * _Nonnull _LZD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2732);
}
// Paint.Masks
NSString * _Nonnull _LZE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2733);
}
// Paint.Neon
NSString * _Nonnull _LZF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2734);
}
// Paint.Outlined
NSString * _Nonnull _LZG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2735);
}
// Paint.Pen
NSString * _Nonnull _LZH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2736);
}
// Paint.RecentStickers
NSString * _Nonnull _LZI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2737);
}
// Paint.Regular
NSString * _Nonnull _LZJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2738);
}
// Paint.Stickers
NSString * _Nonnull _LZK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2739);
}
// Passcode.AppLockedAlert
NSString * _Nonnull _LZL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2740);
}
// PasscodeSettings.4DigitCode
NSString * _Nonnull _LZM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2741);
}
// PasscodeSettings.6DigitCode
NSString * _Nonnull _LZN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2742);
}
// PasscodeSettings.AlphanumericCode
NSString * _Nonnull _LZO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2743);
}
// PasscodeSettings.AutoLock
NSString * _Nonnull _LZP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2744);
}
// PasscodeSettings.AutoLock.Disabled
NSString * _Nonnull _LZQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2745);
}
// PasscodeSettings.AutoLock.IfAwayFor_1hour
NSString * _Nonnull _LZR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2746);
}
// PasscodeSettings.AutoLock.IfAwayFor_1minute
NSString * _Nonnull _LZS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2747);
}
// PasscodeSettings.AutoLock.IfAwayFor_5hours
NSString * _Nonnull _LZT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2748);
}
// PasscodeSettings.AutoLock.IfAwayFor_5minutes
NSString * _Nonnull _LZU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2749);
}
// PasscodeSettings.ChangePasscode
NSString * _Nonnull _LZV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2750);
}
// PasscodeSettings.DoNotMatch
NSString * _Nonnull _LZW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2751);
}
// PasscodeSettings.EncryptData
NSString * _Nonnull _LZX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2752);
}
// PasscodeSettings.EncryptDataHelp
NSString * _Nonnull _LZY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2753);
}
// PasscodeSettings.FailedAttempts
NSString * _Nonnull _LZZ(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2754, value);
}
// PasscodeSettings.Help
NSString * _Nonnull _Laaa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2755);
}
// PasscodeSettings.HelpBottom
NSString * _Nonnull _Laab(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2756);
}
// PasscodeSettings.HelpTop
NSString * _Nonnull _Laac(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2757);
}
// PasscodeSettings.PasscodeOptions
NSString * _Nonnull _Laad(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2758);
}
// PasscodeSettings.SimplePasscode
NSString * _Nonnull _Laae(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2759);
}
// PasscodeSettings.SimplePasscodeHelp
NSString * _Nonnull _Laaf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2760);
}
// PasscodeSettings.Title
NSString * _Nonnull _Laag(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2761);
}
// PasscodeSettings.TryAgainIn1Minute
NSString * _Nonnull _Laah(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2762);
}
// PasscodeSettings.TurnPasscodeOff
NSString * _Nonnull _Laai(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2763);
}
// PasscodeSettings.TurnPasscodeOn
NSString * _Nonnull _Laaj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2764);
}
// PasscodeSettings.UnlockWithFaceId
NSString * _Nonnull _Laak(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2765);
}
// PasscodeSettings.UnlockWithTouchId
NSString * _Nonnull _Laal(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2766);
}
// Passport.AcceptHelp
_FormattedString * _Nonnull _Laam(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2767, _0, _1);
}
// Passport.Address.AddBankStatement
NSString * _Nonnull _Laan(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2768);
}
// Passport.Address.AddPassportRegistration
NSString * _Nonnull _Laao(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2769);
}
// Passport.Address.AddRentalAgreement
NSString * _Nonnull _Laap(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2770);
}
// Passport.Address.AddResidentialAddress
NSString * _Nonnull _Laaq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2771);
}
// Passport.Address.AddTemporaryRegistration
NSString * _Nonnull _Laar(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2772);
}
// Passport.Address.AddUtilityBill
NSString * _Nonnull _Laas(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2773);
}
// Passport.Address.Address
NSString * _Nonnull _Laat(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2774);
}
// Passport.Address.City
NSString * _Nonnull _Laau(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2775);
}
// Passport.Address.CityPlaceholder
NSString * _Nonnull _Laav(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2776);
}
// Passport.Address.Country
NSString * _Nonnull _Laaw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2777);
}
// Passport.Address.CountryPlaceholder
NSString * _Nonnull _Laax(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2778);
}
// Passport.Address.EditBankStatement
NSString * _Nonnull _Laay(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2779);
}
// Passport.Address.EditPassportRegistration
NSString * _Nonnull _Laaz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2780);
}
// Passport.Address.EditRentalAgreement
NSString * _Nonnull _LaaA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2781);
}
// Passport.Address.EditResidentialAddress
NSString * _Nonnull _LaaB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2782);
}
// Passport.Address.EditTemporaryRegistration
NSString * _Nonnull _LaaC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2783);
}
// Passport.Address.EditUtilityBill
NSString * _Nonnull _LaaD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2784);
}
// Passport.Address.OneOfTypeBankStatement
NSString * _Nonnull _LaaE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2785);
}
// Passport.Address.OneOfTypePassportRegistration
NSString * _Nonnull _LaaF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2786);
}
// Passport.Address.OneOfTypeRentalAgreement
NSString * _Nonnull _LaaG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2787);
}
// Passport.Address.OneOfTypeTemporaryRegistration
NSString * _Nonnull _LaaH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2788);
}
// Passport.Address.OneOfTypeUtilityBill
NSString * _Nonnull _LaaI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2789);
}
// Passport.Address.Postcode
NSString * _Nonnull _LaaJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2790);
}
// Passport.Address.PostcodePlaceholder
NSString * _Nonnull _LaaK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2791);
}
// Passport.Address.Region
NSString * _Nonnull _LaaL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2792);
}
// Passport.Address.RegionPlaceholder
NSString * _Nonnull _LaaM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2793);
}
// Passport.Address.ScansHelp
NSString * _Nonnull _LaaN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2794);
}
// Passport.Address.Street
NSString * _Nonnull _LaaO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2795);
}
// Passport.Address.Street1Placeholder
NSString * _Nonnull _LaaP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2796);
}
// Passport.Address.Street2Placeholder
NSString * _Nonnull _LaaQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2797);
}
// Passport.Address.TypeBankStatement
NSString * _Nonnull _LaaR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2798);
}
// Passport.Address.TypeBankStatementUploadScan
NSString * _Nonnull _LaaS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2799);
}
// Passport.Address.TypePassportRegistration
NSString * _Nonnull _LaaT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2800);
}
// Passport.Address.TypePassportRegistrationUploadScan
NSString * _Nonnull _LaaU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2801);
}
// Passport.Address.TypeRentalAgreement
NSString * _Nonnull _LaaV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2802);
}
// Passport.Address.TypeRentalAgreementUploadScan
NSString * _Nonnull _LaaW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2803);
}
// Passport.Address.TypeResidentialAddress
NSString * _Nonnull _LaaX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2804);
}
// Passport.Address.TypeTemporaryRegistration
NSString * _Nonnull _LaaY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2805);
}
// Passport.Address.TypeTemporaryRegistrationUploadScan
NSString * _Nonnull _LaaZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2806);
}
// Passport.Address.TypeUtilityBill
NSString * _Nonnull _Laba(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2807);
}
// Passport.Address.TypeUtilityBillUploadScan
NSString * _Nonnull _Labb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2808);
}
// Passport.Address.UploadOneOfScan
_FormattedString * _Nonnull _Labc(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2809, _0);
}
// Passport.Authorize
NSString * _Nonnull _Labd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2810);
}
// Passport.CorrectErrors
NSString * _Nonnull _Labe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2811);
}
// Passport.DeleteAddress
NSString * _Nonnull _Labf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2812);
}
// Passport.DeleteAddressConfirmation
NSString * _Nonnull _Labg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2813);
}
// Passport.DeleteDocument
NSString * _Nonnull _Labh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2814);
}
// Passport.DeleteDocumentConfirmation
NSString * _Nonnull _Labi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2815);
}
// Passport.DeletePassport
NSString * _Nonnull _Labj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2816);
}
// Passport.DeletePassportConfirmation
NSString * _Nonnull _Labk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2817);
}
// Passport.DeletePersonalDetails
NSString * _Nonnull _Labl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2818);
}
// Passport.DeletePersonalDetailsConfirmation
NSString * _Nonnull _Labm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2819);
}
// Passport.DiscardMessageAction
NSString * _Nonnull _Labn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2820);
}
// Passport.DiscardMessageDescription
NSString * _Nonnull _Labo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2821);
}
// Passport.DiscardMessageTitle
NSString * _Nonnull _Labp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2822);
}
// Passport.Email.CodeHelp
_FormattedString * _Nonnull _Labq(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2823, _0);
}
// Passport.Email.Delete
NSString * _Nonnull _Labr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2824);
}
// Passport.Email.EmailPlaceholder
NSString * _Nonnull _Labs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2825);
}
// Passport.Email.EnterOtherEmail
NSString * _Nonnull _Labt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2826);
}
// Passport.Email.Help
NSString * _Nonnull _Labu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2827);
}
// Passport.Email.Title
NSString * _Nonnull _Labv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2828);
}
// Passport.Email.UseTelegramEmail
_FormattedString * _Nonnull _Labw(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2829, _0);
}
// Passport.Email.UseTelegramEmailHelp
NSString * _Nonnull _Labx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2830);
}
// Passport.FieldAddress
NSString * _Nonnull _Laby(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2831);
}
// Passport.FieldAddressHelp
NSString * _Nonnull _Labz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2832);
}
// Passport.FieldAddressTranslationHelp
NSString * _Nonnull _LabA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2833);
}
// Passport.FieldAddressUploadHelp
NSString * _Nonnull _LabB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2834);
}
// Passport.FieldEmail
NSString * _Nonnull _LabC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2835);
}
// Passport.FieldEmailHelp
NSString * _Nonnull _LabD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2836);
}
// Passport.FieldIdentity
NSString * _Nonnull _LabE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2837);
}
// Passport.FieldIdentityDetailsHelp
NSString * _Nonnull _LabF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2838);
}
// Passport.FieldIdentitySelfieHelp
NSString * _Nonnull _LabG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2839);
}
// Passport.FieldIdentityTranslationHelp
NSString * _Nonnull _LabH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2840);
}
// Passport.FieldIdentityUploadHelp
NSString * _Nonnull _LabI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2841);
}
// Passport.FieldOneOf.Delimeter
NSString * _Nonnull _LabJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2842);
}
// Passport.FieldOneOf.FinalDelimeter
NSString * _Nonnull _LabK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2843);
}
// Passport.FieldOneOf.Or
_FormattedString * _Nonnull _LabL(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2844, _0, _1);
}
// Passport.FieldPhone
NSString * _Nonnull _LabM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2845);
}
// Passport.FieldPhoneHelp
NSString * _Nonnull _LabN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2846);
}
// Passport.FloodError
NSString * _Nonnull _LabO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2847);
}
// Passport.ForgottenPassword
NSString * _Nonnull _LabP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2848);
}
// Passport.Identity.AddDriversLicense
NSString * _Nonnull _LabQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2849);
}
// Passport.Identity.AddIdentityCard
NSString * _Nonnull _LabR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2850);
}
// Passport.Identity.AddInternalPassport
NSString * _Nonnull _LabS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2851);
}
// Passport.Identity.AddPassport
NSString * _Nonnull _LabT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2852);
}
// Passport.Identity.AddPersonalDetails
NSString * _Nonnull _LabU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2853);
}
// Passport.Identity.Country
NSString * _Nonnull _LabV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2854);
}
// Passport.Identity.CountryPlaceholder
NSString * _Nonnull _LabW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2855);
}
// Passport.Identity.DateOfBirth
NSString * _Nonnull _LabX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2856);
}
// Passport.Identity.DateOfBirthPlaceholder
NSString * _Nonnull _LabY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2857);
}
// Passport.Identity.DocumentDetails
NSString * _Nonnull _LabZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2858);
}
// Passport.Identity.DocumentNumber
NSString * _Nonnull _Laca(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2859);
}
// Passport.Identity.DocumentNumberPlaceholder
NSString * _Nonnull _Lacb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2860);
}
// Passport.Identity.DoesNotExpire
NSString * _Nonnull _Lacc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2861);
}
// Passport.Identity.EditDriversLicense
NSString * _Nonnull _Lacd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2862);
}
// Passport.Identity.EditIdentityCard
NSString * _Nonnull _Lace(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2863);
}
// Passport.Identity.EditInternalPassport
NSString * _Nonnull _Lacf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2864);
}
// Passport.Identity.EditPassport
NSString * _Nonnull _Lacg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2865);
}
// Passport.Identity.EditPersonalDetails
NSString * _Nonnull _Lach(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2866);
}
// Passport.Identity.ExpiryDate
NSString * _Nonnull _Laci(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2867);
}
// Passport.Identity.ExpiryDateNone
NSString * _Nonnull _Lacj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2868);
}
// Passport.Identity.ExpiryDatePlaceholder
NSString * _Nonnull _Lack(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2869);
}
// Passport.Identity.FilesTitle
NSString * _Nonnull _Lacl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2870);
}
// Passport.Identity.FilesUploadNew
NSString * _Nonnull _Lacm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2871);
}
// Passport.Identity.FilesView
NSString * _Nonnull _Lacn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2872);
}
// Passport.Identity.FrontSide
NSString * _Nonnull _Laco(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2873);
}
// Passport.Identity.FrontSideHelp
NSString * _Nonnull _Lacp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2874);
}
// Passport.Identity.Gender
NSString * _Nonnull _Lacq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2875);
}
// Passport.Identity.GenderFemale
NSString * _Nonnull _Lacr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2876);
}
// Passport.Identity.GenderMale
NSString * _Nonnull _Lacs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2877);
}
// Passport.Identity.GenderPlaceholder
NSString * _Nonnull _Lact(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2878);
}
// Passport.Identity.IssueDate
NSString * _Nonnull _Lacu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2879);
}
// Passport.Identity.IssueDatePlaceholder
NSString * _Nonnull _Lacv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2880);
}
// Passport.Identity.LatinNameHelp
NSString * _Nonnull _Lacw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2881);
}
// Passport.Identity.MainPage
NSString * _Nonnull _Lacx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2882);
}
// Passport.Identity.MainPageHelp
NSString * _Nonnull _Lacy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2883);
}
// Passport.Identity.MiddleName
NSString * _Nonnull _Lacz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2884);
}
// Passport.Identity.MiddleNamePlaceholder
NSString * _Nonnull _LacA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2885);
}
// Passport.Identity.Name
NSString * _Nonnull _LacB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2886);
}
// Passport.Identity.NamePlaceholder
NSString * _Nonnull _LacC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2887);
}
// Passport.Identity.NativeNameGenericHelp
_FormattedString * _Nonnull _LacD(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2888, _0);
}
// Passport.Identity.NativeNameGenericTitle
NSString * _Nonnull _LacE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2889);
}
// Passport.Identity.NativeNameHelp
NSString * _Nonnull _LacF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2890);
}
// Passport.Identity.NativeNameTitle
_FormattedString * _Nonnull _LacG(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2891, _0);
}
// Passport.Identity.OneOfTypeDriversLicense
NSString * _Nonnull _LacH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2892);
}
// Passport.Identity.OneOfTypeIdentityCard
NSString * _Nonnull _LacI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2893);
}
// Passport.Identity.OneOfTypeInternalPassport
NSString * _Nonnull _LacJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2894);
}
// Passport.Identity.OneOfTypePassport
NSString * _Nonnull _LacK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2895);
}
// Passport.Identity.ResidenceCountry
NSString * _Nonnull _LacL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2896);
}
// Passport.Identity.ResidenceCountryPlaceholder
NSString * _Nonnull _LacM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2897);
}
// Passport.Identity.ReverseSide
NSString * _Nonnull _LacN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2898);
}
// Passport.Identity.ReverseSideHelp
NSString * _Nonnull _LacO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2899);
}
// Passport.Identity.ScansHelp
NSString * _Nonnull _LacP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2900);
}
// Passport.Identity.Selfie
NSString * _Nonnull _LacQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2901);
}
// Passport.Identity.SelfieHelp
NSString * _Nonnull _LacR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2902);
}
// Passport.Identity.Surname
NSString * _Nonnull _LacS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2903);
}
// Passport.Identity.SurnamePlaceholder
NSString * _Nonnull _LacT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2904);
}
// Passport.Identity.Translation
NSString * _Nonnull _LacU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2905);
}
// Passport.Identity.TranslationHelp
NSString * _Nonnull _LacV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2906);
}
// Passport.Identity.Translations
NSString * _Nonnull _LacW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2907);
}
// Passport.Identity.TranslationsHelp
NSString * _Nonnull _LacX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2908);
}
// Passport.Identity.TypeDriversLicense
NSString * _Nonnull _LacY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2909);
}
// Passport.Identity.TypeDriversLicenseUploadScan
NSString * _Nonnull _LacZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2910);
}
// Passport.Identity.TypeIdentityCard
NSString * _Nonnull _Lada(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2911);
}
// Passport.Identity.TypeIdentityCardUploadScan
NSString * _Nonnull _Ladb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2912);
}
// Passport.Identity.TypeInternalPassport
NSString * _Nonnull _Ladc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2913);
}
// Passport.Identity.TypeInternalPassportUploadScan
NSString * _Nonnull _Ladd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2914);
}
// Passport.Identity.TypePassport
NSString * _Nonnull _Lade(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2915);
}
// Passport.Identity.TypePassportUploadScan
NSString * _Nonnull _Ladf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2916);
}
// Passport.Identity.TypePersonalDetails
NSString * _Nonnull _Ladg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2917);
}
// Passport.Identity.UploadOneOfScan
_FormattedString * _Nonnull _Ladh(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2918, _0);
}
// Passport.InfoFAQ_URL
NSString * _Nonnull _Ladi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2919);
}
// Passport.InfoLearnMore
NSString * _Nonnull _Ladj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2920);
}
// Passport.InfoText
NSString * _Nonnull _Ladk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2921);
}
// Passport.InfoTitle
NSString * _Nonnull _Ladl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2922);
}
// Passport.InvalidPasswordError
NSString * _Nonnull _Ladm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2923);
}
// Passport.Language.ar
NSString * _Nonnull _Ladn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2924);
}
// Passport.Language.az
NSString * _Nonnull _Lado(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2925);
}
// Passport.Language.bg
NSString * _Nonnull _Ladp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2926);
}
// Passport.Language.bn
NSString * _Nonnull _Ladq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2927);
}
// Passport.Language.cs
NSString * _Nonnull _Ladr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2928);
}
// Passport.Language.da
NSString * _Nonnull _Lads(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2929);
}
// Passport.Language.de
NSString * _Nonnull _Ladt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2930);
}
// Passport.Language.dv
NSString * _Nonnull _Ladu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2931);
}
// Passport.Language.dz
NSString * _Nonnull _Ladv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2932);
}
// Passport.Language.el
NSString * _Nonnull _Ladw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2933);
}
// Passport.Language.en
NSString * _Nonnull _Ladx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2934);
}
// Passport.Language.es
NSString * _Nonnull _Lady(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2935);
}
// Passport.Language.et
NSString * _Nonnull _Ladz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2936);
}
// Passport.Language.fa
NSString * _Nonnull _LadA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2937);
}
// Passport.Language.fr
NSString * _Nonnull _LadB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2938);
}
// Passport.Language.he
NSString * _Nonnull _LadC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2939);
}
// Passport.Language.hr
NSString * _Nonnull _LadD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2940);
}
// Passport.Language.hu
NSString * _Nonnull _LadE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2941);
}
// Passport.Language.hy
NSString * _Nonnull _LadF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2942);
}
// Passport.Language.id
NSString * _Nonnull _LadG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2943);
}
// Passport.Language.is
NSString * _Nonnull _LadH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2944);
}
// Passport.Language.it
NSString * _Nonnull _LadI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2945);
}
// Passport.Language.ja
NSString * _Nonnull _LadJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2946);
}
// Passport.Language.ka
NSString * _Nonnull _LadK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2947);
}
// Passport.Language.km
NSString * _Nonnull _LadL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2948);
}
// Passport.Language.ko
NSString * _Nonnull _LadM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2949);
}
// Passport.Language.lo
NSString * _Nonnull _LadN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2950);
}
// Passport.Language.lt
NSString * _Nonnull _LadO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2951);
}
// Passport.Language.lv
NSString * _Nonnull _LadP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2952);
}
// Passport.Language.mk
NSString * _Nonnull _LadQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2953);
}
// Passport.Language.mn
NSString * _Nonnull _LadR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2954);
}
// Passport.Language.ms
NSString * _Nonnull _LadS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2955);
}
// Passport.Language.my
NSString * _Nonnull _LadT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2956);
}
// Passport.Language.ne
NSString * _Nonnull _LadU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2957);
}
// Passport.Language.nl
NSString * _Nonnull _LadV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2958);
}
// Passport.Language.pl
NSString * _Nonnull _LadW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2959);
}
// Passport.Language.pt
NSString * _Nonnull _LadX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2960);
}
// Passport.Language.ro
NSString * _Nonnull _LadY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2961);
}
// Passport.Language.ru
NSString * _Nonnull _LadZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2962);
}
// Passport.Language.sk
NSString * _Nonnull _Laea(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2963);
}
// Passport.Language.sl
NSString * _Nonnull _Laeb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2964);
}
// Passport.Language.th
NSString * _Nonnull _Laec(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2965);
}
// Passport.Language.tk
NSString * _Nonnull _Laed(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2966);
}
// Passport.Language.tr
NSString * _Nonnull _Laee(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2967);
}
// Passport.Language.uk
NSString * _Nonnull _Laef(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2968);
}
// Passport.Language.uz
NSString * _Nonnull _Laeg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2969);
}
// Passport.Language.vi
NSString * _Nonnull _Laeh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2970);
}
// Passport.NotLoggedInMessage
NSString * _Nonnull _Laei(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2971);
}
// Passport.PassportInformation
NSString * _Nonnull _Laej(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2972);
}
// Passport.PasswordCompleteSetup
NSString * _Nonnull _Laek(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2973);
}
// Passport.PasswordCreate
NSString * _Nonnull _Lael(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2974);
}
// Passport.PasswordDescription
NSString * _Nonnull _Laem(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2975);
}
// Passport.PasswordHelp
NSString * _Nonnull _Laen(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2976);
}
// Passport.PasswordNext
NSString * _Nonnull _Laeo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2977);
}
// Passport.PasswordPlaceholder
NSString * _Nonnull _Laep(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2978);
}
// Passport.PasswordReset
NSString * _Nonnull _Laeq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2979);
}
// Passport.Phone.Delete
NSString * _Nonnull _Laer(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2980);
}
// Passport.Phone.EnterOtherNumber
NSString * _Nonnull _Laes(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2981);
}
// Passport.Phone.Help
NSString * _Nonnull _Laet(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2982);
}
// Passport.Phone.Title
NSString * _Nonnull _Laeu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2983);
}
// Passport.Phone.UseTelegramNumber
_FormattedString * _Nonnull _Laev(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2984, _0);
}
// Passport.Phone.UseTelegramNumberHelp
NSString * _Nonnull _Laew(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2985);
}
// Passport.PrivacyPolicy
_FormattedString * _Nonnull _Laex(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 2986, _0, _1);
}
// Passport.RequestHeader
_FormattedString * _Nonnull _Laey(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2987, _0);
}
// Passport.RequestedInformation
NSString * _Nonnull _Laez(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2988);
}
// Passport.ScanPassport
NSString * _Nonnull _LaeA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2989);
}
// Passport.ScanPassportHelp
NSString * _Nonnull _LaeB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2990);
}
// Passport.Scans
NSString * _Nonnull _LaeC(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 2991, value);
}
// Passport.Scans.ScanIndex
_FormattedString * _Nonnull _LaeD(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 2992, _0);
}
// Passport.Scans.Upload
NSString * _Nonnull _LaeE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2993);
}
// Passport.Scans.UploadNew
NSString * _Nonnull _LaeF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2994);
}
// Passport.ScansHeader
NSString * _Nonnull _LaeG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2995);
}
// Passport.Title
NSString * _Nonnull _LaeH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2996);
}
// Passport.UpdateRequiredError
NSString * _Nonnull _LaeI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2997);
}
// PeerInfo.AddToContacts
NSString * _Nonnull _LaeJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2998);
}
// PeerInfo.AutoremoveMessages
NSString * _Nonnull _LaeK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 2999);
}
// PeerInfo.AutoremoveMessagesDisabled
NSString * _Nonnull _LaeL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3000);
}
// PeerInfo.BioExpand
NSString * _Nonnull _LaeM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3001);
}
// PeerInfo.ButtonAddMember
NSString * _Nonnull _LaeN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3002);
}
// PeerInfo.ButtonCall
NSString * _Nonnull _LaeO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3003);
}
// PeerInfo.ButtonDiscuss
NSString * _Nonnull _LaeP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3004);
}
// PeerInfo.ButtonLeave
NSString * _Nonnull _LaeQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3005);
}
// PeerInfo.ButtonMessage
NSString * _Nonnull _LaeR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3006);
}
// PeerInfo.ButtonMore
NSString * _Nonnull _LaeS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3007);
}
// PeerInfo.ButtonMute
NSString * _Nonnull _LaeT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3008);
}
// PeerInfo.ButtonSearch
NSString * _Nonnull _LaeU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3009);
}
// PeerInfo.ButtonUnmute
NSString * _Nonnull _LaeV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3010);
}
// PeerInfo.ButtonVideoCall
NSString * _Nonnull _LaeW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3011);
}
// PeerInfo.ButtonVoiceChat
NSString * _Nonnull _LaeX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3012);
}
// PeerInfo.CustomizeNotifications
NSString * _Nonnull _LaeY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3013);
}
// PeerInfo.GroupAboutItem
NSString * _Nonnull _LaeZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3014);
}
// PeerInfo.PaneAudio
NSString * _Nonnull _Lafa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3015);
}
// PeerInfo.PaneFiles
NSString * _Nonnull _Lafb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3016);
}
// PeerInfo.PaneGifs
NSString * _Nonnull _Lafc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3017);
}
// PeerInfo.PaneGroups
NSString * _Nonnull _Lafd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3018);
}
// PeerInfo.PaneLinks
NSString * _Nonnull _Lafe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3019);
}
// PeerInfo.PaneMedia
NSString * _Nonnull _Laff(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3020);
}
// PeerInfo.PaneMembers
NSString * _Nonnull _Lafg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3021);
}
// PeerInfo.PaneVoiceAndVideo
NSString * _Nonnull _Lafh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3022);
}
// PeerInfo.ReportProfilePhoto
NSString * _Nonnull _Lafi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3023);
}
// PeerInfo.ReportProfileVideo
NSString * _Nonnull _Lafj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3024);
}
// PeerSelection.ImportIntoNewGroup
NSString * _Nonnull _Lafk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3025);
}
// PeopleNearby.CreateGroup
NSString * _Nonnull _Lafl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3026);
}
// PeopleNearby.Description
NSString * _Nonnull _Lafm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3027);
}
// PeopleNearby.DiscoverDescription
NSString * _Nonnull _Lafn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3028);
}
// PeopleNearby.Groups
NSString * _Nonnull _Lafo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3029);
}
// PeopleNearby.MakeInvisible
NSString * _Nonnull _Lafp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3030);
}
// PeopleNearby.MakeVisible
NSString * _Nonnull _Lafq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3031);
}
// PeopleNearby.MakeVisibleDescription
NSString * _Nonnull _Lafr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3032);
}
// PeopleNearby.MakeVisibleTitle
NSString * _Nonnull _Lafs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3033);
}
// PeopleNearby.NoMembers
NSString * _Nonnull _Laft(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3034);
}
// PeopleNearby.ShowMorePeople
NSString * _Nonnull _Lafu(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3035, value);
}
// PeopleNearby.Title
NSString * _Nonnull _Lafv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3036);
}
// PeopleNearby.Users
NSString * _Nonnull _Lafw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3037);
}
// PeopleNearby.UsersEmpty
NSString * _Nonnull _Lafx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3038);
}
// PeopleNearby.VisibleUntil
_FormattedString * _Nonnull _Lafy(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3039, _0);
}
// Permissions.CellularDataAllowInSettings.v0
NSString * _Nonnull _Lafz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3040);
}
// Permissions.CellularDataText.v0
NSString * _Nonnull _LafA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3041);
}
// Permissions.CellularDataTitle.v0
NSString * _Nonnull _LafB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3042);
}
// Permissions.ContactsAllow.v0
NSString * _Nonnull _LafC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3043);
}
// Permissions.ContactsAllowInSettings.v0
NSString * _Nonnull _LafD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3044);
}
// Permissions.ContactsText.v0
NSString * _Nonnull _LafE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3045);
}
// Permissions.ContactsTitle.v0
NSString * _Nonnull _LafF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3046);
}
// Permissions.NotificationsAllow.v0
NSString * _Nonnull _LafG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3047);
}
// Permissions.NotificationsAllowInSettings.v0
NSString * _Nonnull _LafH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3048);
}
// Permissions.NotificationsText.v0
NSString * _Nonnull _LafI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3049);
}
// Permissions.NotificationsTitle.v0
NSString * _Nonnull _LafJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3050);
}
// Permissions.NotificationsUnreachableText.v0
NSString * _Nonnull _LafK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3051);
}
// Permissions.PeopleNearbyAllow.v0
NSString * _Nonnull _LafL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3052);
}
// Permissions.PeopleNearbyAllowInSettings.v0
NSString * _Nonnull _LafM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3053);
}
// Permissions.PeopleNearbyText.v0
NSString * _Nonnull _LafN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3054);
}
// Permissions.PeopleNearbyTitle.v0
NSString * _Nonnull _LafO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3055);
}
// Permissions.PrivacyPolicy
NSString * _Nonnull _LafP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3056);
}
// Permissions.SiriAllow.v0
NSString * _Nonnull _LafQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3057);
}
// Permissions.SiriAllowInSettings.v0
NSString * _Nonnull _LafR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3058);
}
// Permissions.SiriText.v0
NSString * _Nonnull _LafS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3059);
}
// Permissions.SiriTitle.v0
NSString * _Nonnull _LafT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3060);
}
// Permissions.Skip
NSString * _Nonnull _LafU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3061);
}
// PhoneLabel.Title
NSString * _Nonnull _LafV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3062);
}
// PhoneNumberHelp.Alert
NSString * _Nonnull _LafW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3063);
}
// PhoneNumberHelp.ChangeNumber
NSString * _Nonnull _LafX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3064);
}
// PhoneNumberHelp.Help
NSString * _Nonnull _LafY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3065);
}
// PhotoEditor.BlurToolLinear
NSString * _Nonnull _LafZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3066);
}
// PhotoEditor.BlurToolOff
NSString * _Nonnull _Laga(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3067);
}
// PhotoEditor.BlurToolPortrait
NSString * _Nonnull _Lagb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3068);
}
// PhotoEditor.BlurToolRadial
NSString * _Nonnull _Lagc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3069);
}
// PhotoEditor.ContrastTool
NSString * _Nonnull _Lagd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3070);
}
// PhotoEditor.CropAspectRatioOriginal
NSString * _Nonnull _Lage(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3071);
}
// PhotoEditor.CropAspectRatioSquare
NSString * _Nonnull _Lagf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3072);
}
// PhotoEditor.CropAuto
NSString * _Nonnull _Lagg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3073);
}
// PhotoEditor.CropReset
NSString * _Nonnull _Lagh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3074);
}
// PhotoEditor.CurvesAll
NSString * _Nonnull _Lagi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3075);
}
// PhotoEditor.CurvesBlue
NSString * _Nonnull _Lagj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3076);
}
// PhotoEditor.CurvesGreen
NSString * _Nonnull _Lagk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3077);
}
// PhotoEditor.CurvesRed
NSString * _Nonnull _Lagl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3078);
}
// PhotoEditor.CurvesTool
NSString * _Nonnull _Lagm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3079);
}
// PhotoEditor.DiscardChanges
NSString * _Nonnull _Lagn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3080);
}
// PhotoEditor.EnhanceTool
NSString * _Nonnull _Lago(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3081);
}
// PhotoEditor.ExposureTool
NSString * _Nonnull _Lagp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3082);
}
// PhotoEditor.FadeTool
NSString * _Nonnull _Lagq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3083);
}
// PhotoEditor.GrainTool
NSString * _Nonnull _Lagr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3084);
}
// PhotoEditor.HighlightsTint
NSString * _Nonnull _Lags(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3085);
}
// PhotoEditor.HighlightsTool
NSString * _Nonnull _Lagt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3086);
}
// PhotoEditor.Original
NSString * _Nonnull _Lagu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3087);
}
// PhotoEditor.QualityHigh
NSString * _Nonnull _Lagv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3088);
}
// PhotoEditor.QualityLow
NSString * _Nonnull _Lagw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3089);
}
// PhotoEditor.QualityMedium
NSString * _Nonnull _Lagx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3090);
}
// PhotoEditor.QualityTool
NSString * _Nonnull _Lagy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3091);
}
// PhotoEditor.QualityVeryHigh
NSString * _Nonnull _Lagz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3092);
}
// PhotoEditor.QualityVeryLow
NSString * _Nonnull _LagA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3093);
}
// PhotoEditor.SaturationTool
NSString * _Nonnull _LagB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3094);
}
// PhotoEditor.SelectCoverFrame
NSString * _Nonnull _LagC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3095);
}
// PhotoEditor.Set
NSString * _Nonnull _LagD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3096);
}
// PhotoEditor.ShadowsTint
NSString * _Nonnull _LagE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3097);
}
// PhotoEditor.ShadowsTool
NSString * _Nonnull _LagF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3098);
}
// PhotoEditor.SharpenTool
NSString * _Nonnull _LagG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3099);
}
// PhotoEditor.SkinTool
NSString * _Nonnull _LagH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3100);
}
// PhotoEditor.Skip
NSString * _Nonnull _LagI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3101);
}
// PhotoEditor.TiltShift
NSString * _Nonnull _LagJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3102);
}
// PhotoEditor.TintTool
NSString * _Nonnull _LagK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3103);
}
// PhotoEditor.VignetteTool
NSString * _Nonnull _LagL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3104);
}
// PhotoEditor.WarmthTool
NSString * _Nonnull _LagM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3105);
}
// PollResults.Collapse
NSString * _Nonnull _LagN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3106);
}
// PollResults.ShowMore
NSString * _Nonnull _LagO(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3107, value);
}
// PollResults.Title
NSString * _Nonnull _LagP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3108);
}
// Presence.online
NSString * _Nonnull _LagQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3109);
}
// Preview.CopyAddress
NSString * _Nonnull _LagR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3110);
}
// Preview.DeleteGif
NSString * _Nonnull _LagS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3111);
}
// Preview.DeletePhoto
NSString * _Nonnull _LagT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3112);
}
// Preview.OpenInInstagram
NSString * _Nonnull _LagU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3113);
}
// Preview.SaveGif
NSString * _Nonnull _LagV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3114);
}
// Preview.SaveToCameraRoll
NSString * _Nonnull _LagW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3115);
}
// Privacy.AddNewPeer
NSString * _Nonnull _LagX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3116);
}
// Privacy.Calls
NSString * _Nonnull _LagY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3117);
}
// Privacy.Calls.AlwaysAllow
NSString * _Nonnull _LagZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3118);
}
// Privacy.Calls.AlwaysAllow.Placeholder
NSString * _Nonnull _Laha(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3119);
}
// Privacy.Calls.AlwaysAllow.Title
NSString * _Nonnull _Lahb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3120);
}
// Privacy.Calls.CustomHelp
NSString * _Nonnull _Lahc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3121);
}
// Privacy.Calls.CustomShareHelp
NSString * _Nonnull _Lahd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3122);
}
// Privacy.Calls.Integration
NSString * _Nonnull _Lahe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3123);
}
// Privacy.Calls.IntegrationHelp
NSString * _Nonnull _Lahf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3124);
}
// Privacy.Calls.NeverAllow
NSString * _Nonnull _Lahg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3125);
}
// Privacy.Calls.NeverAllow.Placeholder
NSString * _Nonnull _Lahh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3126);
}
// Privacy.Calls.NeverAllow.Title
NSString * _Nonnull _Lahi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3127);
}
// Privacy.Calls.P2P
NSString * _Nonnull _Lahj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3128);
}
// Privacy.Calls.P2PAlways
NSString * _Nonnull _Lahk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3129);
}
// Privacy.Calls.P2PContacts
NSString * _Nonnull _Lahl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3130);
}
// Privacy.Calls.P2PHelp
NSString * _Nonnull _Lahm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3131);
}
// Privacy.Calls.P2PNever
NSString * _Nonnull _Lahn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3132);
}
// Privacy.Calls.WhoCanCallMe
NSString * _Nonnull _Laho(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3133);
}
// Privacy.ChatsTitle
NSString * _Nonnull _Lahp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3134);
}
// Privacy.ContactsReset
NSString * _Nonnull _Lahq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3135);
}
// Privacy.ContactsReset.ContactsDeleted
NSString * _Nonnull _Lahr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3136);
}
// Privacy.ContactsResetConfirmation
NSString * _Nonnull _Lahs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3137);
}
// Privacy.ContactsSync
NSString * _Nonnull _Laht(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3138);
}
// Privacy.ContactsSyncHelp
NSString * _Nonnull _Lahu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3139);
}
// Privacy.ContactsTitle
NSString * _Nonnull _Lahv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3140);
}
// Privacy.DeleteDrafts
NSString * _Nonnull _Lahw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3141);
}
// Privacy.DeleteDrafts.DraftsDeleted
NSString * _Nonnull _Lahx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3142);
}
// Privacy.Forwards
NSString * _Nonnull _Lahy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3143);
}
// Privacy.Forwards.AlwaysAllow.Title
NSString * _Nonnull _Lahz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3144);
}
// Privacy.Forwards.AlwaysLink
NSString * _Nonnull _LahA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3145);
}
// Privacy.Forwards.CustomHelp
NSString * _Nonnull _LahB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3146);
}
// Privacy.Forwards.LinkIfAllowed
NSString * _Nonnull _LahC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3147);
}
// Privacy.Forwards.NeverAllow.Title
NSString * _Nonnull _LahD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3148);
}
// Privacy.Forwards.NeverLink
NSString * _Nonnull _LahE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3149);
}
// Privacy.Forwards.Preview
NSString * _Nonnull _LahF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3150);
}
// Privacy.Forwards.PreviewMessageText
NSString * _Nonnull _LahG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3151);
}
// Privacy.Forwards.WhoCanForward
NSString * _Nonnull _LahH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3152);
}
// Privacy.GroupsAndChannels
NSString * _Nonnull _LahI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3153);
}
// Privacy.GroupsAndChannels.AlwaysAllow
NSString * _Nonnull _LahJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3154);
}
// Privacy.GroupsAndChannels.AlwaysAllow.Placeholder
NSString * _Nonnull _LahK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3155);
}
// Privacy.GroupsAndChannels.AlwaysAllow.Title
NSString * _Nonnull _LahL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3156);
}
// Privacy.GroupsAndChannels.CustomHelp
NSString * _Nonnull _LahM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3157);
}
// Privacy.GroupsAndChannels.CustomShareHelp
NSString * _Nonnull _LahN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3158);
}
// Privacy.GroupsAndChannels.InviteToChannelError
_FormattedString * _Nonnull _LahO(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 3159, _0, _1);
}
// Privacy.GroupsAndChannels.InviteToChannelMultipleError
NSString * _Nonnull _LahP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3160);
}
// Privacy.GroupsAndChannels.InviteToGroupError
_FormattedString * _Nonnull _LahQ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 3161, _0, _1);
}
// Privacy.GroupsAndChannels.NeverAllow
NSString * _Nonnull _LahR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3162);
}
// Privacy.GroupsAndChannels.NeverAllow.Placeholder
NSString * _Nonnull _LahS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3163);
}
// Privacy.GroupsAndChannels.NeverAllow.Title
NSString * _Nonnull _LahT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3164);
}
// Privacy.GroupsAndChannels.WhoCanAddMe
NSString * _Nonnull _LahU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3165);
}
// Privacy.PaymentsClear.AllInfoCleared
NSString * _Nonnull _LahV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3166);
}
// Privacy.PaymentsClear.PaymentInfo
NSString * _Nonnull _LahW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3167);
}
// Privacy.PaymentsClear.PaymentInfoCleared
NSString * _Nonnull _LahX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3168);
}
// Privacy.PaymentsClear.ShippingInfo
NSString * _Nonnull _LahY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3169);
}
// Privacy.PaymentsClear.ShippingInfoCleared
NSString * _Nonnull _LahZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3170);
}
// Privacy.PaymentsClearInfo
NSString * _Nonnull _Laia(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3171);
}
// Privacy.PaymentsClearInfoDoneHelp
NSString * _Nonnull _Laib(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3172);
}
// Privacy.PaymentsClearInfoHelp
NSString * _Nonnull _Laic(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3173);
}
// Privacy.PaymentsTitle
NSString * _Nonnull _Laid(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3174);
}
// Privacy.PhoneNumber
NSString * _Nonnull _Laie(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3175);
}
// Privacy.ProfilePhoto
NSString * _Nonnull _Laif(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3176);
}
// Privacy.ProfilePhoto.AlwaysShareWith.Title
NSString * _Nonnull _Laig(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3177);
}
// Privacy.ProfilePhoto.CustomHelp
NSString * _Nonnull _Laih(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3178);
}
// Privacy.ProfilePhoto.NeverShareWith.Title
NSString * _Nonnull _Laii(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3179);
}
// Privacy.ProfilePhoto.WhoCanSeeMyPhoto
NSString * _Nonnull _Laij(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3180);
}
// Privacy.SecretChatsLinkPreviews
NSString * _Nonnull _Laik(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3181);
}
// Privacy.SecretChatsLinkPreviewsHelp
NSString * _Nonnull _Lail(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3182);
}
// Privacy.SecretChatsTitle
NSString * _Nonnull _Laim(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3183);
}
// Privacy.TopPeers
NSString * _Nonnull _Lain(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3184);
}
// Privacy.TopPeersDelete
NSString * _Nonnull _Laio(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3185);
}
// Privacy.TopPeersHelp
NSString * _Nonnull _Laip(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3186);
}
// Privacy.TopPeersWarning
NSString * _Nonnull _Laiq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3187);
}
// PrivacyLastSeenSettings.AddUsers
NSString * _Nonnull _Lair(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3188, value);
}
// PrivacyLastSeenSettings.AlwaysShareWith
NSString * _Nonnull _Lais(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3189);
}
// PrivacyLastSeenSettings.AlwaysShareWith.Placeholder
NSString * _Nonnull _Lait(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3190);
}
// PrivacyLastSeenSettings.AlwaysShareWith.Title
NSString * _Nonnull _Laiu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3191);
}
// PrivacyLastSeenSettings.CustomHelp
NSString * _Nonnull _Laiv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3192);
}
// PrivacyLastSeenSettings.CustomShareSettings.Delete
NSString * _Nonnull _Laiw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3193);
}
// PrivacyLastSeenSettings.CustomShareSettingsHelp
NSString * _Nonnull _Laix(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3194);
}
// PrivacyLastSeenSettings.EmpryUsersPlaceholder
NSString * _Nonnull _Laiy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3195);
}
// PrivacyLastSeenSettings.GroupsAndChannelsHelp
NSString * _Nonnull _Laiz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3196);
}
// PrivacyLastSeenSettings.NeverShareWith
NSString * _Nonnull _LaiA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3197);
}
// PrivacyLastSeenSettings.NeverShareWith.Placeholder
NSString * _Nonnull _LaiB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3198);
}
// PrivacyLastSeenSettings.NeverShareWith.Title
NSString * _Nonnull _LaiC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3199);
}
// PrivacyLastSeenSettings.Title
NSString * _Nonnull _LaiD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3200);
}
// PrivacyLastSeenSettings.WhoCanSeeMyTimestamp
NSString * _Nonnull _LaiE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3201);
}
// PrivacyPhoneNumberSettings.CustomDisabledHelp
NSString * _Nonnull _LaiF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3202);
}
// PrivacyPhoneNumberSettings.CustomHelp
NSString * _Nonnull _LaiG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3203);
}
// PrivacyPhoneNumberSettings.DiscoveryHeader
NSString * _Nonnull _LaiH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3204);
}
// PrivacyPhoneNumberSettings.WhoCanSeeMyPhoneNumber
NSString * _Nonnull _LaiI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3205);
}
// PrivacyPolicy.Accept
NSString * _Nonnull _LaiJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3206);
}
// PrivacyPolicy.AgeVerificationAgree
NSString * _Nonnull _LaiK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3207);
}
// PrivacyPolicy.AgeVerificationMessage
_FormattedString * _Nonnull _LaiL(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3208, _0);
}
// PrivacyPolicy.AgeVerificationTitle
NSString * _Nonnull _LaiM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3209);
}
// PrivacyPolicy.Decline
NSString * _Nonnull _LaiN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3210);
}
// PrivacyPolicy.DeclineDeclineAndDelete
NSString * _Nonnull _LaiO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3211);
}
// PrivacyPolicy.DeclineDeleteNow
NSString * _Nonnull _LaiP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3212);
}
// PrivacyPolicy.DeclineLastWarning
NSString * _Nonnull _LaiQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3213);
}
// PrivacyPolicy.DeclineMessage
NSString * _Nonnull _LaiR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3214);
}
// PrivacyPolicy.DeclineTitle
NSString * _Nonnull _LaiS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3215);
}
// PrivacyPolicy.Title
NSString * _Nonnull _LaiT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3216);
}
// PrivacySettings.AuthSessions
NSString * _Nonnull _LaiU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3217);
}
// PrivacySettings.AutoArchive
NSString * _Nonnull _LaiV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3218);
}
// PrivacySettings.AutoArchiveInfo
NSString * _Nonnull _LaiW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3219);
}
// PrivacySettings.AutoArchiveTitle
NSString * _Nonnull _LaiX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3220);
}
// PrivacySettings.BlockedPeersEmpty
NSString * _Nonnull _LaiY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3221);
}
// PrivacySettings.DataSettings
NSString * _Nonnull _LaiZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3222);
}
// PrivacySettings.DataSettingsHelp
NSString * _Nonnull _Laja(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3223);
}
// PrivacySettings.DeleteAccountHelp
NSString * _Nonnull _Lajb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3224);
}
// PrivacySettings.DeleteAccountIfAwayFor
NSString * _Nonnull _Lajc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3225);
}
// PrivacySettings.DeleteAccountTitle
NSString * _Nonnull _Lajd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3226);
}
// PrivacySettings.LastSeen
NSString * _Nonnull _Laje(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3227);
}
// PrivacySettings.LastSeenContacts
NSString * _Nonnull _Lajf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3228);
}
// PrivacySettings.LastSeenContactsMinus
_FormattedString * _Nonnull _Lajg(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3229, _0);
}
// PrivacySettings.LastSeenContactsMinusPlus
_FormattedString * _Nonnull _Lajh(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 3230, _0, _1);
}
// PrivacySettings.LastSeenContactsPlus
_FormattedString * _Nonnull _Laji(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3231, _0);
}
// PrivacySettings.LastSeenEverybody
NSString * _Nonnull _Lajj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3232);
}
// PrivacySettings.LastSeenEverybodyMinus
_FormattedString * _Nonnull _Lajk(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3233, _0);
}
// PrivacySettings.LastSeenNobody
NSString * _Nonnull _Lajl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3234);
}
// PrivacySettings.LastSeenNobodyPlus
_FormattedString * _Nonnull _Lajm(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3235, _0);
}
// PrivacySettings.LastSeenTitle
NSString * _Nonnull _Lajn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3236);
}
// PrivacySettings.Passcode
NSString * _Nonnull _Lajo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3237);
}
// PrivacySettings.PasscodeAndFaceId
NSString * _Nonnull _Lajp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3238);
}
// PrivacySettings.PasscodeAndTouchId
NSString * _Nonnull _Lajq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3239);
}
// PrivacySettings.PasscodeOff
NSString * _Nonnull _Lajr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3240);
}
// PrivacySettings.PasscodeOn
NSString * _Nonnull _Lajs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3241);
}
// PrivacySettings.PhoneNumber
NSString * _Nonnull _Lajt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3242);
}
// PrivacySettings.PrivacyTitle
NSString * _Nonnull _Laju(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3243);
}
// PrivacySettings.SecurityTitle
NSString * _Nonnull _Lajv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3244);
}
// PrivacySettings.Title
NSString * _Nonnull _Lajw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3245);
}
// PrivacySettings.TwoStepAuth
NSString * _Nonnull _Lajx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3246);
}
// PrivacySettings.WebSessions
NSString * _Nonnull _Lajy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3247);
}
// PrivateDataSettings.Title
NSString * _Nonnull _Lajz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3248);
}
// Profile.About
NSString * _Nonnull _LajA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3249);
}
// Profile.AddToExisting
NSString * _Nonnull _LajB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3250);
}
// Profile.BotInfo
NSString * _Nonnull _LajC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3251);
}
// Profile.CreateEncryptedChatError
NSString * _Nonnull _LajD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3252);
}
// Profile.CreateEncryptedChatOutdatedError
_FormattedString * _Nonnull _LajE(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 3253, _0, _1);
}
// Profile.CreateNewContact
NSString * _Nonnull _LajF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3254);
}
// Profile.EncryptionKey
NSString * _Nonnull _LajG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3255);
}
// Profile.MessageLifetime1d
NSString * _Nonnull _LajH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3256);
}
// Profile.MessageLifetime1h
NSString * _Nonnull _LajI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3257);
}
// Profile.MessageLifetime1m
NSString * _Nonnull _LajJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3258);
}
// Profile.MessageLifetime1w
NSString * _Nonnull _LajK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3259);
}
// Profile.MessageLifetime2s
NSString * _Nonnull _LajL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3260);
}
// Profile.MessageLifetime5s
NSString * _Nonnull _LajM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3261);
}
// Profile.MessageLifetimeForever
NSString * _Nonnull _LajN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3262);
}
// Profile.ShareContactButton
NSString * _Nonnull _LajO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3263);
}
// Profile.Username
NSString * _Nonnull _LajP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3264);
}
// ProfilePhoto.MainPhoto
NSString * _Nonnull _LajQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3265);
}
// ProfilePhoto.MainVideo
NSString * _Nonnull _LajR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3266);
}
// ProfilePhoto.OpenGallery
NSString * _Nonnull _LajS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3267);
}
// ProfilePhoto.OpenInEditor
NSString * _Nonnull _LajT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3268);
}
// ProfilePhoto.SearchWeb
NSString * _Nonnull _LajU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3269);
}
// ProfilePhoto.SetMainPhoto
NSString * _Nonnull _LajV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3270);
}
// ProfilePhoto.SetMainVideo
NSString * _Nonnull _LajW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3271);
}
// Proxy.TooltipUnavailable
NSString * _Nonnull _LajX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3272);
}
// ProxyServer.VoiceOver.Active
NSString * _Nonnull _LajY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3273);
}
// QuickSend.Photos
NSString * _Nonnull _LajZ(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3274, value);
}
// Replies.BlockAndDeleteRepliesActionTitle
NSString * _Nonnull _Laka(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3275);
}
// RepliesChat.DescriptionText
NSString * _Nonnull _Lakb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3276);
}
// Report.AdditionalDetailsPlaceholder
NSString * _Nonnull _Lakc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3277);
}
// Report.AdditionalDetailsText
NSString * _Nonnull _Lakd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3278);
}
// Report.Report
NSString * _Nonnull _Lake(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3279);
}
// Report.Succeed
NSString * _Nonnull _Lakf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3280);
}
// ReportGroupLocation.Report
NSString * _Nonnull _Lakg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3281);
}
// ReportGroupLocation.Text
NSString * _Nonnull _Lakh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3282);
}
// ReportGroupLocation.Title
NSString * _Nonnull _Laki(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3283);
}
// ReportPeer.AlertSuccess
NSString * _Nonnull _Lakj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3284);
}
// ReportPeer.ReasonChildAbuse
NSString * _Nonnull _Lakk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3285);
}
// ReportPeer.ReasonCopyright
NSString * _Nonnull _Lakl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3286);
}
// ReportPeer.ReasonFake
NSString * _Nonnull _Lakm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3287);
}
// ReportPeer.ReasonOther
NSString * _Nonnull _Lakn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3288);
}
// ReportPeer.ReasonOther.Placeholder
NSString * _Nonnull _Lako(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3289);
}
// ReportPeer.ReasonOther.Send
NSString * _Nonnull _Lakp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3290);
}
// ReportPeer.ReasonOther.Title
NSString * _Nonnull _Lakq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3291);
}
// ReportPeer.ReasonPornography
NSString * _Nonnull _Lakr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3292);
}
// ReportPeer.ReasonSpam
NSString * _Nonnull _Laks(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3293);
}
// ReportPeer.ReasonViolence
NSString * _Nonnull _Lakt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3294);
}
// ReportPeer.Report
NSString * _Nonnull _Laku(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3295);
}
// ReportSpam.DeleteThisChat
NSString * _Nonnull _Lakv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3296);
}
// Resolve.ErrorNotFound
NSString * _Nonnull _Lakw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3297);
}
// SaveIncomingPhotosSettings.From
NSString * _Nonnull _Lakx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3298);
}
// SaveIncomingPhotosSettings.Title
NSString * _Nonnull _Laky(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3299);
}
// ScheduleVoiceChat.ChannelText
_FormattedString * _Nonnull _Lakz(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3300, _0);
}
// ScheduleVoiceChat.GroupText
_FormattedString * _Nonnull _LakA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3301, _0);
}
// ScheduleVoiceChat.ScheduleOn
_FormattedString * _Nonnull _LakB(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 3302, _0, _1);
}
// ScheduleVoiceChat.ScheduleToday
_FormattedString * _Nonnull _LakC(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3303, _0);
}
// ScheduleVoiceChat.ScheduleTomorrow
_FormattedString * _Nonnull _LakD(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3304, _0);
}
// ScheduleVoiceChat.Title
NSString * _Nonnull _LakE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3305);
}
// ScheduledIn.Days
NSString * _Nonnull _LakF(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3306, value);
}
// ScheduledIn.Hours
NSString * _Nonnull _LakG(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3307, value);
}
// ScheduledIn.Minutes
NSString * _Nonnull _LakH(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3308, value);
}
// ScheduledIn.Months
NSString * _Nonnull _LakI(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3309, value);
}
// ScheduledIn.Seconds
NSString * _Nonnull _LakJ(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3310, value);
}
// ScheduledIn.Weeks
NSString * _Nonnull _LakK(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3311, value);
}
// ScheduledIn.Years
NSString * _Nonnull _LakL(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3312, value);
}
// ScheduledMessages.BotActionUnavailable
NSString * _Nonnull _LakM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3313);
}
// ScheduledMessages.ClearAll
NSString * _Nonnull _LakN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3314);
}
// ScheduledMessages.ClearAllConfirmation
NSString * _Nonnull _LakO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3315);
}
// ScheduledMessages.Delete
NSString * _Nonnull _LakP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3316);
}
// ScheduledMessages.DeleteMany
NSString * _Nonnull _LakQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3317);
}
// ScheduledMessages.EditTime
NSString * _Nonnull _LakR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3318);
}
// ScheduledMessages.EmptyPlaceholder
NSString * _Nonnull _LakS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3319);
}
// ScheduledMessages.PollUnavailable
NSString * _Nonnull _LakT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3320);
}
// ScheduledMessages.ReminderNotification
NSString * _Nonnull _LakU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3321);
}
// ScheduledMessages.RemindersTitle
NSString * _Nonnull _LakV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3322);
}
// ScheduledMessages.ScheduledDate
_FormattedString * _Nonnull _LakW(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3323, _0);
}
// ScheduledMessages.ScheduledOnline
NSString * _Nonnull _LakX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3324);
}
// ScheduledMessages.ScheduledToday
NSString * _Nonnull _LakY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3325);
}
// ScheduledMessages.SendNow
NSString * _Nonnull _LakZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3326);
}
// ScheduledMessages.Title
NSString * _Nonnull _Lala(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3327);
}
// SearchImages.NoImagesFound
NSString * _Nonnull _Lalb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3328);
}
// SearchImages.Title
NSString * _Nonnull _Lalc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3329);
}
// SecretChat.Title
NSString * _Nonnull _Lald(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3330);
}
// SecretGIF.NotViewedYet
_FormattedString * _Nonnull _Lale(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3331, _0);
}
// SecretGif.Title
NSString * _Nonnull _Lalf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3332);
}
// SecretImage.NotViewedYet
_FormattedString * _Nonnull _Lalg(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3333, _0);
}
// SecretImage.Title
NSString * _Nonnull _Lalh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3334);
}
// SecretTimer.ImageDescription
NSString * _Nonnull _Lali(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3335);
}
// SecretTimer.VideoDescription
NSString * _Nonnull _Lalj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3336);
}
// SecretVideo.NotViewedYet
_FormattedString * _Nonnull _Lalk(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3337, _0);
}
// SecretVideo.Title
NSString * _Nonnull _Lall(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3338);
}
// ServiceMessage.GameScoreExtended
NSString * _Nonnull _Lalm(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3339, value);
}
// ServiceMessage.GameScoreSelfExtended
NSString * _Nonnull _Laln(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3340, value);
}
// ServiceMessage.GameScoreSelfSimple
NSString * _Nonnull _Lalo(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3341, value);
}
// ServiceMessage.GameScoreSimple
NSString * _Nonnull _Lalp(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3342, value);
}
// Settings.About
NSString * _Nonnull _Lalq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3343);
}
// Settings.About.Help
NSString * _Nonnull _Lalr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3344);
}
// Settings.About.Title
NSString * _Nonnull _Lals(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3345);
}
// Settings.AboutEmpty
NSString * _Nonnull _Lalt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3346);
}
// Settings.AddAccount
NSString * _Nonnull _Lalu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3347);
}
// Settings.AddAnotherAccount
NSString * _Nonnull _Lalv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3348);
}
// Settings.AddAnotherAccount.Help
NSString * _Nonnull _Lalw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3349);
}
// Settings.AddDevice
NSString * _Nonnull _Lalx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3350);
}
// Settings.AppLanguage
NSString * _Nonnull _Laly(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3351);
}
// Settings.AppLanguage.Unofficial
NSString * _Nonnull _Lalz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3352);
}
// Settings.Appearance
NSString * _Nonnull _LalA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3353);
}
// Settings.AppleWatch
NSString * _Nonnull _LalB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3354);
}
// Settings.ApplyProxyAlert
_FormattedString * _Nonnull _LalC(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 3355, _0, _1);
}
// Settings.ApplyProxyAlertCredentials
_FormattedString * _Nonnull _LalD(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2, NSString * _Nonnull _3) {
    return getFormatted4(_self, 3356, _0, _1, _2, _3);
}
// Settings.ApplyProxyAlertEnable
NSString * _Nonnull _LalE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3357);
}
// Settings.BlockedUsers
NSString * _Nonnull _LalF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3358);
}
// Settings.CallSettings
NSString * _Nonnull _LalG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3359);
}
// Settings.CancelUpload
NSString * _Nonnull _LalH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3360);
}
// Settings.ChangePhoneNumber
NSString * _Nonnull _LalI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3361);
}
// Settings.ChatBackground
NSString * _Nonnull _LalJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3362);
}
// Settings.ChatFolders
NSString * _Nonnull _LalK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3363);
}
// Settings.ChatSettings
NSString * _Nonnull _LalL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3364);
}
// Settings.CheckPasswordText
NSString * _Nonnull _LalM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3365);
}
// Settings.CheckPasswordTitle
NSString * _Nonnull _LalN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3366);
}
// Settings.CheckPhoneNumberText
NSString * _Nonnull _LalO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3367);
}
// Settings.CheckPhoneNumberTitle
_FormattedString * _Nonnull _LalP(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3368, _0);
}
// Settings.Context.Logout
NSString * _Nonnull _LalQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3369);
}
// Settings.CopyPhoneNumber
NSString * _Nonnull _LalR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3370);
}
// Settings.CopyUsername
NSString * _Nonnull _LalS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3371);
}
// Settings.Devices
NSString * _Nonnull _LalT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3372);
}
// Settings.EditAccount
NSString * _Nonnull _LalU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3373);
}
// Settings.EditPhoto
NSString * _Nonnull _LalV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3374);
}
// Settings.EditVideo
NSString * _Nonnull _LalW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3375);
}
// Settings.FAQ
NSString * _Nonnull _LalX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3376);
}
// Settings.FAQ_Button
NSString * _Nonnull _LalY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3377);
}
// Settings.FAQ_Intro
NSString * _Nonnull _LalZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3378);
}
// Settings.FAQ_URL
NSString * _Nonnull _Lama(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3379);
}
// Settings.FrequentlyAskedQuestions
NSString * _Nonnull _Lamb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3380);
}
// Settings.KeepPassword
NSString * _Nonnull _Lamc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3381);
}
// Settings.KeepPhoneNumber
_FormattedString * _Nonnull _Lamd(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3382, _0);
}
// Settings.Logout
NSString * _Nonnull _Lame(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3383);
}
// Settings.LogoutConfirmationText
NSString * _Nonnull _Lamf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3384);
}
// Settings.LogoutConfirmationTitle
NSString * _Nonnull _Lamg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3385);
}
// Settings.NotificationsAndSounds
NSString * _Nonnull _Lamh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3386);
}
// Settings.Passport
NSString * _Nonnull _Lami(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3387);
}
// Settings.PhoneNumber
NSString * _Nonnull _Lamj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3388);
}
// Settings.PrivacySettings
NSString * _Nonnull _Lamk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3389);
}
// Settings.Proxy
NSString * _Nonnull _Laml(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3390);
}
// Settings.ProxyConnected
NSString * _Nonnull _Lamm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3391);
}
// Settings.ProxyConnecting
NSString * _Nonnull _Lamn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3392);
}
// Settings.ProxyDisabled
NSString * _Nonnull _Lamo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3393);
}
// Settings.RemoveConfirmation
NSString * _Nonnull _Lamp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3394);
}
// Settings.RemoveVideo
NSString * _Nonnull _Lamq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3395);
}
// Settings.SaveEditedPhotos
NSString * _Nonnull _Lamr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3396);
}
// Settings.SaveIncomingPhotos
NSString * _Nonnull _Lams(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3397);
}
// Settings.SavedMessages
NSString * _Nonnull _Lamt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3398);
}
// Settings.Search
NSString * _Nonnull _Lamu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3399);
}
// Settings.SetNewProfilePhotoOrVideo
NSString * _Nonnull _Lamv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3400);
}
// Settings.SetProfilePhoto
NSString * _Nonnull _Lamw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3401);
}
// Settings.SetProfilePhotoOrVideo
NSString * _Nonnull _Lamx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3402);
}
// Settings.SetUsername
NSString * _Nonnull _Lamy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3403);
}
// Settings.Support
NSString * _Nonnull _Lamz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3404);
}
// Settings.Tips
NSString * _Nonnull _LamA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3405);
}
// Settings.TipsUsername
NSString * _Nonnull _LamB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3406);
}
// Settings.Title
NSString * _Nonnull _LamC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3407);
}
// Settings.TryEnterPassword
NSString * _Nonnull _LamD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3408);
}
// Settings.Username
NSString * _Nonnull _LamE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3409);
}
// Settings.UsernameEmpty
NSString * _Nonnull _LamF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3410);
}
// Settings.ViewPhoto
NSString * _Nonnull _LamG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3411);
}
// Settings.ViewVideo
NSString * _Nonnull _LamH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3412);
}
// SettingsSearch.FAQ
NSString * _Nonnull _LamI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3413);
}
// SettingsSearch.Synonyms.AppLanguage
NSString * _Nonnull _LamJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3414);
}
// SettingsSearch.Synonyms.Appearance.Animations
NSString * _Nonnull _LamK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3415);
}
// SettingsSearch.Synonyms.Appearance.AutoNightTheme
NSString * _Nonnull _LamL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3416);
}
// SettingsSearch.Synonyms.Appearance.ChatBackground
NSString * _Nonnull _LamM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3417);
}
// SettingsSearch.Synonyms.Appearance.ChatBackground.Custom
NSString * _Nonnull _LamN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3418);
}
// SettingsSearch.Synonyms.Appearance.ChatBackground.SetColor
NSString * _Nonnull _LamO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3419);
}
// SettingsSearch.Synonyms.Appearance.ColorTheme
NSString * _Nonnull _LamP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3420);
}
// SettingsSearch.Synonyms.Appearance.LargeEmoji
NSString * _Nonnull _LamQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3421);
}
// SettingsSearch.Synonyms.Appearance.TextSize
NSString * _Nonnull _LamR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3422);
}
// SettingsSearch.Synonyms.Appearance.Title
NSString * _Nonnull _LamS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3423);
}
// SettingsSearch.Synonyms.Calls.CallTab
NSString * _Nonnull _LamT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3424);
}
// SettingsSearch.Synonyms.Calls.Title
NSString * _Nonnull _LamU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3425);
}
// SettingsSearch.Synonyms.ChatSettings.IntentsSettings
NSString * _Nonnull _LamV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3426);
}
// SettingsSearch.Synonyms.ChatSettings.OpenLinksIn
NSString * _Nonnull _LamW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3427);
}
// SettingsSearch.Synonyms.Data.AutoDownloadReset
NSString * _Nonnull _LamX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3428);
}
// SettingsSearch.Synonyms.Data.AutoDownloadUsingCellular
NSString * _Nonnull _LamY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3429);
}
// SettingsSearch.Synonyms.Data.AutoDownloadUsingWifi
NSString * _Nonnull _LamZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3430);
}
// SettingsSearch.Synonyms.Data.AutoplayGifs
NSString * _Nonnull _Lana(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3431);
}
// SettingsSearch.Synonyms.Data.AutoplayVideos
NSString * _Nonnull _Lanb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3432);
}
// SettingsSearch.Synonyms.Data.CallsUseLessData
NSString * _Nonnull _Lanc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3433);
}
// SettingsSearch.Synonyms.Data.DownloadInBackground
NSString * _Nonnull _Land(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3434);
}
// SettingsSearch.Synonyms.Data.NetworkUsage
NSString * _Nonnull _Lane(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3435);
}
// SettingsSearch.Synonyms.Data.SaveEditedPhotos
NSString * _Nonnull _Lanf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3436);
}
// SettingsSearch.Synonyms.Data.SaveIncomingPhotos
NSString * _Nonnull _Lang(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3437);
}
// SettingsSearch.Synonyms.Data.Storage.ClearCache
NSString * _Nonnull _Lanh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3438);
}
// SettingsSearch.Synonyms.Data.Storage.KeepMedia
NSString * _Nonnull _Lani(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3439);
}
// SettingsSearch.Synonyms.Data.Storage.Title
NSString * _Nonnull _Lanj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3440);
}
// SettingsSearch.Synonyms.Data.Title
NSString * _Nonnull _Lank(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3441);
}
// SettingsSearch.Synonyms.EditProfile.AddAccount
NSString * _Nonnull _Lanl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3442);
}
// SettingsSearch.Synonyms.EditProfile.Bio
NSString * _Nonnull _Lanm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3443);
}
// SettingsSearch.Synonyms.EditProfile.Logout
NSString * _Nonnull _Lann(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3444);
}
// SettingsSearch.Synonyms.EditProfile.PhoneNumber
NSString * _Nonnull _Lano(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3445);
}
// SettingsSearch.Synonyms.EditProfile.Title
NSString * _Nonnull _Lanp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3446);
}
// SettingsSearch.Synonyms.EditProfile.Username
NSString * _Nonnull _Lanq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3447);
}
// SettingsSearch.Synonyms.FAQ
NSString * _Nonnull _Lanr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3448);
}
// SettingsSearch.Synonyms.Notifications.BadgeCountUnreadMessages
NSString * _Nonnull _Lans(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3449);
}
// SettingsSearch.Synonyms.Notifications.BadgeIncludeMutedChannels
NSString * _Nonnull _Lant(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3450);
}
// SettingsSearch.Synonyms.Notifications.BadgeIncludeMutedChats
NSString * _Nonnull _Lanu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3451);
}
// SettingsSearch.Synonyms.Notifications.BadgeIncludeMutedPublicGroups
NSString * _Nonnull _Lanv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3452);
}
// SettingsSearch.Synonyms.Notifications.ChannelNotificationsAlert
NSString * _Nonnull _Lanw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3453);
}
// SettingsSearch.Synonyms.Notifications.ChannelNotificationsExceptions
NSString * _Nonnull _Lanx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3454);
}
// SettingsSearch.Synonyms.Notifications.ChannelNotificationsPreview
NSString * _Nonnull _Lany(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3455);
}
// SettingsSearch.Synonyms.Notifications.ChannelNotificationsSound
NSString * _Nonnull _Lanz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3456);
}
// SettingsSearch.Synonyms.Notifications.ContactJoined
NSString * _Nonnull _LanA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3457);
}
// SettingsSearch.Synonyms.Notifications.DisplayNamesOnLockScreen
NSString * _Nonnull _LanB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3458);
}
// SettingsSearch.Synonyms.Notifications.GroupNotificationsAlert
NSString * _Nonnull _LanC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3459);
}
// SettingsSearch.Synonyms.Notifications.GroupNotificationsExceptions
NSString * _Nonnull _LanD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3460);
}
// SettingsSearch.Synonyms.Notifications.GroupNotificationsPreview
NSString * _Nonnull _LanE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3461);
}
// SettingsSearch.Synonyms.Notifications.GroupNotificationsSound
NSString * _Nonnull _LanF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3462);
}
// SettingsSearch.Synonyms.Notifications.InAppNotificationsPreview
NSString * _Nonnull _LanG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3463);
}
// SettingsSearch.Synonyms.Notifications.InAppNotificationsSound
NSString * _Nonnull _LanH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3464);
}
// SettingsSearch.Synonyms.Notifications.InAppNotificationsVibrate
NSString * _Nonnull _LanI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3465);
}
// SettingsSearch.Synonyms.Notifications.MessageNotificationsAlert
NSString * _Nonnull _LanJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3466);
}
// SettingsSearch.Synonyms.Notifications.MessageNotificationsExceptions
NSString * _Nonnull _LanK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3467);
}
// SettingsSearch.Synonyms.Notifications.MessageNotificationsPreview
NSString * _Nonnull _LanL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3468);
}
// SettingsSearch.Synonyms.Notifications.MessageNotificationsSound
NSString * _Nonnull _LanM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3469);
}
// SettingsSearch.Synonyms.Notifications.ResetAllNotifications
NSString * _Nonnull _LanN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3470);
}
// SettingsSearch.Synonyms.Notifications.Title
NSString * _Nonnull _LanO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3471);
}
// SettingsSearch.Synonyms.Passport
NSString * _Nonnull _LanP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3472);
}
// SettingsSearch.Synonyms.Privacy.AuthSessions
NSString * _Nonnull _LanQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3473);
}
// SettingsSearch.Synonyms.Privacy.BlockedUsers
NSString * _Nonnull _LanR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3474);
}
// SettingsSearch.Synonyms.Privacy.Calls
NSString * _Nonnull _LanS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3475);
}
// SettingsSearch.Synonyms.Privacy.Data.ClearPaymentsInfo
NSString * _Nonnull _LanT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3476);
}
// SettingsSearch.Synonyms.Privacy.Data.ContactsReset
NSString * _Nonnull _LanU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3477);
}
// SettingsSearch.Synonyms.Privacy.Data.ContactsSync
NSString * _Nonnull _LanV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3478);
}
// SettingsSearch.Synonyms.Privacy.Data.DeleteDrafts
NSString * _Nonnull _LanW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3479);
}
// SettingsSearch.Synonyms.Privacy.Data.SecretChatLinkPreview
NSString * _Nonnull _LanX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3480);
}
// SettingsSearch.Synonyms.Privacy.Data.Title
NSString * _Nonnull _LanY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3481);
}
// SettingsSearch.Synonyms.Privacy.Data.TopPeers
NSString * _Nonnull _LanZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3482);
}
// SettingsSearch.Synonyms.Privacy.DeleteAccountIfAwayFor
NSString * _Nonnull _Laoa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3483);
}
// SettingsSearch.Synonyms.Privacy.Forwards
NSString * _Nonnull _Laob(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3484);
}
// SettingsSearch.Synonyms.Privacy.GroupsAndChannels
NSString * _Nonnull _Laoc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3485);
}
// SettingsSearch.Synonyms.Privacy.LastSeen
NSString * _Nonnull _Laod(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3486);
}
// SettingsSearch.Synonyms.Privacy.Passcode
NSString * _Nonnull _Laoe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3487);
}
// SettingsSearch.Synonyms.Privacy.PasscodeAndFaceId
NSString * _Nonnull _Laof(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3488);
}
// SettingsSearch.Synonyms.Privacy.PasscodeAndTouchId
NSString * _Nonnull _Laog(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3489);
}
// SettingsSearch.Synonyms.Privacy.ProfilePhoto
NSString * _Nonnull _Laoh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3490);
}
// SettingsSearch.Synonyms.Privacy.Title
NSString * _Nonnull _Laoi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3491);
}
// SettingsSearch.Synonyms.Privacy.TwoStepAuth
NSString * _Nonnull _Laoj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3492);
}
// SettingsSearch.Synonyms.Proxy.AddProxy
NSString * _Nonnull _Laok(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3493);
}
// SettingsSearch.Synonyms.Proxy.Title
NSString * _Nonnull _Laol(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3494);
}
// SettingsSearch.Synonyms.Proxy.UseForCalls
NSString * _Nonnull _Laom(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3495);
}
// SettingsSearch.Synonyms.SavedMessages
NSString * _Nonnull _Laon(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3496);
}
// SettingsSearch.Synonyms.Stickers.ArchivedPacks
NSString * _Nonnull _Laoo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3497);
}
// SettingsSearch.Synonyms.Stickers.FeaturedPacks
NSString * _Nonnull _Laop(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3498);
}
// SettingsSearch.Synonyms.Stickers.Masks
NSString * _Nonnull _Laoq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3499);
}
// SettingsSearch.Synonyms.Stickers.SuggestStickers
NSString * _Nonnull _Laor(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3500);
}
// SettingsSearch.Synonyms.Stickers.Title
NSString * _Nonnull _Laos(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3501);
}
// SettingsSearch.Synonyms.Support
NSString * _Nonnull _Laot(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3502);
}
// SettingsSearch.Synonyms.Watch
NSString * _Nonnull _Laou(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3503);
}
// SettingsSearch_Synonyms_ChatFolders
NSString * _Nonnull _Laov(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3504);
}
// Share.AuthDescription
NSString * _Nonnull _Laow(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3505);
}
// Share.AuthTitle
NSString * _Nonnull _Laox(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3506);
}
// Share.MultipleMessagesDisabled
NSString * _Nonnull _Laoy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3507);
}
// Share.Title
NSString * _Nonnull _Laoz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3508);
}
// ShareFileTip.CloseTip
NSString * _Nonnull _LaoA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3509);
}
// ShareFileTip.Text
_FormattedString * _Nonnull _LaoB(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3510, _0);
}
// ShareFileTip.Title
NSString * _Nonnull _LaoC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3511);
}
// ShareMenu.Comment
NSString * _Nonnull _LaoD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3512);
}
// ShareMenu.CopyShareLink
NSString * _Nonnull _LaoE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3513);
}
// ShareMenu.CopyShareLinkGame
NSString * _Nonnull _LaoF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3514);
}
// ShareMenu.SelectChats
NSString * _Nonnull _LaoG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3515);
}
// ShareMenu.Send
NSString * _Nonnull _LaoH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3516);
}
// ShareMenu.ShareTo
NSString * _Nonnull _LaoI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3517);
}
// SharedMedia.CategoryDocs
NSString * _Nonnull _LaoJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3518);
}
// SharedMedia.CategoryLinks
NSString * _Nonnull _LaoK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3519);
}
// SharedMedia.CategoryMedia
NSString * _Nonnull _LaoL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3520);
}
// SharedMedia.CategoryOther
NSString * _Nonnull _LaoM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3521);
}
// SharedMedia.DeleteItemsConfirmation
NSString * _Nonnull _LaoN(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3522, value);
}
// SharedMedia.EmptyFilesText
NSString * _Nonnull _LaoO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3523);
}
// SharedMedia.EmptyLinksText
NSString * _Nonnull _LaoP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3524);
}
// SharedMedia.EmptyMusicText
NSString * _Nonnull _LaoQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3525);
}
// SharedMedia.EmptyText
NSString * _Nonnull _LaoR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3526);
}
// SharedMedia.EmptyTitle
NSString * _Nonnull _LaoS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3527);
}
// SharedMedia.File
NSString * _Nonnull _LaoT(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3528, value);
}
// SharedMedia.Generic
NSString * _Nonnull _LaoU(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3529, value);
}
// SharedMedia.Link
NSString * _Nonnull _LaoV(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3530, value);
}
// SharedMedia.Photo
NSString * _Nonnull _LaoW(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3531, value);
}
// SharedMedia.SearchNoResults
NSString * _Nonnull _LaoX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3532);
}
// SharedMedia.SearchNoResultsDescription
_FormattedString * _Nonnull _LaoY(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3533, _0);
}
// SharedMedia.TitleAll
NSString * _Nonnull _LaoZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3534);
}
// SharedMedia.TitleLink
NSString * _Nonnull _Lapa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3535);
}
// SharedMedia.Video
NSString * _Nonnull _Lapb(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3536, value);
}
// SharedMedia.ViewInChat
NSString * _Nonnull _Lapc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3537);
}
// Shortcut.SwitchAccount
NSString * _Nonnull _Lapd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3538);
}
// SocksProxySetup.AdNoticeHelp
NSString * _Nonnull _Lape(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3539);
}
// SocksProxySetup.AddProxy
NSString * _Nonnull _Lapf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3540);
}
// SocksProxySetup.AddProxyTitle
NSString * _Nonnull _Lapg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3541);
}
// SocksProxySetup.ConnectAndSave
NSString * _Nonnull _Laph(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3542);
}
// SocksProxySetup.Connecting
NSString * _Nonnull _Lapi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3543);
}
// SocksProxySetup.Connection
NSString * _Nonnull _Lapj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3544);
}
// SocksProxySetup.Credentials
NSString * _Nonnull _Lapk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3545);
}
// SocksProxySetup.FailedToConnect
NSString * _Nonnull _Lapl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3546);
}
// SocksProxySetup.Hostname
NSString * _Nonnull _Lapm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3547);
}
// SocksProxySetup.HostnamePlaceholder
NSString * _Nonnull _Lapn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3548);
}
// SocksProxySetup.Password
NSString * _Nonnull _Lapo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3549);
}
// SocksProxySetup.PasswordPlaceholder
NSString * _Nonnull _Lapp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3550);
}
// SocksProxySetup.PasteFromClipboard
NSString * _Nonnull _Lapq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3551);
}
// SocksProxySetup.Port
NSString * _Nonnull _Lapr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3552);
}
// SocksProxySetup.PortPlaceholder
NSString * _Nonnull _Laps(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3553);
}
// SocksProxySetup.ProxyDetailsTitle
NSString * _Nonnull _Lapt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3554);
}
// SocksProxySetup.ProxyEnabled
NSString * _Nonnull _Lapu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3555);
}
// SocksProxySetup.ProxySocks5
NSString * _Nonnull _Lapv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3556);
}
// SocksProxySetup.ProxyStatusChecking
NSString * _Nonnull _Lapw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3557);
}
// SocksProxySetup.ProxyStatusConnected
NSString * _Nonnull _Lapx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3558);
}
// SocksProxySetup.ProxyStatusConnecting
NSString * _Nonnull _Lapy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3559);
}
// SocksProxySetup.ProxyStatusPing
_FormattedString * _Nonnull _Lapz(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3560, _0);
}
// SocksProxySetup.ProxyStatusUnavailable
NSString * _Nonnull _LapA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3561);
}
// SocksProxySetup.ProxyTelegram
NSString * _Nonnull _LapB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3562);
}
// SocksProxySetup.ProxyType
NSString * _Nonnull _LapC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3563);
}
// SocksProxySetup.RequiredCredentials
NSString * _Nonnull _LapD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3564);
}
// SocksProxySetup.SaveProxy
NSString * _Nonnull _LapE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3565);
}
// SocksProxySetup.SavedProxies
NSString * _Nonnull _LapF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3566);
}
// SocksProxySetup.Secret
NSString * _Nonnull _LapG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3567);
}
// SocksProxySetup.SecretPlaceholder
NSString * _Nonnull _LapH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3568);
}
// SocksProxySetup.ShareLink
NSString * _Nonnull _LapI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3569);
}
// SocksProxySetup.ShareProxyList
NSString * _Nonnull _LapJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3570);
}
// SocksProxySetup.ShareQRCode
NSString * _Nonnull _LapK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3571);
}
// SocksProxySetup.ShareQRCodeInfo
NSString * _Nonnull _LapL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3572);
}
// SocksProxySetup.Status
NSString * _Nonnull _LapM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3573);
}
// SocksProxySetup.Title
NSString * _Nonnull _LapN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3574);
}
// SocksProxySetup.TypeNone
NSString * _Nonnull _LapO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3575);
}
// SocksProxySetup.TypeSocks
NSString * _Nonnull _LapP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3576);
}
// SocksProxySetup.UseForCalls
NSString * _Nonnull _LapQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3577);
}
// SocksProxySetup.UseForCallsHelp
NSString * _Nonnull _LapR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3578);
}
// SocksProxySetup.UseProxy
NSString * _Nonnull _LapS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3579);
}
// SocksProxySetup.Username
NSString * _Nonnull _LapT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3580);
}
// SocksProxySetup.UsernamePlaceholder
NSString * _Nonnull _LapU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3581);
}
// State.Connecting
NSString * _Nonnull _LapV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3582);
}
// State.ConnectingToProxy
NSString * _Nonnull _LapW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3583);
}
// State.ConnectingToProxyInfo
NSString * _Nonnull _LapX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3584);
}
// State.Updating
NSString * _Nonnull _LapY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3585);
}
// State.WaitingForNetwork
NSString * _Nonnull _LapZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3586);
}
// State.connecting
NSString * _Nonnull _Laqa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3587);
}
// Stats.EnabledNotifications
NSString * _Nonnull _Laqb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3588);
}
// Stats.Followers
NSString * _Nonnull _Laqc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3589);
}
// Stats.FollowersBySourceTitle
NSString * _Nonnull _Laqd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3590);
}
// Stats.FollowersTitle
NSString * _Nonnull _Laqe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3591);
}
// Stats.GroupActionsTitle
NSString * _Nonnull _Laqf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3592);
}
// Stats.GroupGrowthTitle
NSString * _Nonnull _Laqg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3593);
}
// Stats.GroupLanguagesTitle
NSString * _Nonnull _Laqh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3594);
}
// Stats.GroupMembers
NSString * _Nonnull _Laqi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3595);
}
// Stats.GroupMembersTitle
NSString * _Nonnull _Laqj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3596);
}
// Stats.GroupMessages
NSString * _Nonnull _Laqk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3597);
}
// Stats.GroupMessagesTitle
NSString * _Nonnull _Laql(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3598);
}
// Stats.GroupNewMembersBySourceTitle
NSString * _Nonnull _Laqm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3599);
}
// Stats.GroupOverview
NSString * _Nonnull _Laqn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3600);
}
// Stats.GroupPosters
NSString * _Nonnull _Laqo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3601);
}
// Stats.GroupShowMoreTopAdmins
NSString * _Nonnull _Laqp(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3602, value);
}
// Stats.GroupShowMoreTopInviters
NSString * _Nonnull _Laqq(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3603, value);
}
// Stats.GroupShowMoreTopPosters
NSString * _Nonnull _Laqr(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3604, value);
}
// Stats.GroupTopAdmin.Actions
NSString * _Nonnull _Laqs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3605);
}
// Stats.GroupTopAdmin.Promote
NSString * _Nonnull _Laqt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3606);
}
// Stats.GroupTopAdminBans
NSString * _Nonnull _Laqu(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3607, value);
}
// Stats.GroupTopAdminDeletions
NSString * _Nonnull _Laqv(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3608, value);
}
// Stats.GroupTopAdminKicks
NSString * _Nonnull _Laqw(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3609, value);
}
// Stats.GroupTopAdminsTitle
NSString * _Nonnull _Laqx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3610);
}
// Stats.GroupTopHoursTitle
NSString * _Nonnull _Laqy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3611);
}
// Stats.GroupTopInviter.History
NSString * _Nonnull _Laqz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3612);
}
// Stats.GroupTopInviter.Promote
NSString * _Nonnull _LaqA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3613);
}
// Stats.GroupTopInviterInvites
NSString * _Nonnull _LaqB(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3614, value);
}
// Stats.GroupTopInvitersTitle
NSString * _Nonnull _LaqC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3615);
}
// Stats.GroupTopPoster.History
NSString * _Nonnull _LaqD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3616);
}
// Stats.GroupTopPoster.Promote
NSString * _Nonnull _LaqE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3617);
}
// Stats.GroupTopPosterChars
NSString * _Nonnull _LaqF(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3618, value);
}
// Stats.GroupTopPosterMessages
NSString * _Nonnull _LaqG(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3619, value);
}
// Stats.GroupTopPostersTitle
NSString * _Nonnull _LaqH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3620);
}
// Stats.GroupTopWeekdaysTitle
NSString * _Nonnull _LaqI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3621);
}
// Stats.GroupViewers
NSString * _Nonnull _LaqJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3622);
}
// Stats.GrowthTitle
NSString * _Nonnull _LaqK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3623);
}
// Stats.InstantViewInteractionsTitle
NSString * _Nonnull _LaqL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3624);
}
// Stats.InteractionsTitle
NSString * _Nonnull _LaqM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3625);
}
// Stats.LanguagesTitle
NSString * _Nonnull _LaqN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3626);
}
// Stats.LoadingText
NSString * _Nonnull _LaqO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3627);
}
// Stats.LoadingTitle
NSString * _Nonnull _LaqP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3628);
}
// Stats.Message.PrivateShares
NSString * _Nonnull _LaqQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3629);
}
// Stats.Message.PublicShares
NSString * _Nonnull _LaqR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3630);
}
// Stats.Message.Views
NSString * _Nonnull _LaqS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3631);
}
// Stats.MessageForwards
NSString * _Nonnull _LaqT(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3632, value);
}
// Stats.MessageInteractionsTitle
NSString * _Nonnull _LaqU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3633);
}
// Stats.MessageOverview
NSString * _Nonnull _LaqV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3634);
}
// Stats.MessagePublicForwardsTitle
NSString * _Nonnull _LaqW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3635);
}
// Stats.MessageTitle
NSString * _Nonnull _LaqX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3636);
}
// Stats.MessageViews
NSString * _Nonnull _LaqY(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3637, value);
}
// Stats.NotificationsTitle
NSString * _Nonnull _LaqZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3638);
}
// Stats.Overview
NSString * _Nonnull _Lara(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3639);
}
// Stats.PostsTitle
NSString * _Nonnull _Larb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3640);
}
// Stats.SharesPerPost
NSString * _Nonnull _Larc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3641);
}
// Stats.Total
NSString * _Nonnull _Lard(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3642);
}
// Stats.ViewsByHoursTitle
NSString * _Nonnull _Lare(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3643);
}
// Stats.ViewsBySourceTitle
NSString * _Nonnull _Larf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3644);
}
// Stats.ViewsPerPost
NSString * _Nonnull _Larg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3645);
}
// Stats.ZoomOut
NSString * _Nonnull _Larh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3646);
}
// StickerPack.Add
NSString * _Nonnull _Lari(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3647);
}
// StickerPack.AddMaskCount
NSString * _Nonnull _Larj(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3648, value);
}
// StickerPack.AddStickerCount
NSString * _Nonnull _Lark(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3649, value);
}
// StickerPack.BuiltinPackName
NSString * _Nonnull _Larl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3650);
}
// StickerPack.ErrorNotFound
NSString * _Nonnull _Larm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3651);
}
// StickerPack.HideStickers
NSString * _Nonnull _Larn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3652);
}
// StickerPack.RemoveMaskCount
NSString * _Nonnull _Laro(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3653, value);
}
// StickerPack.RemoveStickerCount
NSString * _Nonnull _Larp(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3654, value);
}
// StickerPack.Send
NSString * _Nonnull _Larq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3655);
}
// StickerPack.Share
NSString * _Nonnull _Larr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3656);
}
// StickerPack.ShowStickers
NSString * _Nonnull _Lars(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3657);
}
// StickerPack.StickerCount
NSString * _Nonnull _Lart(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3658, value);
}
// StickerPack.ViewPack
NSString * _Nonnull _Laru(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3659);
}
// StickerPackActionInfo.AddedText
_FormattedString * _Nonnull _Larv(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3660, _0);
}
// StickerPackActionInfo.AddedTitle
NSString * _Nonnull _Larw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3661);
}
// StickerPackActionInfo.ArchivedTitle
NSString * _Nonnull _Larx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3662);
}
// StickerPackActionInfo.RemovedText
_FormattedString * _Nonnull _Lary(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3663, _0);
}
// StickerPackActionInfo.RemovedTitle
NSString * _Nonnull _Larz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3664);
}
// StickerPacks.ActionArchive
NSString * _Nonnull _LarA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3665);
}
// StickerPacks.ActionDelete
NSString * _Nonnull _LarB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3666);
}
// StickerPacks.ActionShare
NSString * _Nonnull _LarC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3667);
}
// StickerPacks.ArchiveStickerPacksConfirmation
NSString * _Nonnull _LarD(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3668, value);
}
// StickerPacks.DeleteStickerPacksConfirmation
NSString * _Nonnull _LarE(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3669, value);
}
// StickerPacksSettings.AnimatedStickers
NSString * _Nonnull _LarF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3670);
}
// StickerPacksSettings.AnimatedStickersInfo
NSString * _Nonnull _LarG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3671);
}
// StickerPacksSettings.ArchivedMasks
NSString * _Nonnull _LarH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3672);
}
// StickerPacksSettings.ArchivedMasks.Info
NSString * _Nonnull _LarI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3673);
}
// StickerPacksSettings.ArchivedPacks
NSString * _Nonnull _LarJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3674);
}
// StickerPacksSettings.ArchivedPacks.Info
NSString * _Nonnull _LarK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3675);
}
// StickerPacksSettings.FeaturedPacks
NSString * _Nonnull _LarL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3676);
}
// StickerPacksSettings.ManagingHelp
NSString * _Nonnull _LarM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3677);
}
// StickerPacksSettings.ShowStickersButton
NSString * _Nonnull _LarN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3678);
}
// StickerPacksSettings.ShowStickersButtonHelp
NSString * _Nonnull _LarO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3679);
}
// StickerPacksSettings.StickerPacksSection
NSString * _Nonnull _LarP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3680);
}
// StickerPacksSettings.Title
NSString * _Nonnull _LarQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3681);
}
// StickerSettings.ContextHide
NSString * _Nonnull _LarR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3682);
}
// StickerSettings.ContextInfo
NSString * _Nonnull _LarS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3683);
}
// StickerSettings.MaskContextInfo
NSString * _Nonnull _LarT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3684);
}
// Stickers.AddToFavorites
NSString * _Nonnull _LarU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3685);
}
// Stickers.ClearRecent
NSString * _Nonnull _LarV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3686);
}
// Stickers.FavoriteStickers
NSString * _Nonnull _LarW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3687);
}
// Stickers.FrequentlyUsed
NSString * _Nonnull _LarX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3688);
}
// Stickers.GroupChooseStickerPack
NSString * _Nonnull _LarY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3689);
}
// Stickers.GroupStickers
NSString * _Nonnull _LarZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3690);
}
// Stickers.GroupStickersHelp
NSString * _Nonnull _Lasa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3691);
}
// Stickers.Install
NSString * _Nonnull _Lasb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3692);
}
// Stickers.Installed
NSString * _Nonnull _Lasc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3693);
}
// Stickers.NoStickersFound
NSString * _Nonnull _Lasd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3694);
}
// Stickers.RemoveFromFavorites
NSString * _Nonnull _Lase(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3695);
}
// Stickers.Search
NSString * _Nonnull _Lasf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3696);
}
// Stickers.SuggestAdded
NSString * _Nonnull _Lasg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3697);
}
// Stickers.SuggestAll
NSString * _Nonnull _Lash(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3698);
}
// Stickers.SuggestNone
NSString * _Nonnull _Lasi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3699);
}
// Stickers.SuggestStickers
NSString * _Nonnull _Lasj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3700);
}
// Target.InviteToGroupConfirmation
_FormattedString * _Nonnull _Lask(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3701, _0);
}
// Target.InviteToGroupErrorAlreadyInvited
NSString * _Nonnull _Lasl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3702);
}
// Target.SelectGroup
NSString * _Nonnull _Lasm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3703);
}
// Target.ShareGameConfirmationGroup
_FormattedString * _Nonnull _Lasn(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3704, _0);
}
// Target.ShareGameConfirmationPrivate
_FormattedString * _Nonnull _Laso(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3705, _0);
}
// TextFormat.AddLinkPlaceholder
NSString * _Nonnull _Lasp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3706);
}
// TextFormat.AddLinkText
_FormattedString * _Nonnull _Lasq(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3707, _0);
}
// TextFormat.AddLinkTitle
NSString * _Nonnull _Lasr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3708);
}
// TextFormat.Bold
NSString * _Nonnull _Lass(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3709);
}
// TextFormat.Italic
NSString * _Nonnull _Last(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3710);
}
// TextFormat.Link
NSString * _Nonnull _Lasu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3711);
}
// TextFormat.Monospace
NSString * _Nonnull _Lasv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3712);
}
// TextFormat.Strikethrough
NSString * _Nonnull _Lasw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3713);
}
// TextFormat.Underline
NSString * _Nonnull _Lasx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3714);
}
// Theme.Colors.Accent
NSString * _Nonnull _Lasy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3715);
}
// Theme.Colors.Background
NSString * _Nonnull _Lasz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3716);
}
// Theme.Colors.ColorWallpaperWarning
NSString * _Nonnull _LasA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3717);
}
// Theme.Colors.ColorWallpaperWarningProceed
NSString * _Nonnull _LasB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3718);
}
// Theme.Colors.Messages
NSString * _Nonnull _LasC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3719);
}
// Theme.Colors.Proceed
NSString * _Nonnull _LasD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3720);
}
// Theme.Context.Apply
NSString * _Nonnull _LasE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3721);
}
// Theme.Context.ChangeColors
NSString * _Nonnull _LasF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3722);
}
// Theme.ErrorNotFound
NSString * _Nonnull _LasG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3723);
}
// Theme.ThemeChanged
NSString * _Nonnull _LasH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3724);
}
// Theme.ThemeChangedText
NSString * _Nonnull _LasI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3725);
}
// Theme.Unsupported
NSString * _Nonnull _LasJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3726);
}
// Theme.UsersCount
NSString * _Nonnull _LasK(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3727, value);
}
// Time.MediumDate
_FormattedString * _Nonnull _LasL(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 3728, _0, _1);
}
// Time.MonthOfYear_m1
_FormattedString * _Nonnull _LasM(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3729, _0);
}
// Time.MonthOfYear_m10
_FormattedString * _Nonnull _LasN(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3730, _0);
}
// Time.MonthOfYear_m11
_FormattedString * _Nonnull _LasO(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3731, _0);
}
// Time.MonthOfYear_m12
_FormattedString * _Nonnull _LasP(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3732, _0);
}
// Time.MonthOfYear_m2
_FormattedString * _Nonnull _LasQ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3733, _0);
}
// Time.MonthOfYear_m3
_FormattedString * _Nonnull _LasR(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3734, _0);
}
// Time.MonthOfYear_m4
_FormattedString * _Nonnull _LasS(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3735, _0);
}
// Time.MonthOfYear_m5
_FormattedString * _Nonnull _LasT(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3736, _0);
}
// Time.MonthOfYear_m6
_FormattedString * _Nonnull _LasU(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3737, _0);
}
// Time.MonthOfYear_m7
_FormattedString * _Nonnull _LasV(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3738, _0);
}
// Time.MonthOfYear_m8
_FormattedString * _Nonnull _LasW(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3739, _0);
}
// Time.MonthOfYear_m9
_FormattedString * _Nonnull _LasX(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3740, _0);
}
// Time.PreciseDate_m1
_FormattedString * _Nonnull _LasY(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 3741, _0, _1, _2);
}
// Time.PreciseDate_m10
_FormattedString * _Nonnull _LasZ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 3742, _0, _1, _2);
}
// Time.PreciseDate_m11
_FormattedString * _Nonnull _Lata(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 3743, _0, _1, _2);
}
// Time.PreciseDate_m12
_FormattedString * _Nonnull _Latb(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 3744, _0, _1, _2);
}
// Time.PreciseDate_m2
_FormattedString * _Nonnull _Latc(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 3745, _0, _1, _2);
}
// Time.PreciseDate_m3
_FormattedString * _Nonnull _Latd(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 3746, _0, _1, _2);
}
// Time.PreciseDate_m4
_FormattedString * _Nonnull _Late(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 3747, _0, _1, _2);
}
// Time.PreciseDate_m5
_FormattedString * _Nonnull _Latf(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 3748, _0, _1, _2);
}
// Time.PreciseDate_m6
_FormattedString * _Nonnull _Latg(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 3749, _0, _1, _2);
}
// Time.PreciseDate_m7
_FormattedString * _Nonnull _Lath(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 3750, _0, _1, _2);
}
// Time.PreciseDate_m8
_FormattedString * _Nonnull _Lati(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 3751, _0, _1, _2);
}
// Time.PreciseDate_m9
_FormattedString * _Nonnull _Latj(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1, NSString * _Nonnull _2) {
    return getFormatted3(_self, 3752, _0, _1, _2);
}
// Time.TodayAt
_FormattedString * _Nonnull _Latk(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3753, _0);
}
// Time.TomorrowAt
_FormattedString * _Nonnull _Latl(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3754, _0);
}
// Time.YesterdayAt
_FormattedString * _Nonnull _Latm(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3755, _0);
}
// Tour.StartButton
NSString * _Nonnull _Latn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3756);
}
// Tour.Text1
NSString * _Nonnull _Lato(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3757);
}
// Tour.Text2
NSString * _Nonnull _Latp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3758);
}
// Tour.Text3
NSString * _Nonnull _Latq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3759);
}
// Tour.Text4
NSString * _Nonnull _Latr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3760);
}
// Tour.Text5
NSString * _Nonnull _Lats(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3761);
}
// Tour.Text6
NSString * _Nonnull _Latt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3762);
}
// Tour.Title1
NSString * _Nonnull _Latu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3763);
}
// Tour.Title2
NSString * _Nonnull _Latv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3764);
}
// Tour.Title3
NSString * _Nonnull _Latw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3765);
}
// Tour.Title4
NSString * _Nonnull _Latx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3766);
}
// Tour.Title5
NSString * _Nonnull _Laty(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3767);
}
// Tour.Title6
NSString * _Nonnull _Latz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3768);
}
// TwoFactorRemember.CheckPassword
NSString * _Nonnull _LatA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3769);
}
// TwoFactorRemember.Done.Action
NSString * _Nonnull _LatB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3770);
}
// TwoFactorRemember.Done.Text
NSString * _Nonnull _LatC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3771);
}
// TwoFactorRemember.Done.Title
NSString * _Nonnull _LatD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3772);
}
// TwoFactorRemember.Forgot
NSString * _Nonnull _LatE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3773);
}
// TwoFactorRemember.Placeholder
NSString * _Nonnull _LatF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3774);
}
// TwoFactorRemember.Text
NSString * _Nonnull _LatG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3775);
}
// TwoFactorRemember.Title
NSString * _Nonnull _LatH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3776);
}
// TwoFactorRemember.WrongPassword
NSString * _Nonnull _LatI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3777);
}
// TwoFactorSetup.Done.Action
NSString * _Nonnull _LatJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3778);
}
// TwoFactorSetup.Done.Text
NSString * _Nonnull _LatK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3779);
}
// TwoFactorSetup.Done.Title
NSString * _Nonnull _LatL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3780);
}
// TwoFactorSetup.Email.Action
NSString * _Nonnull _LatM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3781);
}
// TwoFactorSetup.Email.Placeholder
NSString * _Nonnull _LatN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3782);
}
// TwoFactorSetup.Email.SkipAction
NSString * _Nonnull _LatO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3783);
}
// TwoFactorSetup.Email.SkipConfirmationSkip
NSString * _Nonnull _LatP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3784);
}
// TwoFactorSetup.Email.SkipConfirmationText
NSString * _Nonnull _LatQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3785);
}
// TwoFactorSetup.Email.SkipConfirmationTitle
NSString * _Nonnull _LatR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3786);
}
// TwoFactorSetup.Email.Text
NSString * _Nonnull _LatS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3787);
}
// TwoFactorSetup.Email.Title
NSString * _Nonnull _LatT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3788);
}
// TwoFactorSetup.EmailVerification.Action
NSString * _Nonnull _LatU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3789);
}
// TwoFactorSetup.EmailVerification.ChangeAction
NSString * _Nonnull _LatV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3790);
}
// TwoFactorSetup.EmailVerification.Placeholder
NSString * _Nonnull _LatW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3791);
}
// TwoFactorSetup.EmailVerification.ResendAction
NSString * _Nonnull _LatX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3792);
}
// TwoFactorSetup.EmailVerification.Text
_FormattedString * _Nonnull _LatY(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3793, _0);
}
// TwoFactorSetup.EmailVerification.Title
NSString * _Nonnull _LatZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3794);
}
// TwoFactorSetup.Hint.Action
NSString * _Nonnull _Laua(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3795);
}
// TwoFactorSetup.Hint.Placeholder
NSString * _Nonnull _Laub(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3796);
}
// TwoFactorSetup.Hint.SkipAction
NSString * _Nonnull _Lauc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3797);
}
// TwoFactorSetup.Hint.Text
NSString * _Nonnull _Laud(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3798);
}
// TwoFactorSetup.Hint.Title
NSString * _Nonnull _Laue(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3799);
}
// TwoFactorSetup.Intro.Action
NSString * _Nonnull _Lauf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3800);
}
// TwoFactorSetup.Intro.Text
NSString * _Nonnull _Laug(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3801);
}
// TwoFactorSetup.Intro.Title
NSString * _Nonnull _Lauh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3802);
}
// TwoFactorSetup.Password.Action
NSString * _Nonnull _Laui(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3803);
}
// TwoFactorSetup.Password.PlaceholderConfirmPassword
NSString * _Nonnull _Lauj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3804);
}
// TwoFactorSetup.Password.PlaceholderPassword
NSString * _Nonnull _Lauk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3805);
}
// TwoFactorSetup.Password.Title
NSString * _Nonnull _Laul(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3806);
}
// TwoFactorSetup.PasswordRecovery.Action
NSString * _Nonnull _Laum(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3807);
}
// TwoFactorSetup.PasswordRecovery.PlaceholderConfirmPassword
NSString * _Nonnull _Laun(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3808);
}
// TwoFactorSetup.PasswordRecovery.PlaceholderPassword
NSString * _Nonnull _Lauo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3809);
}
// TwoFactorSetup.PasswordRecovery.Skip
NSString * _Nonnull _Laup(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3810);
}
// TwoFactorSetup.PasswordRecovery.SkipAlertAction
NSString * _Nonnull _Lauq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3811);
}
// TwoFactorSetup.PasswordRecovery.SkipAlertText
NSString * _Nonnull _Laur(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3812);
}
// TwoFactorSetup.PasswordRecovery.SkipAlertTitle
NSString * _Nonnull _Laus(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3813);
}
// TwoFactorSetup.PasswordRecovery.Text
NSString * _Nonnull _Laut(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3814);
}
// TwoFactorSetup.PasswordRecovery.Title
NSString * _Nonnull _Lauu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3815);
}
// TwoFactorSetup.ResetDone.Action
NSString * _Nonnull _Lauv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3816);
}
// TwoFactorSetup.ResetDone.Text
NSString * _Nonnull _Lauw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3817);
}
// TwoFactorSetup.ResetDone.TextNoPassword
NSString * _Nonnull _Laux(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3818);
}
// TwoFactorSetup.ResetDone.Title
NSString * _Nonnull _Lauy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3819);
}
// TwoFactorSetup.ResetDone.TitleNoPassword
NSString * _Nonnull _Lauz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3820);
}
// TwoFactorSetup.ResetFloodWait
_FormattedString * _Nonnull _LauA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3821, _0);
}
// TwoStepAuth.AddHintDescription
NSString * _Nonnull _LauB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3822);
}
// TwoStepAuth.AddHintTitle
NSString * _Nonnull _LauC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3823);
}
// TwoStepAuth.AdditionalPassword
NSString * _Nonnull _LauD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3824);
}
// TwoStepAuth.CancelResetText
NSString * _Nonnull _LauE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3825);
}
// TwoStepAuth.CancelResetTitle
NSString * _Nonnull _LauF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3826);
}
// TwoStepAuth.ChangeEmail
NSString * _Nonnull _LauG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3827);
}
// TwoStepAuth.ChangePassword
NSString * _Nonnull _LauH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3828);
}
// TwoStepAuth.ChangePasswordDescription
NSString * _Nonnull _LauI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3829);
}
// TwoStepAuth.ConfirmEmailCodePlaceholder
NSString * _Nonnull _LauJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3830);
}
// TwoStepAuth.ConfirmEmailDescription
_FormattedString * _Nonnull _LauK(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3831, _0);
}
// TwoStepAuth.ConfirmEmailResendCode
NSString * _Nonnull _LauL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3832);
}
// TwoStepAuth.ConfirmationAbort
NSString * _Nonnull _LauM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3833);
}
// TwoStepAuth.ConfirmationText
NSString * _Nonnull _LauN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3834);
}
// TwoStepAuth.ConfirmationTitle
NSString * _Nonnull _LauO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3835);
}
// TwoStepAuth.Disable
NSString * _Nonnull _LauP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3836);
}
// TwoStepAuth.DisableSuccess
NSString * _Nonnull _LauQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3837);
}
// TwoStepAuth.Email
NSString * _Nonnull _LauR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3838);
}
// TwoStepAuth.EmailAddSuccess
NSString * _Nonnull _LauS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3839);
}
// TwoStepAuth.EmailChangeSuccess
NSString * _Nonnull _LauT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3840);
}
// TwoStepAuth.EmailCodeExpired
NSString * _Nonnull _LauU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3841);
}
// TwoStepAuth.EmailHelp
NSString * _Nonnull _LauV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3842);
}
// TwoStepAuth.EmailInvalid
NSString * _Nonnull _LauW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3843);
}
// TwoStepAuth.EmailPlaceholder
NSString * _Nonnull _LauX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3844);
}
// TwoStepAuth.EmailSent
NSString * _Nonnull _LauY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3845);
}
// TwoStepAuth.EmailSkip
NSString * _Nonnull _LauZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3846);
}
// TwoStepAuth.EmailSkipAlert
NSString * _Nonnull _Lava(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3847);
}
// TwoStepAuth.EmailTitle
NSString * _Nonnull _Lavb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3848);
}
// TwoStepAuth.EnabledSuccess
NSString * _Nonnull _Lavc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3849);
}
// TwoStepAuth.EnterEmailCode
NSString * _Nonnull _Lavd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3850);
}
// TwoStepAuth.EnterPasswordForgot
NSString * _Nonnull _Lave(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3851);
}
// TwoStepAuth.EnterPasswordHelp
NSString * _Nonnull _Lavf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3852);
}
// TwoStepAuth.EnterPasswordHint
_FormattedString * _Nonnull _Lavg(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3853, _0);
}
// TwoStepAuth.EnterPasswordInvalid
NSString * _Nonnull _Lavh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3854);
}
// TwoStepAuth.EnterPasswordPassword
NSString * _Nonnull _Lavi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3855);
}
// TwoStepAuth.EnterPasswordTitle
NSString * _Nonnull _Lavj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3856);
}
// TwoStepAuth.FloodError
NSString * _Nonnull _Lavk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3857);
}
// TwoStepAuth.GenericHelp
NSString * _Nonnull _Lavl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3858);
}
// TwoStepAuth.HintPlaceholder
NSString * _Nonnull _Lavm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3859);
}
// TwoStepAuth.PasswordChangeSuccess
NSString * _Nonnull _Lavn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3860);
}
// TwoStepAuth.PasswordRemoveConfirmation
NSString * _Nonnull _Lavo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3861);
}
// TwoStepAuth.PasswordRemovePassportConfirmation
NSString * _Nonnull _Lavp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3862);
}
// TwoStepAuth.PasswordSet
NSString * _Nonnull _Lavq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3863);
}
// TwoStepAuth.PendingEmailHelp
_FormattedString * _Nonnull _Lavr(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3864, _0);
}
// TwoStepAuth.ReEnterPasswordDescription
NSString * _Nonnull _Lavs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3865);
}
// TwoStepAuth.ReEnterPasswordTitle
NSString * _Nonnull _Lavt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3866);
}
// TwoStepAuth.RecoveryCode
NSString * _Nonnull _Lavu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3867);
}
// TwoStepAuth.RecoveryCodeExpired
NSString * _Nonnull _Lavv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3868);
}
// TwoStepAuth.RecoveryCodeHelp
NSString * _Nonnull _Lavw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3869);
}
// TwoStepAuth.RecoveryCodeInvalid
NSString * _Nonnull _Lavx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3870);
}
// TwoStepAuth.RecoveryEmailAddDescription
NSString * _Nonnull _Lavy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3871);
}
// TwoStepAuth.RecoveryEmailChangeDescription
NSString * _Nonnull _Lavz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3872);
}
// TwoStepAuth.RecoveryEmailResetNoAccess
NSString * _Nonnull _LavA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3873);
}
// TwoStepAuth.RecoveryEmailResetText
NSString * _Nonnull _LavB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3874);
}
// TwoStepAuth.RecoveryEmailTitle
NSString * _Nonnull _LavC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3875);
}
// TwoStepAuth.RecoveryEmailUnavailable
_FormattedString * _Nonnull _LavD(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3876, _0);
}
// TwoStepAuth.RecoveryFailed
NSString * _Nonnull _LavE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3877);
}
// TwoStepAuth.RecoveryTitle
NSString * _Nonnull _LavF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3878);
}
// TwoStepAuth.RecoveryUnavailable
NSString * _Nonnull _LavG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3879);
}
// TwoStepAuth.RecoveryUnavailableResetAction
NSString * _Nonnull _LavH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3880);
}
// TwoStepAuth.RecoveryUnavailableResetText
NSString * _Nonnull _LavI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3881);
}
// TwoStepAuth.RecoveryUnavailableResetTitle
NSString * _Nonnull _LavJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3882);
}
// TwoStepAuth.RemovePassword
NSString * _Nonnull _LavK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3883);
}
// TwoStepAuth.ResetAccountConfirmation
NSString * _Nonnull _LavL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3884);
}
// TwoStepAuth.ResetAccountHelp
NSString * _Nonnull _LavM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3885);
}
// TwoStepAuth.ResetAction
NSString * _Nonnull _LavN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3886);
}
// TwoStepAuth.ResetPendingText
_FormattedString * _Nonnull _LavO(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3887, _0);
}
// TwoStepAuth.SetPassword
NSString * _Nonnull _LavP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3888);
}
// TwoStepAuth.SetPasswordHelp
NSString * _Nonnull _LavQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3889);
}
// TwoStepAuth.SetupEmail
NSString * _Nonnull _LavR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3890);
}
// TwoStepAuth.SetupHint
NSString * _Nonnull _LavS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3891);
}
// TwoStepAuth.SetupHintTitle
NSString * _Nonnull _LavT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3892);
}
// TwoStepAuth.SetupPasswordConfirmFailed
NSString * _Nonnull _LavU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3893);
}
// TwoStepAuth.SetupPasswordConfirmPassword
NSString * _Nonnull _LavV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3894);
}
// TwoStepAuth.SetupPasswordDescription
NSString * _Nonnull _LavW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3895);
}
// TwoStepAuth.SetupPasswordEnterPasswordChange
NSString * _Nonnull _LavX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3896);
}
// TwoStepAuth.SetupPasswordEnterPasswordNew
NSString * _Nonnull _LavY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3897);
}
// TwoStepAuth.SetupPasswordTitle
NSString * _Nonnull _LavZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3898);
}
// TwoStepAuth.SetupPendingEmail
_FormattedString * _Nonnull _Lawa(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3899, _0);
}
// TwoStepAuth.SetupResendEmailCode
NSString * _Nonnull _Lawb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3900);
}
// TwoStepAuth.SetupResendEmailCodeAlert
NSString * _Nonnull _Lawc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3901);
}
// TwoStepAuth.Title
NSString * _Nonnull _Lawd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3902);
}
// Undo.ChatCleared
NSString * _Nonnull _Lawe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3903);
}
// Undo.ChatClearedForBothSides
NSString * _Nonnull _Lawf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3904);
}
// Undo.ChatDeleted
NSString * _Nonnull _Lawg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3905);
}
// Undo.ChatDeletedForBothSides
NSString * _Nonnull _Lawh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3906);
}
// Undo.DeletedChannel
NSString * _Nonnull _Lawi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3907);
}
// Undo.DeletedGroup
NSString * _Nonnull _Lawj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3908);
}
// Undo.LeftChannel
NSString * _Nonnull _Lawk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3909);
}
// Undo.LeftGroup
NSString * _Nonnull _Lawl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3910);
}
// Undo.ScheduledMessagesCleared
NSString * _Nonnull _Lawm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3911);
}
// Undo.SecretChatDeleted
NSString * _Nonnull _Lawn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3912);
}
// Undo.Undo
NSString * _Nonnull _Lawo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3913);
}
// Update.AppVersion
_FormattedString * _Nonnull _Lawp(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3914, _0);
}
// Update.Skip
NSString * _Nonnull _Lawq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3915);
}
// Update.Title
NSString * _Nonnull _Lawr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3916);
}
// Update.UpdateApp
NSString * _Nonnull _Laws(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3917);
}
// User.DeletedAccount
NSString * _Nonnull _Lawt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3918);
}
// UserCount
NSString * _Nonnull _Lawu(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 3919, value);
}
// UserInfo.About.Placeholder
NSString * _Nonnull _Lawv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3920);
}
// UserInfo.AddContact
NSString * _Nonnull _Laww(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3921);
}
// UserInfo.AddPhone
NSString * _Nonnull _Lawx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3922);
}
// UserInfo.AddToExisting
NSString * _Nonnull _Lawy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3923);
}
// UserInfo.BlockActionTitle
_FormattedString * _Nonnull _Lawz(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3924, _0);
}
// UserInfo.BlockConfirmation
_FormattedString * _Nonnull _LawA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3925, _0);
}
// UserInfo.BlockConfirmationTitle
_FormattedString * _Nonnull _LawB(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3926, _0);
}
// UserInfo.BotHelp
NSString * _Nonnull _LawC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3927);
}
// UserInfo.BotPrivacy
NSString * _Nonnull _LawD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3928);
}
// UserInfo.BotSettings
NSString * _Nonnull _LawE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3929);
}
// UserInfo.ContactForwardTooltip.Chat.One
_FormattedString * _Nonnull _LawF(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3930, _0);
}
// UserInfo.ContactForwardTooltip.ManyChats.One
_FormattedString * _Nonnull _LawG(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 3931, _0, _1);
}
// UserInfo.ContactForwardTooltip.SavedMessages.One
NSString * _Nonnull _LawH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3932);
}
// UserInfo.ContactForwardTooltip.TwoChats.One
_FormattedString * _Nonnull _LawI(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 3933, _0, _1);
}
// UserInfo.CreateNewContact
NSString * _Nonnull _LawJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3934);
}
// UserInfo.DeleteContact
NSString * _Nonnull _LawK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3935);
}
// UserInfo.FakeBotWarning
NSString * _Nonnull _LawL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3936);
}
// UserInfo.FakeUserWarning
NSString * _Nonnull _LawM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3937);
}
// UserInfo.FirstNamePlaceholder
NSString * _Nonnull _LawN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3938);
}
// UserInfo.GenericPhoneLabel
NSString * _Nonnull _LawO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3939);
}
// UserInfo.GroupsInCommon
NSString * _Nonnull _LawP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3940);
}
// UserInfo.Invite
NSString * _Nonnull _LawQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3941);
}
// UserInfo.InviteBotToGroup
NSString * _Nonnull _LawR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3942);
}
// UserInfo.LastNamePlaceholder
NSString * _Nonnull _LawS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3943);
}
// UserInfo.LinkForwardTooltip.Chat.One
_FormattedString * _Nonnull _LawT(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3944, _0);
}
// UserInfo.LinkForwardTooltip.ManyChats.One
_FormattedString * _Nonnull _LawU(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 3945, _0, _1);
}
// UserInfo.LinkForwardTooltip.SavedMessages.One
NSString * _Nonnull _LawV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3946);
}
// UserInfo.LinkForwardTooltip.TwoChats.One
_FormattedString * _Nonnull _LawW(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 3947, _0, _1);
}
// UserInfo.NotificationsDefault
NSString * _Nonnull _LawX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3948);
}
// UserInfo.NotificationsDefaultDisabled
NSString * _Nonnull _LawY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3949);
}
// UserInfo.NotificationsDefaultEnabled
NSString * _Nonnull _LawZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3950);
}
// UserInfo.NotificationsDefaultSound
_FormattedString * _Nonnull _Laxa(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3951, _0);
}
// UserInfo.NotificationsDisable
NSString * _Nonnull _Laxb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3952);
}
// UserInfo.NotificationsDisabled
NSString * _Nonnull _Laxc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3953);
}
// UserInfo.NotificationsEnable
NSString * _Nonnull _Laxd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3954);
}
// UserInfo.NotificationsEnabled
NSString * _Nonnull _Laxe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3955);
}
// UserInfo.PhoneCall
NSString * _Nonnull _Laxf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3956);
}
// UserInfo.ScamBotWarning
NSString * _Nonnull _Laxg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3957);
}
// UserInfo.ScamUserWarning
NSString * _Nonnull _Laxh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3958);
}
// UserInfo.SendMessage
NSString * _Nonnull _Laxi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3959);
}
// UserInfo.ShareBot
NSString * _Nonnull _Laxj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3960);
}
// UserInfo.ShareContact
NSString * _Nonnull _Laxk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3961);
}
// UserInfo.ShareMyContactInfo
NSString * _Nonnull _Laxl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3962);
}
// UserInfo.StartSecretChat
NSString * _Nonnull _Laxm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3963);
}
// UserInfo.StartSecretChatConfirmation
_FormattedString * _Nonnull _Laxn(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3964, _0);
}
// UserInfo.StartSecretChatStart
NSString * _Nonnull _Laxo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3965);
}
// UserInfo.TapToCall
NSString * _Nonnull _Laxp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3966);
}
// UserInfo.TelegramCall
NSString * _Nonnull _Laxq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3967);
}
// UserInfo.Title
NSString * _Nonnull _Laxr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3968);
}
// UserInfo.UnblockConfirmation
_FormattedString * _Nonnull _Laxs(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3969, _0);
}
// Username.CheckingUsername
NSString * _Nonnull _Laxt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3970);
}
// Username.Help
NSString * _Nonnull _Laxu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3971);
}
// Username.InvalidCharacters
NSString * _Nonnull _Laxv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3972);
}
// Username.InvalidStartsWithNumber
NSString * _Nonnull _Laxw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3973);
}
// Username.InvalidTaken
NSString * _Nonnull _Laxx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3974);
}
// Username.InvalidTooShort
NSString * _Nonnull _Laxy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3975);
}
// Username.LinkCopied
NSString * _Nonnull _Laxz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3976);
}
// Username.LinkHint
_FormattedString * _Nonnull _LaxA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3977, _0);
}
// Username.Placeholder
NSString * _Nonnull _LaxB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3978);
}
// Username.Title
NSString * _Nonnull _LaxC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3979);
}
// Username.TooManyPublicUsernamesError
NSString * _Nonnull _LaxD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3980);
}
// Username.UsernameIsAvailable
_FormattedString * _Nonnull _LaxE(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 3981, _0);
}
// VoiceChat.AddBio
NSString * _Nonnull _LaxF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3982);
}
// VoiceChat.AddPhoto
NSString * _Nonnull _LaxG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3983);
}
// VoiceChat.AnonymousDisabledAlertText
NSString * _Nonnull _LaxH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3984);
}
// VoiceChat.AskedToSpeak
NSString * _Nonnull _LaxI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3985);
}
// VoiceChat.AskedToSpeakHelp
NSString * _Nonnull _LaxJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3986);
}
// VoiceChat.Audio
NSString * _Nonnull _LaxK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3987);
}
// VoiceChat.CancelConfirmationEnd
NSString * _Nonnull _LaxL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3988);
}
// VoiceChat.CancelConfirmationText
NSString * _Nonnull _LaxM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3989);
}
// VoiceChat.CancelConfirmationTitle
NSString * _Nonnull _LaxN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3990);
}
// VoiceChat.CancelReminder
NSString * _Nonnull _LaxO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3991);
}
// VoiceChat.CancelSpeakRequest
NSString * _Nonnull _LaxP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3992);
}
// VoiceChat.CancelVoiceChat
NSString * _Nonnull _LaxQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3993);
}
// VoiceChat.ChangeName
NSString * _Nonnull _LaxR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3994);
}
// VoiceChat.ChangeNameTitle
NSString * _Nonnull _LaxS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3995);
}
// VoiceChat.ChangePhoto
NSString * _Nonnull _LaxT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3996);
}
// VoiceChat.ChatFullAlertText
NSString * _Nonnull _LaxU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3997);
}
// VoiceChat.Connecting
NSString * _Nonnull _LaxV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3998);
}
// VoiceChat.ContextAudio
NSString * _Nonnull _LaxW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 3999);
}
// VoiceChat.CopyInviteLink
NSString * _Nonnull _LaxX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4000);
}
// VoiceChat.CreateNewVoiceChatSchedule
NSString * _Nonnull _LaxY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4001);
}
// VoiceChat.CreateNewVoiceChatStart
NSString * _Nonnull _LaxZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4002);
}
// VoiceChat.CreateNewVoiceChatStartNow
NSString * _Nonnull _Laya(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4003);
}
// VoiceChat.CreateNewVoiceChatText
NSString * _Nonnull _Layb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4004);
}
// VoiceChat.DisplayAs
NSString * _Nonnull _Layc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4005);
}
// VoiceChat.DisplayAsInfo
NSString * _Nonnull _Layd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4006);
}
// VoiceChat.DisplayAsInfoGroup
NSString * _Nonnull _Laye(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4007);
}
// VoiceChat.DisplayAsSuccess
_FormattedString * _Nonnull _Layf(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4008, _0);
}
// VoiceChat.EditBio
NSString * _Nonnull _Layg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4009);
}
// VoiceChat.EditBioPlaceholder
NSString * _Nonnull _Layh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4010);
}
// VoiceChat.EditBioSave
NSString * _Nonnull _Layi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4011);
}
// VoiceChat.EditBioSuccess
NSString * _Nonnull _Layj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4012);
}
// VoiceChat.EditBioText
NSString * _Nonnull _Layk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4013);
}
// VoiceChat.EditBioTitle
NSString * _Nonnull _Layl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4014);
}
// VoiceChat.EditDescription
NSString * _Nonnull _Laym(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4015);
}
// VoiceChat.EditDescriptionPlaceholder
NSString * _Nonnull _Layn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4016);
}
// VoiceChat.EditDescriptionSave
NSString * _Nonnull _Layo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4017);
}
// VoiceChat.EditDescriptionSuccess
NSString * _Nonnull _Layp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4018);
}
// VoiceChat.EditDescriptionText
NSString * _Nonnull _Layq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4019);
}
// VoiceChat.EditDescriptionTitle
NSString * _Nonnull _Layr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4020);
}
// VoiceChat.EditNameSuccess
NSString * _Nonnull _Lays(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4021);
}
// VoiceChat.EditPermissions
NSString * _Nonnull _Layt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4022);
}
// VoiceChat.EditTitle
NSString * _Nonnull _Layu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4023);
}
// VoiceChat.EditTitleRemoveSuccess
NSString * _Nonnull _Layv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4024);
}
// VoiceChat.EditTitleSuccess
_FormattedString * _Nonnull _Layw(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4025, _0);
}
// VoiceChat.EditTitleText
NSString * _Nonnull _Layx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4026);
}
// VoiceChat.EditTitleTitle
NSString * _Nonnull _Layy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4027);
}
// VoiceChat.EndConfirmationEnd
NSString * _Nonnull _Layz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4028);
}
// VoiceChat.EndConfirmationText
NSString * _Nonnull _LayA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4029);
}
// VoiceChat.EndConfirmationTitle
NSString * _Nonnull _LayB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4030);
}
// VoiceChat.EndVoiceChat
NSString * _Nonnull _LayC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4031);
}
// VoiceChat.ForwardTooltip.Chat
_FormattedString * _Nonnull _LayD(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4032, _0);
}
// VoiceChat.ForwardTooltip.ManyChats
_FormattedString * _Nonnull _LayE(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 4033, _0, _1);
}
// VoiceChat.ForwardTooltip.TwoChats
_FormattedString * _Nonnull _LayF(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 4034, _0, _1);
}
// VoiceChat.ImproveYourProfileText
NSString * _Nonnull _LayG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4035);
}
// VoiceChat.InviteLink.CopyListenerLink
NSString * _Nonnull _LayH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4036);
}
// VoiceChat.InviteLink.CopySpeakerLink
NSString * _Nonnull _LayI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4037);
}
// VoiceChat.InviteLink.InviteListeners
NSString * _Nonnull _LayJ(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 4038, value);
}
// VoiceChat.InviteLink.InviteSpeakers
NSString * _Nonnull _LayK(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 4039, value);
}
// VoiceChat.InviteLink.Listener
NSString * _Nonnull _LayL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4040);
}
// VoiceChat.InviteLink.Speaker
NSString * _Nonnull _LayM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4041);
}
// VoiceChat.InviteLinkCopiedText
NSString * _Nonnull _LayN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4042);
}
// VoiceChat.InviteMember
NSString * _Nonnull _LayO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4043);
}
// VoiceChat.InviteMemberToChannelFirstText
_FormattedString * _Nonnull _LayP(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 4044, _0, _1);
}
// VoiceChat.InviteMemberToGroupFirstAdd
NSString * _Nonnull _LayQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4045);
}
// VoiceChat.InviteMemberToGroupFirstText
_FormattedString * _Nonnull _LayR(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 4046, _0, _1);
}
// VoiceChat.InvitedPeerText
_FormattedString * _Nonnull _LayS(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4047, _0);
}
// VoiceChat.LateBy
NSString * _Nonnull _LayT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4048);
}
// VoiceChat.Leave
NSString * _Nonnull _LayU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4049);
}
// VoiceChat.LeaveAndCancelVoiceChat
NSString * _Nonnull _LayV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4050);
}
// VoiceChat.LeaveAndEndVoiceChat
NSString * _Nonnull _LayW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4051);
}
// VoiceChat.LeaveConfirmation
NSString * _Nonnull _LayX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4052);
}
// VoiceChat.LeaveVoiceChat
NSString * _Nonnull _LayY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4053);
}
// VoiceChat.Live
NSString * _Nonnull _LayZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4054);
}
// VoiceChat.Mute
NSString * _Nonnull _Laza(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4055);
}
// VoiceChat.MuteForMe
NSString * _Nonnull _Lazb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4056);
}
// VoiceChat.MutePeer
NSString * _Nonnull _Lazc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4057);
}
// VoiceChat.Muted
NSString * _Nonnull _Lazd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4058);
}
// VoiceChat.MutedByAdmin
NSString * _Nonnull _Laze(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4059);
}
// VoiceChat.MutedByAdminHelp
NSString * _Nonnull _Lazf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4060);
}
// VoiceChat.MutedHelp
NSString * _Nonnull _Lazg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4061);
}
// VoiceChat.NoiseSuppression
NSString * _Nonnull _Lazh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4062);
}
// VoiceChat.NoiseSuppressionDisabled
NSString * _Nonnull _Lazi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4063);
}
// VoiceChat.NoiseSuppressionEnabled
NSString * _Nonnull _Lazj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4064);
}
// VoiceChat.OpenChannel
NSString * _Nonnull _Lazk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4065);
}
// VoiceChat.OpenChat
NSString * _Nonnull _Lazl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4066);
}
// VoiceChat.OpenGroup
NSString * _Nonnull _Lazm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4067);
}
// VoiceChat.Panel.Members
NSString * _Nonnull _Lazn(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 4068, value);
}
// VoiceChat.Panel.TapToJoin
NSString * _Nonnull _Lazo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4069);
}
// VoiceChat.PanelJoin
NSString * _Nonnull _Lazp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4070);
}
// VoiceChat.ParticipantIsSpeaking
_FormattedString * _Nonnull _Lazq(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4071, _0);
}
// VoiceChat.PeerJoinedText
_FormattedString * _Nonnull _Lazr(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4072, _0);
}
// VoiceChat.PersonalAccount
NSString * _Nonnull _Lazs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4073);
}
// VoiceChat.PinVideo
NSString * _Nonnull _Lazt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4074);
}
// VoiceChat.Reconnecting
NSString * _Nonnull _Lazu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4075);
}
// VoiceChat.RecordingInProgress
NSString * _Nonnull _Lazv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4076);
}
// VoiceChat.RecordingSaved
NSString * _Nonnull _Lazw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4077);
}
// VoiceChat.RecordingStarted
NSString * _Nonnull _Lazx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4078);
}
// VoiceChat.RecordingTitlePlaceholder
NSString * _Nonnull _Lazy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4079);
}
// VoiceChat.ReminderNotify
NSString * _Nonnull _Lazz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4080);
}
// VoiceChat.RemoveAndBanPeerConfirmation
_FormattedString * _Nonnull _LazA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 4081, _0, _1);
}
// VoiceChat.RemovePeer
NSString * _Nonnull _LazB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4082);
}
// VoiceChat.RemovePeerConfirmation
_FormattedString * _Nonnull _LazC(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4083, _0);
}
// VoiceChat.RemovePeerConfirmationChannel
_FormattedString * _Nonnull _LazD(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4084, _0);
}
// VoiceChat.RemovePeerRemove
NSString * _Nonnull _LazE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4085);
}
// VoiceChat.RemovedPeerText
_FormattedString * _Nonnull _LazF(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4086, _0);
}
// VoiceChat.Scheduled
NSString * _Nonnull _LazG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4087);
}
// VoiceChat.SelectAccount
NSString * _Nonnull _LazH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4088);
}
// VoiceChat.SendPublicLinkSend
NSString * _Nonnull _LazI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4089);
}
// VoiceChat.SendPublicLinkText
_FormattedString * _Nonnull _LazJ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 4090, _0, _1);
}
// VoiceChat.SetReminder
NSString * _Nonnull _LazK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4091);
}
// VoiceChat.Share
NSString * _Nonnull _LazL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4092);
}
// VoiceChat.ShareScreen
NSString * _Nonnull _LazM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4093);
}
// VoiceChat.ShareShort
NSString * _Nonnull _LazN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4094);
}
// VoiceChat.SpeakPermissionAdmin
NSString * _Nonnull _LazO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4095);
}
// VoiceChat.SpeakPermissionEveryone
NSString * _Nonnull _LazP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4096);
}
// VoiceChat.StartNow
NSString * _Nonnull _LazQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4097);
}
// VoiceChat.StartRecording
NSString * _Nonnull _LazR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4098);
}
// VoiceChat.StartRecordingStart
NSString * _Nonnull _LazS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4099);
}
// VoiceChat.StartRecordingText
NSString * _Nonnull _LazT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4100);
}
// VoiceChat.StartRecordingTitle
NSString * _Nonnull _LazU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4101);
}
// VoiceChat.StartsIn
NSString * _Nonnull _LazV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4102);
}
// VoiceChat.Status.Members
NSString * _Nonnull _LazW(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 4103, value);
}
// VoiceChat.Status.MembersFormat
_FormattedString * _Nonnull _LazX(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 4104, _0, _1);
}
// VoiceChat.StatusInvited
NSString * _Nonnull _LazY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4105);
}
// VoiceChat.StatusLateBy
_FormattedString * _Nonnull _LazZ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4106, _0);
}
// VoiceChat.StatusListening
NSString * _Nonnull _LaAa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4107);
}
// VoiceChat.StatusMutedForYou
NSString * _Nonnull _LaAb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4108);
}
// VoiceChat.StatusMutedYou
NSString * _Nonnull _LaAc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4109);
}
// VoiceChat.StatusSpeaking
NSString * _Nonnull _LaAd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4110);
}
// VoiceChat.StatusSpeakingVolume
_FormattedString * _Nonnull _LaAe(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4111, _0);
}
// VoiceChat.StatusStartsIn
_FormattedString * _Nonnull _LaAf(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4112, _0);
}
// VoiceChat.StatusWantsToSpeak
NSString * _Nonnull _LaAg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4113);
}
// VoiceChat.StopRecording
NSString * _Nonnull _LaAh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4114);
}
// VoiceChat.StopRecordingStop
NSString * _Nonnull _LaAi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4115);
}
// VoiceChat.StopRecordingTitle
NSString * _Nonnull _LaAj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4116);
}
// VoiceChat.StopScreenSharing
NSString * _Nonnull _LaAk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4117);
}
// VoiceChat.StopScreenSharingShort
NSString * _Nonnull _LaAl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4118);
}
// VoiceChat.TapToAddBio
NSString * _Nonnull _LaAm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4119);
}
// VoiceChat.TapToAddPhoto
NSString * _Nonnull _LaAn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4120);
}
// VoiceChat.TapToAddPhotoOrBio
NSString * _Nonnull _LaAo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4121);
}
// VoiceChat.TapToEditTitle
NSString * _Nonnull _LaAp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4122);
}
// VoiceChat.TapToViewCameraVideo
NSString * _Nonnull _LaAq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4123);
}
// VoiceChat.TapToViewScreenVideo
NSString * _Nonnull _LaAr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4124);
}
// VoiceChat.Title
NSString * _Nonnull _LaAs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4125);
}
// VoiceChat.Unmute
NSString * _Nonnull _LaAt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4126);
}
// VoiceChat.UnmuteForMe
NSString * _Nonnull _LaAu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4127);
}
// VoiceChat.UnmuteHelp
NSString * _Nonnull _LaAv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4128);
}
// VoiceChat.UnmutePeer
NSString * _Nonnull _LaAw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4129);
}
// VoiceChat.UnmuteSuggestion
NSString * _Nonnull _LaAx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4130);
}
// VoiceChat.Unpin
NSString * _Nonnull _LaAy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4131);
}
// VoiceChat.UnpinVideo
NSString * _Nonnull _LaAz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4132);
}
// VoiceChat.UserCanNowSpeak
_FormattedString * _Nonnull _LaAA(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4133, _0);
}
// VoiceChat.UserInvited
_FormattedString * _Nonnull _LaAB(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4134, _0);
}
// VoiceChat.Video
NSString * _Nonnull _LaAC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4135);
}
// VoiceChat.VideoParticipantsLimitExceeded
_FormattedString * _Nonnull _LaAD(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4136, _0);
}
// VoiceChat.VideoPaused
NSString * _Nonnull _LaAE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4137);
}
// VoiceChat.VideoPreviewDescription
NSString * _Nonnull _LaAF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4138);
}
// VoiceChat.VideoPreviewShareCamera
NSString * _Nonnull _LaAG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4139);
}
// VoiceChat.VideoPreviewShareScreen
NSString * _Nonnull _LaAH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4140);
}
// VoiceChat.VideoPreviewStopScreenSharing
NSString * _Nonnull _LaAI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4141);
}
// VoiceChat.VideoPreviewTitle
NSString * _Nonnull _LaAJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4142);
}
// VoiceChat.You
NSString * _Nonnull _LaAK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4143);
}
// VoiceChat.YouAreSharingScreen
NSString * _Nonnull _LaAL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4144);
}
// VoiceChat.YouCanNowSpeak
NSString * _Nonnull _LaAM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4145);
}
// VoiceChat.YouCanNowSpeakIn
_FormattedString * _Nonnull _LaAN(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4146, _0);
}
// VoiceOver.AttachMedia
NSString * _Nonnull _LaAO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4147);
}
// VoiceOver.AuthSessions.CurrentSession
NSString * _Nonnull _LaAP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4148);
}
// VoiceOver.BotCommands
NSString * _Nonnull _LaAQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4149);
}
// VoiceOver.BotKeyboard
NSString * _Nonnull _LaAR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4150);
}
// VoiceOver.Chat.AnimatedSticker
NSString * _Nonnull _LaAS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4151);
}
// VoiceOver.Chat.AnimatedStickerFrom
_FormattedString * _Nonnull _LaAT(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4152, _0);
}
// VoiceOver.Chat.AnonymousPoll
NSString * _Nonnull _LaAU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4153);
}
// VoiceOver.Chat.AnonymousPollFrom
_FormattedString * _Nonnull _LaAV(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4154, _0);
}
// VoiceOver.Chat.Caption
_FormattedString * _Nonnull _LaAW(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4155, _0);
}
// VoiceOver.Chat.ChannelInfo
NSString * _Nonnull _LaAX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4156);
}
// VoiceOver.Chat.Contact
NSString * _Nonnull _LaAY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4157);
}
// VoiceOver.Chat.ContactEmail
NSString * _Nonnull _LaAZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4158);
}
// VoiceOver.Chat.ContactEmailCount
NSString * _Nonnull _LaBa(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 4159, value);
}
// VoiceOver.Chat.ContactFrom
_FormattedString * _Nonnull _LaBb(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4160, _0);
}
// VoiceOver.Chat.ContactOrganization
_FormattedString * _Nonnull _LaBc(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4161, _0);
}
// VoiceOver.Chat.ContactPhoneNumber
NSString * _Nonnull _LaBd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4162);
}
// VoiceOver.Chat.ContactPhoneNumberCount
NSString * _Nonnull _LaBe(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 4163, value);
}
// VoiceOver.Chat.Duration
_FormattedString * _Nonnull _LaBf(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4164, _0);
}
// VoiceOver.Chat.File
NSString * _Nonnull _LaBg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4165);
}
// VoiceOver.Chat.FileFrom
_FormattedString * _Nonnull _LaBh(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4166, _0);
}
// VoiceOver.Chat.ForwardedFrom
_FormattedString * _Nonnull _LaBi(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4167, _0);
}
// VoiceOver.Chat.ForwardedFromYou
NSString * _Nonnull _LaBj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4168);
}
// VoiceOver.Chat.GoToOriginalMessage
NSString * _Nonnull _LaBk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4169);
}
// VoiceOver.Chat.GroupInfo
NSString * _Nonnull _LaBl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4170);
}
// VoiceOver.Chat.Message
NSString * _Nonnull _LaBm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4171);
}
// VoiceOver.Chat.MessagesSelected
NSString * _Nonnull _LaBn(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 4172, value);
}
// VoiceOver.Chat.Music
NSString * _Nonnull _LaBo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4173);
}
// VoiceOver.Chat.MusicFrom
_FormattedString * _Nonnull _LaBp(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4174, _0);
}
// VoiceOver.Chat.MusicTitle
_FormattedString * _Nonnull _LaBq(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 4175, _0, _1);
}
// VoiceOver.Chat.OpenHint
NSString * _Nonnull _LaBr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4176);
}
// VoiceOver.Chat.OpenLinkHint
NSString * _Nonnull _LaBs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4177);
}
// VoiceOver.Chat.OptionSelected
NSString * _Nonnull _LaBt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4178);
}
// VoiceOver.Chat.PagePreview
NSString * _Nonnull _LaBu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4179);
}
// VoiceOver.Chat.Photo
NSString * _Nonnull _LaBv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4180);
}
// VoiceOver.Chat.PhotoFrom
_FormattedString * _Nonnull _LaBw(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4181, _0);
}
// VoiceOver.Chat.PlayHint
NSString * _Nonnull _LaBx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4182);
}
// VoiceOver.Chat.PollFinalResults
NSString * _Nonnull _LaBy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4183);
}
// VoiceOver.Chat.PollNoVotes
NSString * _Nonnull _LaBz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4184);
}
// VoiceOver.Chat.PollOptionCount
NSString * _Nonnull _LaBA(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 4185, value);
}
// VoiceOver.Chat.PollVotes
NSString * _Nonnull _LaBB(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 4186, value);
}
// VoiceOver.Chat.Profile
NSString * _Nonnull _LaBC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4187);
}
// VoiceOver.Chat.RecordModeVideoMessage
NSString * _Nonnull _LaBD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4188);
}
// VoiceOver.Chat.RecordModeVideoMessageInfo
NSString * _Nonnull _LaBE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4189);
}
// VoiceOver.Chat.RecordModeVoiceMessage
NSString * _Nonnull _LaBF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4190);
}
// VoiceOver.Chat.RecordModeVoiceMessageInfo
NSString * _Nonnull _LaBG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4191);
}
// VoiceOver.Chat.RecordPreviewVoiceMessage
NSString * _Nonnull _LaBH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4192);
}
// VoiceOver.Chat.Reply
NSString * _Nonnull _LaBI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4193);
}
// VoiceOver.Chat.ReplyFrom
_FormattedString * _Nonnull _LaBJ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4194, _0);
}
// VoiceOver.Chat.ReplyToYourMessage
NSString * _Nonnull _LaBK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4195);
}
// VoiceOver.Chat.SeenByRecipient
NSString * _Nonnull _LaBL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4196);
}
// VoiceOver.Chat.SeenByRecipients
NSString * _Nonnull _LaBM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4197);
}
// VoiceOver.Chat.Selected
NSString * _Nonnull _LaBN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4198);
}
// VoiceOver.Chat.Size
_FormattedString * _Nonnull _LaBO(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4199, _0);
}
// VoiceOver.Chat.Sticker
NSString * _Nonnull _LaBP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4200);
}
// VoiceOver.Chat.StickerFrom
_FormattedString * _Nonnull _LaBQ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4201, _0);
}
// VoiceOver.Chat.Title
_FormattedString * _Nonnull _LaBR(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4202, _0);
}
// VoiceOver.Chat.UnreadMessages
NSString * _Nonnull _LaBS(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 4203, value);
}
// VoiceOver.Chat.Video
NSString * _Nonnull _LaBT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4204);
}
// VoiceOver.Chat.VideoFrom
_FormattedString * _Nonnull _LaBU(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4205, _0);
}
// VoiceOver.Chat.VideoMessage
NSString * _Nonnull _LaBV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4206);
}
// VoiceOver.Chat.VideoMessageFrom
_FormattedString * _Nonnull _LaBW(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4207, _0);
}
// VoiceOver.Chat.VoiceMessage
NSString * _Nonnull _LaBX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4208);
}
// VoiceOver.Chat.VoiceMessageFrom
_FormattedString * _Nonnull _LaBY(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4209, _0);
}
// VoiceOver.Chat.YourAnimatedSticker
NSString * _Nonnull _LaBZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4210);
}
// VoiceOver.Chat.YourAnonymousPoll
NSString * _Nonnull _LaCa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4211);
}
// VoiceOver.Chat.YourContact
NSString * _Nonnull _LaCb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4212);
}
// VoiceOver.Chat.YourFile
NSString * _Nonnull _LaCc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4213);
}
// VoiceOver.Chat.YourMessage
NSString * _Nonnull _LaCd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4214);
}
// VoiceOver.Chat.YourMusic
NSString * _Nonnull _LaCe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4215);
}
// VoiceOver.Chat.YourPhoto
NSString * _Nonnull _LaCf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4216);
}
// VoiceOver.Chat.YourSticker
NSString * _Nonnull _LaCg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4217);
}
// VoiceOver.Chat.YourVideo
NSString * _Nonnull _LaCh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4218);
}
// VoiceOver.Chat.YourVideoMessage
NSString * _Nonnull _LaCi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4219);
}
// VoiceOver.Chat.YourVoiceMessage
NSString * _Nonnull _LaCj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4220);
}
// VoiceOver.ChatList.Message
NSString * _Nonnull _LaCk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4221);
}
// VoiceOver.ChatList.MessageEmpty
NSString * _Nonnull _LaCl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4222);
}
// VoiceOver.ChatList.MessageFrom
_FormattedString * _Nonnull _LaCm(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4223, _0);
}
// VoiceOver.ChatList.MessageRead
NSString * _Nonnull _LaCn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4224);
}
// VoiceOver.ChatList.OutgoingMessage
NSString * _Nonnull _LaCo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4225);
}
// VoiceOver.Common.Off
NSString * _Nonnull _LaCp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4226);
}
// VoiceOver.Common.On
NSString * _Nonnull _LaCq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4227);
}
// VoiceOver.Common.SwitchHint
NSString * _Nonnull _LaCr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4228);
}
// VoiceOver.DiscardPreparedContent
NSString * _Nonnull _LaCs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4229);
}
// VoiceOver.DismissContextMenu
NSString * _Nonnull _LaCt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4230);
}
// VoiceOver.Editing.ClearText
NSString * _Nonnull _LaCu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4231);
}
// VoiceOver.Keyboard
NSString * _Nonnull _LaCv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4232);
}
// VoiceOver.Media.PlaybackPause
NSString * _Nonnull _LaCw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4233);
}
// VoiceOver.Media.PlaybackPlay
NSString * _Nonnull _LaCx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4234);
}
// VoiceOver.Media.PlaybackRate
NSString * _Nonnull _LaCy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4235);
}
// VoiceOver.Media.PlaybackRateChange
NSString * _Nonnull _LaCz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4236);
}
// VoiceOver.Media.PlaybackRateFast
NSString * _Nonnull _LaCA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4237);
}
// VoiceOver.Media.PlaybackRateNormal
NSString * _Nonnull _LaCB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4238);
}
// VoiceOver.Media.PlaybackStop
NSString * _Nonnull _LaCC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4239);
}
// VoiceOver.MessageContextDelete
NSString * _Nonnull _LaCD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4240);
}
// VoiceOver.MessageContextForward
NSString * _Nonnull _LaCE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4241);
}
// VoiceOver.MessageContextOpenMessageMenu
NSString * _Nonnull _LaCF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4242);
}
// VoiceOver.MessageContextReply
NSString * _Nonnull _LaCG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4243);
}
// VoiceOver.MessageContextReport
NSString * _Nonnull _LaCH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4244);
}
// VoiceOver.MessageContextSend
NSString * _Nonnull _LaCI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4245);
}
// VoiceOver.MessageContextShare
NSString * _Nonnull _LaCJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4246);
}
// VoiceOver.Navigation.Compose
NSString * _Nonnull _LaCK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4247);
}
// VoiceOver.Navigation.ProxySettings
NSString * _Nonnull _LaCL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4248);
}
// VoiceOver.Navigation.Search
NSString * _Nonnull _LaCM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4249);
}
// VoiceOver.Recording.StopAndPreview
NSString * _Nonnull _LaCN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4250);
}
// VoiceOver.ScheduledMessages
NSString * _Nonnull _LaCO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4251);
}
// VoiceOver.ScrollStatus
_FormattedString * _Nonnull _LaCP(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 4252, _0, _1);
}
// VoiceOver.SelfDestructTimerOff
NSString * _Nonnull _LaCQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4253);
}
// VoiceOver.SelfDestructTimerOn
_FormattedString * _Nonnull _LaCR(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4254, _0);
}
// VoiceOver.SilentPostOff
NSString * _Nonnull _LaCS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4255);
}
// VoiceOver.SilentPostOn
NSString * _Nonnull _LaCT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4256);
}
// VoiceOver.Stickers
NSString * _Nonnull _LaCU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4257);
}
// Wallpaper.DeleteConfirmation
NSString * _Nonnull _LaCV(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 4258, value);
}
// Wallpaper.ErrorNotFound
NSString * _Nonnull _LaCW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4259);
}
// Wallpaper.PhotoLibrary
NSString * _Nonnull _LaCX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4260);
}
// Wallpaper.ResetWallpapers
NSString * _Nonnull _LaCY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4261);
}
// Wallpaper.ResetWallpapersConfirmation
NSString * _Nonnull _LaCZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4262);
}
// Wallpaper.ResetWallpapersInfo
NSString * _Nonnull _LaDa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4263);
}
// Wallpaper.Search
NSString * _Nonnull _LaDb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4264);
}
// Wallpaper.SearchShort
NSString * _Nonnull _LaDc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4265);
}
// Wallpaper.Set
NSString * _Nonnull _LaDd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4266);
}
// Wallpaper.SetColor
NSString * _Nonnull _LaDe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4267);
}
// Wallpaper.SetCustomBackground
NSString * _Nonnull _LaDf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4268);
}
// Wallpaper.SetCustomBackgroundInfo
NSString * _Nonnull _LaDg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4269);
}
// Wallpaper.Title
NSString * _Nonnull _LaDh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4270);
}
// Wallpaper.Wallpaper
NSString * _Nonnull _LaDi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4271);
}
// WallpaperColors.SetCustomColor
NSString * _Nonnull _LaDj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4272);
}
// WallpaperColors.Title
NSString * _Nonnull _LaDk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4273);
}
// WallpaperPreview.Blurred
NSString * _Nonnull _LaDl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4274);
}
// WallpaperPreview.CropBottomText
NSString * _Nonnull _LaDm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4275);
}
// WallpaperPreview.CropTopText
NSString * _Nonnull _LaDn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4276);
}
// WallpaperPreview.CustomColorBottomText
NSString * _Nonnull _LaDo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4277);
}
// WallpaperPreview.CustomColorTopText
NSString * _Nonnull _LaDp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4278);
}
// WallpaperPreview.Motion
NSString * _Nonnull _LaDq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4279);
}
// WallpaperPreview.Pattern
NSString * _Nonnull _LaDr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4280);
}
// WallpaperPreview.PatternIntensity
NSString * _Nonnull _LaDs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4281);
}
// WallpaperPreview.PatternPaternApply
NSString * _Nonnull _LaDt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4282);
}
// WallpaperPreview.PatternPaternDiscard
NSString * _Nonnull _LaDu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4283);
}
// WallpaperPreview.PatternTitle
NSString * _Nonnull _LaDv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4284);
}
// WallpaperPreview.PreviewBottomText
NSString * _Nonnull _LaDw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4285);
}
// WallpaperPreview.PreviewBottomTextAnimatable
NSString * _Nonnull _LaDx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4286);
}
// WallpaperPreview.PreviewTopText
NSString * _Nonnull _LaDy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4287);
}
// WallpaperPreview.SwipeBottomText
NSString * _Nonnull _LaDz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4288);
}
// WallpaperPreview.SwipeColorsBottomText
NSString * _Nonnull _LaDA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4289);
}
// WallpaperPreview.SwipeColorsTopText
NSString * _Nonnull _LaDB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4290);
}
// WallpaperPreview.SwipeTopText
NSString * _Nonnull _LaDC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4291);
}
// WallpaperPreview.Title
NSString * _Nonnull _LaDD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4292);
}
// WallpaperPreview.WallpaperColors
NSString * _Nonnull _LaDE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4293);
}
// WallpaperSearch.ColorBlack
NSString * _Nonnull _LaDF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4294);
}
// WallpaperSearch.ColorBlue
NSString * _Nonnull _LaDG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4295);
}
// WallpaperSearch.ColorBrown
NSString * _Nonnull _LaDH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4296);
}
// WallpaperSearch.ColorGray
NSString * _Nonnull _LaDI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4297);
}
// WallpaperSearch.ColorGreen
NSString * _Nonnull _LaDJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4298);
}
// WallpaperSearch.ColorOrange
NSString * _Nonnull _LaDK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4299);
}
// WallpaperSearch.ColorPink
NSString * _Nonnull _LaDL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4300);
}
// WallpaperSearch.ColorPrefix
NSString * _Nonnull _LaDM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4301);
}
// WallpaperSearch.ColorPurple
NSString * _Nonnull _LaDN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4302);
}
// WallpaperSearch.ColorRed
NSString * _Nonnull _LaDO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4303);
}
// WallpaperSearch.ColorTeal
NSString * _Nonnull _LaDP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4304);
}
// WallpaperSearch.ColorTitle
NSString * _Nonnull _LaDQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4305);
}
// WallpaperSearch.ColorWhite
NSString * _Nonnull _LaDR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4306);
}
// WallpaperSearch.ColorYellow
NSString * _Nonnull _LaDS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4307);
}
// WallpaperSearch.Recent
NSString * _Nonnull _LaDT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4308);
}
// Watch.AppName
NSString * _Nonnull _LaDU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4309);
}
// Watch.AuthRequired
NSString * _Nonnull _LaDV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4310);
}
// Watch.Bot.Restart
NSString * _Nonnull _LaDW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4311);
}
// Watch.ChannelInfo.Title
NSString * _Nonnull _LaDX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4312);
}
// Watch.ChatList.Compose
NSString * _Nonnull _LaDY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4313);
}
// Watch.ChatList.NoConversationsText
NSString * _Nonnull _LaDZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4314);
}
// Watch.ChatList.NoConversationsTitle
NSString * _Nonnull _LaEa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4315);
}
// Watch.Compose.AddContact
NSString * _Nonnull _LaEb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4316);
}
// Watch.Compose.CreateMessage
NSString * _Nonnull _LaEc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4317);
}
// Watch.Compose.CurrentLocation
NSString * _Nonnull _LaEd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4318);
}
// Watch.Compose.Send
NSString * _Nonnull _LaEe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4319);
}
// Watch.ConnectionDescription
NSString * _Nonnull _LaEf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4320);
}
// Watch.Contacts.NoResults
NSString * _Nonnull _LaEg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4321);
}
// Watch.Conversation.GroupInfo
NSString * _Nonnull _LaEh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4322);
}
// Watch.Conversation.Reply
NSString * _Nonnull _LaEi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4323);
}
// Watch.Conversation.Unblock
NSString * _Nonnull _LaEj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4324);
}
// Watch.Conversation.UserInfo
NSString * _Nonnull _LaEk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4325);
}
// Watch.GroupInfo.Title
NSString * _Nonnull _LaEl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4326);
}
// Watch.LastSeen.ALongTimeAgo
NSString * _Nonnull _LaEm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4327);
}
// Watch.LastSeen.AtDate
_FormattedString * _Nonnull _LaEn(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4328, _0);
}
// Watch.LastSeen.HoursAgo
NSString * _Nonnull _LaEo(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 4329, value);
}
// Watch.LastSeen.JustNow
NSString * _Nonnull _LaEp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4330);
}
// Watch.LastSeen.Lately
NSString * _Nonnull _LaEq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4331);
}
// Watch.LastSeen.MinutesAgo
NSString * _Nonnull _LaEr(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 4332, value);
}
// Watch.LastSeen.WithinAMonth
NSString * _Nonnull _LaEs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4333);
}
// Watch.LastSeen.WithinAWeek
NSString * _Nonnull _LaEt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4334);
}
// Watch.LastSeen.YesterdayAt
_FormattedString * _Nonnull _LaEu(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4335, _0);
}
// Watch.Location.Access
NSString * _Nonnull _LaEv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4336);
}
// Watch.Location.Current
NSString * _Nonnull _LaEw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4337);
}
// Watch.Message.Call
NSString * _Nonnull _LaEx(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4338);
}
// Watch.Message.ForwardedFrom
NSString * _Nonnull _LaEy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4339);
}
// Watch.Message.Game
NSString * _Nonnull _LaEz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4340);
}
// Watch.Message.Invoice
NSString * _Nonnull _LaEA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4341);
}
// Watch.Message.Poll
NSString * _Nonnull _LaEB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4342);
}
// Watch.Message.Unsupported
NSString * _Nonnull _LaEC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4343);
}
// Watch.MessageView.Forward
NSString * _Nonnull _LaED(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4344);
}
// Watch.MessageView.Reply
NSString * _Nonnull _LaEE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4345);
}
// Watch.MessageView.Title
NSString * _Nonnull _LaEF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4346);
}
// Watch.MessageView.ViewOnPhone
NSString * _Nonnull _LaEG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4347);
}
// Watch.Microphone.Access
NSString * _Nonnull _LaEH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4348);
}
// Watch.NoConnection
NSString * _Nonnull _LaEI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4349);
}
// Watch.Notification.Joined
NSString * _Nonnull _LaEJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4350);
}
// Watch.PhotoView.Title
NSString * _Nonnull _LaEK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4351);
}
// Watch.Stickers.RecentPlaceholder
NSString * _Nonnull _LaEL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4352);
}
// Watch.Stickers.Recents
NSString * _Nonnull _LaEM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4353);
}
// Watch.Stickers.StickerPacks
NSString * _Nonnull _LaEN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4354);
}
// Watch.Suggestion.BRB
NSString * _Nonnull _LaEO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4355);
}
// Watch.Suggestion.CantTalk
NSString * _Nonnull _LaEP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4356);
}
// Watch.Suggestion.HoldOn
NSString * _Nonnull _LaEQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4357);
}
// Watch.Suggestion.OK
NSString * _Nonnull _LaER(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4358);
}
// Watch.Suggestion.OnMyWay
NSString * _Nonnull _LaES(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4359);
}
// Watch.Suggestion.TalkLater
NSString * _Nonnull _LaET(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4360);
}
// Watch.Suggestion.Thanks
NSString * _Nonnull _LaEU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4361);
}
// Watch.Suggestion.WhatsUp
NSString * _Nonnull _LaEV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4362);
}
// Watch.Time.ShortFullAt
_FormattedString * _Nonnull _LaEW(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 4363, _0, _1);
}
// Watch.Time.ShortTodayAt
_FormattedString * _Nonnull _LaEX(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4364, _0);
}
// Watch.Time.ShortWeekdayAt
_FormattedString * _Nonnull _LaEY(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0, NSString * _Nonnull _1) {
    return getFormatted2(_self, 4365, _0, _1);
}
// Watch.Time.ShortYesterdayAt
_FormattedString * _Nonnull _LaEZ(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4366, _0);
}
// Watch.UserInfo.Block
NSString * _Nonnull _LaFa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4367);
}
// Watch.UserInfo.Mute
NSString * _Nonnull _LaFb(_PresentationStrings * _Nonnull _self, int32_t value) {
    return getPluralizedIndirect(_self, 4368, value);
}
// Watch.UserInfo.MuteTitle
NSString * _Nonnull _LaFc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4369);
}
// Watch.UserInfo.Service
NSString * _Nonnull _LaFd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4370);
}
// Watch.UserInfo.Title
NSString * _Nonnull _LaFe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4371);
}
// Watch.UserInfo.Unblock
NSString * _Nonnull _LaFf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4372);
}
// Watch.UserInfo.Unmute
NSString * _Nonnull _LaFg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4373);
}
// WatchRemote.AlertOpen
NSString * _Nonnull _LaFh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4374);
}
// WatchRemote.AlertText
NSString * _Nonnull _LaFi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4375);
}
// WatchRemote.AlertTitle
NSString * _Nonnull _LaFj(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4376);
}
// WatchRemote.NotificationText
NSString * _Nonnull _LaFk(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4377);
}
// Web.Error
NSString * _Nonnull _LaFl(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4378);
}
// Web.OpenExternal
NSString * _Nonnull _LaFm(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4379);
}
// WebBrowser.DefaultBrowser
NSString * _Nonnull _LaFn(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4380);
}
// WebBrowser.InAppSafari
NSString * _Nonnull _LaFo(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4381);
}
// WebBrowser.Title
NSString * _Nonnull _LaFp(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4382);
}
// WebPreview.GettingLinkInfo
NSString * _Nonnull _LaFq(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4383);
}
// WebSearch.GIFs
NSString * _Nonnull _LaFr(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4384);
}
// WebSearch.Images
NSString * _Nonnull _LaFs(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4385);
}
// WebSearch.RecentClearConfirmation
NSString * _Nonnull _LaFt(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4386);
}
// WebSearch.RecentSectionClear
NSString * _Nonnull _LaFu(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4387);
}
// WebSearch.RecentSectionTitle
NSString * _Nonnull _LaFv(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4388);
}
// WebSearch.SearchNoResults
NSString * _Nonnull _LaFw(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4389);
}
// WebSearch.SearchNoResultsDescription
_FormattedString * _Nonnull _LaFx(_PresentationStrings * _Nonnull _self, NSString * _Nonnull _0) {
    return getFormatted1(_self, 4390, _0);
}
// Weekday.Friday
NSString * _Nonnull _LaFy(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4391);
}
// Weekday.Monday
NSString * _Nonnull _LaFz(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4392);
}
// Weekday.Saturday
NSString * _Nonnull _LaFA(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4393);
}
// Weekday.ShortFriday
NSString * _Nonnull _LaFB(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4394);
}
// Weekday.ShortMonday
NSString * _Nonnull _LaFC(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4395);
}
// Weekday.ShortSaturday
NSString * _Nonnull _LaFD(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4396);
}
// Weekday.ShortSunday
NSString * _Nonnull _LaFE(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4397);
}
// Weekday.ShortThursday
NSString * _Nonnull _LaFF(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4398);
}
// Weekday.ShortTuesday
NSString * _Nonnull _LaFG(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4399);
}
// Weekday.ShortWednesday
NSString * _Nonnull _LaFH(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4400);
}
// Weekday.Sunday
NSString * _Nonnull _LaFI(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4401);
}
// Weekday.Thursday
NSString * _Nonnull _LaFJ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4402);
}
// Weekday.Today
NSString * _Nonnull _LaFK(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4403);
}
// Weekday.Tuesday
NSString * _Nonnull _LaFL(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4404);
}
// Weekday.Wednesday
NSString * _Nonnull _LaFM(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4405);
}
// Weekday.Yesterday
NSString * _Nonnull _LaFN(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4406);
}
// Widget.ApplicationLocked
NSString * _Nonnull _LaFO(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4407);
}
// Widget.ApplicationStartRequired
NSString * _Nonnull _LaFP(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4408);
}
// Widget.AuthRequired
NSString * _Nonnull _LaFQ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4409);
}
// Widget.ChatsGalleryDescription
NSString * _Nonnull _LaFR(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4410);
}
// Widget.ChatsGalleryTitle
NSString * _Nonnull _LaFS(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4411);
}
// Widget.GalleryDescription
NSString * _Nonnull _LaFT(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4412);
}
// Widget.GalleryTitle
NSString * _Nonnull _LaFU(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4413);
}
// Widget.LongTapToEdit
NSString * _Nonnull _LaFV(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4414);
}
// Widget.MessageAutoremoveTimerRemoved
NSString * _Nonnull _LaFW(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4415);
}
// Widget.MessageAutoremoveTimerUpdated
NSString * _Nonnull _LaFX(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4416);
}
// Widget.NoUsers
NSString * _Nonnull _LaFY(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4417);
}
// Widget.ShortcutsGalleryDescription
NSString * _Nonnull _LaFZ(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4418);
}
// Widget.ShortcutsGalleryTitle
NSString * _Nonnull _LaGa(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4419);
}
// Widget.UpdatedAt
NSString * _Nonnull _LaGb(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4420);
}
// Widget.UpdatedTodayAt
NSString * _Nonnull _LaGc(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4421);
}
// Your_card_has_expired
NSString * _Nonnull _LaGd(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4422);
}
// Your_card_was_declined
NSString * _Nonnull _LaGe(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4423);
}
// Your_cards_expiration_month_is_invalid
NSString * _Nonnull _LaGf(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4424);
}
// Your_cards_expiration_year_is_invalid
NSString * _Nonnull _LaGg(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4425);
}
// Your_cards_number_is_invalid
NSString * _Nonnull _LaGh(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4426);
}
// Your_cards_security_code_is_invalid
NSString * _Nonnull _LaGi(_PresentationStrings * _Nonnull _self) {
    return getSingleIndirect(_self, 4427);
}
