#import <Foundation/Foundation.h>

@interface SBag : NSObject

- (NSInteger)addItem:(id)item;
- (void)enumerateItems:(void (^)(id))block;
- (void)removeItem:(NSInteger)key;
- (bool)isEmpty;
- (NSArray *)copyItems;

@end
