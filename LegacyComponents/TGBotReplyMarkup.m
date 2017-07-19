#import "TGBotReplyMarkup.h"

#import "PSKeyValueCoder.h"

@implementation TGBotReplyMarkup

- (instancetype)initWithUserId:(int32_t)userId messageId:(int32_t)messageId rows:(NSArray *)rows matchDefaultHeight:(bool)matchDefaultHeight hideKeyboardOnActivation:(bool)hideKeyboardOnActivation alreadyActivated:(bool)alreadyActivated manuallyHidden:(bool)manuallyHidden isInline:(bool)isInline
{
    self = [super init];
    if (self != nil)
    {
        _userId = userId;
        _messageId = messageId;
        _rows = rows;
        _matchDefaultHeight = matchDefaultHeight;
        _hideKeyboardOnActivation = hideKeyboardOnActivation;
        _alreadyActivated = alreadyActivated;
        _manuallyHidden = manuallyHidden;
        _isInline = isInline;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    return [self initWithUserId:[coder decodeInt32ForCKey:"userId"] messageId:[coder decodeInt32ForCKey:"messageId"] rows:[coder decodeArrayForCKey:"rows"] matchDefaultHeight:[coder decodeInt32ForCKey:"matchDefaultHeight"] hideKeyboardOnActivation:[coder decodeInt32ForCKey:"hideKeyboardOnActivation"] alreadyActivated:[coder decodeInt32ForCKey:"alreadyActivated"] manuallyHidden:[coder decodeInt32ForCKey:"manuallyHidden"] isInline:[coder decodeInt32ForCKey:"isInline"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeInt32:_userId forCKey:"userId"];
    [coder encodeInt32:_messageId forCKey:"messageId"];
    [coder encodeArray:_rows forCKey:"rows"];
    [coder encodeInt32:_matchDefaultHeight forCKey:"matchDefaultHeight"];
    [coder encodeInt32:_hideKeyboardOnActivation forCKey:"hideKeyboardOnActivation"];
    [coder encodeInt32:_alreadyActivated forCKey:"alreadyActivated"];
    [coder encodeInt32:_manuallyHidden forCKey:"manuallyHidden"];
    [coder encodeInt32:_isInline forCKey:"isInline"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithUserId:[aDecoder decodeInt32ForKey:@"userId"] messageId:[aDecoder decodeInt32ForKey:@"messageId"] rows:[aDecoder decodeObjectForKey:@"rows"] matchDefaultHeight:[aDecoder decodeBoolForKey:@"matchDefaultHeight"] hideKeyboardOnActivation:[aDecoder decodeBoolForKey:@"hideKeyboardOnDeactivation"] alreadyActivated:[aDecoder decodeBoolForKey:@"alreadyActivated"] manuallyHidden:[aDecoder decodeBoolForKey:@"manuallyHidden"] isInline:[aDecoder decodeBoolForKey:@"isInline"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt32:_userId forKey:@"userId"];
    [aCoder encodeInt32:_messageId forKey:@"messageId"];
    [aCoder encodeObject:_rows forKey:@"rows"];
    [aCoder encodeBool:_matchDefaultHeight forKey:@"matchDefaultHeight"];
    [aCoder encodeBool:_hideKeyboardOnActivation forKey:@"hideKeyboardOnActivation"];
    [aCoder encodeBool:_alreadyActivated forKey:@"alreadyActivated"];
    [aCoder encodeBool:_manuallyHidden forKey:@"manuallyHidden"];
    [aCoder encodeBool:_isInline forKey:@"isInline"];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGBotReplyMarkup class]] && [((TGBotReplyMarkup *)object)->_rows isEqual:_rows] && ((TGBotReplyMarkup *)object)->_userId == _userId && ((TGBotReplyMarkup *)object)->_messageId == _messageId && ((TGBotReplyMarkup *)object)->_matchDefaultHeight == _matchDefaultHeight && _isInline == ((TGBotReplyMarkup *)object)->_isInline;
}

- (TGBotReplyMarkup *)activatedMarkup
{
    if (_alreadyActivated)
        return self;
    
    return [[TGBotReplyMarkup alloc] initWithUserId:_userId messageId:_messageId rows:_rows matchDefaultHeight:_matchDefaultHeight hideKeyboardOnActivation:_hideKeyboardOnActivation alreadyActivated:true manuallyHidden:_manuallyHidden isInline:_isInline];
}

- (TGBotReplyMarkup *)manuallyHide
{
    if (_manuallyHidden) {
        return self;
    }
    
    return [[TGBotReplyMarkup alloc] initWithUserId:_userId messageId:_messageId rows:_rows matchDefaultHeight:_matchDefaultHeight hideKeyboardOnActivation:_hideKeyboardOnActivation alreadyActivated:_alreadyActivated manuallyHidden:true isInline:_isInline];
}

- (TGBotReplyMarkup *)manuallyUnhide
{
    if (!_manuallyHidden) {
        return self;
    }
    
    return [[TGBotReplyMarkup alloc] initWithUserId:_userId messageId:_messageId rows:_rows matchDefaultHeight:_matchDefaultHeight hideKeyboardOnActivation:_hideKeyboardOnActivation alreadyActivated:_alreadyActivated manuallyHidden:false isInline:_isInline];
}

@end
