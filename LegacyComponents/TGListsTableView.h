#import <UIKit/UIKit.h>

@interface TGListsTableView : UITableView

@property (nonatomic, assign) bool blockContentOffset;
@property (nonatomic, assign) CGFloat indexOffset;
@property (nonatomic, assign) bool mayHaveIndex;

@property (nonatomic, copy) void (^onHitTest)(CGPoint);

- (void)adjustBehaviour;
- (void)scrollToTop;

@end
