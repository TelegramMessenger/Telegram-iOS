#import "TGNeoViewModel.h"

@class TGBridgeForwardedMessageMediaAttachment;
@class TGBridgeUser;
@class TGBridgeChat;

@interface TGNeoForwardHeaderViewModel : TGNeoViewModel

- (instancetype)initWithForwardAttachment:(TGBridgeForwardedMessageMediaAttachment *)attachment user:(TGBridgeUser *)user outgoing:(bool)outgoing;
- (instancetype)initWithForwardAttachment:(TGBridgeForwardedMessageMediaAttachment *)attachment chat:(TGBridgeChat *)chat outgoing:(bool)outgoing;

@end

extern const CGFloat TGNeoForwardHeaderHeight;
