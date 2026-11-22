#import "TGBridgeBotReplyMarkup.h"

NSString *const TGBridgeBotReplyMarkupButtonText = @"text";

@implementation TGBridgeBotReplyMarkupButton

- (instancetype)initWithText:(NSString *)text
{
    self = [super init];
    if (self != nil)
    {
        _text = text;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _text = [aDecoder decodeObjectForKey:TGBridgeBotReplyMarkupButtonText];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.text forKey:TGBridgeBotReplyMarkupButtonText];
}

@end


NSString *const TGBridgeBotReplyMarkupRowButtons = @"buttons";

@implementation  TGBridgeBotReplyMarkupRow

- (instancetype)initWithButtons:(NSArray *)buttons
{
    self = [super init];
    if (self != nil)
    {
        _buttons = buttons;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _buttons = [aDecoder decodeObjectForKey:TGBridgeBotReplyMarkupRowButtons];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.buttons forKey:TGBridgeBotReplyMarkupRowButtons];
}

@end


NSString *const TGBridgeBotReplyMarkupUserId = @"userId";
NSString *const TGBridgeBotReplyMarkupMessageId = @"messageId";
NSString *const TGBridgeBotReplyMarkupMessage = @"message";
NSString *const TGBridgeBotReplyMarkupHideKeyboardOnActivation = @"hideKeyboardOnActivation";
NSString *const TGBridgeBotReplyMarkupAlreadyActivated = @"alreadyActivated";
NSString *const TGBridgeBotReplyMarkupRows = @"rows";

@implementation TGBridgeBotReplyMarkup

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _userId = [aDecoder decodeInt32ForKey:TGBridgeBotReplyMarkupUserId];
        _messageId = [aDecoder decodeInt32ForKey:TGBridgeBotReplyMarkupMessageId];
        _message = [aDecoder decodeObjectForKey:TGBridgeBotReplyMarkupMessage];
        _hideKeyboardOnActivation = [aDecoder decodeBoolForKey:TGBridgeBotReplyMarkupHideKeyboardOnActivation];
        _alreadyActivated = [aDecoder decodeBoolForKey:TGBridgeBotReplyMarkupAlreadyActivated];
        _rows = [aDecoder decodeObjectForKey:TGBridgeBotReplyMarkupRows];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt32:self.userId forKey:TGBridgeBotReplyMarkupUserId];
    [aCoder encodeInt32:self.messageId forKey:TGBridgeBotReplyMarkupMessageId];
    [aCoder encodeObject:self.message forKey:TGBridgeBotReplyMarkupMessage];
    [aCoder encodeBool:self.hideKeyboardOnActivation forKey:TGBridgeBotReplyMarkupHideKeyboardOnActivation];
    [aCoder encodeBool:self.alreadyActivated forKey:TGBridgeBotReplyMarkupAlreadyActivated];
    [aCoder encodeObject:self.rows forKey:TGBridgeBotReplyMarkupRows];
}

@end
