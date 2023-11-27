#import <ShelfPack/ShelfPack.h>

#import "shelf-pack.hpp"
#import <memory>

@interface ShelfPackContext () {
    std::unique_ptr<mapbox::ShelfPack> _pack;
    int32_t _nextItemId;
    int _count;
}

@end

@implementation ShelfPackContext

- (instancetype _Nonnull)initWithWidth:(int32_t)width height:(int32_t)height {
    self = [super init];
    if (self != nil) {
        _pack = std::make_unique<mapbox::ShelfPack>(width, height);
    }
    return self;
}

- (bool)isEmpty {
    return _count == 0;
}

- (ShelfPackItem)addItemWithWidth:(int32_t)width height:(int32_t)height {
    ShelfPackItem item = {
        .itemId = -1,
        .x = 0,
        .y = 0,
        .width = 0,
        .height = 0
    };
    
    int32_t itemId = _nextItemId;
    _nextItemId += 1;
    if (const auto bin = _pack->packOne(itemId, width, height)) {
        item.itemId = bin->id;
        item.x = bin->x;
        item.y = bin->y;
        item.width = bin->w;
        item.height = bin->h;
        _count += 1;
    }
    
    return item;
}

- (void)removeItem:(int32_t)itemId {
    if (const auto bin = _pack->getBin(itemId)) {
        _pack->unref(*bin);
        _count -= 1;
    }
}

@end
