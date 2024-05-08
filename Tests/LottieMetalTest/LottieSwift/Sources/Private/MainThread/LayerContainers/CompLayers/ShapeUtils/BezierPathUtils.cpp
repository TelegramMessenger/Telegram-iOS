#include "BezierPathUtils.hpp"

namespace lottie {

BezierPath makeEllipseBezierPath(
    Vector2D const &size,
    Vector2D const &center,
    PathDirection direction
) {
    const double ControlPointConstant = 0.55228;
    
    Vector2D half = size * 0.5;
    if (direction == PathDirection::CounterClockwise) {
        half.x = half.x * -1.0;
    }
    
    Vector2D q1(center.x, center.y - half.y);
    Vector2D q2(center.x + half.x, center.y);
    Vector2D q3(center.x, center.y + half.y);
    Vector2D q4(center.x - half.x, center.y);
    
    Vector2D cp = half * ControlPointConstant;
    
    BezierPath path(CurveVertex::relative(
        q1,
        Vector2D(-cp.x, 0),
        Vector2D(cp.x, 0)));
    path.addVertex(CurveVertex::relative(
        q2,
        Vector2D(0, -cp.y),
        Vector2D(0, cp.y)));
    
    path.addVertex(CurveVertex::relative(
        q3,
        Vector2D(cp.x, 0),
        Vector2D(-cp.x, 0)));
    
    path.addVertex(CurveVertex::relative(
        q4,
        Vector2D(0, cp.y),
        Vector2D(0, -cp.y)));
    
    path.addVertex(CurveVertex::relative(
        q1,
        Vector2D(-cp.x, 0),
        Vector2D(cp.x, 0)));
    path.close();
    return path;
}

BezierPath makeRectangleBezierPath(
    Vector2D const &position,
    Vector2D const &inputSize,
    double cornerRadius,
    PathDirection direction
) {
    const double ControlPointConstant = 0.55228;
    
    Vector2D size = inputSize * 0.5;
    double radius = std::min(std::min(cornerRadius, size.x), size.y);
    
    BezierPath bezierPath;
    std::vector<CurveVertex> points;
    
    if (radius <= 0.0) {
        /// No Corners
        points = {
            /// Lead In
            CurveVertex::relative(
                Vector2D(size.x, -size.y),
                Vector2D::Zero(),
                Vector2D::Zero())
            .translated(position),
            /// Corner 1
            CurveVertex::relative(
                Vector2D(size.x, size.y),
                Vector2D::Zero(),
                Vector2D::Zero())
            .translated(position),
            /// Corner 2
            CurveVertex::relative(
                Vector2D(-size.x, size.y),
                Vector2D::Zero(),
                Vector2D::Zero())
            .translated(position),
            /// Corner 3
            CurveVertex::relative(
                Vector2D(-size.x, -size.y),
                Vector2D::Zero(),
                Vector2D::Zero())
            .translated(position),
            /// Corner 4
            CurveVertex::relative(
                Vector2D(size.x, -size.y),
                Vector2D::Zero(),
                Vector2D::Zero())
            .translated(position)
        };
    } else {
        double controlPoint = radius * ControlPointConstant;
        points = {
            /// Lead In
            CurveVertex::absolute(
                Vector2D(radius, 0),
                Vector2D(radius, 0),
                Vector2D(radius, 0))
            .translated(Vector2D(-radius, radius))
            .translated(Vector2D(size.x, -size.y))
            .translated(position),
            /// Corner 1
            CurveVertex::absolute(
                Vector2D(radius, 0), // Point
                Vector2D(radius, 0), // In tangent
                Vector2D(radius, controlPoint))
            .translated(Vector2D(-radius, -radius))
            .translated(Vector2D(size.x, size.y))
            .translated(position),
            CurveVertex::absolute(
                Vector2D(0, radius), // Point
                Vector2D(controlPoint, radius), // In tangent
                Vector2D(0, radius)) // Out Tangent
                .translated(Vector2D(-radius, -radius))
                .translated(Vector2D(size.x, size.y))
                .translated(position),
            /// Corner 2
            CurveVertex::absolute(
                Vector2D(0, radius), // Point
                Vector2D(0, radius), // In tangent
                Vector2D(-controlPoint, radius))// Out tangent
                .translated(Vector2D(radius, -radius))
                .translated(Vector2D(-size.x, size.y))
                .translated(position),
            CurveVertex::absolute(
                Vector2D(-radius, 0), // Point
                Vector2D(-radius, controlPoint), // In tangent
                Vector2D(-radius, 0)) // Out tangent
                .translated(Vector2D(radius, -radius))
                .translated(Vector2D(-size.x, size.y))
                .translated(position),
            /// Corner 3
            CurveVertex::absolute(
                Vector2D(-radius, 0), // Point
                Vector2D(-radius, 0), // In tangent
                Vector2D(-radius, -controlPoint)) // Out tangent
                .translated(Vector2D(radius, radius))
                .translated(Vector2D(-size.x, -size.y))
                .translated(position),
            CurveVertex::absolute(
                Vector2D(0, -radius), // Point
                Vector2D(-controlPoint, -radius), // In tangent
                Vector2D(0, -radius)) // Out tangent
                .translated(Vector2D(radius, radius))
                .translated(Vector2D(-size.x, -size.y))
                .translated(position),
            /// Corner 4
            CurveVertex::absolute(
                Vector2D(0, -radius), // Point
                Vector2D(0, -radius), // In tangent
                Vector2D(controlPoint, -radius)) // Out tangent
                .translated(Vector2D(-radius, radius))
                .translated(Vector2D(size.x, -size.y))
                .translated(position),
            CurveVertex::absolute(
                Vector2D(radius, 0), // Point
                Vector2D(radius, -controlPoint), // In tangent
                Vector2D(radius, 0)) // Out tangent
                .translated(Vector2D(-radius, radius))
                .translated(Vector2D(size.x, -size.y))
                .translated(position)
        };
    }
    bool reversed = direction == PathDirection::CounterClockwise;
    if (reversed) {
        for (auto vertexIt = points.rbegin(); vertexIt != points.rend(); vertexIt++) {
            bezierPath.addVertex((*vertexIt).reversed());
        }
    } else {
        for (auto vertexIt = points.begin(); vertexIt != points.end(); vertexIt++) {
            bezierPath.addVertex(*vertexIt);
        }
    }
    bezierPath.close();
    return bezierPath;
}

/// Magic number needed for building path data
static constexpr double StarNodePolystarConstant = 0.47829;

BezierPath makeStarBezierPath(
    Vector2D const &position,
    double outerRadius,
    double innerRadius,
    double inputOuterRoundedness,
    double inputInnerRoundedness,
    double numberOfPoints,
    double rotation,
    PathDirection direction
) {
    double currentAngle = degreesToRadians(rotation - 90.0);
    double anglePerPoint = (2.0 * M_PI) / numberOfPoints;
    double halfAnglePerPoint = anglePerPoint / 2.0;
    double partialPointAmount = numberOfPoints - floor(numberOfPoints);
    double outerRoundedness = inputOuterRoundedness * 0.01;
    double innerRoundedness = inputInnerRoundedness * 0.01;
    
    Vector2D point = Vector2D::Zero();
    
    double partialPointRadius = 0.0;
    if (partialPointAmount != 0.0) {
        currentAngle += halfAnglePerPoint * (1 - partialPointAmount);
        partialPointRadius = innerRadius + partialPointAmount * (outerRadius - innerRadius);
        point.x = (partialPointRadius * cos(currentAngle));
        point.y = (partialPointRadius * sin(currentAngle));
        currentAngle += anglePerPoint * partialPointAmount / 2;
    } else {
        point.x = (outerRadius * cos(currentAngle));
        point.y = (outerRadius * sin(currentAngle));
        currentAngle += halfAnglePerPoint;
    }
    
    std::vector<CurveVertex> vertices;
    vertices.push_back(CurveVertex::relative(point + position, Vector2D::Zero(), Vector2D::Zero()));
    
    Vector2D previousPoint = point;
    bool longSegment = false;
    int numPoints = (int)(ceil(numberOfPoints) * 2.0);
    for (int i = 0; i < numPoints; i++) {
        double radius = longSegment ? outerRadius : innerRadius;
        double dTheta = halfAnglePerPoint;
        if (partialPointRadius != 0.0 && i == numPoints - 2) {
            dTheta = anglePerPoint * partialPointAmount / 2;
        }
        if (partialPointRadius != 0.0 && i == numPoints - 1) {
            radius = partialPointRadius;
        }
        previousPoint = point;
        point.x = (radius * cos(currentAngle));
        point.y = (radius * sin(currentAngle));
        
        if (innerRoundedness == 0.0 && outerRoundedness == 0.0) {
            vertices.push_back(CurveVertex::relative(point + position, Vector2D::Zero(), Vector2D::Zero()));
        } else {
            double cp1Theta = (atan2(previousPoint.y, previousPoint.x) - M_PI / 2.0);
            double cp1Dx = cos(cp1Theta);
            double cp1Dy = sin(cp1Theta);
            
            double cp2Theta = (atan2(point.y, point.x) - M_PI / 2.0);
            double cp2Dx = cos(cp2Theta);
            double cp2Dy = sin(cp2Theta);
            
            double cp1Roundedness = longSegment ? innerRoundedness : outerRoundedness;
            double cp2Roundedness = longSegment ? outerRoundedness : innerRoundedness;
            double cp1Radius = longSegment ? innerRadius : outerRadius;
            double cp2Radius = longSegment ? outerRadius : innerRadius;
            
            Vector2D cp1(
                cp1Radius * cp1Roundedness * StarNodePolystarConstant * cp1Dx,
                cp1Radius * cp1Roundedness * StarNodePolystarConstant * cp1Dy
            );
            Vector2D cp2(
                cp2Radius * cp2Roundedness * StarNodePolystarConstant * cp2Dx,
                cp2Radius * cp2Roundedness * StarNodePolystarConstant * cp2Dy
            );
            if (partialPointAmount != 0.0) {
                if (i == 0) {
                    cp1 = cp1 * partialPointAmount;
                } else if (i == numPoints - 1) {
                    cp2 = cp2 * partialPointAmount;
                }
            }
            auto previousVertex = vertices[vertices.size() - 1];
            vertices[vertices.size() - 1] = CurveVertex::absolute(
                previousVertex.point,
                previousVertex.inTangent,
                previousVertex.point - cp1
            );
            vertices.push_back(CurveVertex::relative(point + position, cp2, Vector2D::Zero()));
        }
        currentAngle += dTheta;
        longSegment = !longSegment;
    }
    
    bool reverse = direction == PathDirection::CounterClockwise;
    BezierPath path;
    if (reverse) {
        for (auto vertexIt = vertices.rbegin(); vertexIt != vertices.rend(); vertexIt++) {
            path.addVertex((*vertexIt).reversed());
        }
    } else {
        for (auto vertexIt = vertices.begin(); vertexIt != vertices.end(); vertexIt++) {
            path.addVertex(*vertexIt);
        }
    }
    path.close();
    return path;
}

CompoundBezierPath trimCompoundPath(CompoundBezierPath sourcePath, double start, double end, double offset, TrimType type) {
    /// No need to trim, it's a full path
    if (start == 0.0 && end == 1.0) {
        return sourcePath;
    }
    
    /// All paths are empty.
    if (start == end) {
        return CompoundBezierPath();
    }
    
    if (type == TrimType::Simultaneously) {
        CompoundBezierPath result;
        
        for (BezierPath &path : sourcePath.paths) {
            CompoundBezierPath tempPath;
            tempPath.appendPath(path);
            
            auto subPaths = tempPath.trim(start, end, offset);
            
            for (const auto &subPath : subPaths->paths) {
                result.appendPath(subPath);
            }
        }

        return result;
    }
    
    /// Individual path trimming.
    
    /// Brace yourself for the below code.
    
    /// Normalize lengths with offset.
    double startPosition = fmod(start + offset, 1.0);
    double endPosition = fmod(end + offset, 1.0);
    
    if (startPosition < 0.0) {
        startPosition = 1.0 + startPosition;
    }
    
    if (endPosition < 0.0) {
        endPosition = 1.0 + endPosition;
    }
    if (startPosition == 1.0) {
        startPosition = 0.0;
    }
    if (endPosition == 0.0) {
        endPosition = 1.0;
    }
    
    /// First get the total length of all paths.
    double totalLength = 0.0;
    for (auto &upstreamPath : sourcePath.paths) {
        totalLength += upstreamPath.length();
    }
    
    /// Now determine the start and end cut lengths
    double startLength = startPosition * totalLength;
    double endLength = endPosition * totalLength;
    double pathStart = 0.0;
    
    CompoundBezierPath result;
    
    /// Now loop through all path containers
    for (auto &pathContainer : sourcePath.paths) {
        auto pathEnd = pathStart + pathContainer.length();
        
        if (!isInRange(startLength, pathStart, pathEnd) &&
            isInRange(endLength, pathStart, pathEnd)) {
            // pathStart|=======E----------------------|pathEnd
            // Cut path components, removing after end.
            
            double pathCutLength = endLength - pathStart;
            double subpathStart = 0.0;
            double subpathEnd = subpathStart + pathContainer.length();
            if (pathCutLength < subpathEnd) {
                /// This is the subpath that needs to be cut.
                double cutLength = pathCutLength - subpathStart;
                
                CompoundBezierPath tempPath;
                tempPath.appendPath(pathContainer);
                auto newPaths = tempPath.trim(0, cutLength / pathContainer.length(), 0);
                for (const auto &newPath : newPaths->paths) {
                    result.appendPath(newPath);
                }
            } else {
                /// Add to container and move on
                result.appendPath(pathContainer);
            }
            /*if (pathCutLength == subpathEnd) {
                /// Right on the end. The next subpath is not included. Break.
                break;
            }
            subpathStart = subpathEnd;*/
        } else if (!isInRange(endLength, pathStart, pathEnd) &&
                   isInRange(startLength, pathStart, pathEnd)) {
            // pathStart|-------S======================|pathEnd
            //
            
            // Cut path components, removing before beginning.
            double pathCutLength = startLength - pathStart;
            // Clear paths from container
            double subpathStart = 0.0;
            double subpathEnd = subpathStart + pathContainer.length();
            
            if (subpathStart < pathCutLength && pathCutLength < subpathEnd) {
                /// This is the subpath that needs to be cut.
                double cutLength = pathCutLength - subpathStart;
                CompoundBezierPath tempPath;
                tempPath.appendPath(pathContainer);
                auto newPaths = tempPath.trim(cutLength / pathContainer.length(), 1, 0);
                for (const auto &newPath : newPaths->paths) {
                    result.appendPath(newPath);
                }
            } else if (pathCutLength <= subpathStart) {
                result.appendPath(pathContainer);
            }
            //subpathStart = subpathEnd;
        } else if (isInRange(endLength, pathStart, pathEnd) &&
                   isInRange(startLength, pathStart, pathEnd)) {
            // pathStart|-------S============E---------|endLength
            // pathStart|=====E----------------S=======|endLength
            // trim from path beginning to endLength.
            
            // Cut path components, removing before beginnings.
            double startCutLength = startLength - pathStart;
            double endCutLength = endLength - pathStart;
            
            double subpathStart = 0.0;
                
            double subpathEnd = subpathStart + pathContainer.length();
            
            if (!isInRange(startCutLength, subpathStart, subpathEnd) &&
                !isInRange(endCutLength, subpathStart, subpathEnd))
            {
                // The whole path is included. Add
                // S|==============================|E
                result.appendPath(pathContainer);
            } else if (isInRange(startCutLength, subpathStart, subpathEnd) &&
                       !isInRange(endCutLength, subpathStart, subpathEnd)) {
                /// The start of the path needs to be trimmed
                //  |-------S======================|E
                double cutLength = startCutLength - subpathStart;
                CompoundBezierPath tempPath;
                tempPath.appendPath(pathContainer);
                auto newPaths = tempPath.trim(cutLength / pathContainer.length(), 1, 0);
                for (const auto &newPath : newPaths->paths) {
                    result.appendPath(newPath);
                }
            } else if (!isInRange(startCutLength, subpathStart, subpathEnd) &&
                       isInRange(endCutLength, subpathStart, subpathEnd)) {
                // S|=======E----------------------|
                double cutLength = endCutLength - subpathStart;
                CompoundBezierPath tempPath;
                tempPath.appendPath(pathContainer);
                auto newPaths = tempPath.trim(0, cutLength / pathContainer.length(), 0);
                for (const auto &newPath : newPaths->paths) {
                    result.appendPath(newPath);
                }
            } else if (isInRange(startCutLength, subpathStart, subpathEnd) &&
                       isInRange(endCutLength, subpathStart, subpathEnd)) {
                //  |-------S============E---------|
                double cutFromLength = startCutLength - subpathStart;
                double cutToLength = endCutLength - subpathStart;
                CompoundBezierPath tempPath;
                tempPath.appendPath(pathContainer);
                auto newPaths = tempPath.trim(
                    cutFromLength / pathContainer.length(),
                    cutToLength / pathContainer.length(),
                    0
                );
                for (const auto &newPath : newPaths->paths) {
                    result.appendPath(newPath);
                }
            }
        } else if ((endLength <= pathStart && pathEnd <= startLength) ||
                   (startLength <= pathStart && endLength <= pathStart) ||
                   (pathEnd <= startLength && pathEnd <= endLength)) {
            /// The Path needs to be cleared
        } else {
            result.appendPath(pathContainer);
        }
        
        pathStart = pathEnd;
    }
    
    return result;
}

}
