#import <Foundation/Foundation.h>

#import <LegacyComponents/PSCoding.h>

#import <LegacyComponents/TGBotReplyMarkupRow.h>

@interface TGBotReplyMarkup : NSObject <NSCoding, PSCoding>

@property (nonatomic, readonly) int32_t userId;
@property (nonatomic, readonly) int32_t messageId;
@property (nonatomic, strong, readonly) NSArray *rows;
@property (nonatomic) bool matchDefaultHeight;
@property (nonatomic) bool hideKeyboardOnActivation;
@property (nonatomic) bool alreadyActivated;
@property (nonatomic) bool manuallyHidden;
@property (nonatomic) bool isInline;

- (instancetype)initWithUserId:(int32_t)userId messageId:(int32_t)messageId rows:(NSArray *)rows matchDefaultHeight:(bool)matchDefaultHeight hideKeyboardOnActivation:(bool)hideKeyboardOnActivation alreadyActivated:(bool)alreadyActivated manuallyHidden:(bool)manuallyHidden isInline:(bool)isInline;

- (TGBotReplyMarkup *)activatedMarkup;
- (TGBotReplyMarkup *)manuallyHide;
- (TGBotReplyMarkup *)manuallyUnhide;

@end
