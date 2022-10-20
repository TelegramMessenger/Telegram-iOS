#import "TGDataResource.h"

@interface TGDataResource ()
{
    NSData *_data;
    NSInputStream *_stream;
    UIImage *_image;
    bool _imageDecoded;
}

@end

@implementation TGDataResource

- (instancetype)initWithData:(NSData *)data
{
    self = [super init];
    if (self != nil)
    {
        _data = data;
    }
    return self;
}

- (instancetype)initWithInputStream:(NSInputStream *)stream
{
    self = [super init];
    if (self != nil)
    {
        _stream = stream;
    }
    return self;
}

- (instancetype)initWithImage:(UIImage *)image decoded:(bool)decoded
{
    self = [super init];
    if (self != nil)
    {
        _image = image;
        _imageDecoded = decoded;
    }
    return self;
}

- (void)dealloc
{
    [_stream close];
}

- (NSData *)data
{
    return _data;
}

- (NSInputStream *)stream
{
    return _stream;
}

- (UIImage *)image
{
    return _image;
}

- (bool)isImageDecoded
{
    return _imageDecoded;
}

@end
