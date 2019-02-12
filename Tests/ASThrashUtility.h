//
//  Tests/ASThrashUtility.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <stdatomic.h>

NS_ASSUME_NONNULL_BEGIN

#define kInitialSectionCount 10
#define kInitialItemCount 10
#define kMinimumItemCount 5
#define kMinimumSectionCount 3
#define kFickleness 0.1
#define kThrashingIterationCount 10

// Set to 1 to use UITableView and see if the issue still exists.
#define USE_UIKIT_REFERENCE 0

#if USE_UIKIT_REFERENCE
#define TableView UITableView
#define CollectionView UICollectionView
#define kCellReuseID @"ASThrashTestCellReuseID"
#else
#define TableView ASTableView
#define CollectionView ASCollectionNode
#endif

static NSInteger ASThrashUpdateCurrentSerializationVersion = 1;

@class ASThrashTestSection;
static atomic_uint ASThrashTestItemNextID;
@interface ASThrashTestItem: NSObject <NSSecureCoding>
@property (nonatomic, readonly) NSInteger itemID;

+ (NSMutableArray <ASThrashTestItem *> *)itemsWithCount:(NSInteger)count;

- (CGFloat)rowHeight;
@end


@interface ASThrashTestSection: NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, readonly) NSMutableArray *items;
@property (nonatomic, readonly) NSInteger sectionID;

+ (NSMutableArray <ASThrashTestSection *> *)sectionsWithCount:(NSInteger)count;

- (instancetype)initWithCount:(NSInteger)count;
- (CGFloat)headerHeight;
@end

@interface ASThrashDataSource: NSObject
#if USE_UIKIT_REFERENCE
<UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate>
#else
<ASTableDataSource, ASTableDelegate, ASCollectionDelegate, ASCollectionDataSource>
#endif

@property (nonatomic, readonly) UIWindow *window;
@property (nonatomic, readonly) TableView *tableView;
@property (nonatomic, readonly) CollectionView *collectionView;
@property (nonatomic) NSArray <ASThrashTestSection *> *data;
// Only access on main
@property (nonatomic) ASWeakSet *allNodes;

- (instancetype)initTableViewDataSourceWithData:(NSArray <ASThrashTestSection *> *)data;
- (instancetype)initCollectionViewDataSourceWithData:(NSArray <ASThrashTestSection *> * _Nullable)data;
- (NSPredicate *)predicateForDeallocatedHierarchy;
@end

@interface NSIndexSet (ASThrashHelpers)
- (NSArray <NSIndexPath *> *)indexPathsInSection:(NSInteger)section;
/// `insertMode` means that for each index selected, the max goes up by one.
+ (NSMutableIndexSet *)randomIndexesLessThan:(NSInteger)max probability:(float)probability insertMode:(BOOL)insertMode;
@end

#if !USE_UIKIT_REFERENCE
@interface ASThrashTestNode: ASCellNode
@property (nonatomic) ASThrashTestItem *item;
@end
#endif

@interface ASThrashUpdate : NSObject <NSSecureCoding>
@property (nonatomic, readonly) NSArray<ASThrashTestSection *> *oldData;
@property (nonatomic, readonly) NSMutableArray<ASThrashTestSection *> *data;
@property (nonatomic, readonly) NSMutableIndexSet *deletedSectionIndexes;
@property (nonatomic, readonly) NSMutableIndexSet *replacedSectionIndexes;
/// The sections used to replace the replaced sections.
@property (nonatomic, readonly) NSMutableArray<ASThrashTestSection *> *replacingSections;
@property (nonatomic, readonly) NSMutableIndexSet *insertedSectionIndexes;
@property (nonatomic, readonly) NSMutableArray<ASThrashTestSection *> *insertedSections;
@property (nonatomic, readonly) NSMutableArray<NSMutableIndexSet *> *deletedItemIndexes;
@property (nonatomic, readonly) NSMutableArray<NSMutableIndexSet *> *replacedItemIndexes;
/// The items used to replace the replaced items.
@property (nonatomic, readonly) NSMutableArray<NSArray <ASThrashTestItem *> *> *replacingItems;
@property (nonatomic, readonly) NSMutableArray<NSMutableIndexSet *> *insertedItemIndexes;
@property (nonatomic, readonly) NSMutableArray<NSArray <ASThrashTestItem *> *> *insertedItems;

- (instancetype)initWithData:(NSArray<ASThrashTestSection *> *)data;

+ (ASThrashUpdate *)thrashUpdateWithBase64String:(NSString *)base64;
- (NSString *)base64Representation;
- (NSString *)logFriendlyBase64Representation;
@end

NS_ASSUME_NONNULL_END
