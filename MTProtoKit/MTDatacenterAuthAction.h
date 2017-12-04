#import <Foundation/Foundation.h>

@class MTContext;
@class MTDatacenterAuthAction;

@protocol MTDatacenterAuthActionDelegate <NSObject>

- (void)datacenterAuthActionCompleted:(MTDatacenterAuthAction *)action;

@end

@interface MTDatacenterAuthAction : NSObject

@property (nonatomic, weak) id<MTDatacenterAuthActionDelegate> delegate;

- (instancetype)initWithTempAuth:(bool)tempAuth;

- (void)execute:(MTContext *)context datacenterId:(NSInteger)datacenterId isCdn:(bool)isCdn;
- (void)cancel;

@end
