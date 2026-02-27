#import "TGProfilePhotoController.h"
#import "TGWatchCommon.h"
#import "WKInterfaceGroup+Signals.h"
#import "TGBridgeMediaSignals.h"

NSString *const TGProfilePhotoControllerIdentifier = @"TGProfilePhotoController";

@implementation TGProfilePhotoControllerContext

- (instancetype)initWithIdentifier:(int64_t)identifier imageUrl:(NSString *)imageUrl
{
    self = [super init];
    if (self != nil)
    {
        _identifier = identifier;
        _imageUrl = imageUrl;
    }
    return self;
}

@end

@interface TGProfilePhotoController ()
{
    TGProfilePhotoControllerContext *_context;
}
@end

@implementation TGProfilePhotoController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        
    }
    return self;
}

- (void)configureWithContext:(TGProfilePhotoControllerContext *)context
{
    _context = context;
    
    self.title = TGLocalized(@"Watch.PhotoView.Title");

    __weak TGProfilePhotoController *weakSelf = self;
    [self.imageGroup setBackgroundImageSignal:[[TGBridgeMediaSignals avatarWithPeerId:_context.identifier url:_context.imageUrl type:TGBridgeMediaAvatarTypeLarge] onNext:^(id next)
    {
        __strong TGProfilePhotoController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (next != nil)
        {
            strongSelf.imageGroup.alpha = 0.0f;
            strongSelf.activityIndicator.hidden = true;
            [strongSelf animateWithDuration:0.25f animations:^
            {
                strongSelf.imageGroup.alpha = 1.0f;
            }];
        }
    }] isVisible:^bool
    {
        __strong TGProfilePhotoController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return false;
        
        return strongSelf.isVisible;
    }];
}

- (void)willActivate
{
    [super willActivate];
    
    [self.imageGroup updateIfNeeded];
}

- (void)didDeactivate
{
    [super didDeactivate];
}

+ (NSString *)identifier
{
    return TGProfilePhotoControllerIdentifier;
}

@end
