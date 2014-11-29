/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

@class MTRequestContext;
@class MTRequestErrorContext;

@interface MTRequest : NSObject

@property (nonatomic, strong, readonly) id internalId;

@property (nonatomic) id body;
@property (nonatomic, strong) NSArray *decorators;
@property (nonatomic, strong) MTRequestContext *requestContext;
@property (nonatomic, strong) MTRequestErrorContext *errorContext;
@property (nonatomic) bool hasHighPriority;
@property (nonatomic) bool dependsOnPasswordEntry;

@property (nonatomic, copy) void (^completed)(id result, NSTimeInterval completionTimestamp, id error);
@property (nonatomic, copy) void (^progressUpdated)(float progress, NSUInteger packetLength);
@property (nonatomic, copy) void (^acknowledgementReceived)();

@property (nonatomic, copy) bool (^shouldContinueExecutionWithErrorContext)(MTRequestErrorContext *errorContext);
@property (nonatomic, copy) bool (^shouldDependOnRequest)(MTRequest *anotherRequest);

@end
