#import "TGListsTableView.h"

#import "LegacyComponentsInternal.h"
#import "Freedom.h"

#import "TGSearchBar.h"

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
            [self insertSubview:_whiteFooterView atIndex:0];
        }
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = self.bounds;
    
    if (_whiteFooterView != nil)
        _whiteFooterView.frame = CGRectMake(0.0f, MAX(0.0f, bounds.origin.y), bounds.size.width, bounds.size.height);
    else
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
    
    UIView *tableHeaderView = self.tableHeaderView;
    if (tableHeaderView != nil && [tableHeaderView respondsToSelector:@selector(updateClipping:)])
    {
        [(TGSearchBar *)tableHeaderView updateClipping:bounds.origin.y + self.contentInset.top];
    }
}

- (void)didAddSubview:(UIView *)subview
{
    [super didAddSubview:subview];
    
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

- (void)setContentOffset:(CGPoint)contentOffset
{
    if (_blockContentOffset)
        return;
    
    [super setContentOffset:contentOffset];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (_onHitTest) {
        _onHitTest(point);
    }
    return [super hitTest:point withEvent:event];
}

@end
