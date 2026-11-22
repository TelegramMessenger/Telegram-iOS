#import "TGInputController.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"
#import "TGInterfaceController.h"

#import "TGFileCache.h"
#import "TGExtensionDelegate.h"
#import "TGBridgePresetsSignals.h"

@implementation TGInputController

+ (void)presentPlainInputControllerForInterfaceController:(TGInterfaceController *)interfaceController completion:(void (^)(NSString *))completion;
{
    [interfaceController presentTextInputControllerWithSuggestions:nil allowedInputMode:WKTextInputModePlain completion:^(NSArray *results)
    {
        if (completion != nil && results.count > 0 && [results.firstObject isKindOfClass:[NSString class]])
            completion(results.firstObject);
    }];
}

+ (void)presentInputControllerForInterfaceController:(TGInterfaceController *)interfaceController suggestionsForText:(NSString *)text completion:(void (^)(NSString *))completion
{
    [interfaceController presentTextInputControllerWithSuggestions:[self suggestionsForText:text] allowedInputMode:WKTextInputModeAllowEmoji completion:^(NSArray *results)
    {
        if (completion != nil && results.count > 0 && [results.firstObject isKindOfClass:[NSString class]])
            completion(results.firstObject);
    }];
}

+ (void)presentAudioControllerForInterfaceController:(TGInterfaceController *)interfaceController completion:(void (^)(int64_t, int32_t, NSURL *))completion
{
    NSDictionary *options = @
    {
        WKAudioRecorderControllerOptionsActionTitleKey: TGLocalized(@"Watch.Compose.Send"),
    };
    
    int64_t randomId = 0;
    arc4random_buf(&randomId, sizeof(int64_t));
    
    NSURL *url = [[TGExtensionDelegate instance].audioCache urlForKey:[NSString stringWithFormat:@"%lld", randomId]];
    [interfaceController presentAudioRecorderControllerWithOutputURL:url preset:WKAudioRecorderPresetWideBandSpeech options:options completion:^(BOOL didSave, NSError * _Nullable error)
    {
        WKAudioFileAsset *asset = [WKAudioFileAsset assetWithURL:url];
        
        if (didSave && !error)
            completion(randomId, (int32_t)asset.duration, url);
    }];
}

+ (NSArray *)suggestionsForText:(NSString *)text
{
    return [self customSuggestions];
}

+ (NSArray *)customSuggestions
{
    NSArray *presetIdentifiers = [self presetIdentifiers];
    
    NSMutableArray *suggestions = [[NSMutableArray alloc] init];
    NSDictionary *customPresets = [self customPresets];
    for (NSString *identifier in presetIdentifiers)
    {
        NSString *preset = customPresets[identifier];
        if (preset == nil)
            preset = TGLocalized([NSString stringWithFormat:@"Watch.Suggestion.%@", identifier]);
        
        [suggestions addObject:preset];
    }
    
    return suggestions;
}

+ (NSDictionary *)customPresets
{
    NSData *data = [NSData dataWithContentsOfURL:[TGBridgePresetsSignals presetsURL]];
    
    @try
    {
        id presets = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        if ([presets isKindOfClass:[NSDictionary class]])
            return presets;
        
        return nil;
    }
    @catch (NSException *exception)
    {
        return nil;
    }
}

+ (NSArray *)presetIdentifiers
{
    return @
    [
     @"OK",
     @"Thanks",
     @"WhatsUp",
     @"TalkLater",
     @"CantTalk",
     @"HoldOn",
     @"BRB",
     @"OnMyWay"
    ];
}

+ (NSArray *)composeSuggestions
{
    static NSArray *suggestions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        suggestions = @
        [
         TGLocalized(@"Watch.Suggestion.WhatsUp"),
         TGLocalized(@"Watch.Suggestion.OnMyWay"),
         TGLocalized(@"Watch.Suggestion.OK"),
         TGLocalized(@"Watch.Suggestion.CantTalk"),
         TGLocalized(@"Watch.Suggestion.CallSoon"),
         TGLocalized(@"Watch.Suggestion.Thanks")
        ];
    });
    return suggestions;
}

+ (NSArray *)generalSuggestions
{
    static NSArray *suggestions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        suggestions = @
        [
         TGLocalized(@"Watch.Suggestion.OK"),
         TGLocalized(@"Watch.Suggestion.Thanks"),
         TGLocalized(@"Watch.Suggestion.WhatsUp")
        ];
    });
    return suggestions;
}

+ (NSArray *)yesNoSuggestions
{
    static NSArray *suggestions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        suggestions = @
        [
         TGLocalized(@"Watch.Suggestion.Yes"),
         TGLocalized(@"Watch.Suggestion.No"),
         TGLocalized(@"Watch.Suggestion.Absolutely"),
         TGLocalized(@"Watch.Suggestion.Nope")
        ];
    });
    return suggestions;
}

+ (NSArray *)laterSuggestions
{
    static NSArray *suggestions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        suggestions = @
        [
         TGLocalized(@"Watch.Suggestion.TalkLater"),
         TGLocalized(@"Watch.Suggestion.CantTalk"),
         TGLocalized(@"Watch.Suggestion.HoldOn"),
         TGLocalized(@"Watch.Suggestion.BRB"),
         TGLocalized(@"Watch.Suggestion.OnMyWay")
        ];
    });
    return suggestions;
}

@end
