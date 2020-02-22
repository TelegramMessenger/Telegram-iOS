#import "TGKeyCommand.h"
#import "TGKeyCommandController.h"
#import "LegacyComponentsInternal.h"

@implementation TGKeyCommand

+ (TGKeyCommand *)keyCommandWithTitle:(NSString *)title input:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags
{
    if (input == nil)
        input = @"";
    
    TGKeyCommand *keyCommand = [[TGKeyCommand alloc] init];
    keyCommand->_title = title;
    keyCommand->_input = input;
    keyCommand->_modifierFlags = modifierFlags;
    
    return keyCommand;
}

+ (TGKeyCommand *)keyCommandWithUIKeyCommand:(UIKeyCommand *)uiKeyCommand
{
    if (uiKeyCommand == nil)
        return nil;
    
    NSString *title = nil;
    if (iosMajorVersion() >= 9)
        title = uiKeyCommand.discoverabilityTitle;
    
    return [self keyCommandWithTitle:title input:uiKeyCommand.input modifierFlags:uiKeyCommand.modifierFlags];
}

+ (TGKeyCommand *)keyCommandForSystemActionSelector:(SEL)selector
{
    if (selector == @selector(toggleBoldface:))
        return [TGKeyCommand keyCommandWithTitle:nil input:@"B" modifierFlags:UIKeyModifierCommand];
    else if (selector == @selector(toggleItalics:))
        return [TGKeyCommand keyCommandWithTitle:nil input:@"I" modifierFlags:UIKeyModifierCommand];
    else if (selector == @selector(toggleUnderline:))
        return [TGKeyCommand keyCommandWithTitle:nil input:@"U" modifierFlags:UIKeyModifierCommand];
    
    return nil;
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGKeyCommand *command = [[TGKeyCommand alloc] init];
    command->_title = _title;
    command->_input = _input;
    command->_modifierFlags = _modifierFlags;
    
    return command;
}

- (UIKeyCommand *)UIKeyCommand
{
    if (iosMajorVersion() < 7)
        return nil;
    
    if (iosMajorVersion() >= 9 && _title != nil)
        return [UIKeyCommand keyCommandWithInput:_input modifierFlags:_modifierFlags action:@selector(processKeyCommand:) discoverabilityTitle:_title];
    else
        return [UIKeyCommand keyCommandWithInput:_input modifierFlags:_modifierFlags action:@selector(processKeyCommand:)];
}

- (NSUInteger)hash
{
    return _input.hash ^ _modifierFlags;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return true;
    
    if (!object || ![object isKindOfClass:[self class]])
        return false;
    
    TGKeyCommand *keyCommand = (TGKeyCommand *)object;
    
    if (![keyCommand->_input isEqualToString:_input])
        return false;
    
    if (keyCommand->_modifierFlags != _modifierFlags)
        return false;
    
    return true;
}

@end
