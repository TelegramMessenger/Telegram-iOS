#import "PGPhotoGaussianBlurFilter.h"

#import "PGPhotoProcessPass.h"

@interface PGPhotoGaussianBlurFilter ()
{
    GPUImageFramebuffer *_secondOutputFramebuffer;
    
    GLProgram *_secondFilterProgram;
    GLint _secondFilterPositionAttribute;
    GLint _secondFilterTextureCoordinateAttribute;
    GLint _secondFilterInputTextureUniform;
    
    GLint _verticalPassTexelWidthOffsetUniform;
    GLint _verticalPassTexelHeightOffsetUniform;
    GLint _horizontalPassTexelWidthOffsetUniform;
    GLint _horizontalPassTexelHeightOffsetUniform;

    GLfloat _verticalPassTexelWidthOffset;
    GLfloat _verticalPassTexelHeightOffset;
    GLfloat _horizontalPassTexelWidthOffset;
    GLfloat _horizontalPassTexelHeightOffset;
    
    CGFloat _verticalTexelSpacing;
    CGFloat _horizontalTexelSpacing;
    
    NSMutableDictionary *_secondProgramUniformStateRestorationBlocks;
    
    NSUInteger _currentRadius;
}

@end

@implementation PGPhotoGaussianBlurFilter

+ (NSString *)vertexShaderForBlurOfRadius:(NSUInteger)blurRadius sigma:(CGFloat)sigma
{
    if (blurRadius < 1)
    {
        return kGPUImageVertexShaderString;
    }
    
    // First, generate the normal Gaussian weights for a given sigma
    GLfloat *standardGaussianWeights = calloc(blurRadius + 1, sizeof(GLfloat));
    GLfloat sumOfWeights = 0.0;
    for (NSUInteger currentGaussianWeightIndex = 0; currentGaussianWeightIndex < blurRadius + 1; currentGaussianWeightIndex++)
    {
        standardGaussianWeights[currentGaussianWeightIndex] = (GLfloat)((1.0 / sqrt(2.0 * M_PI * pow(sigma, 2.0))) * exp(-pow(currentGaussianWeightIndex, 2.0) / (2.0 * pow(sigma, 2.0))));
        
        if (currentGaussianWeightIndex == 0)
            sumOfWeights += standardGaussianWeights[currentGaussianWeightIndex];
        else
            sumOfWeights += 2.0 * standardGaussianWeights[currentGaussianWeightIndex];
    }
    
    for (NSUInteger currentGaussianWeightIndex = 0; currentGaussianWeightIndex < blurRadius + 1; currentGaussianWeightIndex++)
        standardGaussianWeights[currentGaussianWeightIndex] = standardGaussianWeights[currentGaussianWeightIndex] / sumOfWeights;
    
    NSUInteger numberOfOptimizedOffsets = MIN(blurRadius / 2 + (blurRadius % 2), 7U);
    GLfloat *optimizedGaussianOffsets = calloc(numberOfOptimizedOffsets, sizeof(GLfloat));
    
    for (NSUInteger currentOptimizedOffset = 0; currentOptimizedOffset < numberOfOptimizedOffsets; currentOptimizedOffset++)
    {
        GLfloat firstWeight = standardGaussianWeights[currentOptimizedOffset*2 + 1];
        GLfloat secondWeight = standardGaussianWeights[currentOptimizedOffset*2 + 2];
        
        GLfloat optimizedWeight = firstWeight + secondWeight;
        
        optimizedGaussianOffsets[currentOptimizedOffset] = (firstWeight * (currentOptimizedOffset*2 + 1) + secondWeight * (currentOptimizedOffset*2 + 2)) / optimizedWeight;
    }
    
    NSMutableString *shaderString = [[NSMutableString alloc] init];
    [shaderString appendFormat:@"\
     attribute vec4 position;\n\
     attribute vec4 inputTexCoord;\n\
     \n\
     uniform float texelWidthOffset;\n\
     uniform float texelHeightOffset;\n\
     \n\
     varying vec2 blurCoordinates[%lu];\n\
     \n\
     void main()\n\
     {\n\
     gl_Position = position;\n\
     \n\
     vec2 singleStepOffset = vec2(texelWidthOffset, texelHeightOffset);\n", (unsigned long)(1 + (numberOfOptimizedOffsets * 2))];
    
    [shaderString appendString:@"blurCoordinates[0] = inputTexCoord.xy;\n"];
    for (NSUInteger currentOptimizedOffset = 0; currentOptimizedOffset < numberOfOptimizedOffsets; currentOptimizedOffset++)
    {
        [shaderString appendFormat:@"\
         blurCoordinates[%lu] = inputTexCoord.xy + singleStepOffset * %f;\n\
         blurCoordinates[%lu] = inputTexCoord.xy - singleStepOffset * %f;\n", (unsigned long)((currentOptimizedOffset * 2) + 1), optimizedGaussianOffsets[currentOptimizedOffset], (unsigned long)((currentOptimizedOffset * 2) + 2), optimizedGaussianOffsets[currentOptimizedOffset]];
    }
    
    [shaderString appendString:@"}\n"];
    
    free(optimizedGaussianOffsets);
    free(standardGaussianWeights);
    return shaderString;
}

+ (NSString *)fragmentShaderForBlurOfRadius:(NSUInteger)blurRadius sigma:(CGFloat)sigma
{
    if (blurRadius < 1)
        return kGPUImagePassthroughFragmentShaderString;
    
    GLfloat *standardGaussianWeights = calloc(blurRadius + 1, sizeof(GLfloat));
    GLfloat sumOfWeights = 0.0;
    for (NSUInteger currentGaussianWeightIndex = 0; currentGaussianWeightIndex < blurRadius + 1; currentGaussianWeightIndex++)
    {
        standardGaussianWeights[currentGaussianWeightIndex] = (GLfloat)((1.0 / sqrt(2.0 * M_PI * pow(sigma, 2.0))) * exp(-pow(currentGaussianWeightIndex, 2.0) / (2.0 * pow(sigma, 2.0))));
        
        if (currentGaussianWeightIndex == 0)
        {
            sumOfWeights += standardGaussianWeights[currentGaussianWeightIndex];
        }
        else
        {
            sumOfWeights += 2.0 * standardGaussianWeights[currentGaussianWeightIndex];
        }
    }
    
    for (NSUInteger currentGaussianWeightIndex = 0; currentGaussianWeightIndex < blurRadius + 1; currentGaussianWeightIndex++)
        standardGaussianWeights[currentGaussianWeightIndex] = standardGaussianWeights[currentGaussianWeightIndex] / sumOfWeights;
    
    NSUInteger numberOfOptimizedOffsets = MIN(blurRadius / 2 + (blurRadius % 2), 7U);
    NSUInteger trueNumberOfOptimizedOffsets = blurRadius / 2 + (blurRadius % 2);
    
    NSMutableString *shaderString = [[NSMutableString alloc] init];
    
    [shaderString appendFormat:@"\
     uniform sampler2D sourceImage;\n\
     uniform highp float texelWidthOffset;\n\
     uniform highp float texelHeightOffset;\n\
     \n\
     varying highp vec2 blurCoordinates[%lu];\n\
     \n\
     void main()\n\
     {\n\
     lowp vec4 sum = vec4(0.0);\n", (unsigned long)(1 + (numberOfOptimizedOffsets * 2)) ];
    
    [shaderString appendFormat:@"sum += texture2D(sourceImage, blurCoordinates[0]) * %f;\n", standardGaussianWeights[0]];
    
    for (NSUInteger currentBlurCoordinateIndex = 0; currentBlurCoordinateIndex < numberOfOptimizedOffsets; currentBlurCoordinateIndex++)
    {
        GLfloat firstWeight = standardGaussianWeights[currentBlurCoordinateIndex * 2 + 1];
        GLfloat secondWeight = standardGaussianWeights[currentBlurCoordinateIndex * 2 + 2];
        GLfloat optimizedWeight = firstWeight + secondWeight;
        
        [shaderString appendFormat:@"sum += texture2D(sourceImage, blurCoordinates[%lu]) * %f;\n", (unsigned long)((currentBlurCoordinateIndex * 2) + 1), optimizedWeight];
        [shaderString appendFormat:@"sum += texture2D(sourceImage, blurCoordinates[%lu]) * %f;\n", (unsigned long)((currentBlurCoordinateIndex * 2) + 2), optimizedWeight];
    }
    
    if (trueNumberOfOptimizedOffsets > numberOfOptimizedOffsets)
    {
        [shaderString appendString:@"highp vec2 singleStepOffset = vec2(texelWidthOffset, texelHeightOffset);\n"];
        
        for (NSUInteger currentOverlowTextureRead = numberOfOptimizedOffsets; currentOverlowTextureRead < trueNumberOfOptimizedOffsets; currentOverlowTextureRead++)
        {
            GLfloat firstWeight = standardGaussianWeights[currentOverlowTextureRead * 2 + 1];
            GLfloat secondWeight = standardGaussianWeights[currentOverlowTextureRead * 2 + 2];
            
            GLfloat optimizedWeight = firstWeight + secondWeight;
            GLfloat optimizedOffset = (firstWeight * (currentOverlowTextureRead * 2 + 1) + secondWeight * (currentOverlowTextureRead * 2 + 2)) / optimizedWeight;
            
            [shaderString appendFormat:@"sum += texture2D(sourceImage, blurCoordinates[0] + singleStepOffset * %f) * %f;\n", optimizedOffset, optimizedWeight];
            [shaderString appendFormat:@"sum += texture2D(sourceImage, blurCoordinates[0] - singleStepOffset * %f) * %f;\n", optimizedOffset, optimizedWeight];
        }
    }
    
    [shaderString appendString:@"\
     gl_FragColor = sum;\n\
     }\n"];
    
    free(standardGaussianWeights);
    return shaderString;
}

- (instancetype)init
{
    _currentRadius = 6;
    NSUInteger calculatedSampleRadius = 0;
    CGFloat minimumWeightToFindEdgeOfSamplingArea = 1.0/256.0;
    calculatedSampleRadius = (NSUInteger)(floor(sqrt(-2.0 * pow(_currentRadius, 2.0) * log(minimumWeightToFindEdgeOfSamplingArea * sqrt(2.0 * M_PI * pow(_currentRadius, 2.0))) )));
    calculatedSampleRadius += calculatedSampleRadius % 2;
    
    NSString *vertexShader = [[self class] vertexShaderForBlurOfRadius:calculatedSampleRadius sigma:_currentRadius];
    NSString *fragmentShader = [[self class] fragmentShaderForBlurOfRadius:calculatedSampleRadius sigma:_currentRadius];
    
    return [self initWithFirstStageVertexShaderFromString:vertexShader firstStageFragmentShaderFromString:fragmentShader secondStageVertexShaderFromString:vertexShader secondStageFragmentShaderFromString:fragmentShader];
}

- (instancetype)initWithFirstStageVertexShaderFromString:(NSString *)firstStageVertexShaderString firstStageFragmentShaderFromString:(NSString *)firstStageFragmentShaderString secondStageVertexShaderFromString:(NSString *)secondStageVertexShaderString secondStageFragmentShaderFromString:(NSString *)secondStageFragmentShaderString
{
    if (!(self = [super initWithVertexShaderFromString:firstStageVertexShaderString fragmentShaderFromString:firstStageFragmentShaderString]))
    {
        return nil;
    }
    
    _secondProgramUniformStateRestorationBlocks = [NSMutableDictionary dictionaryWithCapacity:10];
    
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];
        
        _secondFilterProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:secondStageVertexShaderString fragmentShaderString:secondStageFragmentShaderString];
        
        if (!_secondFilterProgram.initialized)
        {
            [self initializeSecondaryAttributes];
            
            if (![_secondFilterProgram link])
            {
                NSString *progLog = [_secondFilterProgram programLog];
                NSLog(@"Program link log: %@", progLog);
                NSString *fragLog = [_secondFilterProgram fragmentShaderLog];
                NSLog(@"Fragment shader compile log: %@", fragLog);
                NSString *vertLog = [_secondFilterProgram vertexShaderLog];
                NSLog(@"Vertex shader compile log: %@", vertLog);
                _secondFilterProgram = nil;
                NSAssert(NO, @"Filter shader link failed");
            }
        }
        
        _secondFilterPositionAttribute = [_secondFilterProgram attributeIndex:@"position"];
        _secondFilterTextureCoordinateAttribute = [_secondFilterProgram attributeIndex:@"inputTexCoord"];
        _secondFilterInputTextureUniform = [_secondFilterProgram uniformIndex:@"sourceImage"];
        
        _verticalPassTexelWidthOffsetUniform = [filterProgram uniformIndex:@"texelWidthOffset"];
        _verticalPassTexelHeightOffsetUniform = [filterProgram uniformIndex:@"texelHeightOffset"];
        
        _horizontalPassTexelWidthOffsetUniform = [_secondFilterProgram uniformIndex:@"texelWidthOffset"];
        _horizontalPassTexelHeightOffsetUniform = [_secondFilterProgram uniformIndex:@"texelHeightOffset"];
        
        [GPUImageContext setActiveShaderProgram:_secondFilterProgram];
        
        glEnableVertexAttribArray(_secondFilterPositionAttribute);
        glEnableVertexAttribArray(_secondFilterTextureCoordinateAttribute);
    });
    
    _verticalTexelSpacing = 1.0f;
    _horizontalTexelSpacing = 1.0f;
    
    [self setupFilterForSize:[self sizeOfFBO]];
    
    return self;
}

- (instancetype)initWithFirstStageFragmentShaderFromString:(NSString *)firstStageFragmentShaderString secondStageFragmentShaderFromString:(NSString *)secondStageFragmentShaderString
{
    if (!(self = [self initWithFirstStageVertexShaderFromString:kGPUImageVertexShaderString firstStageFragmentShaderFromString:firstStageFragmentShaderString secondStageVertexShaderFromString:kGPUImageVertexShaderString secondStageFragmentShaderFromString:secondStageFragmentShaderString]))
    {
        return nil;
    }
    
    return self;
}

- (void)initializeSecondaryAttributes
{
    [_secondFilterProgram addAttribute:@"position"];
    [_secondFilterProgram addAttribute:@"inputTexCoord"];
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex
{
    [super setInputSize:newSize atIndex:textureIndex];
    
    CGFloat maxSize = MAX(newSize.width, newSize.height);
    NSUInteger blurRadius = (NSUInteger)ceil(maxSize * 0.008);
    
    if (_currentRadius != blurRadius)
    {
        _currentRadius = blurRadius;
        
        NSUInteger calculatedSampleRadius = 0;
        if (_currentRadius >= 1)
        {
            CGFloat minimumWeightToFindEdgeOfSamplingArea = 1.0/256.0;
            calculatedSampleRadius = (NSUInteger)(floor(sqrt(-2.0 * pow(_currentRadius, 2.0) * log(minimumWeightToFindEdgeOfSamplingArea * sqrt(2.0 * M_PI * pow(_currentRadius, 2.0))) )));
            calculatedSampleRadius += calculatedSampleRadius % 2;
        }
        
        NSString *newGaussianBlurVertexShader = [[self class] vertexShaderForBlurOfRadius:calculatedSampleRadius sigma:_currentRadius];
        NSString *newGaussianBlurFragmentShader = [[self class] fragmentShaderForBlurOfRadius:calculatedSampleRadius sigma:_currentRadius];
        
        [self switchToVertexShader:newGaussianBlurVertexShader fragmentShader:newGaussianBlurFragmentShader];
    }
}

- (void)switchToVertexShader:(NSString *)newVertexShader fragmentShader:(NSString *)newFragmentShader
{
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];
        
        filterProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:newVertexShader fragmentShaderString:newFragmentShader];
        
        if (!filterProgram.initialized)
        {
            [self initializeAttributes];
            
            if (![filterProgram link])
            {
                NSString *progLog = [filterProgram programLog];
                NSLog(@"Program link log: %@", progLog);
                NSString *fragLog = [filterProgram fragmentShaderLog];
                NSLog(@"Fragment shader compile log: %@", fragLog);
                NSString *vertLog = [filterProgram vertexShaderLog];
                NSLog(@"Vertex shader compile log: %@", vertLog);
                filterProgram = nil;
                NSAssert(NO, @"Filter shader link failed");
            }
        }
        
        filterPositionAttribute = [filterProgram attributeIndex:@"position"];
        filterTextureCoordinateAttribute = [filterProgram attributeIndex:@"inputTexCoord"];
        filterInputTextureUniform = [filterProgram uniformIndex:@"sourceImage"];
        
        [GPUImageContext setActiveShaderProgram:filterProgram];
        
        glEnableVertexAttribArray(filterPositionAttribute);
        glEnableVertexAttribArray(filterTextureCoordinateAttribute);
        
        
        _secondFilterProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:newVertexShader fragmentShaderString:newFragmentShader];
        
        if (!_secondFilterProgram.initialized)
        {
            [self initializeSecondaryAttributes];
            
            if (![_secondFilterProgram link])
            {
                NSString *progLog = [_secondFilterProgram programLog];
                NSLog(@"Program link log: %@", progLog);
                NSString *fragLog = [_secondFilterProgram fragmentShaderLog];
                NSLog(@"Fragment shader compile log: %@", fragLog);
                NSString *vertLog = [_secondFilterProgram vertexShaderLog];
                NSLog(@"Vertex shader compile log: %@", vertLog);
                _secondFilterProgram = nil;
                NSAssert(NO, @"Filter shader link failed");
            }
        }
        
        _secondFilterPositionAttribute = [_secondFilterProgram attributeIndex:@"position"];
        _secondFilterTextureCoordinateAttribute = [_secondFilterProgram attributeIndex:@"inputTexCoord"];
        _secondFilterInputTextureUniform = [_secondFilterProgram uniformIndex:@"sourceImage"];
        
        _verticalPassTexelWidthOffsetUniform = [filterProgram uniformIndex:@"texelWidthOffset"];
        _verticalPassTexelHeightOffsetUniform = [filterProgram uniformIndex:@"texelHeightOffset"];
        
        _horizontalPassTexelWidthOffsetUniform = [_secondFilterProgram uniformIndex:@"texelWidthOffset"];
        _horizontalPassTexelHeightOffsetUniform = [_secondFilterProgram uniformIndex:@"texelHeightOffset"];
        
        [GPUImageContext setActiveShaderProgram:_secondFilterProgram];
        
        glEnableVertexAttribArray(_secondFilterPositionAttribute);
        glEnableVertexAttribArray(_secondFilterTextureCoordinateAttribute);
        
        [self setupFilterForSize:[self sizeOfFBO]];
        glFinish();
    });
}

- (GPUImageFramebuffer *)framebufferForOutput
{
    return _secondOutputFramebuffer;
}

- (void)removeOutputFramebuffer
{
    _secondOutputFramebuffer = nil;
}

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates
{
    if (self.preventRendering)
    {
        [firstInputFramebuffer unlock];
        return;
    }
    
    [GPUImageContext setActiveShaderProgram:filterProgram];
    
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO]
                                                                           textureOptions:self.outputTextureOptions
                                                                              onlyTexture:false];
    [outputFramebuffer activateFramebuffer];
    
    [self setUniformsForProgramAtIndex:0];
    
    glClearColor(backgroundColorRed, backgroundColorGreen, backgroundColorBlue, backgroundColorAlpha);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
    
    glUniform1i(filterInputTextureUniform, 2);
    
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    [firstInputFramebuffer unlock];
    firstInputFramebuffer = nil;
    
    _secondOutputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO]
                                                                                  textureOptions:self.outputTextureOptions
                                                                                     onlyTexture:false];
    [_secondOutputFramebuffer activateFramebuffer];
    [GPUImageContext setActiveShaderProgram:_secondFilterProgram];
    if (usingNextFrameForImageCapture)
        [_secondOutputFramebuffer lock];
    
    [self setUniformsForProgramAtIndex:1];
    
    glActiveTexture(GL_TEXTURE3);
    glBindTexture(GL_TEXTURE_2D, [outputFramebuffer texture]);
    glVertexAttribPointer(_secondFilterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, [GPUImageFilter textureCoordinatesForRotation:kGPUImageNoRotation]);
    
    glUniform1i(_secondFilterInputTextureUniform, 3);
    
    glVertexAttribPointer(_secondFilterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    [outputFramebuffer unlock];
    outputFramebuffer = nil;
    
    if (usingNextFrameForImageCapture)
        dispatch_semaphore_signal(imageCaptureSemaphore);
}

- (void)setAndExecuteUniformStateCallbackAtIndex:(GLint)uniform forProgram:(GLProgram *)shaderProgram toBlock:(dispatch_block_t)uniformStateBlock
{
    if (shaderProgram == filterProgram)
        [uniformStateRestorationBlocks setObject:[uniformStateBlock copy] forKey:[NSNumber numberWithInt:uniform]];
    else
        [_secondProgramUniformStateRestorationBlocks setObject:[uniformStateBlock copy] forKey:[NSNumber numberWithInt:uniform]];
    
    uniformStateBlock();
}

- (void)setUniformsForProgramAtIndex:(NSUInteger)programIndex
{
    if (programIndex == 0)
    {
        [uniformStateRestorationBlocks enumerateKeysAndObjectsUsingBlock:^(__unused id key, id obj, __unused BOOL *stop)
        {
            dispatch_block_t currentBlock = obj;
            currentBlock();
        }];
    }
    else
    {
        [_secondProgramUniformStateRestorationBlocks enumerateKeysAndObjectsUsingBlock:^(__unused id key, id obj, __unused BOOL *stop)
        {
            dispatch_block_t currentBlock = obj;
            currentBlock();
        }];
    }
    
    if (programIndex == 0)
    {
        glUniform1f(_verticalPassTexelWidthOffsetUniform, _verticalPassTexelWidthOffset);
        glUniform1f(_verticalPassTexelHeightOffsetUniform, _verticalPassTexelHeightOffset);
    }
    else
    {
        glUniform1f(_horizontalPassTexelWidthOffsetUniform, _horizontalPassTexelWidthOffset);
        glUniform1f(_horizontalPassTexelHeightOffsetUniform, _horizontalPassTexelHeightOffset);
    }
}

- (void)setupFilterForSize:(CGSize)filterFrameSize
{
    runSynchronouslyOnVideoProcessingQueue(^
    {
        if (GPUImageRotationSwapsWidthAndHeight(inputRotation))
        {
            _verticalPassTexelWidthOffset = (GLfloat)(_verticalTexelSpacing / filterFrameSize.height);
            _verticalPassTexelHeightOffset = 0.0;
        }
        else
        {
            _verticalPassTexelWidthOffset = 0.0;
            _verticalPassTexelHeightOffset = (GLfloat)(_verticalTexelSpacing / filterFrameSize.height);
        }
       
        _horizontalPassTexelWidthOffset = (GLfloat)(_horizontalTexelSpacing / filterFrameSize.width);
        _horizontalPassTexelHeightOffset = 0.0;
    });
}

@end
