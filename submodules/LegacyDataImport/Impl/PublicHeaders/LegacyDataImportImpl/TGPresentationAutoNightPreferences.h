#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum
{
    TGPresentationAutoNightModeDisabled,
    TGPresentationAutoNightModeBrightness,
    TGPresentationAutoNightModeScheduled,
    TGPresentationAutoNightModeSunsetSunrise
} TGPresentationAutoNightMode;

@interface TGPresentationAutoNightPreferences : NSObject <NSCoding>

@property (nonatomic, readonly) TGPresentationAutoNightMode mode;

@property (nonatomic, readonly) CGFloat brightnessThreshold;

@property (nonatomic, readonly) int32_t scheduleStart;
@property (nonatomic, readonly) int32_t scheduleEnd;

@property (nonatomic, readonly) CGFloat latitude;
@property (nonatomic, readonly) CGFloat longitude;
@property (nonatomic, readonly) NSString *cachedLocationName;

@property (nonatomic, readonly) int32_t preferredPalette;

@end

NS_ASSUME_NONNULL_END
