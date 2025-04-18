#import "TGComplicationController.h"
#import "TGWatchCommon.h"
#import "TGStringUtils.h"

@implementation TGComplicationController

- (void)getSupportedTimeTravelDirectionsForComplication:(CLKComplication *)complication withHandler:(void (^)(CLKComplicationTimeTravelDirections))handler
{
    handler(CLKComplicationTimeTravelDirectionNone);
}

- (void)getPrivacyBehaviorForComplication:(CLKComplication *)complication withHandler:(void (^)(CLKComplicationPrivacyBehavior))handler
{
    handler(CLKComplicationPrivacyBehaviorShowOnLockScreen);
}

- (void)getPlaceholderTemplateForComplication:(CLKComplication *)complication withHandler:(void (^)(CLKComplicationTemplate * _Nullable))handler
{
    CLKComplicationTemplate *result = nil;
    
    switch (complication.family)
    {
        case CLKComplicationFamilyModularLarge:
        {
            
        }
            break;
            
        case CLKComplicationFamilyUtilitarianSmall:
        {
            
        }
            break;
            
        case CLKComplicationFamilyUtilitarianLarge:
        {
            CLKComplicationTemplateUtilitarianLargeFlat *template = [[CLKComplicationTemplateUtilitarianLargeFlat alloc] init];
            
            CLKSimpleTextProvider *textProvider = [[CLKSimpleTextProvider alloc] init];
            textProvider.text = TGLocalized(@"Complication.LongNone");
            template.textProvider = textProvider;
            result = template;
        }
            break;
            
        default:
            break;
    }
    
    handler(result);
}

- (void)getCurrentTimelineEntryForComplication:(CLKComplication *)complication withHandler:(void (^)(CLKComplicationTimelineEntry * _Nullable))handler
{
    CLKComplicationTemplate *result = nil;
    
    switch (complication.family)
    {
        case CLKComplicationFamilyUtilitarianLarge:
        {
            CLKComplicationTemplateUtilitarianLargeFlat *template = [[CLKComplicationTemplateUtilitarianLargeFlat alloc] init];
            
            CLKSimpleTextProvider *textProvider = [[CLKSimpleTextProvider alloc] init];
            textProvider.text = TGLocalized(@"Complication.LongNone");
            template.textProvider = textProvider;
            result = template;
        }
            break;
            
        default:
            break;
    }
    
    CLKComplicationTimelineEntry *entry = [CLKComplicationTimelineEntry entryWithDate:[NSDate date] complicationTemplate:result];
    handler(entry);
}

@end
