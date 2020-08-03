#import "TGCameraInterfaceAssets.h"
#import <CoreText/CoreText.h>

#import "LegacyComponentsInternal.h"

@implementation TGCameraInterfaceAssets

+ (UIColor *)normalColor
{
    return [UIColor whiteColor];
}

+ (UIColor *)accentColor
{
    return UIColorRGB(0xf8d74a);
}

+ (UIColor *)redColor
{
    return UIColorRGB(0xea4e3d);
}

+ (UIColor *)panelBackgroundColor
{
    return [UIColor blackColor];
}

+ (UIColor *)transparentPanelBackgroundColor
{
    return [UIColor colorWithWhite:0.0f alpha:0.5];
}

+ (UIColor *)transparentOverlayBackgroundColor
{
    return [UIColor colorWithWhite:0.0f alpha:0.7];
}

+ (UIFont *)regularFontOfSize:(CGFloat)size
{
    if (@available(iOSApplicationExtension 13.0, iOS 13.0, *)) {
        UIFontDescriptor *descriptor = [UIFont systemFontOfSize:size].fontDescriptor;
        descriptor = [descriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitCondensed];
        
        NSMutableArray *features = [[NSMutableArray alloc] init];
        [features addObject:@{
            UIFontFeatureTypeIdentifierKey     : @(kStylisticAlternativesType),
            UIFontFeatureSelectorIdentifierKey : @(kStylisticAltThreeOnSelector)
        }];
        [features addObject:@{
            UIFontFeatureTypeIdentifierKey     : @(kNumberSpacingType),
            UIFontFeatureSelectorIdentifierKey : @(kMonospacedNumbersSelector)
        }];
        
        NSMutableDictionary *traits = [[NSMutableDictionary alloc] init];
        traits[UIFontWidthTrait] = @(UIFontWeightMedium);
        
        descriptor = [descriptor fontDescriptorByAddingAttributes:@{ UIFontDescriptorFeatureSettingsAttribute: features}];
                
        return [UIFont fontWithDescriptor:descriptor size:size];
    } else {
        return [UIFont fontWithName:@"DINAlternate-Bold" size:size];
    }
}

+ (UIFont *)boldFontOfSize:(CGFloat)size
{
    if (@available(iOSApplicationExtension 13.0, iOS 13.0, *)) {
        UIFontDescriptor *descriptor = [UIFont systemFontOfSize:size weight:UIFontWeightSemibold].fontDescriptor;
        descriptor = [descriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitCondensed];
        
        NSMutableArray *features = [[NSMutableArray alloc] init];
        [features addObject:@{
            UIFontFeatureTypeIdentifierKey     : @(kStylisticAlternativesType),
            UIFontFeatureSelectorIdentifierKey : @(kStylisticAltThreeOnSelector)
        }];
        [features addObject:@{
            UIFontFeatureTypeIdentifierKey     : @(kNumberSpacingType),
            UIFontFeatureSelectorIdentifierKey : @(kMonospacedNumbersSelector)
        }];
                
        descriptor = [descriptor fontDescriptorByAddingAttributes:@{ UIFontDescriptorFeatureSettingsAttribute: features}];
        return [UIFont fontWithDescriptor:descriptor size:size];
    } else {
        return [UIFont fontWithName:@"DINAlternate-Bold" size:size];
    }
}

@end
