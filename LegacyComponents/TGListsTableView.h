#import <UIKit/UIKit.h>

@interface TGListsTableView : UITableView

@property (nonatomic, assign) bool blockContentOffset;

@property (nonatomic, copy) void (^onHitTest)(CGPoint);

- (void)adjustBehaviour;

@end
