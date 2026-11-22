#import "WKInterfaceGroup+Signals.h"
#import "TGWatchCommon.h"
#import <objc/runtime.h>

@interface WKInterfaceGroup (Signals_Private)

@property (nonatomic, strong) SMetaDisposable *disposable;
@property (nonatomic, strong) id postponedImage;

@property (nonatomic, assign) bool isEmpty;

@end

@implementation WKInterfaceGroup (Signals)

+ (void)load
{
    TGSwizzleMethodImplementation(self.class, NSSelectorFromString(@"dealloc"), @selector(tg_dealloc));
}

- (void)tg_dealloc
{
    [self.disposable dispose];
    
    [self tg_dealloc];
}

- (id)postponedImage
{
    return objc_getAssociatedObject(self, @selector(postponedImage));
}

- (void)setPostponedImage:(id)image
{
    objc_setAssociatedObject(self, @selector(postponedImage), image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSInteger)isEmpty
{
    return [objc_getAssociatedObject(self, @selector(isEmpty)) boolValue];
}

- (void)setIsEmpty:(bool)empty
{
    objc_setAssociatedObject(self, @selector(isEmpty), @(empty), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSInteger)version
{
    return [objc_getAssociatedObject(self, @selector(version)) integerValue];
}

- (void)setVersion:(NSInteger)version
{
    objc_setAssociatedObject(self, @selector(version), @(version), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (SMetaDisposable *)disposable
{
    return objc_getAssociatedObject(self, @selector(disposable));
}

- (void)setDisposable:(SMetaDisposable *)disposable
{
    objc_setAssociatedObject(self, @selector(disposable), disposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setBackgroundImageSignal:(SSignal *)signal isVisible:(bool (^)(void))isVisible
{
    if (self.disposable == nil)
        self.disposable = [[SMetaDisposable alloc] init];
    
    NSInteger version = ++self.version;
    
    __weak WKInterfaceGroup *weakSelf = self;
    [self.disposable setDisposable:[[signal deliverOn:[SQueue mainQueue]] startWithNext:^(id next)
    {
        __strong WKInterfaceGroup *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf.version != version)
            return;

        bool shouldUpdate = true;
        if (isVisible != nil)
            shouldUpdate = isVisible();
        
        if (shouldUpdate)
            [strongSelf _setBackgroundImageWithNext:next];
        else
            strongSelf.postponedImage = next;
    } error:^(id error)
    {
    } completed:^
    {
    }]];
    
    if (signal == nil && !self.isEmpty)
    {
        bool shouldUpdate = true;
        if (isVisible != nil)
            shouldUpdate = isVisible();
        
        if (shouldUpdate)
        {
            self.isEmpty = true;
            [self setBackgroundImage:nil];
        }
        else
        {
            self.postponedImage = [NSNull null];
        }
    }
}

- (void)updateIfNeeded
{
    if (self.postponedImage == nil)
        return;

    UIImage *image = self.postponedImage;
    self.postponedImage = nil;
    
    [self _setBackgroundImageWithNext:image];
}

- (void)_setBackgroundImageWithNext:(id)next
{
    if ([next isKindOfClass:[NSString class]])
    {
        [self setBackgroundImageNamed:(NSString *)next];
    }
    else if ([next isKindOfClass:[NSData class]])
    {
        [self setBackgroundImageData:(NSData *)next];
    }
    else if ([next isKindOfClass:[UIImage class]])
    {
        [self setBackgroundImage:(UIImage *)next];
    }
    else if ([next isKindOfClass:[NSNull class]])
    {
        self.isEmpty = true;
        [self setBackgroundImage:nil];
    }
}

@end
