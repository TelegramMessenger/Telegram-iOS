#import <MtProtoKit/MTIncomingMessage.h>

@implementation MTIncomingMessage

- (instancetype)initWithMessageId:(int64_t)messageId seqNo:(int32_t)seqNo authKeyId:(int64_t)authKeyId sessionId:(int64_t)sessionId salt:(int64_t)salt timestamp:(NSTimeInterval)timestamp size:(NSInteger)size body:(id)body
{
    self = [super init];
    if (self != nil)
    {
        _messageId = messageId;
        _seqNo = seqNo;
        _authKeyId = authKeyId;
        _sessionId = sessionId;
        _salt = salt;
        _timestamp = timestamp;
        _size = size;
        _body = body;
    }
    return self;
}

@end
