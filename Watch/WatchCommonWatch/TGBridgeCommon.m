#import "TGBridgeCommon.h"

NSString *const TGBridgeIncomingFileTypeKey = @"type";
NSString *const TGBridgeIncomingFileIdentifierKey = @"identifier";
NSString *const TGBridgeIncomingFileRandomIdKey = @"randomId";
NSString *const TGBridgeIncomingFilePeerIdKey = @"peerId";
NSString *const TGBridgeIncomingFileReplyToMidKey = @"replyToMid";
NSString *const TGBridgeIncomingFileTypeAudio = @"audio";
NSString *const TGBridgeIncomingFileTypeImage = @"image";

NSString *const TGBridgeResponseSubscriptionIdentifier = @"identifier";
NSString *const TGBridgeResponseTypeKey = @"type";
NSString *const TGBridgeResponseNextKey = @"next";
NSString *const TGBridgeResponseErrorKey = @"error";

@implementation TGBridgeResponse

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _subscriptionIdentifier = [aDecoder decodeInt64ForKey:TGBridgeResponseSubscriptionIdentifier];
        _type = [aDecoder decodeInt32ForKey:TGBridgeResponseTypeKey];
        _next = [aDecoder decodeObjectForKey:TGBridgeResponseNextKey];
        _error = [aDecoder decodeObjectForKey:TGBridgeResponseErrorKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.subscriptionIdentifier forKey:TGBridgeResponseSubscriptionIdentifier];
    [aCoder encodeInt32:self.type forKey:TGBridgeResponseTypeKey];
    [aCoder encodeObject:self.next forKey:TGBridgeResponseNextKey];
    [aCoder encodeObject:self.error forKey:TGBridgeResponseErrorKey];
}

+ (TGBridgeResponse *)single:(id)next forSubscription:(TGBridgeSubscription *)subscription
{
    TGBridgeResponse *response = [[TGBridgeResponse alloc] init];
    response->_subscriptionIdentifier = subscription.identifier;
    response->_type = TGBridgeResponseTypeNext;
    response->_next = next;
    return response;
}

+ (TGBridgeResponse *)fail:(id)error forSubscription:(TGBridgeSubscription *)subscription
{
    TGBridgeResponse *response = [[TGBridgeResponse alloc] init];
    response->_subscriptionIdentifier = subscription.identifier;
    response->_type = TGBridgeResponseTypeFailed;
    response->_error = error;
    return response;
}

+ (TGBridgeResponse *)completeForSubscription:(TGBridgeSubscription *)subscription
{
    TGBridgeResponse *response = [[TGBridgeResponse alloc] init];
    response->_subscriptionIdentifier = subscription.identifier;
    response->_type = TGBridgeResponseTypeCompleted;
    return response;
}

@end


NSString *const TGBridgeSubscriptionIdentifierKey = @"identifier";
NSString *const TGBridgeSubscriptionNameKey = @"name";
NSString *const TGBridgeSubscriptionParametersKey = @"parameters";

@implementation TGBridgeSubscription

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        int64_t randomId = 0;
        arc4random_buf(&randomId, sizeof(int64_t));
        _identifier = randomId;
        _name = [[self class] subscriptionName];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _identifier = [aDecoder decodeInt64ForKey:TGBridgeSubscriptionIdentifierKey];
        _name = [aDecoder decodeObjectForKey:TGBridgeSubscriptionNameKey];
        [self _unserializeParametersWithCoder:aDecoder];
    }
    return self;
}

- (bool)synchronous
{
    return false;
}

- (bool)renewable
{
    return true;
}

- (bool)dropPreviouslyQueued
{
    return false;
}

- (void)_serializeParametersWithCoder:(NSCoder *)__unused aCoder
{
    
}

- (void)_unserializeParametersWithCoder:(NSCoder *)__unused aDecoder
{
    
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.identifier forKey:TGBridgeSubscriptionIdentifierKey];
    [aCoder encodeObject:self.name forKey:TGBridgeSubscriptionNameKey];
    [self _serializeParametersWithCoder:aCoder];
}

+ (NSString *)subscriptionName
{
    return nil;
}

@end


@implementation TGBridgeDisposal

- (instancetype)initWithIdentifier:(int64_t)identifier
{
    self = [super init];
    if (self != nil)
    {
        _identifier = identifier;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _identifier = [aDecoder decodeInt64ForKey:TGBridgeSubscriptionIdentifierKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.identifier forKey:TGBridgeSubscriptionIdentifierKey];
}

@end

NSString *const TGBridgeFileDataKey = @"data";
NSString *const TGBridgeFileMetadataKey = @"metadata";

@implementation TGBridgeFile

- (instancetype)initWithData:(NSData *)data metadata:(NSDictionary *)metadata
{
    self = [super init];
    if (self != nil)
    {
        _data = data;
        _metadata = metadata;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _data = [aDecoder decodeObjectForKey:TGBridgeFileDataKey];
        _metadata = [aDecoder decodeObjectForKey:TGBridgeFileMetadataKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.data forKey:TGBridgeFileDataKey];
    [aCoder encodeObject:self.metadata forKey:TGBridgeFileMetadataKey];
}

@end


NSString *const TGBridgeSessionIdKey = @"sessionId";

@implementation TGBridgePing

- (instancetype)initWithSessionId:(int32_t)sessionId
{
    self = [super init];
    if (self != nil)
    {
        _sessionId = sessionId;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _sessionId = [aDecoder decodeInt32ForKey:TGBridgeSessionIdKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt32:self.sessionId forKey:TGBridgeSessionIdKey];
}

@end


@implementation TGBridgeSubscriptionListRequest

- (instancetype)initWithSessionId:(int32_t)sessionId
{
    self = [super init];
    if (self != nil)
    {
        _sessionId = sessionId;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _sessionId = [aDecoder decodeInt32ForKey:TGBridgeSessionIdKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt32:self.sessionId forKey:TGBridgeSessionIdKey];
}

@end


NSString *const TGBridgeSubscriptionListSubscriptionsKey = @"subscriptions";

@implementation TGBridgeSubscriptionList

- (instancetype)initWithArray:(NSArray *)array
{
    self = [super init];
    if (self != nil)
    {
        _subscriptions = array;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _subscriptions = [aDecoder decodeObjectForKey:TGBridgeSubscriptionListSubscriptionsKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.subscriptions forKey:TGBridgeSubscriptionListSubscriptionsKey];
}

@end
