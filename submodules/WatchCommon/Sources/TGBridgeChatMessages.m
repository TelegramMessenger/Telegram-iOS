#import "TGBridgeChatMessages.h"
#import "TGBridgeMessage.h"

NSString *const TGBridgeChatMessageListViewMessagesKey = @"messages";
NSString *const TGBridgeChatMessageListViewEarlierMessageIdKey = @"earlier";
NSString *const TGBridgeChatMessageListViewLaterMessageIdKey = @"later";

NSString *const TGBridgeChatMessageListViewKey = @"messageListView";

@implementation TGBridgeChatMessages

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _messages = [aDecoder decodeObjectForKey:TGBridgeChatMessageListViewMessagesKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.messages forKey:TGBridgeChatMessageListViewMessagesKey];
}

@end
