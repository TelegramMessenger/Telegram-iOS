#import <LegacyDataImportImpl/TGPresentationAutoNightPreferences.h>

@implementation TGPresentationAutoNightPreferences

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _mode = [aDecoder decodeInt32ForKey:@"m"];
        _brightnessThreshold = [aDecoder decodeDoubleForKey:@"b"];
        _scheduleStart = [aDecoder decodeInt32ForKey:@"ss"];
        _scheduleEnd = [aDecoder decodeInt32ForKey:@"se"];
        _latitude = [aDecoder decodeDoubleForKey:@"lat"];
        _longitude = [aDecoder decodeDoubleForKey:@"lon"];
        _cachedLocationName = [aDecoder decodeObjectForKey:@"loc"];
        _preferredPalette = [aDecoder decodeInt32ForKey:@"p"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
}

@end
