#import "WKInterfaceTable+TGDataDrivenTable.h"
#import <objc/runtime.h>
#import "TGWatchCommon.h"

#import "TGTableDeltaUpdater.h"

typedef enum
{
    TGTableDataEntryTypeRow,
    TGTableDataEntryTypeSection,
    TGTableDataEntryTypeHeader,
    TGTableDataEntryTypeFooter
} TGTableDataEntryType;

@interface TGTableDataEntry : NSObject

@property (nonatomic, readonly) TGTableDataEntryType type;
@property (nonatomic, readonly) Class controllerClass;
@property (nonatomic, assign) NSUInteger section;
@property (nonatomic, assign) NSUInteger row;

@property (nonatomic, readonly) TGIndexPath *indexPath;
@property (nonatomic, readonly) NSString *controllerIdentifier;

@end

@implementation TGTableDataEntry

- (instancetype)initWithControllerClass:(Class)controllerClass type:(TGTableDataEntryType)type
{
    NSParameterAssert(type == TGTableDataEntryTypeHeader || type == TGTableDataEntryTypeFooter);
    return [self initWithControllerClass:controllerClass section:NSNotFound row:NSNotFound type:type];
}

- (instancetype)initWithControllerClass:(Class)controllerClass section:(NSInteger)section
{
    return [self initWithControllerClass:controllerClass section:section row:NSNotFound type:TGTableDataEntryTypeSection];
}

- (instancetype)initWithControllerClass:(Class)controllerClass section:(NSUInteger)section row:(NSUInteger)row
{
    return [self initWithControllerClass:controllerClass section:section row:row type:TGTableDataEntryTypeRow];
}

- (instancetype)initWithControllerClass:(Class)controllerClass section:(NSUInteger)section row:(NSUInteger)row type:(TGTableDataEntryType) type
{
    self = [super init];
    if (self != nil)
    {
        _controllerClass = controllerClass;
        _section = section;
        _row = row;
        _type = type;
    }
    return self;
}

- (TGIndexPath *)indexPath
{
    if (self.section == NSNotFound || self.row == NSNotFound)
        return nil;
    
    return [TGIndexPath indexPathForRow:self.row inSection:self.section];
}

- (NSString *)controllerIdentifier
{
    return [self.controllerClass identifier];
}

- (NSUInteger)hash
{
    return self.controllerIdentifier.hash ^ self.section ^ self.row;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (!object || ![object isKindOfClass:[self class]])
        return NO;
    
    TGTableDataEntry *entry = (TGTableDataEntry *)object;
    return (self.controllerClass == entry.controllerClass && self.section == entry.section && self.row == entry.row);
}

@end


@implementation TGTableRowController

- (bool)_isVisible
{
    if (self.isVisible == nil)
        return true;
    
    return self.isVisible();
}

- (void)setupInterface
{
    _initialized = true;
}

- (void)notifyVisiblityChange
{
    
}

+ (NSString *)identifier
{
    return nil;
}

@end


@implementation WKInterfaceTable (TGDataDrivenTable)

@dynamic tableDataSource;

- (void)reloadData
{
    NSArray *tableData = [self fetchDataFromDataSource:self.tableDataSource];
    NSArray *rowControllerIdentifiers = [tableData valueForKey:@"controllerIdentifier"];
    [self setRowTypes:rowControllerIdentifiers];
    [self updateRowControllersWithData:tableData];
    [self setTableData:tableData];
}

- (void)reloadHeader
{
    if ([self _hasHeader] && self.numberOfRows > 0)
        [self updateRowAtIndex:0];
}

- (void)reloadFooter
{
    if ([self _hasFooter] && self.numberOfRows > 0)
        [self updateRowAtIndex:self.numberOfRows - 1];
}

- (void)reloadSectionHeader:(NSUInteger)section
{
    NSUInteger rowIndex = [self rowIndexForSection:section];
    if (rowIndex != NSNotFound)
        [self updateRowAtIndex:rowIndex];
}

- (NSArray *)fetchDataFromDataSource:(id<TGTableDataSource>)dataSource
{
    NSParameterAssert(dataSource);
    
    NSMutableArray *tableData = [[NSMutableArray alloc] init];
    
    if ([dataSource respondsToSelector:@selector(headerControllerClassForTable:)])
    {
        Class controllerClass = [dataSource headerControllerClassForTable:self];
        if (controllerClass != nil)
            [tableData addObject:[[TGTableDataEntry alloc] initWithControllerClass:controllerClass type:TGTableDataEntryTypeHeader]];
    }
    
    NSUInteger sectionsCount = 1;
    if ([dataSource respondsToSelector:@selector(numberOfSectionsInTable:)])
        sectionsCount = [dataSource numberOfSectionsInTable:self];
    
    bool mayHaveSectionHeader = [dataSource respondsToSelector:@selector(table:controllerClassForSection:)];
    
    for (NSUInteger section = 0; section < sectionsCount; section++)
    {
        if (mayHaveSectionHeader)
        {
            Class controllerClass = [dataSource table:self controllerClassForSection:section];
            if (controllerClass != nil)
                [tableData addObject:[[TGTableDataEntry alloc] initWithControllerClass:controllerClass section:section]];
        }
        
        NSUInteger rowsCount = [dataSource numberOfRowsInTable:self section:section];
        for (NSUInteger row = 0; row < rowsCount; row++)
        {
            TGIndexPath *indexPath = [TGIndexPath indexPathForRow:row inSection:section];
            Class controllerClass = [dataSource table:self rowControllerClassAtIndexPath:indexPath];
            NSAssert(controllerClass, @"Row controller class is a must");
            [tableData addObject:[[TGTableDataEntry alloc] initWithControllerClass:controllerClass section:section row:row]];
        }
    }
    
    if ([dataSource respondsToSelector:@selector(footerControllerClassForTable:)])
    {
        Class controllerClass = [dataSource footerControllerClassForTable:self];
        if (controllerClass != nil)
            [tableData addObject:[[TGTableDataEntry alloc] initWithControllerClass:controllerClass type:TGTableDataEntryTypeFooter]];
    }
    
    return tableData;
}

- (void)updateRowControllersWithData:(NSArray *)tableData
{
    NSEnumerationOptions options = kNilOptions;
    if (self.reloadDataReversed)
        options = NSEnumerationReverse;
    
    [tableData enumerateObjectsWithOptions:options usingBlock:^(TGTableDataEntry *tableEntry, NSUInteger index, BOOL *stop)
    {
        [self updateRowAtIndex:index withTableData:tableData];
    }];
}

#pragma mark -

- (bool)_hasHeader
{
    return ([self.tableDataSource respondsToSelector:@selector(headerControllerClassForTable:)] && [self.tableDataSource headerControllerClassForTable:self] != nil);
}

- (TGTableRowController *)headerController
{
    if ([self _hasHeader])
        return [self rowControllerAtIndex:0];
    
    return nil;
}

- (bool)_hasFooter
{
    return ([self.tableDataSource respondsToSelector:@selector(footerControllerClassForTable:)] && [self.tableDataSource footerControllerClassForTable:self] != nil);
}

- (TGTableRowController *)footerController
{
    if ([self _hasFooter])
        return [self rowControllerAtIndex:self.numberOfRows - 1];
    
    return nil;
}

- (TGTableRowController *)controllerForRowAtIndexPath:(TGIndexPath *)indexPath
{
    NSInteger rowIndex = [self rowIndexForIndexPath:indexPath];
    if (rowIndex != NSNotFound)
        return [self rowControllerAtIndex:rowIndex];
    
    return nil;
}

- (TGIndexPath *)indexPathForRowWithController:(TGTableRowController *)controller
{
    for (NSInteger i = 0; i < self.numberOfRows; i++)
    {
        TGTableRowController *rowController = [self rowControllerAtIndex:i];
        if (rowController == controller)
            return [self indexPathForRowIndex:i];
    }
    
    return nil;
}

#pragma mark - 

- (void)beginUpdates
{
    self.isUpdating = true;
    self.rowIndexesToAdd = [[NSMutableArray alloc] init];
    self.rowClassesToAdd = [[NSMutableDictionary alloc] init];
}

- (void)endUpdates
{
    NSAssert(self.isUpdating, @"Call beginUpdates first");
    
    if (!self.isUpdating)
        return;
    
    [self.rowIndexesToAdd sortUsingComparator:^NSComparisonResult(TGIndexPath *obj1, TGIndexPath *obj2)
    {
        NSInteger r1 = obj1.row;
        NSInteger r2 = obj2.row;
        
        if (r1 > r2)
            return NSOrderedDescending;
        if (r1 < r2)
            return NSOrderedAscending;

        return NSOrderedSame;
    }];
    
    self.isUpdating = false;
    
    [self.rowIndexesToAdd enumerateObjectsUsingBlock:^(TGIndexPath *indexPath, NSUInteger idx, BOOL *stop)
    {
        [self insertRowsAtIndexPaths:@[ indexPath ] withRowControllerClass:self.rowClassesToAdd[indexPath]];
    }];
    
    self.rowIndexesToAdd = nil;
    self.rowClassesToAdd = nil;
}

#pragma mark -

- (void)insertSections:(NSIndexSet *)sections withSectionControllerClass:(Class)controllerClass
{
    NSMutableIndexSet *rowIndexes = [[NSMutableIndexSet alloc] init];
    NSMutableArray *insertedSections = [[NSMutableArray alloc] init];
    
    [sections enumerateIndexesUsingBlock:^(NSUInteger section, BOOL *stop)
    {
        NSUInteger rowIndex = [self rowIndexForSection:section];
        if (rowIndex != NSNotFound)
        {
            [rowIndexes addIndex:rowIndex];
            [insertedSections addObject:@(section)];
        }
    }];
    
    [self insertRowsAtIndexes:rowIndexes withRowType:[controllerClass identifier]];
    
    if ([self.tableDataSource respondsToSelector:@selector(table:updateSectionController:forSection:)])
    {
        [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop)
        {
            TGTableRowController *controller = [self rowControllerAtIndex:index];
            NSUInteger section = [insertedSections[index] integerValue];
            [self.tableDataSource table:self updateSectionController:controller forSection:section];
        }];
    }
    
    [self _updateTableData];
}

- (void)removeSections:(NSIndexSet *)sections
{
    NSMutableIndexSet *rowIndexes = [[NSMutableIndexSet alloc] init];
    NSArray *tableData = [self tableData];
    NSUInteger count = tableData.count;
    
    [sections enumerateIndexesUsingBlock:^(NSUInteger section, BOOL *stop)
    {
        NSUInteger rowIndex = [self rowIndexForSection:section];
        if (rowIndex != NSNotFound)
        {
            [rowIndexes addIndex:rowIndex];
            
            if (rowIndex < tableData.count - 1)
            {
                NSUInteger subArrayStart = rowIndex + 1;
                NSArray *subRowData = [tableData subarrayWithRange:NSMakeRange(subArrayStart, count - subArrayStart)];
                [subRowData enumerateObjectsUsingBlock:^(TGTableDataEntry *row, NSUInteger index, BOOL *stop2)
                {
                    if (row.section == section)
                        [rowIndexes addIndex:subArrayStart + index];
                    else
                        *stop2 = true;
                }];
            }
        }
    }];
    
    [self removeRowsAtIndexes:rowIndexes];
    
    [self _updateTableData];
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowControllerClass:(Class)controllerClass
{
    if (indexPaths.count == 0)
        return;
    
    if (self.isUpdating)
    {
        [self.rowIndexesToAdd addObjectsFromArray:indexPaths];
        [indexPaths enumerateObjectsUsingBlock:^(TGIndexPath *indexPath, NSUInteger idx, BOOL *stop)
        {
            [self.rowClassesToAdd setObject:controllerClass forKey:indexPath];
        }];
        
        return;
    }
    
    NSArray *tableData = [self fetchDataFromDataSource:self.tableDataSource];
    [self setTableData:tableData];
    
    NSMutableIndexSet *rowIndexes = [[NSMutableIndexSet alloc] init];
  
    for (TGIndexPath *indexPath in indexPaths)
    {
        NSUInteger rowIndex = [self rowIndexForIndexPath:indexPath];
        if (rowIndex != NSNotFound)
            [rowIndexes addIndex:rowIndex];
    }

    [self insertRowsAtIndexes:rowIndexes withRowType:[controllerClass identifier]];
    
    if ([self.tableDataSource respondsToSelector:@selector(table:updateRowController:forIndexPath:)])
    {
        [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop)
        {
            TGTableRowController *controller = [self rowControllerAtIndex:index];
            TGTableDataEntry *tableEntry = tableData[index];
            TGIndexPath *indexPath = [TGIndexPath indexPathForRow:tableEntry.row inSection:tableEntry.section];
            [self.tableDataSource table:self updateRowController:controller forIndexPath:indexPath];
        }];
    }
}

- (void)removeRowsAtIndexPaths:(NSArray *)indexPaths
{
    if (indexPaths.count == 0)
        return;
    
    NSMutableIndexSet *rowIndexes = [[NSMutableIndexSet alloc] init];
    
    for (TGIndexPath *indexPath in indexPaths)
    {
        NSUInteger rowIndex = [self rowIndexForIndexPath:indexPath];
        [rowIndexes addIndex:rowIndex];
    }
    
    [self removeRowsAtIndexes:rowIndexes];
    
    NSArray *tableData = [self fetchDataFromDataSource:self.tableDataSource];
    [self setTableData:tableData];
}

- (void)reloadAllRows
{
    NSMutableArray *reloads = [[NSMutableArray alloc] init];
    NSInteger count = [self.tableDataSource numberOfRowsInTable:self section:0];
    
    for (NSInteger i = 0; i < count; i++)
        [reloads addObject:[TGIndexPath indexPathForRow:i inSection:0]];
    
    [self reloadRowsAtIndexPaths:reloads];
}

- (void)applyBatchChanges:(NSArray *)changes
{
    NSArray *tableData = [self fetchDataFromDataSource:self.tableDataSource];
    [self setTableData:tableData];
    
    NSInteger indexOffset = [self rowIndexForIndexPath:[TGIndexPath indexPathForRow:0 inSection:0]];
    if (indexOffset == NSNotFound)
        indexOffset = 0;
    
    for (TGTableAlignment *alignment in changes)
    {
        if (alignment.pos < 0 || alignment.pos > 1000)
        {
            [self reloadData];
            return;
        }
        
        if (!alignment.deletion)
        {
            for (NSInteger i = alignment.pos; i < alignment.pos + alignment.len; i++)
            {
                NSInteger index = i + indexOffset;
                Class controllerClass = [self.tableDataSource table:self rowControllerClassAtIndexPath:[TGIndexPath indexPathForRow:i inSection:0]];
                [self insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:index] withRowType:[controllerClass identifier]];
            }
        }
        else
        {
            NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];
            for (NSInteger i = alignment.pos; i < alignment.pos + alignment.len; i++)
            {
                [indexSet addIndex:i + indexOffset];
            }
            [self removeRowsAtIndexes:indexSet];
        }
    }
}

- (NSInteger)_indexForIndexPath:(TGIndexPath *)indexPath firstIndex:(NSInteger)firstIndex
{
    return indexPath.row + firstIndex;
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths
{
    if (indexPaths.count == 0)
        return;
    
    NSMutableIndexSet *rowIndexes = [[NSMutableIndexSet alloc] init];
    
    for (TGIndexPath *indexPath in indexPaths)
    {
        NSUInteger rowIndex = [self rowIndexForIndexPath:indexPath];
        if (rowIndex != NSNotFound)
            [rowIndexes addIndex:rowIndex];
    }
    
    [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop)
    {
        [self updateRowAtIndex:index];
    }];
}

- (void)notifyVisiblityChange
{
    for (NSInteger i = 0; i < self.numberOfRows; i++)
    {
        TGTableRowController *controller = [self rowControllerAtIndex:i];
        [controller notifyVisiblityChange];
    }
}

- (void)updateRowAtIndex:(NSUInteger)index
{
    [self updateRowAtIndex:index withTableData:self.tableData];
}

- (void)updateRowAtIndex:(NSUInteger)index withTableData:(NSArray *)tableData
{
    id<TGTableDataSource> dataSource = self.tableDataSource;
    
    TGTableRowController *controller = [self rowControllerAtIndex:index];
    TGTableDataEntry *tableEntry = tableData[index];
    
    if (!controller.initialized)
        [controller setupInterface];
    
    switch (tableEntry.type)
    {
        case TGTableDataEntryTypeHeader:
        {
            if ([dataSource respondsToSelector:@selector(table:updateHeaderController:)])
                [dataSource table:self updateHeaderController:controller];
        }
            break;
            
        case TGTableDataEntryTypeFooter:
        {
            if ([dataSource respondsToSelector:@selector(table:updateFooterController:)])
                [dataSource table:self updateFooterController:controller];
        }
            break;
            
        case TGTableDataEntryTypeSection:
        {
            if ([dataSource respondsToSelector:@selector(table:updateSectionController:forSection:)])
                [dataSource table:self updateSectionController:controller forSection:tableEntry.section];
        }
            break;
            
        case TGTableDataEntryTypeRow:
        {
            if ([dataSource respondsToSelector:@selector(table:updateRowController:forIndexPath:)])
                [dataSource table:self updateRowController:controller forIndexPath:tableEntry.indexPath];
        }
            break;
            
        default:
            break;
    }
}

- (void)_updateTableData
{
    [self setTableData:[self fetchDataFromDataSource:self.tableDataSource]];
}

- (NSArray *)smoothedTableData:(NSArray *)tableData
{
    NSMutableArray *newTableData = [[NSMutableArray alloc] initWithCapacity:tableData.count];
    NSUInteger runningSection = 0, previousSection = 0, runningRow = 0, previousRow = 0;
    
    TGTableDataEntry *firstRowData = [tableData firstObject];
    previousSection = firstRowData.section;
    
    for (TGTableDataEntry *tableEntry in tableData)
    {
        NSUInteger section = tableEntry.section;
        NSUInteger row = tableEntry.row;
        
        if (section < NSNotFound)
        {
            if (section != previousSection && previousSection != NSNotFound)
            {
                runningSection++;
                runningRow = 0;
            }
            
            section = runningSection;
            
            if (row < NSNotFound)
            {
                row = runningRow;
                runningRow++;
            }
        }
        
        previousSection = tableEntry.section;

        TGTableDataEntry *newTableEntry = [[TGTableDataEntry alloc] initWithControllerClass:tableEntry.controllerClass section:section row:row];
        [newTableData addObject:newTableEntry];
    }
    
    return newTableData;
}

#pragma mark -

- (void)scrollToSection:(NSUInteger)section
{
    NSUInteger rowIndex = [self rowIndexForSection:section];
    if (rowIndex != NSNotFound)
        [self scrollToRowAtIndex:rowIndex];
    else
        [self scrollToRowAtIndexPath:[TGIndexPath indexPathForRow:0 inSection:section]];
}

- (void)scrollToRowAtIndexPath:(TGIndexPath *)indexPath
{
    NSUInteger rowIndex = [self rowIndexForIndexPath:indexPath];
    if (rowIndex != NSNotFound)
        [self scrollToRowAtIndex:rowIndex];
}

- (void)scrollToBottom
{
    [self scrollToRowAtIndex:[self numberOfRows] + 1];
}

#pragma mark -

- (bool)isUpdating
{
    return [objc_getAssociatedObject(self, @selector(isUpdating)) boolValue];
}

- (void)setIsUpdating:(bool)updating
{
    objc_setAssociatedObject(self, @selector(isUpdating), @(updating), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableArray *)rowIndexesToAdd
{
    return objc_getAssociatedObject(self, @selector(rowIndexesToAdd));
}

- (void)setRowIndexesToAdd:(NSMutableArray *)rowIndexesToAdd
{
    objc_setAssociatedObject(self, @selector(rowIndexesToAdd), rowIndexesToAdd, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary *)rowClassesToAdd
{
    return objc_getAssociatedObject(self, @selector(rowClassesToAdd));
}

- (void)setRowClassesToAdd:(NSMutableDictionary *)rowClassesToAdd
{
    objc_setAssociatedObject(self, @selector(rowClassesToAdd), rowClassesToAdd, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id<TGTableDataSource>)tableDataSource
{
    return objc_getAssociatedObject(self, @selector(tableDataSource));
}

- (void)setTableDataSource:(id<TGTableDataSource>)dataSource
{
    objc_setAssociatedObject(self, @selector(tableDataSource), dataSource, OBJC_ASSOCIATION_ASSIGN);
}

- (bool)reloadDataReversed
{
    return [objc_getAssociatedObject(self, @selector(reloadDataReversed)) boolValue];
}

- (void)setReloadDataReversed:(bool)reloadDataReversed
{
    objc_setAssociatedObject(self, @selector(reloadDataReversed), @(reloadDataReversed), OBJC_ASSOCIATION_ASSIGN);
}

- (NSArray *)tableData
{
    return objc_getAssociatedObject(self, @selector(tableData));
}

- (void)setTableData:(NSArray *)tableData
{
    objc_setAssociatedObject(self, @selector(tableData), tableData, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - 

- (TGIndexPath *)indexPathForRowIndex:(NSUInteger)rowIndex
{
    if (rowIndex >= [self tableData].count)
        return nil;
    
    return [[self tableData][rowIndex] indexPath];
}

- (NSUInteger)rowIndexForIndexPath:(TGIndexPath *)indexPath
{
    NSParameterAssert(indexPath);
 
    __block NSUInteger rowIndex = NSNotFound;
    
    [[self tableData] enumerateObjectsUsingBlock:^(TGTableDataEntry *tableEntry, NSUInteger index, BOOL *stop)
    {
        if (tableEntry.section == indexPath.section && tableEntry.row == indexPath.row)
        {
            rowIndex = index;
            *stop = true;
        }
    }];
    
    return rowIndex;
}

- (NSUInteger)rowIndexForSection:(NSUInteger)section
{
    return [self rowIndexForIndexPath:[TGIndexPath indexPathForRow:NSNotFound inSection:section]];
}

- (NSUInteger)sectionForRowIndex:(NSUInteger)rowIndex
{
    return [[self tableData][rowIndex] section];
}

@end


@implementation WKInterfaceController (TGDataDrivenTable)

+ (void)load
{
    TGSwizzleMethodImplementation(self.class, @selector(table:didSelectRowAtIndex:), @selector(tg_table:didSelectRowAtIndex:));
}

- (void)tg_table:(WKInterfaceTable *)table didSelectRowAtIndex:(NSInteger)rowIndex
{
    [self tg_table:table didSelectRowAtIndex:rowIndex];
    
    TGTableDataEntry *tableEntry = [table tableData][rowIndex];
    
    switch (tableEntry.type)
    {
        case TGTableDataEntryTypeHeader:
        {
            [self tableDidSelectHeader:table];
        }
            break;
            
        case TGTableDataEntryTypeFooter:
        {
            [self tableDidSelectFooter:table];
        }
            break;
            
        case TGTableDataEntryTypeSection:
        {
            [self table:table didSelectSection:tableEntry.section];
        }
            break;
            
        case TGTableDataEntryTypeRow:
        {
            [self table:table didSelectRowAtIndexPath:tableEntry.indexPath];
        }
            break;
            
        default:
            break;
    }
}

- (void)tableDidSelectHeader:(WKInterfaceTable *)table
{
    
}

- (void)tableDidSelectFooter:(WKInterfaceTable *)table
{
    
}

- (void)table:(WKInterfaceTable *)table didSelectSection:(NSUInteger)section
{
    
}

- (void)table:(WKInterfaceTable *)table didSelectRowAtIndexPath:(TGIndexPath *)indexPath
{
    
}

@end
