#import <LegacyComponents/TGKeyCommand.h>

@class TGViewController;

@protocol TGKeyCommandResponder

- (void)processKeyCommand:(UIKeyCommand *)keyCommand;
- (NSArray *)availableKeyCommands;

@optional
- (bool)isExclusive;

@end

@interface TGKeyCommandController : UIResponder

- (instancetype)initWithRootController:(TGViewController *)rootController;
- (void)performActionForKeyCommand:(TGKeyCommand *)keyCommand;

- (bool)isKeyCommandOccupied:(TGKeyCommand *)keyCommand;

+ (bool)keyCommandsSupported;

@end

