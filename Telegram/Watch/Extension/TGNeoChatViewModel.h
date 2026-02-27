#import "TGNeoRenderableViewModel.h"

@class TGBridgeContext;
@class TGBridgeChat;

@interface TGNeoChatViewModel : TGNeoRenderableViewModel

- (instancetype)initWithChat:(TGBridgeChat *)chat users:(NSDictionary *)users context:(TGBridgeContext *)context;

@end
