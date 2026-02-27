#ifndef MeshTransformApi_h
#define MeshTransformApi_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef struct MeshTransformMeshFace {
    unsigned int indices[4];
    float w[4];
} MeshTransformMeshFace;
 
typedef struct MeshTransformPoint3D {
    CGFloat x;
    CGFloat y;
    CGFloat z;
} MeshTransformPoint3D;
 
typedef struct MeshTransformMeshVertex {
    CGPoint from;
    MeshTransformPoint3D to;
} MeshTransformMeshVertex;

@protocol MeshTransformClass <NSObject>

- (id)meshTransformWithVertexCount:(NSUInteger)vertexCount
                                    vertices:(MeshTransformMeshVertex *)vertices
                                   faceCount:(NSUInteger)faceCount
                                       faces:(MeshTransformMeshFace *)faces
                          depthNormalization:(NSString *)depthNormalization;

@end

#endif
