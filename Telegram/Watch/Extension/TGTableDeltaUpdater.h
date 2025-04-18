#import <WatchKit/WatchKit.h>

@class TGIndexPath;

@interface TGTableAlignment : NSObject

@property (nonatomic, assign) bool deletion;
@property (nonatomic, assign) NSInteger pos;
@property (nonatomic, assign) NSInteger len;

@end

@interface TGTableDeltaUpdater : NSObject

+ (void)updateTable:(WKInterfaceTable *)table oldData:(NSArray *)oldData newData:(NSArray *)newData controllerClassForIndexPath:(Class (^)(TGIndexPath *indexPath))controllerClassForIndexPath;

@end
