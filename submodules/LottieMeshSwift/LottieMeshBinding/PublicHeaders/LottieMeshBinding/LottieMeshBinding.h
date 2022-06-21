#ifndef LOTTIE_MESH_BINDING_H
#define LOTTIE_MESH_BINDING_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_CLOSED_ENUM(NSInteger, LottieMeshFillRule) {
    LottieMeshFillRuleEvenOdd,
    LottieMeshFillRuleNonZero
};

@interface LottieMeshFill : NSObject

@property (nonatomic, readonly) LottieMeshFillRule fillRule;

- (instancetype _Nonnull)initWithFillRule:(LottieMeshFillRule)fillRule;

@end

@interface LottieMeshStroke : NSObject

@property (nonatomic, readonly) CGFloat lineWidth;
@property (nonatomic, readonly) CGLineJoin lineJoin;
@property (nonatomic, readonly) CGLineCap lineCap;
@property (nonatomic, readonly) CGFloat miterLimit;

- (instancetype _Nonnull)initWithLineWidth:(CGFloat)lineWidth lineJoin:(CGLineJoin)lineJoin lineCap:(CGLineCap)lineCap miterLimit:(CGFloat)miterLimit;

@end

@interface LottieMeshData : NSObject

- (NSInteger)vertexCount;
- (void)getVertexAt:(NSInteger)index x:(float * _Nullable)x y:(float * _Nullable)y;

- (NSInteger)triangleCount;
- (void * _Nonnull)getTriangles;

+ (LottieMeshData * _Nullable)generateWithPath:(UIBezierPath * _Nonnull)path fill:(LottieMeshFill * _Nullable)fill stroke:(LottieMeshStroke * _Nullable)stroke;

@end

#endif
