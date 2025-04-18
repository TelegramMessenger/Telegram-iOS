#include "BezierPath.hpp"

#include <simd/simd.h>
#include <Accelerate/Accelerate.h>

namespace lottie {

CGRect calculateBoundingRectOpt(float const *pointsX, float const *pointsY, int count) {
    float minX = 0.0;
    float maxX = 0.0;
    vDSP_minv(pointsX, 1, &minX, count);
    vDSP_maxv(pointsX, 1, &maxX, count);
    
    float minY = 0.0;
    float maxY = 0.0;
    vDSP_minv(pointsY, 1, &minY, count);
    vDSP_maxv(pointsY, 1, &maxY, count);
    
    return CGRect(minX, minY, maxX - minX, maxY - minY);
}

CGRect bezierPathsBoundingBoxParallel(BezierPathsBoundingBoxContext &context, std::vector<BezierPath> const &paths) {
    int pointCount = 0;
    
    float *pointsX = context.pointsX;
    float *pointsY = context.pointsY;
    int pointsSize = context.pointsSize;
    
    for (const auto &path : paths) {
        PathElement const *pathElements = path.elements().data();
        int pathElementCount = (int)path.elements().size();
        
        for (int i = 0; i < pathElementCount; i++) {
            const auto &element = pathElements[i];
            
            if (pointsSize < pointCount + 1) {
                pointsSize = (pointCount + 1) * 2;
                pointsX = (float *)realloc(pointsX, pointsSize * 4);
                pointsY = (float *)realloc(pointsY, pointsSize * 4);
            }
            pointsX[pointCount] = (float)element.vertex.point.x;
            pointsY[pointCount] = (float)element.vertex.point.y;
            pointCount++;
            
            if (i != 0) {
                const auto &previousElement = pathElements[i - 1];
                if (previousElement.vertex.outTangentRelative().isZero() && element.vertex.inTangentRelative().isZero()) {
                } else {
                    if (pointsSize < pointCount + 1) {
                        pointsSize = (pointCount + 2) * 2;
                        pointsX = (float *)realloc(pointsX, pointsSize * 4);
                        pointsY = (float *)realloc(pointsY, pointsSize * 4);
                    }
                    pointsX[pointCount] = (float)previousElement.vertex.outTangent.x;
                    pointsY[pointCount] = (float)previousElement.vertex.outTangent.y;
                    pointCount++;
                    pointsX[pointCount] = (float)element.vertex.inTangent.x;
                    pointsY[pointCount] = (float)element.vertex.inTangent.y;
                    pointCount++;
                }
            }
        }
    }
    
    context.pointsX = pointsX;
    context.pointsY = pointsY;
    context.pointsSize = pointsSize;
    
    if (pointCount == 0) {
        return CGRect(0.0, 0.0, 0.0, 0.0);
    }
    
    return calculateBoundingRectOpt(pointsX, pointsY, pointCount);
}

CGRect bezierPathsBoundingBox(std::vector<BezierPath> const &paths) {
    int pointCount = 0;
    
    float *pointsX = (float *)malloc(128 * 4);
    float *pointsY = (float *)malloc(128 * 4);
    int pointsSize = 128;
    
    for (const auto &path : paths) {
        PathElement const *pathElements = path.elements().data();
        int pathElementCount = (int)path.elements().size();
        
        for (int i = 0; i < pathElementCount; i++) {
            const auto &element = pathElements[i];
            
            if (pointsSize < pointCount + 1) {
                pointsSize = (pointCount + 1) * 2;
                pointsX = (float *)realloc(pointsX, pointsSize * 4);
                pointsY = (float *)realloc(pointsY, pointsSize * 4);
            }
            pointsX[pointCount] = (float)element.vertex.point.x;
            pointsY[pointCount] = (float)element.vertex.point.y;
            pointCount++;
            
            if (i != 0) {
                const auto &previousElement = pathElements[i - 1];
                if (previousElement.vertex.outTangentRelative().isZero() && element.vertex.inTangentRelative().isZero()) {
                } else {
                    if (pointsSize < pointCount + 1) {
                        pointsSize = (pointCount + 2) * 2;
                        pointsX = (float *)realloc(pointsX, pointsSize * 4);
                        pointsY = (float *)realloc(pointsY, pointsSize * 4);
                    }
                    pointsX[pointCount] = (float)previousElement.vertex.outTangent.x;
                    pointsY[pointCount] = (float)previousElement.vertex.outTangent.y;
                    pointCount++;
                    pointsX[pointCount] = (float)element.vertex.inTangent.x;
                    pointsY[pointCount] = (float)element.vertex.inTangent.y;
                    pointCount++;
                }
            }
        }
    }
    
    if (pointCount == 0) {
        free(pointsX);
        free(pointsY);
        
        return CGRect(0.0, 0.0, 0.0, 0.0);
    }
    
    auto result = calculateBoundingRectOpt(pointsX, pointsY, pointCount);
    
    free(pointsX);
    free(pointsY);
    
    return result;
}

}
