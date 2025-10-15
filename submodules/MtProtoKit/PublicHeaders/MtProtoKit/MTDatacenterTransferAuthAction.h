

#import <Foundation/Foundation.h>

@class MTContext;

@class MTDatacenterTransferAuthAction;

@protocol MTDatacenterTransferAuthActionDelegate <NSObject>

- (void)datacenterTransferAuthActionCompleted:(MTDatacenterTransferAuthAction *)action;

@end

@interface MTDatacenterTransferAuthAction : NSObject

@property (nonatomic, weak) id<MTDatacenterTransferAuthActionDelegate> delegate;

- (void)execute:(MTContext *)context masterDatacenterId:(NSInteger)masterDatacenterId destinationDatacenterId:(NSInteger)destinationDatacenterId authToken:(id)authToken;
- (void)cancel;

@end
