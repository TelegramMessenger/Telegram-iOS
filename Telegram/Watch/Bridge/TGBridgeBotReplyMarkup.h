#import <Foundation/Foundation.h>

@class TGBridgeMessage;

@interface TGBridgeBotReplyMarkupButton : NSObject <NSCoding>
{
    NSString *_text;
}

@property (nonatomic, readonly) NSString *text;

- (instancetype)initWithText:(NSString *)text;

@end


@interface TGBridgeBotReplyMarkupRow : NSObject <NSCoding>
{
    NSArray *_buttons;
}

@property (nonatomic, readonly) NSArray *buttons;

- (instancetype)initWithButtons:(NSArray *)buttons;

@end


@interface TGBridgeBotReplyMarkup : NSObject <NSCoding>
{
    int32_t _userId;
    int32_t _messageId;
    TGBridgeMessage *_message;
    bool _hideKeyboardOnActivation;
    bool _alreadyActivated;
    NSArray *_rows;
}

@property (nonatomic, readonly) int32_t userId;
@property (nonatomic, readonly) int32_t messageId;
@property (nonatomic, readonly) TGBridgeMessage *message;
@property (nonatomic, readonly) bool hideKeyboardOnActivation;
@property (nonatomic, readonly) bool alreadyActivated;
@property (nonatomic, readonly) NSArray *rows;

@end
