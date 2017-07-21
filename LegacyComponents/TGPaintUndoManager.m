#import "TGPaintUndoManager.h"

#import "LegacyComponentsInternal.h"

#import <SSignalKit/SQueue.h>

@interface TGPaintUndoOperation : NSObject <NSCopying>

@property (nonatomic, readonly) NSInteger uuid;
@property (nonatomic, readonly) void (^block)(TGPaintUndoManager *);

- (void)performWithManager:(TGPaintUndoManager *)manager;

+ (instancetype)operationWithUUID:(NSInteger)uuid block:(void (^)(TGPaintUndoManager *manager))block;

@end

@interface TGPaintUndoManager ()
{
    SQueue *_queue;
    NSMutableArray *_operations;
    NSMutableDictionary *_uuidToOperationMap;
}
@end

@implementation TGPaintUndoManager

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _queue = [[SQueue alloc] init];
        _operations = [[NSMutableArray alloc] init];
        _uuidToOperationMap = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGPaintUndoManager *undoManager = [[TGPaintUndoManager alloc] init];
    undoManager->_operations = [[NSMutableArray alloc] initWithArray:_operations copyItems:true];
    undoManager->_uuidToOperationMap = [[NSMutableDictionary alloc] initWithDictionary:_uuidToOperationMap copyItems:true];
    return undoManager;
}

- (bool)canUndo
{
    return _operations.count > 0;
}

- (void)undo
{
    [_queue dispatch:^
    {
        if (_operations.count == 0)
            return;
        
        NSNumber *key = _operations.lastObject;
        TGPaintUndoOperation *operation = _uuidToOperationMap[key];
        [_uuidToOperationMap removeObjectForKey:key];
        [_operations removeLastObject];
        
        TGDispatchOnMainThread(^
        {
            [operation performWithManager:self];
            
            if (self.historyChanged != nil)
                self.historyChanged();
        });
    }];
}

- (void)registerUndoWithUUID:(NSInteger)uuid block:(void (^)(TGPainting *, TGPhotoEntitiesContainerView *, NSInteger))block
{
    [_queue dispatch:^
    {
        TGPaintUndoOperation *operation = [TGPaintUndoOperation operationWithUUID:uuid block:^(TGPaintUndoManager *manager)
        {
            [manager _performBlock:block uuid:uuid];
        }];
        
        NSNumber *key = @(uuid);
        _uuidToOperationMap[key] = operation;
        [_operations addObject:key];
        
        [self _notifyOfHistoryChanges];
    }];
}

- (void)unregisterUndoWithUUID:(NSInteger)uuid
{
    [_queue dispatch:^
    {
        NSNumber *key = @(uuid);
        [_uuidToOperationMap removeObjectForKey:key];
        [_operations removeObject:key];
        
        [self _notifyOfHistoryChanges];
    }];
}

- (void)_performBlock:(void (^)(TGPainting *, TGPhotoEntitiesContainerView *, NSInteger))block uuid:(NSInteger)uuid
{
    block(self.painting, self.entitiesContainer, uuid);
}

- (void)reset
{
    [_queue dispatch:^
    {
        [_operations removeAllObjects];
        [_uuidToOperationMap removeAllObjects];
        
        [self _notifyOfHistoryChanges];
    }];
}

- (void)_notifyOfHistoryChanges
{
    TGDispatchOnMainThread(^
    {
        if (self.historyChanged != nil)
            self.historyChanged();
    });
}

@end


@implementation TGPaintUndoOperation

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGPaintUndoOperation *operation = [[TGPaintUndoOperation alloc] init];
    operation->_uuid = _uuid;
    operation->_block = [_block copy];
    return operation;
}

- (void)performWithManager:(TGPaintUndoManager *)manager
{
    self.block(manager);
}

+ (instancetype)operationWithUUID:(NSInteger)uuid block:(void (^)(TGPaintUndoManager *manager))block
{
    if (uuid == 0 || block == nil)
        return nil;
    
    TGPaintUndoOperation *operation = [[TGPaintUndoOperation alloc] init];
    operation->_uuid = uuid;
    operation->_block = [block copy];
    return operation;
}

@end
