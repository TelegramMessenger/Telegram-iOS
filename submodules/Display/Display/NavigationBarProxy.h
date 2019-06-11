#import <UIKit/UIKit.h>

@interface NavigationBarProxy : UINavigationBar

@property (nonatomic, copy) void (^setItemsProxy)(NSArray *, NSArray *, bool);

@end
