#import "PGPhotoToolComposer.h"

#import <LegacyComponents/LegacyComponents.h>

#import "PGPhotoProcessPass.h"
#import "PGPhotoTool.h"

#define PGTick   NSDate *startTime = [NSDate date]
#define PGTock   NSLog(@"%s Time: %f", __func__, -[startTime timeIntervalSinceNow])

NSString *const PGPhotoToolAncillaryShaderString = PGShaderString
(
 highp float getLuma(highp vec3 rgbP) {
     return  (0.299 * rgbP.r) + (0.587 * rgbP.g) + (0.114 * rgbP.b);
 }
 
 lowp vec3 rgbToHsv(lowp vec3 c) {
     highp vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
     highp vec4 p = c.g < c.b ? vec4(c.bg, K.wz) : vec4(c.gb, K.xy);
     highp vec4 q = c.r < p.x ? vec4(p.xyw, c.r) : vec4(c.r, p.yzx);
     
     highp float d = q.x - min(q.w, q.y);
     highp float e = 1.0e-10;
     return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
 }
 
 lowp vec3 hsvToRgb(lowp vec3 c) {
     highp vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
     highp vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
     return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
 }
 
 highp vec3 rgbToHsl(highp vec3 color) {
     highp vec3 hsl;
     
     highp float fmin = min(min(color.r, color.g), color.b);
     highp float fmax = max(max(color.r, color.g), color.b);
     highp float delta = fmax - fmin;
     
     hsl.z = (fmax + fmin) / 2.0;
     
     if (delta == 0.0) {
         hsl.x = 0.0;
         hsl.y = 0.0;
     }
     else {
         if (hsl.z < 0.5)
             hsl.y = delta / (fmax + fmin);
         else
             hsl.y = delta / (2.0 - fmax - fmin);
         
         highp float deltaR = (((fmax - color.r) / 6.0) + (delta / 2.0)) / delta;
         highp float deltaG = (((fmax - color.g) / 6.0) + (delta / 2.0)) / delta;
         highp float deltaB = (((fmax - color.b) / 6.0) + (delta / 2.0)) / delta;
         
         if (color.r == fmax )
             hsl.x = deltaB - deltaG;
         else if (color.g == fmax)
             hsl.x = (1.0 / 3.0) + deltaR - deltaB;
         else if (color.b == fmax)
             hsl.x = (2.0 / 3.0) + deltaG - deltaR;
         
         if (hsl.x < 0.0)
             hsl.x += 1.0;
         else if (hsl.x > 1.0)
             hsl.x -= 1.0;
     }
     
     return hsl;
 }
 
 highp float hueToRgb(highp float f1, highp float f2, highp float hue) {
     if (hue < 0.0)
         hue += 1.0;
     else if (hue > 1.0)
         hue -= 1.0;
     highp float res;
     if ((6.0 * hue) < 1.0)
         res = f1 + (f2 - f1) * 6.0 * hue;
     else if ((2.0 * hue) < 1.0)
         res = f2;
     else if ((3.0 * hue) < 2.0)
         res = f1 + (f2 - f1) * ((2.0 / 3.0) - hue) * 6.0;
     else
         res = f1;
     return res;
 }
 
 highp vec3 hslToRgb(highp vec3 hsl) {
     highp vec3 rgb;
     
     if (hsl.y == 0.0) {
         rgb = vec3(hsl.z);
     }
     else {
         highp float f2;
         
         if (hsl.z < 0.5)
             f2 = hsl.z * (1.0 + hsl.y);
         else
             f2 = (hsl.z + hsl.y) - (hsl.y * hsl.z);
         
         highp float f1 = 2.0 * hsl.z - f2;
         
         rgb.r = hueToRgb(f1, f2, hsl.x + (1.0/3.0));
         rgb.g = hueToRgb(f1, f2, hsl.x);
         rgb.b = hueToRgb(f1, f2, hsl.x - (1.0/3.0));
     }
     
     return rgb;
 }

 highp vec3 rgbToYuv(highp vec3 inP) {
     highp vec3 outP;
     outP.r = getLuma(inP);
     outP.g = (1.0 / 1.772) * (inP.b - outP.r);
     outP.b = (1.0 / 1.402) * (inP.r - outP.r);
     return outP;
 }

 lowp vec3 yuvToRgb(highp vec3 inP) {
     highp float y = inP.r;
     highp float u = inP.g;
     highp float v = inP.b;
     lowp vec3 outP;
     outP.r = 1.402 * v + y;
     outP.g = (y - (0.299 * 1.402 / 0.587) * v - (0.114 * 1.772 / 0.587) * u);
     outP.b = 1.772 * u + y;
     return outP;
 }

 lowp float easeInOutSigmoid(lowp float value, lowp float strength) {
     lowp float t = 1.0 / (1.0 - strength);
     if (value > 0.5) {
         return 1.0 - pow(2.0 - 2.0 * value, t) * 0.5;
     }
     else {
         return pow(2.0 * value, t) * 0.5;
     }
 }
 
 lowp float powerCurve(lowp float inVal, lowp float mag) {
     lowp float outVal;
     highp float power = 1.0 + abs(mag);
     
     if (mag > 0.0)
         power = 1.0 / power;
    
     inVal = 1.0 - inVal;
     outVal = pow((1.0 - inVal), power);
     
     return outVal;
 }
);

@interface PGPhotoToolFilter : GPUImageFilter
{
    GLint _aspectRatioUniform;
    GLint _widthUniform;
    GLint _heightUniform;
}

@property (nonatomic, assign) CGSize imageSize;

@end

@implementation PGPhotoToolFilter

- (instancetype)initWithFragmentShaderFromString:(NSString *)fragmentShaderString
{
    self = [super initWithFragmentShaderFromString:fragmentShaderString];
    if (self != nil)
    {
        _aspectRatioUniform = [self.program uniformIndex:@"aspectRatio"];
        _widthUniform = [self.program uniformIndex:@"width"];
        _heightUniform = [self.program uniformIndex:@"height"];
    }
    return self;
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex
{
    [super setInputSize:newSize atIndex:textureIndex];
    inputTextureSize = newSize;
    
    [self setFloat:(float)(inputTextureSize.height / inputTextureSize.width) forUniform:_aspectRatioUniform program:self.program];
    
    if (CGSizeEqualToSize(_imageSize, CGSizeZero))
    {
        [self setFloat:(float)newSize.width forUniform:_widthUniform program:self.program];
        [self setFloat:(float)newSize.height forUniform:_heightUniform program:self.program];
    }
}

- (void)setImageSize:(CGSize)imageSize
{
    _imageSize = imageSize;
    [self setFloat:(float)_imageSize.width forUniform:_widthUniform program:self.program];
    [self setFloat:(float)_imageSize.height forUniform:_heightUniform program:self.program];
}

@end

@implementation PGPhotoToolComposer
{
    NSMutableArray *_advancedTools;
    NSMutableArray *_tools;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _tools = [NSMutableArray array];
        _advancedTools = [NSMutableArray array];
    }
    return self;
}

- (NSArray *)tools
{
    return _tools;
}

- (NSArray *)advancedTools
{
    return _advancedTools;
}

- (void)setImageSize:(CGSize)imageSize
{
    _imageSize = imageSize;
    [(PGPhotoToolFilter *)_filter setImageSize:imageSize];
}

- (void)addPhotoTool:(PGPhotoTool *)tool
{
    if (!tool)
        return;

    [_tools addObject:tool];
}

- (void)addPhotoTools:(NSArray *)tools
{
    [_tools addObjectsFromArray:tools];
}

- (void)compose
{
    [_tools sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        PGPhotoTool *t1 = (PGPhotoTool *)obj1;
        PGPhotoTool *t2 = (PGPhotoTool *)obj2;
        
        if (t1.order > t2.order)
            return NSOrderedDescending;
        else if (t1.order < t2.order)
            return NSOrderedAscending;
        else
            return NSOrderedSame;
    }];
    
    NSMutableString *shaderString = [NSMutableString string];
    [shaderString appendString:@"varying highp vec2 texCoord;"];
    [shaderString appendString:@"uniform sampler2D sourceImage;"];
    [shaderString appendString:@"uniform highp float aspectRatio;"];
    [shaderString appendString:@"uniform highp float width;"];
    [shaderString appendString:@"uniform highp float height;"];
    
    NSMutableString *definitionsString = [NSMutableString string];
    NSMutableString *ancillaryShaderString = [NSMutableString string];
    NSMutableString *mainShaderString = [NSMutableString string];
    
    NSMutableArray *uniforms = [NSMutableArray array];
    
    for (PGPhotoTool *tool in _tools)
    {
        switch (tool.type)
        {
            case PGPhotoToolTypeShader:
            {
                if (tool.parameters)
                {
                    for (PGPhotoProcessPassParameter *parameter in tool.parameters)
                    {
                        [definitionsString appendString:[NSString stringWithFormat:@"%@;", parameter.shaderString]];
                        
                        if (parameter.isUniform)
                            [uniforms addObject:parameter];
                    }
                }
                if (tool.ancillaryShaderString != nil)
                    [ancillaryShaderString appendString:tool.ancillaryShaderString];
                
                if (tool.shaderString != nil)
                    [mainShaderString appendString:tool.shaderString];
                
                tool.toolComposer = self;
            }
                break;
             
            case PGPhotoToolTypePass:
            {
                [_advancedTools addObject:tool];
            }
                break;
        }
    }
    
    [shaderString appendString:definitionsString];
    [shaderString appendString:PGPhotoToolAncillaryShaderString];
    
    [shaderString appendString:ancillaryShaderString];
    
    [shaderString appendString:@"void main() {"];
    [shaderString appendString:@"lowp vec4 source = texture2D(sourceImage, texCoord);"];
    [shaderString appendString:@"lowp vec4 result = source;"];
    [shaderString appendString:@"const lowp float toolEpsilon = 0.005;"];
    
    [shaderString appendString:mainShaderString];
    
    [shaderString appendString:@"gl_FragColor = result;"];
    [shaderString appendString:@"}"];
    
    [_filter removeAllTargets];
    
    PGPhotoToolFilter *filter = [[PGPhotoToolFilter alloc] initWithFragmentShaderFromString:shaderString];;
    for (PGPhotoProcessPassParameter *parameter in uniforms)
    {
        GLint uniformIndex = [filter uniformIndexForName:parameter.name];
        [parameter storeFilter:filter uniformIndex:uniformIndex];
    }
    
    for (PGPhotoTool *tool in _tools)
        [tool updateParameters];
    
    _filter = filter;
}

- (bool)shouldBeSkipped
{
    return false;
}

- (void)invalidate
{
    for (PGPhotoTool *tool in _tools)
        [tool invalidate];
}

@end
