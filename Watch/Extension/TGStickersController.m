#import "TGStickersController.h"
#import "TGWatchCommon.h"
#import "TGBridgeStickersSignals.h"
#import "TGBridgeStickerPack.h"

#import "WKInterfaceTable+TGDataDrivenTable.h"
#import "TGTableDeltaUpdater.h"

#import "TGStickersHeaderController.h"
#import "TGStickersSectionHeaderController.h"
#import "TGStickersRowController.h"

#import "TGStickerPacksController.h"

NSString *const TGStickersControllerIdentifier = @"TGStickersController";

@implementation TGStickersControllerContext

@end


@interface TGStickersController () <TGTableDataSource>
{
    TGStickersControllerContext *_context;
    
    TGBridgeStickerPack *_stickerPack;
    
    SMetaDisposable *_stickerPacksDisposable;
    SMetaDisposable *_recentStickersDisposable;
    NSArray *_stickerPackModels;
    NSArray *_stickerModels;
}
@end

@implementation TGStickersController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _stickerPacksDisposable = [[SMetaDisposable alloc] init];
        _recentStickersDisposable = [[SMetaDisposable alloc] init];
        
        [self.alertGroup _setInitialHidden:true];
        [self.table _setInitialHidden:true];
        self.table.tableDataSource = self;
    }
    return self;
}

- (void)dealloc
{
    [_stickerPacksDisposable dispose];
    [_recentStickersDisposable dispose];
}

- (void)configureWithContext:(TGStickersControllerContext *)context
{
    _context = context;
    
    [self reloadData];
}

- (void)reloadData
{
    __weak TGStickersController *weakSelf = self;
    void (^updateInteface)(bool, NSArray *, bool) = ^(bool initial, NSArray *oldData, bool recent)
    {
        __strong TGStickersController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf performInterfaceUpdate:^(bool animated)
        {
            __strong TGStickersController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (recent && strongSelf->_stickerModels.count == 0)
            {
                strongSelf.alertGroup.hidden = false;
                strongSelf.alertLabel.text = TGLocalized(@"Watch.Stickers.RecentPlaceholder");
            }
            else
            {
                strongSelf.alertGroup.hidden = true;
            }
            
            strongSelf.activityIndicator.hidden = true;
            strongSelf.table.hidden = false;
            
            [strongSelf.table reloadData];
        }];
    };

    if (_stickerPack == nil)
    {
//        [_stickerPacksDisposable setDisposable:[[[TGBridgeStickersSignals stickerPacks] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *stickerPacks)
//        {
//            __strong TGStickersController *strongSelf = weakSelf;
//            if (strongSelf == nil)
//                return;
//
//            strongSelf->_stickerPackModels = stickerPacks;
//        }]];
        [_recentStickersDisposable setDisposable:[[[TGBridgeStickersSignals recentStickersWithLimit:24] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *recent)
        {
            __strong TGStickersController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            NSArray *currentStickerModels = strongSelf->_stickerModels;
            bool initial = currentStickerModels == nil;
            if (![currentStickerModels isEqual:recent]) {
                strongSelf->_stickerModels = recent;
                updateInteface(initial, currentStickerModels, true);
            }
        }]];
    }
    else
    {
        [_recentStickersDisposable setDisposable:nil];
        
        _stickerModels = _stickerPack.documents;
        updateInteface(true, nil, false);
    }
}

- (void)willActivate
{
    [super willActivate];
    
    [self.table notifyVisiblityChange];
}

#pragma mark -

- (NSUInteger)numberOfSectionsInTable:(WKInterfaceTable *)table
{
    return 1;
}

- (NSUInteger)numberOfRowsInTable:(WKInterfaceTable *)table section:(NSUInteger)section
{
    return (NSInteger)ceilf(_stickerModels.count / 2.0f);
}

- (Class)table:(WKInterfaceTable *)table rowControllerClassAtIndexPath:(TGIndexPath *)indexPath
{
    return [TGStickersRowController class];
}

- (void)table:(WKInterfaceTable *)table updateRowController:(TGStickersRowController *)controller forIndexPath:(TGIndexPath *)indexPath
{
    NSInteger leftIndex = indexPath.row * 2;
    NSInteger rightIndex = indexPath.row * 2 + 1;
    
    TGBridgeDocumentMediaAttachment *leftSticker = nil;
    if (leftIndex < _stickerModels.count)
        leftSticker = _stickerModels[leftIndex];
    
    TGBridgeDocumentMediaAttachment *rightSticker = nil;
    if (rightIndex < _stickerModels.count)
        rightSticker = _stickerModels[rightIndex];
    
    __weak TGStickersController *weakSelf = self;
    controller.isVisible = ^bool
    {
        __strong TGStickersController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return false;
        
        return strongSelf.isVisible;
    };
    
    [controller updateWithLeftSticker:leftSticker rightSticker:rightSticker];
   
    if (leftSticker != nil)
    {
        controller.leftStickerPressed = ^
        {
            __strong TGStickersController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf completeWithSticker:leftSticker];
        };
    }
    
    if (rightSticker != nil)
    {
        controller.rightStickerPressed = ^
        {
            __strong TGStickersController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf completeWithSticker:rightSticker];
        };
    }
}

- (id<TGInterfaceContext>)contextForSegueWithIdentifer:(NSString *)segueIdentifier table:(WKInterfaceTable *)table indexPath:(TGIndexPath *)indexPath
{
    __weak TGStickersController *weakSelf = self;
    TGStickerPacksControllerContext *context = [[TGStickerPacksControllerContext alloc] initWithStickerPacks:_stickerPackModels];
    context.completionBlock = ^(TGBridgeStickerPack *stickerPack)
    {
        __strong TGStickersController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_stickerPack = stickerPack;
        [strongSelf reloadData];
    };
    
    return context;
}

- (void)completeWithSticker:(TGBridgeDocumentMediaAttachment *)sticker
{
    if (_context.completionBlock != nil)
        _context.completionBlock(sticker);
    
    [self dismissController];
}

+ (NSString *)identifier
{
    return TGStickersControllerIdentifier;
}

@end
