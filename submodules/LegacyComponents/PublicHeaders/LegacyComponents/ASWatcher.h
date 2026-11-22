#import <Foundation/Foundation.h>

#import <LegacyComponents/ASHandle.h>
#import <LegacyComponents/SGraphNode.h>

@protocol ASWatcher <NSObject>

@required

@property (nonatomic, strong, readonly) ASHandle *actionHandle;

@optional

- (void)actorCompleted:(int)status path:(NSString *)path result:(id)result;
- (void)actorReportedProgress:(NSString *)path progress:(float)progress;
- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)arguments;
- (void)actionStageActionRequested:(NSString *)action options:(id)options;
- (void)actorMessageReceived:(NSString *)path messageType:(NSString *)messageType message:(id)message;

@end
