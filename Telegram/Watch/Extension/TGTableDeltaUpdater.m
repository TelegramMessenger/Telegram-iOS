#import "TGTableDeltaUpdater.h"
#import "WKInterfaceTable+TGDataDrivenTable.h"

@implementation TGTableAlignment

+ (instancetype)insertionWithPos:(NSInteger)pos len:(NSInteger)len
{
    TGTableAlignment *alignment = [[TGTableAlignment alloc] init];
    alignment.pos = pos;
    alignment.len = len;
    return alignment;
}

+ (instancetype)deletionWithPos:(NSInteger)pos len:(NSInteger)len
{
    TGTableAlignment *alignment = [[TGTableAlignment alloc] init];
    alignment.deletion = true;
    alignment.pos = pos;
    alignment.len = len;
    return alignment;
}

@end

@implementation TGTableDeltaUpdater

+ (NSArray *)longestCommonSubsequenceForOldData:(NSArray *)oldData newData:(NSArray *)newData
{
    NSUInteger x = oldData.count;
    NSUInteger y = newData.count;
    
    NSInteger lens[x + 1][y + 1];
    for (NSUInteger i = 0; i < (x + 1); i++)
    {
        for (NSUInteger j = 0; j < (y + 1); j++)
        {
            lens[i][j] = 0;
        }
    }
    
    NSMutableArray *result = [[NSMutableArray alloc] init];
    
    for (NSUInteger i = 0; i < x; i++)
    {
        for (NSUInteger j = 0; j < y; j++)
        {
            NSObject<TGTableItem> *oldItem = oldData[i];
            NSObject<TGTableItem> *newItem = newData[j];
            
            if ([[oldItem uniqueIdentifier] isEqual:[newItem uniqueIdentifier]])
                lens[i + 1][j + 1] = lens[i][j] + 1;
            else
                lens[i + 1][j + 1] = MAX(lens[i + 1][j], lens[i][j + 1]);
        }
    }
    
    while (x != 0 && y != 0)
    {
        if (lens[x][y] == lens[x - 1][y])
        {
            --x;
        }
        else if (lens[x][y] == lens[x][y - 1])
        {
            --y;
        }
        else
        {
            [result insertObject:oldData[x - 1] atIndex:0];
            --x;
            --y;
        }
    }
    
    return result;
}

+ (NSArray *)differenceForOldData:(NSArray *)left newData:(NSArray *)right
{
    NSArray *lcs = [self longestCommonSubsequenceForOldData:left newData:right];
    
    NSInteger left_i = 0;
    NSInteger right_i = 0;
    
    NSInteger totalOffset = 0;
    
    NSMutableArray *changes = [[NSMutableArray alloc] init];
    
    for (NSObject<TGTableItem> *element in lcs)
    {
        NSInteger leftOffset = 0;
        NSInteger rightOffset = 0;
        
        while (true)
        {
            if ([[left[left_i] uniqueIdentifier] isEqual:[element uniqueIdentifier]])
            {
                break;
            }
            else
            {
                left_i++;
                leftOffset++;
            }
        }
        
        while (true)
        {
            if ([[right[right_i] uniqueIdentifier] isEqual:[element uniqueIdentifier]])
            {
                break;
            }
            else
            {
                right_i++;
                rightOffset++;
            }
        }
        
        if (rightOffset > leftOffset)
        {
            NSInteger insertions = rightOffset - leftOffset;
            NSInteger pos = left_i + totalOffset;
            [changes addObject:[TGTableAlignment insertionWithPos:pos len:insertions]];
            totalOffset += insertions;
        }
        else if (leftOffset > rightOffset)
        {
            NSInteger deletions = leftOffset - rightOffset;
            NSInteger pos = left_i - deletions + totalOffset;
            [changes addObject:[TGTableAlignment deletionWithPos:pos len:deletions]];
            totalOffset -= deletions;
        }
        
        left_i++;
        right_i++;
    }
    
    NSInteger afterLastInLeft = left.count - left_i;
    NSInteger afterLastInRight = right.count - right_i;
    
    if (afterLastInRight > afterLastInLeft)
    {
        NSInteger insertions = afterLastInRight - afterLastInLeft;
        NSInteger pos = left_i + totalOffset;
        [changes addObject:[TGTableAlignment insertionWithPos:pos len:insertions]];
    }
    else if (afterLastInLeft > afterLastInRight)
    {
        NSInteger deletions = afterLastInLeft - afterLastInRight;
        NSInteger pos = left_i + totalOffset;
        [changes addObject:[TGTableAlignment deletionWithPos:pos len:deletions]];
    }
    
    return changes;
}

+ (void)updateTable:(WKInterfaceTable *)table oldData:(NSArray *)oldData newData:(NSArray *)newData controllerClassForIndexPath:(Class (^)(TGIndexPath *indexPath))controllerClassForIndexPath
{
    if (table.numberOfRows == 0)
    {
        [table reloadData];
        return;
    }
    
    NSArray *changes = [self differenceForOldData:oldData newData:newData];
    [table applyBatchChanges:changes];
    
    NSMutableArray *reloads = [[NSMutableArray alloc] init];
    for (NSInteger i = 0; i < newData.count; i++)
        [reloads addObject:[TGIndexPath indexPathForRow:i inSection:0]];
    
    [table reloadRowsAtIndexPaths:reloads];
}

@end
