#import "TGObserverProxy.h"

@interface TGObserverProxyScheduledNotification : NSObject

@property (nonatomic, weak) id target;
@property (nonatomic) SEL targetSelector;
@property (nonatomic, strong) id notification;
@property (nonatomic) NSUInteger passCount;

@property (nonatomic) bool cancelled;

@end

@implementation TGObserverProxyScheduledNotification

- (instancetype)initWithTarget:(id)target targetSelector:(SEL)targetSelector notification:(id)notification passCount:(NSUInteger)passCount
{
    self = [super init];
    if (self != nil)
    {
        self.target = target;
        _targetSelector = targetSelector;
        _notification = notification;
        _passCount = passCount;
    }
    return self;
}

- (void)dealloc
{
    _cancelled = true;
}

- (void)execute
{
    if (_cancelled)
        return;
    
    if (_passCount == 0)
    {
        __strong id target = self.target;
        if (target != nil)
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [target performSelector:_targetSelector withObject:_notification];
#pragma clang diagnostic pop
        }
    }
    else
    {
        _passCount--;
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self execute];
        });
    }
}

@end

@interface TGObserverProxy ()

@property (nonatomic, weak) id target;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) id object;
@property (nonatomic) SEL targetSelector;

@property (nonatomic) TGObserverProxyScheduledNotification *pendingNotification;

@end

@implementation TGObserverProxy

- (instancetype)initWithTarget:(id)target targetSelector:(SEL)targetSelector name:(NSString *)name
{
    return [self initWithTarget:target targetSelector:targetSelector name:name object:nil];
}

- (instancetype)initWithTarget:(id)target targetSelector:(SEL)targetSelector name:(NSString *)name object:(id)object
{
    self = [super init];
    if (self != nil)
    {
        self.target = target;
        self.name = name;
        self.object = object;
        self.targetSelector = targetSelector;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationReceived:) name:name object:object];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:_name object:_object];
}

- (void)notificationReceived:(NSNotification *)notification
{
    if (_pendingNotification != nil)
    {
        _pendingNotification.cancelled = true;
        _pendingNotification = nil;
    }
    
    __strong id target = self.target;
    if (target != nil)
    {
        if (_numberOfRunLoopPassesToDelayTargetNotifications == 0)
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [target performSelector:_targetSelector withObject:notification];
#pragma clang diagnostic pop
        }
        else
        {
            _pendingNotification = [[TGObserverProxyScheduledNotification alloc] initWithTarget:self.target targetSelector:_targetSelector notification:notification passCount:_numberOfRunLoopPassesToDelayTargetNotifications];
            [_pendingNotification execute];
        }
    }
}

@end
