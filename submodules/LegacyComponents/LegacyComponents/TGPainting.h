#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>

@class TGPaintBrush;
@class TGPaintShader;
@class TGPaintPath;
@class TGPaintUndoManager;

@interface TGPainting : NSObject

@property (nonatomic, readonly) EAGLContext *context;
@property (nonatomic, readonly) GLuint textureName;

@property (nonatomic, readonly) bool isEmpty;

@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) CGRect bounds;

@property (nonatomic, strong) TGPaintBrush *brush;
@property (nonatomic, strong) TGPaintPath *activePath;

@property (nonatomic, copy) void (^contentChanged)(CGRect rect);
@property (nonatomic, copy) void (^strokeCommited)(void);

- (instancetype)initWithSize:(CGSize)size undoManager:(TGPaintUndoManager *)undoManager imageData:(NSData *)imageData;

- (void)performAsynchronouslyInContext:(void (^)(void))block;

- (void)paintStroke:(TGPaintPath *)path clearBuffer:(bool)clearBuffer completion:(void (^)(void))completion;
- (void)commitStrokeWithColor:(UIColor *)color erase:(bool)erase;

- (void)renderWithProjection:(GLfloat *)projection;
- (NSData *)imageDataForRect:(CGRect)rect resultPaintingData:(NSData **)resultPaintingData;

- (UIImage *)imageWithSize:(CGSize)size andData:(NSData *__autoreleasing *)outData;

- (TGPaintShader *)shaderForKey:(NSString *)key;

- (void)clear;

- (GLuint)_quad;
- (GLfloat *)_projection;

- (dispatch_queue_t)_queue;

@end
