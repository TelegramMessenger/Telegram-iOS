#import "TGStickerPacksController.h"
#import "TGWatchCommon.h"
#import "TGBridgeStickersSignals.h"
#import "TGBridgeStickerPack.h"

#import "WKInterfaceTable+TGDataDrivenTable.h"

#import "TGStickerPackRowController.h"

#import "TGStickersController.h"

NSString *const TGStickerPacksControllerIdentifier = @"TGStickerPacksController";

@implementation TGStickerPacksControllerContext

- (instancetype)initWithStickerPacks:(NSArray *)stickerPacks
{
    self = [super init];
    if (self != nil)
    {
        _stickerPacks = stickerPacks;
    }
    return self;
}

@end

@interface TGStickerPacksController () <TGTableDataSource>
{
    TGStickerPacksControllerContext *_context;
    
    NSArray *_stickerPackModels;
}
@end

@implementation TGStickerPacksController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [self.table _setInitialHidden:true];
        self.table.tableDataSource = self;
    }
    return self;
}

- (void)configureWithContext:(TGStickerPacksControllerContext *)context
{
    _context = context;
    
    _stickerPackModels = context.stickerPacks;
    
    __weak TGStickerPacksController *weakSelf = self;
    [self performInterfaceUpdate:^(bool animated)
    {
        __strong TGStickerPacksController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
         
        strongSelf.activityIndicator.hidden = true;
        [strongSelf.table reloadData];
    }];
}

- (void)willActivate
{
    [super willActivate];
    
    [self.table notifyVisiblityChange];
}

#pragma mark - 

- (Class)table:(WKInterfaceTable *)table rowControllerClassAtIndexPath:(NSIndexPath *)indexPath
{
    return [TGStickerPackRowController class];
}

- (NSUInteger)numberOfRowsInTable:(WKInterfaceTable *)table section:(NSUInteger)section
{
    return _stickerPackModels.count;
}

- (void)table:(WKInterfaceTable *)table updateRowController:(TGStickerPackRowController *)controller forIndexPath:(TGIndexPath *)indexPath
{
    __weak TGStickerPacksController *weakSelf = self;
    controller.isVisible = ^bool
    {
        __strong TGStickerPacksController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return false;
        
        return strongSelf.isVisible;
    };
    [controller updateWithStickerPack:_stickerPackModels[indexPath.row]];
}

- (void)table:(WKInterfaceTable *)table didSelectRowAtIndexPath:(TGIndexPath *)indexPath
{
    [self dismissController];
    
    if (_context.completionBlock != nil)
        _context.completionBlock(_stickerPackModels[indexPath.row]);
}

#pragma mark - 

+ (NSString *)identifier
{
    return TGStickerPacksControllerIdentifier;
}

@end
