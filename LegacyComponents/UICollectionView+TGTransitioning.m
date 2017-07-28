#import "UICollectionView+TGTransitioning.h"

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "TGTransitionLayout.h"

@implementation UICollectionView (TGTransitioning)

- (BOOL)isTransitionInProgress
{
    return ([self tg_transitionData] != nil);
}

- (NSMutableDictionary *)tg_transitionData
{
    return objc_getAssociatedObject(self, @selector(tg_transitionData));
}

- (void)tg_setTransitionData:(NSMutableDictionary *)data
{
    objc_setAssociatedObject(self, @selector(tg_transitionData), data, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (SPipe *)tg_transitionPipe
{
    SPipe *pipe = objc_getAssociatedObject(self, @selector(tg_transitionPipe));
    if (pipe == nil)
    {
        pipe = [[SPipe alloc] init];
        objc_setAssociatedObject(self, @selector(tg_transitionPipe), pipe, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return pipe;
}

#pragma mark - Transition logic

- (UICollectionViewTransitionLayout *)transitionToCollectionViewLayout:(UICollectionViewLayout *)layout duration:(NSTimeInterval)duration completion:(UICollectionViewLayoutInteractiveTransitionCompletion)completion
{
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    data[@"duration"] = @(duration);
    data[@"startTime"] = @(CACurrentMediaTime());
    [self tg_setTransitionData:data];
    
    CADisplayLink *link = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateProgress:)];
    [link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
    __weak UICollectionView *weakSelf = self;
    UICollectionViewTransitionLayout *transitionLayout = [self startInteractiveTransitionToCollectionViewLayout:layout completion:^(BOOL completed, BOOL finish)
    {
        __strong UICollectionView *strongSelf = weakSelf;
        NSMutableDictionary *data = [strongSelf tg_transitionData];
        UICollectionViewTransitionLayout *transitionLayout = data[@"transitionLayout"];
        if ([transitionLayout conformsToProtocol:@protocol(TGTransitionAnimatorLayout)])
        {
            id<TGTransitionAnimatorLayout>layout = (id<TGTransitionAnimatorLayout>)transitionLayout;
            [layout collectionViewDidCompleteTransitioning:strongSelf completed:completed finish:finish];
        }
        [strongSelf tg_setTransitionData:nil];
        
        if (completion != nil)
            completion(completed, finish);
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self tg_transitionPipe].sink(@true);            
        });
    }];
    data[@"transitionLayout"] = transitionLayout;
    data[@"link"] = link;
    
    return transitionLayout;
}

CGFloat TGQuadraticEaseInOut(CGFloat p)
{
    if (p < 0.5)
        return 2 * p * p;
    else
        return (-2 * p * p) + (4 * p) - 1;
}

- (void)updateProgress:(CADisplayLink *)link
{
    NSMutableDictionary *data = [self tg_transitionData];
    UICollectionViewLayout *layout = self.collectionViewLayout;
    
    if ([layout isKindOfClass:[UICollectionViewTransitionLayout class]])
    {
        CFTimeInterval startTime = [data[@"startTime"] floatValue];
        NSTimeInterval duration = [data[@"duration"] floatValue];
        CFTimeInterval time = duration > 0 ? (link.timestamp - startTime) / duration : 1;
        time = MIN(1, time);
        time = MAX(0, time);
        
        CGFloat progress = TGQuadraticEaseInOut(time);
        UICollectionViewTransitionLayout *l = (UICollectionViewTransitionLayout *)layout;
        [l setTransitionProgress:progress];
        [l invalidateLayout];
        
        if (time >= 1)
            [self finishTransition:link];
    }
    else
    {
        [self finishTransition:link];
    }
}

- (void)finishTransition:(CADisplayLink *)link
{
    NSMutableDictionary *data = [self tg_transitionData];
    UICollectionViewTransitionLayout *transitionLayout = data[@"transitionLayout"];
    if ([transitionLayout conformsToProtocol:@protocol(TGTransitionAnimatorLayout)])
    {
        id<TGTransitionAnimatorLayout>layout = (id<TGTransitionAnimatorLayout>)transitionLayout;
        [layout collectionViewAlmostCompleteTransitioning:self];
    }
    
    [link invalidate];

    [data removeObjectForKey:@"link"];
    [self finishInteractiveTransition];
}

#pragma mark - Calculating transition values

- (CGPoint)toContentOffsetForLayout:(UICollectionViewTransitionLayout *)layout indexPath:(NSIndexPath *)indexPath toSize:(CGSize)toSize toContentInset:(UIEdgeInsets)toContentInset
{
    CGRect fromFrame = CGRectNull;
    CGRect toFrame = CGRectNull;
    if (indexPath)
    {
        UICollectionViewLayoutAttributes *fromPose =
        [layout.currentLayout layoutAttributesForItemAtIndexPath:indexPath];
        UICollectionViewLayoutAttributes *toPose =
        [layout.nextLayout layoutAttributesForItemAtIndexPath:indexPath];
        fromFrame = CGRectUnion(fromFrame, fromPose.frame);
        toFrame = CGRectUnion(toFrame, toPose.frame);
    }
    
    CGRect placementFrame = (CGRect){{0, 0}, toSize};
    
    CGPoint sourcePoint = CGPointMake(CGRectGetMidX(toFrame), CGRectGetMidY(toFrame));
    CGPoint destinationPoint = CGPointMake(CGRectGetMidX(placementFrame), CGRectGetMidY(placementFrame));
    
    CGSize contentSize = layout.nextLayout.collectionViewContentSize;
    CGPoint offset = CGPointMake(sourcePoint.x - destinationPoint.x, sourcePoint.y - destinationPoint.y);
    
    CGFloat minOffsetX = 0;
    CGFloat minOffsetY = -toContentInset.top;
    
    CGFloat maxOffsetX = contentSize.width - placementFrame.size.width;
    CGFloat maxOffsetY = toContentInset.bottom + contentSize.height - placementFrame.size.height;
    maxOffsetX = MAX(minOffsetX, maxOffsetX);
    maxOffsetY = MAX(minOffsetY, maxOffsetY);
    
    offset.x = MAX(minOffsetX, offset.x);
    offset.y = MAX(minOffsetY, offset.y);
    
    offset.x = MIN(maxOffsetX, offset.x);
    offset.y = MIN(maxOffsetY, offset.y);
        
    return offset;
}

#pragma mark - 

- (SSignal *)noOngoingTransitionSignal
{
    if (!self.isTransitionInProgress)
        return [SSignal complete];
    
    return [[[self tg_transitionPipe].signalProducer() take:1] mapToSignal:^SSignal *(__unused id value)
    {
        return [SSignal complete];
    }];
}

@end
