#import "TGImageLuminanceMap.h"

@interface TGImageLuminanceMap ()
{
    uint8_t *_luminance;
    int _luminanceWidth;
    int _luminanceHeight;
}

@end

@implementation TGImageLuminanceMap

- (instancetype)initWithPixels:(uint8_t *)pixels width:(unsigned int)width height:(unsigned int)height stride:(unsigned int)stride
{
    self = [super init];
    if (self != nil)
    {
        _luminanceWidth = width / 2;
        _luminanceHeight = height / 2;
        
        _luminance = malloc(_luminanceWidth * _luminanceHeight);
        
        for (int y = 0; y < (int)height; y += 2)
        {
            int halfY = y >> 1;
            
            for (int x = 0; x < (int)width; x += 2)
            {
                //(0.299*R + 0.587*G + 0.114*B)
                uint32_t color = *((uint32_t *)&pixels[y * stride + x * 4]);
                
                uint32_t r = (color >> 24) & 0xff;
                uint32_t g = (color >> 16) & 0xff;
                uint32_t b = color & 0xff;
                
                _luminance[halfY * _luminanceWidth + (x >> 1)] = (uint8_t)((r * 299 + g * 587 + b * 114) / 1000);
            }
        }
    }
    return self;
}

- (void)dealloc
{
    if (_luminance != NULL)
        free(_luminance);
}

- (float)averageLuminanceForArea:(CGRect)area maxWeightedDeviation:(float *)__unused maxWeightedDeviation
{
    uint32_t sum = 0;
    
    int minY = (int)(area.origin.y * _luminanceHeight);
    int maxY = (int)((area.origin.y + area.size.height) * _luminanceHeight);
    
    int minX = (int)(area.origin.x * _luminanceWidth);
    int maxX = (int)((area.origin.x + area.size.width) * _luminanceWidth);
    
    if (minY == maxY || minX == maxX)
        return 0.0f;
    
    for (int y = minY; y < maxY; y++)
    {
        for (int x = minX; x < maxX; x++)
        {
            sum += _luminance[y * _luminanceWidth + x];
        }
    }
    
    return sum / (float)((maxY - minY) * (maxX - minX) * 255.0f);
}

@end
