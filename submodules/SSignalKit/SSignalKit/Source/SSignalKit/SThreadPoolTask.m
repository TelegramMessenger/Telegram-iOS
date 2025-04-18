#import "SThreadPoolTask.h"

@interface SThreadPoolTaskState : NSObject
{
    @public
    bool _cancelled;
}

@end

@implementation SThreadPoolTaskState

@end

@interface SThreadPoolTask ()
{
    void (^_block)(bool (^)());
    SThreadPoolTaskState *_state;
}

@end

@implementation SThreadPoolTask

- (instancetype)initWithBlock:(void (^)(bool (^)()))block
{
    self = [super init];
    if (self != nil)
    {
        _block = [block copy];
        _state = [[SThreadPoolTaskState alloc] init];
    }
    return self;
}

- (void)execute
{
    if (_state->_cancelled)
        return;
    
    SThreadPoolTaskState *state = _state;
    _block(^bool
    {
        return state->_cancelled;
    });
}

- (void)cancel
{
    _state->_cancelled = true;
}

@end
