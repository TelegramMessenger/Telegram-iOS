#import <Foundation/Foundation.h>

#import <LegacyComponents/ASWatcher.h>
#import <LegacyComponents/ASActor.h>

#import <LegacyComponents/SGraphObjectNode.h>

typedef enum {
    ASStatusSuccess = 0,
    ASStatusFailed = -1
} ASStatus;

#ifdef DEBUG
#define dispatchOnStageQueue dispatchOnStageQueueDebug:__FILE__ line:__LINE__ block
#endif

@class ActionStage;

#ifdef __cplusplus
extern "C" {
#endif

ActionStage *ActionStageInstance();
    
#ifdef __cplusplus
}
#endif

typedef enum {
    TGActorRequestChangePriority = 1
} TGActorRequestFlags;

@interface ActionStage : NSObject

- (dispatch_queue_t)globalStageDispatchQueue;
#ifdef DEBUG
- (void)dispatchOnStageQueueDebug:(const char *)function line:(int)line block:(dispatch_block_t)block;
#else
- (void)dispatchOnStageQueue:(dispatch_block_t)block;
#endif

- (NSFileManager *)globalFileManager;

- (bool)isCurrentQueueStageQueue;

- (void)cancelActorTimeout:(NSString *)path;

- (NSString *)genericStringForParametrizedPath:(NSString *)path;

- (void)requestActor:(NSString *)path options:(NSDictionary *)options flags:(int)flags watcher:(id<ASWatcher>)watcher;
- (void)requestActor:(NSString *)path options:(NSDictionary *)options watcher:(id<ASWatcher>)watcher;
- (void)changeActorPriority:(NSString *)path;

- (NSArray *)rejoinActionsWithGenericPathNow:(NSString *)genericPath prefix:(NSString *)prefix watcher:(id<ASWatcher>)watcher;
- (bool)isExecutingActorsWithGenericPath:(NSString *)genericPath;
- (bool)isExecutingActorsWithPathPrefix:(NSString *)pathPrefix;
- (NSArray *)executingActorsWithPathPrefix:(NSString *)pathPrefix;
- (ASActor *)executingActorWithPath:(NSString *)path;

- (void)watchForPath:(NSString *)path watcher:(id<ASWatcher>)watcher;
- (void)watchForPaths:(NSArray *)paths watcher:(id<ASWatcher>)watcher;
- (void)watchForGenericPath:(NSString *)path watcher:(id<ASWatcher>)watcher;
- (void)watchForMessagesToWatchersAtGenericPath:(NSString *)genericPath watcher:(id<ASWatcher>)watcher;
- (void)removeWatcherByHandle:(ASHandle *)actionHandle;
- (void)removeWatcher:(id<ASWatcher>)watcher;
- (void)removeWatcherByHandle:(ASHandle *)actionHandle fromPath:(NSString *)path;
- (void)removeWatcher:(id<ASWatcher>)watcher fromPath:(NSString *)path;
- (void)removeAllWatchersFromPath:(NSString *)path;

- (bool)requestActorStateNow:(NSString *)path;

- (void)dispatchResource:(NSString *)path resource:(id)resource arguments:(id)arguments;
- (void)dispatchResource:(NSString *)path resource:(id)resource;

- (void)actionCompleted:(NSString *)action result:(id)result;
- (void)dispatchMessageToWatchers:(NSString *)path messageType:(NSString *)messageType message:(id)message;
- (void)actionFailed:(NSString *)action reason:(int)reason;
- (void)nodeRetrieved:(NSString *)path node:(SGraphNode *)node;
- (void)nodeRetrieveProgress:(NSString *)path progress:(float)progress;
- (void)nodeRetrieveFailed:(NSString *)path;

@end
