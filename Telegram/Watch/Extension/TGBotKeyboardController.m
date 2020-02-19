#import "TGBotKeyboardController.h"
#import "TGWatchCommon.h"
#import "TGBridgeBotReplyMarkup.h"

#import "WKInterfaceTable+TGDataDrivenTable.h"

#import "TGBotKeyboardButtonController.h"

NSString *const TGBotKeyboardControllerIdentifier = @"TGBotKeyboardController";

@implementation TGBotKeyboardControllerContext

@end


@interface TGBotKeyboardController () <TGTableDataSource>
{
    TGBotKeyboardControllerContext *_context;
    TGBridgeBotReplyMarkup *_replyMarkup;
}

@end

@implementation TGBotKeyboardController

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

- (void)configureWithContext:(TGBotKeyboardControllerContext *)context
{
    _context = context;
    _replyMarkup = context.replyMarkup;
    
    [self.table reloadData];
}

#pragma mark - 

- (NSUInteger)numberOfRowsInTable:(WKInterfaceTable *)table section:(NSUInteger)section
{
    return [self numberOfAvailableButtons];
}

- (Class)table:(WKInterfaceTable *)table rowControllerClassAtIndexPath:(TGIndexPath *)indexPath
{
    return [TGBotKeyboardButtonController class];
}

- (void)table:(WKInterfaceTable *)table updateRowController:(TGBotKeyboardButtonController *)controller forIndexPath:(TGIndexPath *)indexPath
{
    TGBridgeBotReplyMarkupButton *button = [self buttonForRow:indexPath.row];
    [controller updateWithButton:button];
}

- (void)table:(WKInterfaceTable *)table didSelectRowAtIndexPath:(TGIndexPath *)indexPath
{
    [self dismissController];
    
    TGBridgeBotReplyMarkupButton *button = [self buttonForRow:indexPath.row];
    if (_context.completionBlock != nil)
        _context.completionBlock(button.text);
}

#pragma mark - 

- (TGBridgeBotReplyMarkupButton *)buttonForRow:(NSUInteger)row
{
    NSRange currentRange = NSMakeRange(0, 0);
    for (TGBridgeBotReplyMarkupRow *markupRow in _replyMarkup.rows)
    {
        NSArray *buttons = markupRow.buttons;
        currentRange = NSMakeRange(currentRange.location + currentRange.length, buttons.count);
        
        NSInteger transposedRow = row - currentRange.location;
        if (transposedRow >= 0 && transposedRow < currentRange.length)
            return buttons[transposedRow];
    }
    
    return nil;
}

- (NSUInteger)numberOfAvailableButtons
{
    NSUInteger count = 0;
    for (TGBridgeBotReplyMarkupRow *row in _replyMarkup.rows)
        count += row.buttons.count;
    
    return count;
}

#pragma mark -

+ (NSString *)identifier
{
    return TGBotKeyboardControllerIdentifier;
}

@end
