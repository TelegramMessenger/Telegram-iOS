

#import <Foundation/Foundation.h>

@class MTContext;

@class MTDatacenterTransferAuthAction;

@protocol MTDatacenterTransferAuthActionDelegate <NSObject>

- (void)datacenterTransferAuthActionCompleted:(MTDatacenterTransferAuthAction *)action;

@optional

// The transfer ended without a token. Without this method a failure is
// reported through datacenterTransferAuthActionCompleted:.
- (void)datacenterTransferAuthActionFailed:(MTDatacenterTransferAuthAction *)action;

@end

@interface MTDatacenterTransferAuthAction : NSObject

@property (nonatomic, weak) id<MTDatacenterTransferAuthActionDelegate> delegate;

- (void)execute:(MTContext *)context masterDatacenterId:(NSInteger)masterDatacenterId destinationDatacenterId:(NSInteger)destinationDatacenterId authToken:(id)authToken;
- (void)cancel;

@end
