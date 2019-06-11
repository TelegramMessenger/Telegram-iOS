#import "TGMediaAssetFetchResultChange.h"

#import <Photos/Photos.h>

@interface TGMediaAssetFetchResultChangeMovePair : NSObject

@property (nonatomic, assign) NSUInteger from;
@property (nonatomic, assign) NSUInteger to;

@end


@interface TGMediaAssetFetchResultChange ()
{
    NSArray *_moves;
}
@end

@implementation TGMediaAssetFetchResultChange

- (void)enumerateMovesWithBlock:(void (^)(NSUInteger, NSUInteger))handler
{
    if (handler == nil)
        return;
    
    for (TGMediaAssetFetchResultChangeMovePair *move in _moves)
        handler(move.from, move.to);
}

+ (instancetype)changeWithPHFetchResultChangeDetails:(PHFetchResultChangeDetails *)changeDetails reversed:(bool)reversed
{
    if (changeDetails == nil)
        return nil;
    
    TGMediaAssetFetchResultChange *change = [[TGMediaAssetFetchResultChange alloc] init];
    change->_fetchResultBeforeChanges = [[TGMediaAssetFetchResult alloc] initWithPHFetchResult:changeDetails.fetchResultBeforeChanges reversed:reversed];
    change->_fetchResultAfterChanges = [[TGMediaAssetFetchResult alloc] initWithPHFetchResult:changeDetails.fetchResultAfterChanges reversed:reversed];
    change->_hasIncrementalChanges = changeDetails.hasIncrementalChanges;
    change->_removedIndexes = [self transponedIndexSet:changeDetails.removedIndexes reversed:reversed initialCount:changeDetails.fetchResultBeforeChanges.count removedCount:0 insertedCount:0]; //changeDetails.removedIndexes;
    change->_insertedIndexes = [self transponedIndexSet:changeDetails.insertedIndexes reversed:reversed initialCount:changeDetails.fetchResultBeforeChanges.count removedCount:changeDetails.removedIndexes.count insertedCount:changeDetails.insertedIndexes.count]; //changeDetails.insertedIndexes;
    change->_updatedIndexes = [self transponedIndexSet:changeDetails.changedIndexes reversed:reversed initialCount:changeDetails.fetchResultBeforeChanges.count removedCount:changeDetails.removedIndexes.count insertedCount:changeDetails.insertedIndexes.count]; //changeDetails.changedIndexes;
    change->_hasMoves = changeDetails.hasMoves;
    
    if (changeDetails.hasMoves)
    {
        NSMutableArray *moves = [[NSMutableArray alloc] init];
        [changeDetails enumerateMovesWithBlock:^(NSUInteger fromIndex, NSUInteger toIndex)
        {
            TGMediaAssetFetchResultChangeMovePair *move = [[TGMediaAssetFetchResultChangeMovePair alloc] init];
            move.from = [self transponedIndex:fromIndex reversed:reversed initialCount:changeDetails.fetchResultBeforeChanges.count removedCount:change->_removedIndexes.count insertedCount:change->_insertedIndexes.count]; //fromIndex;
            move.to = [self transponedIndex:toIndex reversed:reversed initialCount:changeDetails.fetchResultBeforeChanges.count removedCount:change->_removedIndexes.count insertedCount:change->_insertedIndexes.count];
            [moves addObject:move];
        }];
        change->_moves = moves;
    }
    
    return change;
}

+ (NSInteger)transponedIndex:(NSInteger)index reversed:(bool)reversed initialCount:(NSInteger)initialCount removedCount:(NSInteger)removedCount insertedCount:(NSInteger)insertedCount
{
    return reversed ? initialCount - removedCount + insertedCount - index - 1 : index;
}

+ (NSIndexSet *)transponedIndexSet:(NSIndexSet *)indexSet reversed:(bool)reversed initialCount:(NSInteger)initialCount removedCount:(NSInteger)removedCount insertedCount:(NSInteger)insertedCount
{
    if (!reversed)
        return indexSet;
    
    NSMutableIndexSet *transponedIndexSet = [[NSMutableIndexSet alloc] init];
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, __unused BOOL *stop)
    {
        [transponedIndexSet addIndex:[self transponedIndex:idx reversed:reversed initialCount:initialCount removedCount:removedCount insertedCount:insertedCount]];
    }];
    return transponedIndexSet;
}

@end


@implementation TGMediaAssetFetchResultChangeMovePair

@end
