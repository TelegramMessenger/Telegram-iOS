#import "TGTransitionLayout.h"

@interface TGTransitionLayout ()
{
    NSDictionary *_poses;
    NSDictionary *_targetPoses;
    
    CGPoint _fromContentOffset;
}

@property (nonatomic) BOOL toContentOffsetInitialized;
@property (strong, nonatomic) NSDictionary *poses;
@property (nonatomic) CGFloat previousProgress;
@property (strong, nonatomic) NSArray *supplementaryKinds;
@end

@implementation TGTransitionLayout

- (instancetype)initWithCurrentLayout:(UICollectionViewLayout *)currentLayout nextLayout:(UICollectionViewLayout *)newLayout
{
    self = [super initWithCurrentLayout:currentLayout nextLayout:newLayout];
    if (self != nil)
    {
        _fromContentOffset = currentLayout.collectionView.contentOffset;
    }
    return self;
}

- (void)setTransitionProgress:(CGFloat)transitionProgress
{
    if (self.transitionProgress != transitionProgress)
    {
        self.previousProgress = self.transitionProgress;
        super.transitionProgress = transitionProgress;

        if (self.toContentOffsetInitialized)
        {
            CGFloat t = self.transitionProgress;
            CGFloat f = 1 - t;
            CGPoint offset = CGPointMake(f * _fromContentOffset.x + t * self.toContentOffset.x, f * _fromContentOffset.y + t * self.toContentOffset.y);
            self.collectionView.contentOffset = offset;
        }
        
        if (self.progressChanged != nil)
            self.progressChanged(transitionProgress);
    }
}

- (void)prepareLayout
{
    [super prepareLayout];
    
    CGFloat remaining = 1 - self.previousProgress;
    CGFloat t = remaining == 0 ? self.transitionProgress : fabs(self.transitionProgress - self.previousProgress) / remaining;
    CGFloat f = 1 - t;
    
    NSMutableDictionary *poses = [[NSMutableDictionary alloc] init];
    
    NSMutableDictionary *targetPoses = nil;
    if (_targetPoses == nil)
    {
        targetPoses = [[NSMutableDictionary alloc] init];
        _targetPoses = targetPoses;
    }
    
    for (NSInteger section = 0; section < [self.collectionView numberOfSections]; section++)
    {
        for (NSInteger item = 0; item < [self.collectionView numberOfItemsInSection:section]; item++)
        {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
            NSIndexPath *key = [self keyForIndexPath:indexPath];
            
            UICollectionViewLayoutAttributes *fromPose = self.poses != nil ? self.poses[key] : [self.currentLayout layoutAttributesForItemAtIndexPath:indexPath];
            UICollectionViewLayoutAttributes *toPose = nil;
            
            if (_targetPoses[key] != nil)
            {
                toPose = _targetPoses[key];
            }
            else
            {
                toPose = [self.nextLayout layoutAttributesForItemAtIndexPath:indexPath];
                targetPoses[key] = toPose;
            }
            UICollectionViewLayoutAttributes *pose = nil;
            if (t > DBL_EPSILON)
            {
                pose = [[[self class] layoutAttributesClass] layoutAttributesForCellWithIndexPath:indexPath];
                [self interpolatePose:pose fromPose:fromPose toPose:toPose fromProgress:f toProgress:t];
            }
            else
            {
                pose = fromPose;
            }
            
            [poses setObject:pose forKey:key];
        }
    }
    self.poses = poses;
}

- (void)interpolatePose:(UICollectionViewLayoutAttributes *)pose fromPose:(UICollectionViewLayoutAttributes *)fromPose toPose:(UICollectionViewLayoutAttributes *)toPose fromProgress:(CGFloat)f toProgress:(CGFloat)t
{
    CGRect bounds = CGRectZero;
    bounds.size.width = f * fromPose.bounds.size.width + t * toPose.bounds.size.width;
    bounds.size.height = f * fromPose.bounds.size.height + t * toPose.bounds.size.height;
    pose.bounds = bounds;
    
    CGPoint center = CGPointZero;
    center.x = f * fromPose.center.x + t * toPose.center.x;
    center.y = f * fromPose.center.y + t * toPose.center.y;
    pose.center = center;
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
    NSMutableArray *poses = [NSMutableArray array];
    for (NSInteger section = 0; section < [self.collectionView numberOfSections]; section++)
    {
        for (NSInteger item = 0; item < [self.collectionView numberOfItemsInSection:section]; item++)
        {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
            UICollectionViewLayoutAttributes *pose = [self.poses objectForKey:indexPath];
            CGRect intersection = CGRectIntersection(rect, pose.frame);
            if (!CGRectIsEmpty(intersection))
                [poses addObject:pose];
        }
    }
    return poses;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    id key = [self keyForIndexPath:indexPath];
    return [self.poses objectForKey:key];
}

- (NSIndexPath *)keyForIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath class] == [NSIndexPath class]) {
        return indexPath;
    }
    return [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section];
}

- (void)setToContentOffset:(CGPoint)toContentOffset
{
    self.toContentOffsetInitialized = true;
    if (!CGPointEqualToPoint(_toContentOffset, toContentOffset))
    {
        _toContentOffset = toContentOffset;
        [self invalidateLayout];
    }
}

- (void)collectionViewAlmostCompleteTransitioning:(UICollectionView *)__unused collectionView
{
    if (self.transitionAlmostFinished != nil)
        self.transitionAlmostFinished();
}

- (void)collectionViewDidCompleteTransitioning:(UICollectionView *)collectionView completed:(bool)__unused completed finish:(bool)__unused finish
{
    if (finish && self.toContentOffsetInitialized)
        collectionView.contentOffset = self.toContentOffset;
}

@end
