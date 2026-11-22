#import "TGBotCommandController.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"
#import <SSignalKit/SSignalKit.h>

#import "WKInterfaceTable+TGDataDrivenTable.h"

#import "TGUserRowController.h"

NSString *const TGBotCommandControllerIdentifier = @"TGBotCommandController";

NSString *const TGBotCommandKey = @"command";
NSString *const TGBotCommandUserKey = @"user";
NSString *const TGBotCommandListKey = @"list";

@implementation TGBotCommandControllerContext

@end


@interface TGBotCommandController () <TGTableDataSource>
{
    SMetaDisposable *_commandDisposable;
    NSArray *_commandList;
    
    TGBotCommandControllerContext *_context;
}
@end

@implementation TGBotCommandController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _commandDisposable = [[SMetaDisposable alloc] init];
        
        [self.table _setInitialHidden:true];
        self.table.tableDataSource = self;
    }
    return self;
}

- (void)dealloc
{
    [_commandDisposable dispose];
}

- (void)configureWithContext:(TGBotCommandControllerContext *)context
{
    _context = context;
    
    __weak TGBotCommandController *weakSelf = self;
    [_commandDisposable setDisposable:[[context.commandListSignal deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *next)
    {
        __strong TGBotCommandController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
       
        strongSelf->_commandList = next;
        [strongSelf performInterfaceUpdate:^(bool animated)
        {
            __strong TGBotCommandController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf.activityIndicator.hidden = true;
            [strongSelf.table reloadData];
            strongSelf.table.hidden = false;
        }];
    }]];
}

#pragma mark - 

- (Class)table:(WKInterfaceTable *)table rowControllerClassAtIndexPath:(TGIndexPath *)indexPath
{
    return [TGUserRowController class];
}

- (NSUInteger)numberOfRowsInTable:(WKInterfaceTable *)table section:(NSUInteger)section
{
    return [self numberOfAvailableCommands];
}

- (void)table:(WKInterfaceTable *)table updateRowController:(TGUserRowController *)controller forIndexPath:(TGIndexPath *)indexPath
{
    NSDictionary *dict = [self dictionaryForRow:indexPath.row];
    TGBridgeBotCommandInfo *commandInfo = dict[TGBotCommandKey];
    TGBridgeUser *botUser = dict[TGBotCommandUserKey];
    [controller updateWithBotCommandInfo:commandInfo botUser:botUser context:_context.context];
}

- (void)table:(WKInterfaceTable *)table didSelectRowAtIndexPath:(TGIndexPath *)indexPath
{
    [self dismissController];
    
    NSDictionary *dict = [self dictionaryForRow:indexPath.row];
    TGBridgeBotCommandInfo *commandInfo = dict[TGBotCommandKey];
    TGBridgeUser *botUser = dict[TGBotCommandUserKey];
    
    bool isSingleBot = (_commandList.count == 1);
    NSString *mention = isSingleBot ? @"" : [NSString stringWithFormat:@"@%@", botUser.userName];
    NSString *command = [NSString stringWithFormat:@"/%@%@", commandInfo.command, mention];
    
    if (_context.completionBlock != nil)
        _context.completionBlock(command);
}

- (NSDictionary *)dictionaryForRow:(NSUInteger)row
{
    NSRange currentRange = NSMakeRange(0, 0);
    for (NSDictionary *dict in _commandList)
    {
        NSArray *commandList = dict[TGBotCommandListKey];
        currentRange = NSMakeRange(currentRange.location + currentRange.length, commandList.count);
        
        NSInteger transposedRow = row - currentRange.location;
        if (transposedRow >= 0 && transposedRow < currentRange.length)
            return @{ TGBotCommandUserKey: dict[TGBotCommandUserKey], TGBotCommandKey: commandList[transposedRow]};
    }
    
    return nil;
}

- (NSUInteger)numberOfAvailableCommands
{
    NSUInteger count = 0;
    for (NSDictionary *dict in _commandList)
    {
        id commandList = dict[TGBotCommandListKey];
        if ([commandList isKindOfClass:[NSArray class]])
            count += [commandList count];
    }
    
    return count;
}

#pragma mark -

+ (NSString *)identifier
{
    return TGBotCommandControllerIdentifier;
}

@end
