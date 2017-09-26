#import "TGMediaPickerSelectionGestureRecognizer.h"

const CGFloat TGSelectionGestureActivationThreshold = 4.0f;
const CGFloat TGSelectionGestureVerticalFailureThreshold = 5.0f;

@interface TGMediaPickerSelectionGestureRecognizer () <UIGestureRecognizerDelegate>
{
    UICollectionView *_collectionView;
    UIPanGestureRecognizer *_gestureRecognizer;
    
    CGPoint _checkGestureStartPoint;
    bool _processingCheckGesture;
    bool _failCheckGesture;
    bool _checkGestureChecks;
}
@end

@implementation TGMediaPickerSelectionGestureRecognizer

- (instancetype)initForCollectionView:(UICollectionView *)collectionView
{
    self = [super init];
    if (self != nil)
    {
        _collectionView = collectionView;
        
        _gestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _gestureRecognizer.delegate = self;
        [collectionView addGestureRecognizer:_gestureRecognizer];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)recognizer
{
    switch (recognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            _checkGestureStartPoint = [recognizer locationInView:_collectionView];
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled:
        {
            _processingCheckGesture = false;
            _collectionView.scrollEnabled = true;
            _failCheckGesture = false;
        }
            break;
            
        case UIGestureRecognizerStateChanged:
        {
            CGPoint translation = [recognizer translationInView:_collectionView];
            CGPoint location = [recognizer locationInView:_collectionView];
            
            bool processAdditionalLocation = false;
            CGPoint additionalLocation = CGPointZero;
            
            if (!_processingCheckGesture && !_failCheckGesture)
            {
                if (fabs(translation.y) >= TGSelectionGestureVerticalFailureThreshold)
                {
                    _failCheckGesture = true;
                }
                else if (fabs(translation.x) >= TGSelectionGestureActivationThreshold)
                {
                    for (UICollectionViewCell *cell in _collectionView.visibleCells)
                    {
                        if (CGRectContainsPoint(cell.frame, location))
                        {
                            NSIndexPath *indexPath = [_collectionView indexPathForCell:cell];
                            if (indexPath == nil)
                                continue;
                            
                            _collectionView.scrollEnabled = false;
                            
                            _processingCheckGesture = true;
                            _checkGestureChecks = !self.isItemSelected(indexPath);
                            
                            processAdditionalLocation = true;
                            additionalLocation = location;
                            location = _checkGestureStartPoint;
                            
                            break;
                        }
                    }
                }
            }
            
            if (_processingCheckGesture)
            {
                for (int i = 0; i < (processAdditionalLocation ? 2 : 1); i++)
                {
                    CGPoint currentLocation = (i == 0) ? location : additionalLocation;
                    
                    for (UICollectionViewCell *cell in _collectionView.visibleCells)
                    {
                        if (CGRectContainsPoint(cell.frame, currentLocation))
                        {
                            NSIndexPath *indexPath = [_collectionView indexPathForCell:cell];
                            if (indexPath == nil)
                                continue;
                            
                            if (self.isItemSelected(indexPath) != _checkGestureChecks)
                                self.toggleItemSelection(indexPath);
                            
                            break;
                        }
                    }
                }
            }
        }
            break;
            
        default:
            break;
    }
}

- (void)cancel
{
    _gestureRecognizer.enabled = false;
    _gestureRecognizer.enabled = true;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)__unused otherGestureRecognizer
{
    return gestureRecognizer == _gestureRecognizer;
}

@end
