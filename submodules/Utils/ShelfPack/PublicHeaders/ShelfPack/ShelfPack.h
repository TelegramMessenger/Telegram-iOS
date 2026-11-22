#ifndef ShelfPack_h
#define ShelfPack_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int32_t itemId;
    int32_t x;
    int32_t y;
    int32_t width;
    int32_t height;
} ShelfPackItem;

@interface ShelfPackContext : NSObject

@property (nonatomic, readonly) bool isEmpty;

- (instancetype _Nonnull)initWithWidth:(int32_t)width height:(int32_t)height;

- (ShelfPackItem)addItemWithWidth:(int32_t)width height:(int32_t)height;
- (void)removeItem:(int32_t)itemId;

@end

#ifdef __cplusplus
}
#endif

#endif /* ShelfPack_h */
