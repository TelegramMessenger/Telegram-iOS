#import <Foundation/Foundation.h>

@interface SBag : NSObject

- (NSInteger)addItem:(id _Nonnull)item;
- (void)enumerateItems:(void (^ _Nonnull)(id _Nonnull))block;
- (void)removeItem:(NSInteger)key;
- (bool)isEmpty;
- (NSArray * _Nonnull)copyItems;

@end
