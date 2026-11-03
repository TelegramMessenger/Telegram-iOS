#import <Foundation/Foundation.h>

#import <LegacyComponents/PSCoding.h>

@interface TGBotReplyMarkupButtonActionUrl : NSObject <PSCoding, NSCoding>

@property (nonatomic, strong, readonly) NSString *url;

- (instancetype)initWithUrl:(NSString *)url;

@end

@interface TGBotReplyMarkupButtonActionCallback : NSObject <PSCoding, NSCoding>

@property (nonatomic, strong, readonly) NSData *data;

- (instancetype)initWithData:(NSData *)data;

@end

@interface TGBotReplyMarkupButtonActionRequestPhone : NSObject <PSCoding, NSCoding>

@end

@interface TGBotReplyMarkupButtonActionRequestLocation : NSObject <PSCoding, NSCoding>

@end

@interface TGBotReplyMarkupButtonActionSwitchInline : NSObject <PSCoding, NSCoding>

@property (nonatomic, strong, readonly) NSString *query;
@property (nonatomic, readonly) bool samePeer;

- (instancetype)initWithQuery:(NSString *)query samePeer:(bool)samePeer;

@end

@interface TGBotReplyMarkupButtonActionGame : NSObject <PSCoding, NSCoding>

@property (nonatomic, strong, readonly) NSString *text;

- (instancetype)initWithText:(NSString *)text;

@end

@interface TGBotReplyMarkupButtonActionPurchase : NSObject <PSCoding, NSCoding>

@property (nonatomic, strong, readonly) NSString *text;

- (instancetype)initWithText:(NSString *)text;

@end

@interface TGBotReplyMarkupButton : NSObject <PSCoding, NSCoding>

@property (nonatomic, strong, readonly) NSString *text;
@property (nonatomic, strong, readonly) id<PSCoding, NSCoding> action;

- (instancetype)initWithText:(NSString *)text action:(id<PSCoding, NSCoding>)action;

@end
