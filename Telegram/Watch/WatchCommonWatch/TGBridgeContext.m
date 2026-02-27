#import "TGBridgeContext.h"
#import "TGBridgeCommon.h"
//#import "TGWatchCommon.h"

NSString *const TGBridgeContextAuthorized = @"authorized";
NSString *const TGBridgeContextUserId = @"userId";
NSString *const TGBridgeContextMicAccessAllowed = @"micAccessAllowed";
NSString *const TGBridgeContextStartupData = @"startupData";
NSString *const TGBridgeContextStartupDataVersion = @"version";

@implementation TGBridgeContext

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self != nil)
    {
        _authorized = [dictionary[TGBridgeContextAuthorized] boolValue];
        _userId = (int32_t)[dictionary[TGBridgeContextUserId] intValue];
        _micAccessAllowed = [dictionary[TGBridgeContextMicAccessAllowed] boolValue];
        
        if (dictionary[TGBridgeContextStartupData] != nil) {
            _preheatData = [NSKeyedUnarchiver unarchiveObjectWithData:dictionary[TGBridgeContextStartupData]];
            _preheatVersion = [dictionary[TGBridgeContextStartupDataVersion] integerValue];
        }
    }
    return self;
}

- (NSDictionary *)dictionary
{
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    dictionary[TGBridgeContextAuthorized] = @(self.authorized);
    dictionary[TGBridgeContextUserId] = @(self.userId);
    dictionary[TGBridgeContextMicAccessAllowed] = @(self.micAccessAllowed);
    if (self.preheatData != nil) {
        dictionary[TGBridgeContextStartupData] = [NSKeyedArchiver archivedDataWithRootObject:self.preheatData];
        dictionary[TGBridgeContextStartupDataVersion] = @(self.preheatVersion);
    }
    return dictionary;
}

- (TGBridgeContext *)updatedWithAuthorized:(bool)authorized peerId:(int64_t)peerId
{
    TGBridgeContext *context = [[TGBridgeContext alloc] init];
    context->_authorized = authorized;
    context->_userId = peerId;
    context->_micAccessAllowed = self.micAccessAllowed;
    if (authorized) {
        context->_preheatData = self.preheatData;
        context->_preheatVersion = self.preheatVersion;
    }
    return context;
}

- (TGBridgeContext *)updatedWithPreheatData:(NSDictionary *)data
{
    TGBridgeContext *context = [[TGBridgeContext alloc] init];
    context->_authorized = self.authorized;
    context->_userId = self.userId;
    context->_micAccessAllowed = self.micAccessAllowed;
    if (data != nil) {
        context->_preheatData = data;
        context->_preheatVersion = (int32_t)[NSDate date].timeIntervalSinceReferenceDate;
    }
    return context;
}

- (TGBridgeContext *)updatedWithMicAccessAllowed:(bool)allowed
{
    TGBridgeContext *context = [[TGBridgeContext alloc] init];
    context->_authorized = self.authorized;
    context->_userId = self.userId;
    context->_micAccessAllowed = allowed;
    context->_preheatData = self.preheatData;
    context->_preheatVersion = self.preheatVersion;
    return context;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return true;
    
    if (!object || ![object isKindOfClass:[self class]])
        return false;
    
    TGBridgeContext *context = (TGBridgeContext *)object;
    if (context.authorized != self.authorized)
        return false;
    if (context.userId != self.userId)
        return false;
    if (context.micAccessAllowed != self.micAccessAllowed)
        return false;
    if (context.preheatVersion != self.preheatVersion)
        return false;
    
    return true;
}

@end
