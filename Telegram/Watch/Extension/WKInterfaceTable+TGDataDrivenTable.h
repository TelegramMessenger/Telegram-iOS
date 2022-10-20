#import <WatchKit/WatchKit.h>
#import "TGIndexPath.h"

@protocol TGTableItem <NSObject>

- (NSString *)uniqueIdentifier;

@end

@interface TGTableRowController : NSObject

@property (nonatomic, readonly) bool initialized;
@property (nonatomic, copy) bool (^isVisible)(void);
- (void)notifyVisiblityChange;
- (bool)_isVisible;

- (void)setupInterface;

+ (NSString *)identifier;

@end

@protocol TGTableDataSource <NSObject>

- (NSUInteger)numberOfRowsInTable:(WKInterfaceTable *)table section:(NSUInteger)section;
- (Class)table:(WKInterfaceTable *)table rowControllerClassAtIndexPath:(TGIndexPath *)indexPath;

@optional

- (NSUInteger)numberOfSectionsInTable:(WKInterfaceTable *)table;

- (Class)headerControllerClassForTable:(WKInterfaceTable *)table;
- (Class)footerControllerClassForTable:(WKInterfaceTable *)table;

- (Class)table:(WKInterfaceTable *)table controllerClassForSection:(NSUInteger)section;

- (void)table:(WKInterfaceTable *)table updateHeaderController:(TGTableRowController *)controller;
- (void)table:(WKInterfaceTable *)table updateFooterController:(TGTableRowController *)controller;

- (void)table:(WKInterfaceTable *)table updateSectionController:(TGTableRowController *)controller forSection:(NSUInteger)section;

- (void)table:(WKInterfaceTable *)table updateRowController:(TGTableRowController *)controller forIndexPath:(TGIndexPath *)indexPath;

@end


@interface WKInterfaceTable (TGDataDrivenTable)

@property (nonatomic, weak) id<TGTableDataSource> tableDataSource;

@property (nonatomic, readonly) TGTableRowController *headerController;
@property (nonatomic, readonly) TGTableRowController *footerController;

@property (nonatomic, assign) bool reloadDataReversed;

- (TGTableRowController *)controllerForRowAtIndexPath:(TGIndexPath *)indexPath;
- (TGIndexPath *)indexPathForRowWithController:(TGTableRowController *)controller;

- (void)reloadData;

- (void)reloadHeader;
- (void)reloadFooter;
- (void)reloadSectionHeader:(NSUInteger)section;

- (void)beginUpdates;
- (void)endUpdates;

- (void)scrollToSection:(NSUInteger)section;
- (void)scrollToRowAtIndexPath:(TGIndexPath *)indexPath;
- (void)scrollToBottom;

- (void)insertSections:(NSIndexSet *)sections withSectionControllerClass:(Class)controllerClass;
- (void)removeSections:(NSIndexSet *)sections;

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowControllerClass:(Class)controllerClass;
- (void)removeRowsAtIndexPaths:(NSArray *)indexPaths;
- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths;
- (void)reloadAllRows;

- (void)applyBatchChanges:(NSArray *)changes;

- (void)notifyVisiblityChange;

- (TGIndexPath *)indexPathForRowIndex:(NSUInteger)rowIndex;

@end


@interface WKInterfaceController (TGDataDrivenTable)

- (void)tableDidSelectHeader:(WKInterfaceTable *)table;
- (void)tableDidSelectFooter:(WKInterfaceTable *)table;
- (void)table:(WKInterfaceTable *)table didSelectSection:(NSUInteger)section;
- (void)table:(WKInterfaceTable *)table didSelectRowAtIndexPath:(TGIndexPath *)indexPath;

@end
