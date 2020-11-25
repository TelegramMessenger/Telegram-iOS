#import "TGListsTableView.h"

#import "LegacyComponentsInternal.h"
#import "POPBasicAnimation.h"
#import "Freedom.h"

#import <objc/runtime.h>

@interface TGListsTableView ()
{
    UIView *_whiteFooterView;
    bool _hackHeaderSize;
}

@end

@implementation TGListsTableView

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
    self = [super initWithFrame:frame style:style];
    if (self != nil)
    {
        if (iosMajorVersion() < 7)
        {
            self.backgroundView = [[UIView alloc] init];
            self.backgroundView.backgroundColor = [UIColor whiteColor];
        }
        else
        {
            _whiteFooterView = [[UIView alloc] init];
            _whiteFooterView.backgroundColor = [UIColor whiteColor];
            //_whiteFooterView.layer.zPosition = -1.0;
            _whiteFooterView.userInteractionEnabled = false;
            [self insertSubview:_whiteFooterView atIndex:0];
        }
    }
    return self;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    
    if (iosMajorVersion() < 7)
        self.backgroundView.backgroundColor = backgroundColor;
    else if (![backgroundColor isEqual:[UIColor clearColor]])
        _whiteFooterView.backgroundColor = backgroundColor;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = self.bounds;
    
    if (_whiteFooterView != nil) {
        _whiteFooterView.frame = CGRectMake(0.0f, MAX(0.0f, bounds.origin.y), bounds.size.width, bounds.size.height);
        /*if (self.subviews.firstObject != _whiteFooterView) {
            [self insertSubview:_whiteFooterView atIndex:0];
        }*/
    } else
        self.backgroundView.frame = CGRectMake(0.0f, MAX(0.0f, bounds.origin.y), bounds.size.width, bounds.size.height);
    
    if (_hackHeaderSize)
    {
        UIView *tableHeaderView = self.tableHeaderView;
        if (tableHeaderView != nil)
        {
            CGSize size = self.frame.size;
            
            CGRect frame = tableHeaderView.frame;
            if (frame.size.width < size.width)
            {
                frame.size.width = size.width;
                tableHeaderView.frame = frame;
            }
        }
    }
    
    UIView *indexView = self.subviews.lastObject;
    if ([NSStringFromClass([indexView class]) rangeOfString:@"ViewIndex"].location != NSNotFound)
    {
        indexView.frame = CGRectMake(self.frame.size.width - indexView.frame.size.width - self.indexOffset, indexView.frame.origin.y, indexView.frame.size.width, indexView.frame.size.height);
    }
}

- (void)insertSubview:(UIView *)view atIndex:(NSInteger)index {
    if (index == 0 && view != _whiteFooterView) {
        index = 1;
    }
    [super insertSubview:view atIndex:index];
}

- (void)didAddSubview:(UIView *)subview
{
    [super didAddSubview:subview];
    if (!self.mayHaveIndex)
        return;
    
    if (iosMajorVersion() >= 7)
    {
        static Class indexClass = Nil;
        
        static ptrdiff_t backgroundColorPtr = -1;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            indexClass = freedomClass(0xd93a1ed6U);
            if (indexClass != Nil)
                backgroundColorPtr = freedomIvarOffset(indexClass, 0xca7e3046U);
        });
        
        if ([subview isKindOfClass:indexClass] && backgroundColorPtr >= 0)
        {
            __strong UIColor **backgroundColor = (__strong UIColor **)(void *)(((uint8_t *)(__bridge void *)subview) + backgroundColorPtr);
            *backgroundColor = [UIColor clearColor];
        }
    }
}

- (void)sendSubviewToBack:(UIView *)view
{
    [super sendSubviewToBack:view];
    if (_whiteFooterView != nil && view != _whiteFooterView)
        [super sendSubviewToBack:_whiteFooterView];
}

- (void)hackHeaderSize
{
    _hackHeaderSize = true;
}

- (void)adjustBehaviour
{
    //FreedomBitfield tableFlagsOffset = freedomIvarBitOffset([UITableView class], 0x3fa93ecU, 0xe3ca73b1U);
    //if (tableFlagsOffset.offset != -1 && tableFlagsOffset.bit != -1)
    //    freedomSetBitfield((__bridge void *)self, tableFlagsOffset, 1);
}

- (void)scrollToTop
{
    if (iosMajorVersion() >= 11)
        [self performCustomScrollToTop];
    else
        [self setContentOffset:CGPointMake(0.0f, -self.contentInset.top) animated:true];
}

- (void)performCustomScrollToTop
{
    POPBasicAnimation *animation = [self pop_animationForKey:@"contentOffset"];
    if (animation != nil)
        return;
    
    [self setContentOffset:self.contentOffset animated:false];
    self.blockContentOffset = true;
    
    animation = [POPBasicAnimation animation];
    animation.property = [POPAnimatableProperty propertyWithName:@"contentOffset" initializer:^(POPMutableAnimatableProperty *prop)
    {
        prop.readBlock = ^(TGListsTableView *tableView, CGFloat values[])
        {
            values[0] = tableView.contentOffset.y;
        };
        
        prop.writeBlock = ^(TGListsTableView *tableView, const CGFloat values[])
        {
            tableView.forcedContentOffset = CGPointMake(tableView.contentOffset.x, values[0]);
        };
        
        prop.threshold = 1.0f;
    }];
    animation.fromValue = @(self.contentOffset.y);
    animation.toValue = @(-self.contentInset.top);
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.duration = 0.25;
    
    __weak TGListsTableView *weakSelf = self;
    animation.completionBlock = ^(POPAnimation *anim, BOOL finished)
    {
        __strong TGListsTableView *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            strongSelf.blockContentOffset = false;
            strongSelf.forcedContentOffset = CGPointMake(strongSelf.contentOffset.x, -strongSelf.contentInset.top);
        }
    };
    [self pop_addAnimation:animation forKey:@"contentOffset"];
}

- (void)setContentOffset:(CGPoint)contentOffset
{
    if (_blockContentOffset)
        return;
    
    [super setContentOffset:contentOffset];
}

- (void)setForcedContentOffset:(CGPoint)contentOffset
{
    [super setContentOffset:contentOffset];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (_onHitTest) {
        _onHitTest(point);
    }
    return [super hitTest:point withEvent:event];
}

@end
