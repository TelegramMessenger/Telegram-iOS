#import <Foundation/Foundation.h>

@class TGPainting;
@class TGPhotoEntitiesContainerView;

@interface TGPaintUndoManager : NSObject <NSCopying>

@property (nonatomic, weak) TGPainting *painting;
@property (nonatomic, weak) TGPhotoEntitiesContainerView *entitiesContainer;

@property (nonatomic, copy) void (^historyChanged)(void);

@property (nonatomic, readonly) bool canUndo;
- (void)registerUndoWithUUID:(NSInteger)uuid block:(void (^)(TGPainting *, TGPhotoEntitiesContainerView *, NSInteger))block;
- (void)unregisterUndoWithUUID:(NSInteger)uuid;

- (void)undo;

- (void)reset;

@end
