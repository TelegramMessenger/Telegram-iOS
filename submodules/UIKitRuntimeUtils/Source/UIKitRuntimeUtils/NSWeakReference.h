#import <Foundation/Foundation.h>

@interface NSWeakReference : NSObject

@property (nonatomic, weak) id value;

- (instancetype)initWithValue:(id)value;

@end
