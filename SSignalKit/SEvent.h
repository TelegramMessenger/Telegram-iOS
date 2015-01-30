#import <Foundation/Foundation.h>

typedef enum {
    SEventTypeNext,
    SEventTypeError,
    SEventTypeCompleted
} SEventType;

@interface SEvent : NSObject

@property (nonatomic, readonly) SEventType type;
@property (nonatomic, strong, readonly) id data;

- (instancetype)initWithNext:(id)next;
- (instancetype)initWithError:(id)error;
- (instancetype)initWithCompleted;

@end
