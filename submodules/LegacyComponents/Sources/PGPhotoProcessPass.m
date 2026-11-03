#import "PGPhotoProcessPass.h"

NSString *const PGPhotoEnhanceColorSwapShaderString = PGShaderString
(
 varying highp vec2 texCoord;
 
 uniform sampler2D sourceImage;
 
 void main() {
     gl_FragColor = texture2D(sourceImage, texCoord).bgra;
 }
);

@interface PGPhotoProcessPassParameter ()
{
    NSString *_type;
    NSString *_value;
    BOOL _isConst;
}

@property (nonatomic, weak) GPUImageFilter *filter;
@property (nonatomic, assign) GLint uniformIndex;

@end

@implementation PGPhotoProcessPassParameter

- (instancetype)initWithName:(NSString *)name type:(NSString *)type count:(NSInteger)count
{
    self = [super init];
    if (self != nil)
    {
        _name = name;
        _type = type;
        _count = count;
    }
    return self;
}

- (bool)isConst
{
    return _isConst;
}

- (bool)isUniform
{
    return !_isConst;
}

- (void)storeFilter:(GPUImageFilter *)filter uniformIndex:(GLint)uniformIndex
{
    self.filter = filter;
    self.uniformIndex = uniformIndex;
}

- (void)setFloatValue:(CGFloat)floatValue
{
    GPUImageFilter *filter = self.filter;
    [filter setFloat:(GLfloat)floatValue forUniform:self.uniformIndex program:filter.program];
}

- (void)setFloatArray:(NSArray *)floatArray
{
    GPUImageFilter *filter = self.filter;
    
    GLfloat *glArray = malloc(sizeof(GLfloat) * floatArray.count);
    
    [floatArray enumerateObjectsUsingBlock:^(NSNumber *value, NSUInteger index, __unused BOOL *stop)
    {
        glArray[index] = value.floatValue;
    }];
    
    [filter setFloatArray:glArray length:(GLsizei)floatArray.count forUniform:self.uniformIndex program:filter.program];
}

- (void)setColorValue:(UIColor *)colorValue
{
    GPUImageFilter *filter = self.filter;
    GPUVector3 colorVector;
    
    const CGFloat *colors = CGColorGetComponents(colorValue.CGColor);
    size_t componentCount = CGColorGetNumberOfComponents(colorValue.CGColor);
    
    if (componentCount == 4) {
        colorVector.one = (GLfloat)colors[0];
        colorVector.two = (GLfloat)colors[1];
        colorVector.three = (GLfloat)colors[2];
    } else {
        colorVector.one = (GLfloat)colors[0];
        colorVector.two = (GLfloat)colors[0];
        colorVector.three = (GLfloat)colors[0];
    }
        
    [filter setVec3:colorVector forUniform:self.uniformIndex program:filter.program];
}

+ (instancetype)varyingWithName:(NSString *)name type:(NSString *)type
{
    PGPhotoProcessPassParameter *parameter = [[[self class] alloc] initWithName:name type:type count:0];
    parameter->_isVarying = true;
    return parameter;
}

+ (instancetype)parameterWithName:(NSString *)name type:(NSString *)type
{
    return [[[self class] alloc] initWithName:name type:type count:0];
}

+ (instancetype)parameterWithName:(NSString *)name type:(NSString *)type count:(NSInteger)count
{
    return [[[self class] alloc] initWithName:name type:type count:count];
}

+ (instancetype)constWithName:(NSString *)name type:(NSString *)type value:(NSString *)value
{
    PGPhotoProcessPassParameter *parameter = [[[self class] alloc] initWithName:name type:type count:0];
    parameter->_isConst = true;
    parameter->_value = value;
    return parameter;
}

- (NSString *)shaderString
{
    if (_isConst)
    {
        return [NSString stringWithFormat:@"const %@ %@ = %@", _type, _name, _value];
    }
    else if (_isVarying)
    {
        return [NSString stringWithFormat:@"varying %@ %@", _type, _name];
    }
    else
    {
        if (self.count > 0)
            return [NSString stringWithFormat:@"uniform %@ %@[%ld]", _type, _name, _count];
        else
            return [NSString stringWithFormat:@"uniform %@ %@", _type, _name];
    }
}

@end


@implementation PGPhotoProcessPass

- (void)dealloc
{
    [_filter removeAllTargets];
}

- (void)invalidate
{
    
}

- (void)updateParameters
{
}

- (GPUImageOutput <GPUImageInput> *)filter
{
    if (_filter == nil)
        _filter = [[GPUImageFilter alloc] init];
    
    return _filter;
}

@end
