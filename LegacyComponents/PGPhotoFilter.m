#import "PGPhotoFilter.h"

#import "TGPhotoEditorGenericToolView.h"

#import "PGPhotoFilterDefinition.h"

#import "PGPhotoCustomFilterPass.h"
#import "PGPhotoLookupFilterPass.h"
#import "PGPhotoProcessPass.h"

@interface PGPhotoFilter ()
{
    PGPhotoProcessPass *_parameter;
}
@end

@implementation PGPhotoFilter

@synthesize value = _value;
@synthesize tempValue = _tempValue;
@synthesize parameters = _parameters;
@synthesize beingEdited = _beingEdited;
@synthesize shouldBeSkipped = _shouldBeSkipped;
@synthesize parametersChanged = _parametersChanged;
@synthesize disabled = _disabled;
@synthesize segmented = _segmented;

- (instancetype)initWithDefinition:(PGPhotoFilterDefinition *)definition
{
    self = [super init];
    if (self != nil)
    {
        _definition = definition;
        _value = @(self.defaultValue);
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)__unused zone
{
    PGPhotoFilter *filter = [[PGPhotoFilter alloc] initWithDefinition:self.definition];
    filter.value = self.value;
    return filter;
}

- (NSString *)title
{
    return _definition.title;
}

- (NSString *)identifier
{
    return _definition.identifier;
}

- (PGPhotoProcessPass *)pass
{
    if (_pass == nil)
    {
        switch (_definition.type)
        {
            case PGPhotoFilterTypeCustom:
            {
                _pass = [[PGPhotoCustomFilterPass alloc] initWithShaderFile:_definition.shaderFilename textureFiles:_definition.textureFilenames];
            }
                break;
                
            case PGPhotoFilterTypeLookup:
            {
                _pass = [[PGPhotoLookupFilterPass alloc] initWithLookupImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@.png", _definition.lookupFilename]]];
            }
                break;
                
            default:
            {
                _pass = [[PGPhotoProcessPass alloc] init];
            }
                break;
        }
    }
    
    [self updatePassParameters];
    
    return _pass;
}

- (PGPhotoProcessPass *)optimizedPass
{
    switch (_definition.type)
    {
        case PGPhotoFilterTypeCustom:
        {
            return [[PGPhotoCustomFilterPass alloc] initWithShaderFile:_definition.shaderFilename textureFiles:_definition.textureFilenames optimized:true];
        }
            break;
            
        case PGPhotoFilterTypeLookup:
        {
            return [[PGPhotoLookupFilterPass alloc] initWithLookupImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@.png", _definition.lookupFilename]]];
        }
            break;
            
        default:
            break;
    }
    
    return [[PGPhotoProcessPass alloc] init];
}

- (Class)valueClass
{
    return [NSNumber class];
}

- (CGFloat)minimumValue
{
    return 0.0f;
}

- (CGFloat)maximumValue
{
    return 100.0f;
}

- (CGFloat)defaultValue
{
    return 100.0f;
}

- (id)tempValue
{
    if (self.disabled)
    {
        if ([_tempValue isKindOfClass:[NSNumber class]])
            return @0;
    }
    
    return _tempValue;
}

- (id)displayValue
{
    if (self.beingEdited)
        return self.tempValue;
    
    return self.value;
}

- (void)setValue:(id)value
{
    _value = value;
    
    if (!self.beingEdited)
        [self updateParameters];
}

- (void)setTempValue:(id)tempValue
{
    _tempValue = tempValue;
    
    if (self.beingEdited)
        [self updateParameters];
}

- (NSArray *)parameters
{
    return _parameters;
}

- (void)updateParameters
{
    
}

- (void)updatePassParameters
{
    CGFloat value = ((NSNumber *)self.displayValue).floatValue / self.maximumValue;
        
    if ([_pass isKindOfClass:[PGPhotoLookupFilterPass class]])
    {
        PGPhotoLookupFilterPass *pass = (PGPhotoLookupFilterPass *)_pass;
        [pass setIntensity:value];
    }
    else if ([_pass isKindOfClass:[PGPhotoCustomFilterPass class]])
    {
        PGPhotoCustomFilterPass *pass = (PGPhotoCustomFilterPass *)_pass;
        [pass setIntensity:value];
    }
}

- (void)invalidate
{
    _pass = nil;
    _value = @(self.defaultValue);
}

- (void)reset
{
    [_pass.filter removeAllTargets];
}

- (id<TGPhotoEditorToolView>)itemControlViewWithChangeBlock:(void (^)(id newValue, bool animated))changeBlock
{
    __weak PGPhotoFilter *weakSelf = self;
    
    id<TGPhotoEditorToolView> view = [[TGPhotoEditorGenericToolView alloc] initWithEditorItem:self];
    view.valueChanged = ^(id newValue, bool animated)
    {
        __strong PGPhotoFilter *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf.tempValue = newValue;
        
        if (changeBlock != nil)
            changeBlock(newValue, animated);
    };
    return view;
}

- (UIView <TGPhotoEditorToolView> *)itemAreaViewWithChangeBlock:(void (^)(id newValue))__unused changeBlock
{
    return nil;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (!object || ![object isKindOfClass:[self class]])
        return NO;
    
    return ([[(PGPhotoFilter *)object definition].identifier isEqualToString:self.definition.identifier]);
}

+ (PGPhotoFilter *)filterWithDefinition:(PGPhotoFilterDefinition *)definition
{
    return [[[self class] alloc] initWithDefinition:definition];
}

@end
