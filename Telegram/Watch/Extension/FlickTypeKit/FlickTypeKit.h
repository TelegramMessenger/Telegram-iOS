//
//  FlickTypeKit.h
//  FlickTypeKit
//
//  Created by Kosta Eleftheriou on 5/3/21.
//  Copyright © 2021 Kpaw. All rights reserved.
//

#import <WatchKit/WatchKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FlickTypeMode) {
    FlickTypeModeAsk,
    FlickTypeModeAlways,
    FlickTypeModeOff
};

typedef NS_ENUM(NSInteger, FlickTypeCompletionType) {
    FlickTypeCompletionTypeDismiss,
    FlickTypeCompletionTypeAction,
};

@interface FlickType : NSObject

@property (class, readonly) NSString* sdkVersion;

// eg "https://your.app.domain/flicktype"
@property (class) NSURL* returnURL;

// Returns true if `userActivity` was a FlickType response activity
+ (BOOL)handle:(NSUserActivity*)userActivity;

@end

@interface WKInterfaceController (FlickType)

// Suggestion list, with `flickType` argument
- (void)presentTextInputControllerWithSuggestions:(nullable NSArray<NSString*> *)suggestions allowedInputMode:(WKTextInputMode)inputMode flickType:(FlickTypeMode)flickTypeMode completion:(void(^)(NSArray * __nullable results))completion;

// Suggestion list, with `flickType` and `startingText` arguments
- (void)presentTextInputControllerWithSuggestions:(nullable NSArray<NSString*> *)suggestions allowedInputMode:(WKTextInputMode)inputMode flickType:(FlickTypeMode)flickTypeMode startingText:(NSString *)startingText completion:(void(^)(NSArray * __nullable results))completion;

// Suggestion handler, with `flickType` argument
- (void)presentTextInputControllerWithSuggestionsForLanguage:(NSArray * __nullable (^ __nullable)(NSString *inputLanguage))suggestionsHandler allowedInputMode:(WKTextInputMode)inputMode flickType:(FlickTypeMode)flickTypeMode completion:(void(^)(NSArray * __nullable results))completion;

// Suggestion handler, with `flickType` and `startingText` arguments
- (void)presentTextInputControllerWithSuggestionsForLanguage:(NSArray * __nullable (^ __nullable)(NSString *inputLanguage))suggestionsHandler allowedInputMode:(WKTextInputMode)inputMode flickType:(FlickTypeMode)flickTypeMode startingText:(NSString *)startingText completion:(void(^)(NSArray * __nullable results))completion;

@end

NS_ASSUME_NONNULL_END
