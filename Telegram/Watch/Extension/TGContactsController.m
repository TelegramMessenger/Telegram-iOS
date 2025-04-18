#import "TGContactsController.h"
#import "TGWatchCommon.h"
#import "TGBridgeContactsSignals.h"

#import "WKInterfaceTable+TGDataDrivenTable.h"

#import "TGInputController.h"

#import "TGUserRowController.h"

NSString *const TGContactsControllerIdentifier = @"TGContactsController";
const NSUInteger TGContactsControllerBatchCount = 15;

@implementation TGContactsControllerContext

- (instancetype)initWithQuery:(NSString *)query
{
    self = [super init];
    if (self != nil)
    {
        _query = query;
    }
    return self;
}

@end


@interface TGContactsController () <TGTableDataSource>
{
    SMetaDisposable *_contactsDisposable;
    
    TGContactsControllerContext *_context;
    NSArray *_userModels;
}
@end

@implementation TGContactsController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _contactsDisposable = [[SMetaDisposable alloc] init];
        
        [self.alertLabel _setInitialHidden:true];
        [self.table _setInitialHidden:true];
        self.table.tableDataSource = self;
    }
    return self;
}

- (void)dealloc
{
    [_contactsDisposable dispose];
}

- (void)configureWithContext:(TGContactsControllerContext *)context
{
    _context = context;
    
    __weak TGContactsController *weakSelf = self;
    [_contactsDisposable setDisposable:[[[TGBridgeContactsSignals searchContactsWithQuery:_context.query] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *users)
    {
        __strong TGContactsController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (users.count > TGContactsControllerBatchCount)
            strongSelf->_userModels = [users subarrayWithRange:NSMakeRange(0, TGContactsControllerBatchCount)];
        else
            strongSelf->_userModels = users;

        [strongSelf performInterfaceUpdate:^(bool animated)
        {
            __strong TGContactsController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf.activityIndicator.hidden = true;
            
            if (strongSelf->_userModels.count > 0)
            {
                strongSelf.table.hidden = false;
                [strongSelf.table reloadData];
            }
            else
            {
                strongSelf->_alertLabel.hidden = false;
                strongSelf->_alertLabel.text = TGLocalized(@"Watch.Contacts.NoResults");
            }
        }];
    } error:^(id error)
    {
        
    } completed:^
    {
        
    }]];
}

- (void)willActivate
{
    [super willActivate];
    
    [self.table notifyVisiblityChange];
}

- (void)didDeactivate
{
    [super didDeactivate];
}

#pragma mark - 

- (NSUInteger)numberOfRowsInTable:(WKInterfaceTable *)table section:(NSUInteger)section
{
    return _userModels.count;
}

- (Class)table:(WKInterfaceTable *)table rowControllerClassAtIndexPath:(NSIndexPath *)indexPath
{
    return [TGUserRowController class];
}

- (void)table:(WKInterfaceTable *)table updateRowController:(TGUserRowController *)controller forIndexPath:(TGIndexPath *)indexPath
{
    __weak TGContactsController *weakSelf = self;
    controller.isVisible = ^bool
    {
        __strong TGContactsController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return false;
        
        return strongSelf.isVisible;
    };
    [controller updateWithUser:_userModels[indexPath.row] context:_context.context];
}

- (void)table:(WKInterfaceTable *)table didSelectRowAtIndexPath:(TGIndexPath *)indexPath
{
    [self dismissController];
    
    if (_context.completionBlock != nil)
        _context.completionBlock(_userModels[indexPath.row]);
}

+ (NSString *)identifier
{
    return TGContactsControllerIdentifier;
}

@end
