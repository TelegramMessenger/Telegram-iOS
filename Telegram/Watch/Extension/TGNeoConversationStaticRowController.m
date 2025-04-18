#import "TGNeoConversationStaticRowController.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGBridgeUserCache.h"

#import "TGChatInfo.h"

#import "TGNeoServiceMessageViewModel.h"

#import <SSignalKit/SSignalKit.h>

NSString *const TGNeoConversationStaticRowIdentifier = @"TGNeoConversationStaticRow";

@interface TGNeoConversationStaticRowController ()
{
    TGNeoMessageViewModel *_viewModel;
    SMetaDisposable *_renderDisposable;
    
    TGChatInfo *_currentChatInfo;
}
@end

@implementation TGNeoConversationStaticRowController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _renderDisposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_renderDisposable dispose];
}

- (void)updateWithChatInfo:(TGChatInfo *)chatInfo
{
    if (_viewModel != nil)
        return;
    
    _viewModel = [TGNeoConversationStaticRowController viewModelForChatInfo:chatInfo];
    
    CGSize containerSize = [[WKInterfaceDevice currentDevice] screenBounds].size;
    CGSize contentSize = [_viewModel layoutWithContainerSize:containerSize];
    
    self.contentGroup.width = contentSize.width;
    self.contentGroup.height = contentSize.height;
    
    __weak TGNeoConversationStaticRowController *weakSelf = self;
    [_renderDisposable setDisposable:[[[[TGNeoRenderableViewModel renderSignalForViewModel:_viewModel] startOn:[SQueue concurrentDefaultQueue]] deliverOn:[SQueue mainQueue]] startWithNext:^(UIImage *image)
    {
        __strong TGNeoConversationStaticRowController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf.contentGroup setBackgroundImage:image];
    }]];
}

- (bool)shouldUpdateChatInfoFrom:(TGChatInfo *)oldChatInfo to:(TGChatInfo *)newChatInfo
{
    if (oldChatInfo == nil)
        return true;
 
    if (![oldChatInfo.text isEqualToString:newChatInfo.text])
        return true;
    
    return false;
}

+ (TGNeoMessageViewModel *)viewModelForChatInfo:(TGChatInfo *)chatInfo
{
    return [[TGNeoServiceMessageViewModel alloc] initWithChatInfo:chatInfo];
}

+ (NSString *)identifier
{
    return TGNeoConversationStaticRowIdentifier;
}

@end
