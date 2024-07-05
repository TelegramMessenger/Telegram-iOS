//
//  FlickTypeKit.m
//  FlickTypeKit
//
//  Created by Kosta Eleftheriou on 5/3/21.
//  Copyright © 2021 Kpaw. All rights reserved.
//

#import "FlickTypeKit.h"
#import <objc/runtime.h>

typedef void (^CompletionBlock)(NSArray * __nullable results);
typedef NSArray * __nullable (^SuggestionsBlock)(NSString *inputLanguage);

struct TextInputInvocation {
    NSArray<NSString*> * suggestions;
    SuggestionsBlock suggestionsHandler;
    WKTextInputMode inputMode;
    FlickTypeMode flickTypeMode;
    NSDictionary* flickTypeProperties;
    NSString* startingText;
    CompletionBlock completion;
};

typedef void (^InvocationCompletionHandler)(NSString*, FlickTypeCompletionType);

static InvocationCompletionHandler completionHandler(struct TextInputInvocation invocation) {
    return ^void(NSString* result, FlickTypeCompletionType completionType) { invocation.completion(@[result, @(completionType)]); };
}

@interface WKInterfaceController (FlickType_Private)
- (void)alert:(NSString*)message;
- (void)handlePresentTextInput:(struct TextInputInvocation)invocation;
- (void)presentSystemInputController:(struct TextInputInvocation)invocation;
- (void)presentFlickTypeOrIntermediateController:(struct TextInputInvocation)invocation;
@end

// These are to ensure we can call the original methods of the `WKInterfaceController` class when needed
@interface WKInterfaceController (Original_Methods)
- (void)presentWKTextInputControllerWithSuggestions:(NSArray *)suggestions allowedInputMode:(WKTextInputMode)inputMode completion:(CompletionBlock)completion;
- (void)presentWKTextInputControllerWithSuggestionsForLanguage:(SuggestionsBlock)suggestionsHandler allowedInputMode:(WKTextInputMode)inputMode completion:(CompletionBlock)completion;
@end

@implementation WKInterfaceController (FlickType)

// Wrapper for default `startingText` value
- (void)presentTextInputControllerWithSuggestions:(nullable NSArray<NSString*> *)suggestions allowedInputMode:(WKTextInputMode)inputMode flickType:(FlickTypeMode)flickTypeMode  completion:(CompletionBlock)completion {
    [self presentTextInputControllerWithSuggestions:suggestions allowedInputMode:inputMode flickType:flickTypeMode startingText:@"" completion:completion];
}

- (void)presentTextInputControllerWithSuggestions:(nullable NSArray<NSString*> *)suggestions allowedInputMode:(WKTextInputMode)inputMode flickType:(FlickTypeMode)flickTypeMode startingText:(NSString *)startingText completion:(CompletionBlock)completion {
    
    // This source version of FlickTypeKit only supports watchOS 7 or later
    if (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion < 7) {
        return [self presentWKTextInputControllerWithSuggestions:suggestions allowedInputMode:inputMode completion:completion];
    }
    
    assert([NSThread isMainThread]);
    struct TextInputInvocation invocation = {
        .suggestions = suggestions,
        .suggestionsHandler = nil,
        .inputMode = inputMode,
        .flickTypeMode = flickTypeMode,
        .flickTypeProperties = @{}, // TODO: currently not implemented in Objective-C version
        .startingText = startingText,
        .completion = completion
    };
    [self handlePresentTextInput:invocation];
}

// Wrapper for default `startingText` value
- (void)presentTextInputControllerWithSuggestionsForLanguage:(SuggestionsBlock)suggestionsHandler allowedInputMode:(WKTextInputMode)inputMode flickType:(FlickTypeMode)flickTypeMode completion:(CompletionBlock)completion {
    [self presentTextInputControllerWithSuggestionsForLanguage:suggestionsHandler allowedInputMode:inputMode flickType:flickTypeMode startingText:@"" completion:completion];
}

- (void)presentTextInputControllerWithSuggestionsForLanguage:(SuggestionsBlock)suggestionsHandler allowedInputMode:(WKTextInputMode)inputMode flickType:(FlickTypeMode)flickTypeMode startingText:(NSString *)startingText completion:(CompletionBlock)completion {
    
    // This source version of FlickTypeKit only supports watchOS 7 or later
    if (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion < 7) {
        return [self presentWKTextInputControllerWithSuggestionsForLanguage:suggestionsHandler allowedInputMode:inputMode completion:completion];
    }
    
    assert([NSThread isMainThread]);
    struct TextInputInvocation invocation = {
        .suggestions = nil,
        .suggestionsHandler = suggestionsHandler,
        .inputMode = inputMode,
        .flickTypeMode = flickTypeMode,
        .flickTypeProperties = @{},
        .startingText = startingText,
        .completion = completion
    };
    [self handlePresentTextInput:invocation];
}

@end

struct ReturnHandler {
    NSString* token;
    InvocationCompletionHandler completion;
};

@interface FlickType (Private)

@property (class, readonly) NSString* typeURL;
@property (class) struct ReturnHandler returnHandler;
@property (class) BOOL hasSwitchedFromFlickType;

@end

@implementation WKInterfaceController (FlickType_Private)

- (void)handlePresentTextInput:(struct TextInputInvocation)invocation {
    // You can only edit existing text with FlickType.
    BOOL existingText = [invocation.startingText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length > 0;
    FlickTypeMode flickTypeMode = existingText ? FlickTypeModeAlways : invocation.flickTypeMode;
  
    // Don't force FlickType if the app is not known to be installed on the device
    if (flickTypeMode == FlickTypeModeAlways && !FlickType.hasSwitchedFromFlickType) {
        flickTypeMode = FlickTypeModeAsk;
    }
    
    switch (flickTypeMode) {
        case FlickTypeModeAsk:    [self presentSystemInputController:invocation]; break;
        case FlickTypeModeAlways: [self presentFlickTypeOrIntermediateController:invocation]; break;
        case FlickTypeModeOff:    [self presentSystemInputController:invocation]; break;
    }
}

- (void)presentSystemInputController:(struct TextInputInvocation)invocation {
  
    NSString* flickTypeText = @"⌨︎\tFlickType\n\tKeyboard";
  
    void (^completionWrapper)(NSArray*) = ^void(NSArray* textInputControllerReturnedItems) {
        if ([textInputControllerReturnedItems.firstObject isEqualToString:flickTypeText]) {
            return [self presentFlickTypeOrIntermediateController:invocation];
        }
        invocation.completion(textInputControllerReturnedItems);
    };

    // Handle the 4 combinations of (list or handler) x (include flicktype or not)
    if (invocation.suggestionsHandler != nil) {
        SuggestionsBlock wrappedSuggestionsHandler = ^NSArray * __nullable (NSString *inputLanguage){
            return [(invocation.flickTypeMode == FlickTypeModeOff ? @[] : @[flickTypeText]) arrayByAddingObjectsFromArray:invocation.suggestionsHandler(inputLanguage)];
        };
        [self presentWKTextInputControllerWithSuggestionsForLanguage:wrappedSuggestionsHandler allowedInputMode:invocation.inputMode completion:completionWrapper];
    } else {
        NSArray<NSString*>* suggestions = [(invocation.flickTypeMode == FlickTypeModeOff ? @[] : @[flickTypeText]) arrayByAddingObjectsFromArray:invocation.suggestions];
        [self presentWKTextInputControllerWithSuggestions: suggestions allowedInputMode:invocation.inputMode completion:completionWrapper];
    }
}

- (void)alert:(NSString*)message {
    NSLog(@"⚠️ FlickTypeKit: %@", message);
    [self presentAlertControllerWithTitle:@"⚠️\nFlickTypeKit" message:message preferredStyle: WKAlertControllerStyleAlert actions: @[
        [WKAlertAction actionWithTitle:@"OK" style:WKAlertActionStyleDefault handler:^{}],
    ]];
}

- (void)presentFlickTypeOrIntermediateController:(struct TextInputInvocation)invocation {

    if (FlickType.returnURL == nil) { return [self alert:@"FlickType.returnURL is not set"]; }
    if (![FlickType.returnURL.absoluteString hasPrefix:@"https://"]) { return [self alert:@"FlickType.returnURL must start with `https://`"]; }
    
    void (^switchToFlickType)(BOOL) = ^void(BOOL includeStartingText) {
        NSString* token = [NSString stringWithFormat:@"%f", NSDate.timeIntervalSinceReferenceDate];
        struct ReturnHandler returnHandler = { .token = token, .completion = completionHandler(invocation) };
        FlickType.returnHandler = returnHandler;
        NSMutableDictionary* queryItems = [@{
            @"token" : token,
            @"returnURL" : FlickType.returnURL.absoluteString,
            @"startingText" : includeStartingText ? invocation.startingText : @"",
        } mutableCopy];
        [queryItems addEntriesFromDictionary:invocation.flickTypeProperties];
        NSURLComponents* urlComps = [NSURLComponents componentsWithString:FlickType.typeURL];
        NSMutableArray* urlCompsQueryItems = [@[] mutableCopy];
        [queryItems enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull value, BOOL * _Nonnull stop) {
            [urlCompsQueryItems addObject:[NSURLQueryItem queryItemWithName:key value:value]];
        }];
        urlComps.queryItems = urlCompsQueryItems;
        [WKExtension.sharedExtension openSystemURL:urlComps.URL];
    };
    
    if (FlickType.hasSwitchedFromFlickType) {
        switchToFlickType(YES); // YES: includeStartingText
    } else {
        NSURL* flickTypeAppStoreURL = [NSURL URLWithString:@"https://apps.apple.com/us/app/flicktype-keyboard/id1359485719"];
        [self presentAlertControllerWithTitle:@"⌨️" message:@"Download “FlickType Keyboard” from the App Store?" preferredStyle:WKAlertControllerStyleAlert actions:@[
            [WKAlertAction actionWithTitle:@"Download now" style:WKAlertActionStyleDefault handler:^{
                [WKExtension.sharedExtension openSystemURL:flickTypeAppStoreURL];
            }],
            [WKAlertAction actionWithTitle:@"I already have it" style:WKAlertActionStyleDefault handler:^{
                // Redact `startingText` until the first successful app-switch roundtrip, to prevent sensitive content from
                // ever reaching our web server if watchOS implements opening a web browser when our app isn't installed.
                // Regardless, our web server does not keep logs of any kind.
                switchToFlickType(NO); // NO: do not includeStartingText
            }],
        ]];
    }
}

@end

// We use these because `self` might be some `WKInterfaceController` subclass that has overriden
// `presentTextInputControllerWithSuggestions`, which would cause an infinite recursion if called like `[self presentTextInput...];`
@implementation WKInterfaceController (Original_Methods)

- (void)presentWKTextInputControllerWithSuggestions:(NSArray *)suggestions allowedInputMode:(WKTextInputMode)inputMode completion:(CompletionBlock)completion {
    SEL selector = @selector(presentTextInputControllerWithSuggestions:allowedInputMode:completion:);
    IMP imp = class_getMethodImplementation([WKInterfaceController class], selector);
    void (*callableImp)(id, SEL, NSArray<NSString*> *, WKTextInputMode, CompletionBlock) = (typeof(callableImp)) imp;
    callableImp(self, selector, suggestions, inputMode, completion);
}

- (void)presentWKTextInputControllerWithSuggestionsForLanguage:(SuggestionsBlock)suggestionsHandler allowedInputMode:(WKTextInputMode)inputMode completion:(CompletionBlock)completion {
    SEL selector = @selector(presentTextInputControllerWithSuggestionsForLanguage:allowedInputMode:completion:);
    IMP imp = class_getMethodImplementation([WKInterfaceController class], selector);
    void (*callableImp)(id, SEL, SuggestionsBlock, WKTextInputMode, CompletionBlock) = (typeof(callableImp)) imp;
    callableImp(self, selector, suggestionsHandler, inputMode, completion);
}

@end


@implementation FlickType

+ (NSString*)sdkVersion {
    return @"2.0.0/objc";
}

static NSURL* _returnURL = nil;
static struct ReturnHandler _returnHandler;

+ (NSURL*)returnURL {
    return _returnURL;
}

+ (void)setReturnURL:(NSURL*)url {
    _returnURL = url;
}

+ (NSString*)typeURL {
    return @"https://flicktype.com/type/";
}

+ (struct ReturnHandler)returnHandler {
    return _returnHandler;
}

+ (void)setReturnHandler:(struct ReturnHandler)handler {
    _returnHandler = handler;
}

+ (BOOL)hasSwitchedFromFlickType {
    return [NSUserDefaults.standardUserDefaults boolForKey:@"FlickType_HAS_SWITCHED_FROM_MAIN_APP"];
}

+ (void)setHasSwitchedFromFlickType:(BOOL)value {
    [NSUserDefaults.standardUserDefaults setBool:value forKey:@"FlickType_HAS_SWITCHED_FROM_MAIN_APP"];
}

+ (BOOL)handle:(NSUserActivity*)userActivity {
    NSLog(@"FlickTypeKit: handle userActivity %@", userActivity);
    // TODO: main thread check?
    
    void (^alert)(NSString*) = ^void(NSString* message) {
        [WKExtension.sharedExtension.visibleInterfaceController alert:message];
    };
        
    // Get URL components from the incoming user activity
    if (![userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) { return false; }
    NSURL* incomingURL = userActivity.webpageURL;
    if (incomingURL == nil) { return false; }
    NSURLComponents* components = [NSURLComponents componentsWithURL:incomingURL resolvingAgainstBaseURL:YES];
    if (components == nil) { return false; }
    
    if (_returnURL == nil) {
        alert(@"Return URL is not set");
        return false;
    }
    
    if (![incomingURL.absoluteString hasPrefix:_returnURL.absoluteString]) { return false; }
    
    if (_returnHandler.token == nil || _returnHandler.completion == nil) {
        alert(@"Unexpected activity");
        return true;
    }
    
    NSString* expectedToken = _returnHandler.token;
    InvocationCompletionHandler completionHandler = _returnHandler.completion;
    
    if (components.queryItems == nil) {
        alert(@"No query items");
        return true;
    }
    
    NSMutableDictionary<NSString*,NSURLQueryItem*>* params = [@{} mutableCopy];
    for (NSURLQueryItem* queryItem in components.queryItems) {
        params[queryItem.name] = queryItem;
    }

    NSString* token = params[@"token"].value;
    if (token == nil) {
        alert(@"No token param");
        return true;
    }
    
    if (![token isEqualToString:expectedToken]) {
        alert(@"Unexpected token");
        return true;
    }
    
    NSString* text = params[@"text"].value;
    if (text == nil) {
        alert(@"No text param");
        return true;
    }
    
    FlickTypeCompletionType completionType = FlickTypeCompletionTypeAction;
    // App versions < 2020.8 did not supply a completion type on return
    if ([params[@"completion"].value isEqualToString:@"0"]) {
        completionType = FlickTypeCompletionTypeDismiss;
    }
    
    [self setHasSwitchedFromFlickType:YES];
    _returnHandler.token = nil;
    _returnHandler.completion = nil;
    completionHandler(text, completionType);
    
    return true;
}

@end
