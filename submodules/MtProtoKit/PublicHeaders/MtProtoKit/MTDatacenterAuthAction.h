#import <Foundation/Foundation.h>

#import <MtProtoKit/MTDatacenterAuthInfo.h>


@class MTContext;
@class MTDatacenterAuthAction;

@protocol MTDatacenterAuthActionDelegate <NSObject>

- (void)datacenterAuthActionCompleted:(MTDatacenterAuthAction *)action;

@end

@interface MTDatacenterAuthAction : NSObject

@property (nonatomic, readonly) bool tempAuth;
@property (nonatomic, weak) id<MTDatacenterAuthActionDelegate> delegate;
@property (nonatomic, copy) void (^completedWithResult)(bool);

- (instancetype)initWithTempAuth:(bool)tempAuth tempAuthKeyType:(MTDatacenterAuthTempKeyType)tempAuthKeyType bindKey:(MTDatacenterAuthKey *)bindKey;

- (void)execute:(MTContext *)context datacenterId:(NSInteger)datacenterId isCdn:(bool)isCdn;
- (void)cancel;

@end
