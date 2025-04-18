#ifndef CurveVertex_hpp
#define CurveVertex_hpp

#include "Lottie/Public/Primitives/Vectors.hpp"
#include "Lottie/Public/Primitives/CGPath.hpp"

#include <math.h>

namespace lottie {

template<typename T>
struct CurveVertexSplitResult {
    T start;
    T trimPoint;
    T end;
    
    explicit CurveVertexSplitResult(
        T const &start_,
        T const &trimPoint_,
        T const &end_
    ) :
    start(start_),
    trimPoint(trimPoint_),
    end(end_) {
    }
};

/// A single vertex with an in and out tangent
struct CurveVertex {
private:
    /// Initializes a curve point with absolute or relative values
    explicit CurveVertex(Vector2D const &point_, Vector2D const &inTangent_, Vector2D const &outTangent_, bool isRelative_) :
    point(point_),
    inTangent(isRelative_ ? (point_ + inTangent_) : inTangent_),
    outTangent(isRelative_ ? (point_ + outTangent_) : outTangent_) {
    }
    
public:
    static CurveVertex absolute(Vector2D const &point_, Vector2D const &inTangent_, Vector2D const &outTangent_) {
        return CurveVertex(point_, inTangent_, outTangent_, false);
    }
    
    static CurveVertex relative(Vector2D const &point_, Vector2D const &inTangent_, Vector2D const &outTangent_) {
        return CurveVertex(point_, inTangent_, outTangent_, true);
    }
    
    Vector2D inTangentRelative() const {
        Vector2D result = inTangent - point;
        return result;
    }
    
    Vector2D outTangentRelative() const {
        Vector2D result = outTangent - point;
        return result;
    }
    
    CurveVertex reversed() const {
        return CurveVertex(point, outTangent, inTangent, false);
    }
    
    CurveVertex translated(Vector2D const &translation) const {
        return CurveVertex(point + translation, inTangent + translation, outTangent + translation, false);
    }
    
    CurveVertex transformed(CATransform3D const &transform) const {
        return CurveVertex(transformVector(point, transform), transformVector(inTangent, transform), transformVector(outTangent, transform), false);
    }
        
public:
    Vector2D point = Vector2D::Zero();
    
    Vector2D inTangent = Vector2D::Zero();
    Vector2D outTangent = Vector2D::Zero();
    
    /// Trims a path defined by two Vertices at a specific position, from 0 to 1
    ///
    /// The path can be visualized below.
    ///
    /// F is fromVertex.
    /// V is the vertex of the receiver.
    /// P is the position from 0-1.
    /// O is the outTangent of fromVertex.
    /// F====O=========P=======I====V
    ///
    /// After trimming the curve can be visualized below.
    ///
    /// S is the returned Start vertex.
    /// E is the returned End vertex.
    /// T is the trim point.
    /// TI and TO are the new tangents for the trimPoint
    /// NO and NI are the new tangents for the startPoint and endPoints
    /// S==NO=========TI==T==TO=======NI==E
    CurveVertexSplitResult<CurveVertex> splitCurve(CurveVertex const &toVertex, double position) const {
        /// If position is less than or equal to 0, trim at start.
        if (position <= 0.0) {
            return CurveVertexSplitResult<CurveVertex>(
                CurveVertex(point, inTangentRelative(), Vector2D::Zero(), true),
                CurveVertex(point, Vector2D::Zero(), outTangentRelative(), true),
                toVertex
            );
        }
            
        /// If position is greater than or equal to 1, trim at end.
        if (position >= 1.0) {
            return CurveVertexSplitResult<CurveVertex>(
                *this,
                CurveVertex(toVertex.point, toVertex.inTangentRelative(), Vector2D::Zero(), true),
                CurveVertex(toVertex.point, Vector2D::Zero(), toVertex.outTangentRelative(), true)
            );
        }
        
        if (outTangentRelative().isZero() && toVertex.inTangentRelative().isZero()) {
            /// If both tangents are zero, then span to be trimmed is a straight line.
            Vector2D trimPoint = interpolate(point, toVertex.point, position);
            return CurveVertexSplitResult<CurveVertex>(
                *this,
                CurveVertex(trimPoint, Vector2D::Zero(), Vector2D::Zero(), true),
                toVertex
            );
        }
        /// Cutting by amount gives incorrect length....
        /// One option is to cut by a stride until it gets close then edge it down.
        /// Measuring a percentage of the spans does not equal the same as measuring a percentage of length.
        /// This is where the historical trim path bugs come from.
        Vector2D a = interpolate(point, outTangent, position);
        Vector2D b = interpolate(outTangent, toVertex.inTangent, position);
        Vector2D c = interpolate(toVertex.inTangent, toVertex.point, position);
        Vector2D d = interpolate(a, b, position);
        Vector2D e = interpolate(b, c, position);
        Vector2D f = interpolate(d, e, position);
        return CurveVertexSplitResult<CurveVertex>(
            CurveVertex::absolute(point, inTangent, a),
            CurveVertex::absolute(f, d, e),
            CurveVertex::absolute(toVertex.point, c, toVertex.outTangent)
        );
    }
    
    /// Trims a curve of a known length to a specific length and returns the points.
    ///
    /// There is not a performant yet accurate way to cut a curve to a specific length.
    /// This calls splitCurve(toVertex: position:) to split the curve and then measures
    /// the length of the new curve. The function then iterates through the samples,
    /// adjusting the position of the cut for a more precise cut.
    /// Usually a single iteration is enough to get within 0.5 points of the desired
    /// length.
    ///
    /// This function should probably live in PathElement, since it deals with curve
    /// lengths.
    CurveVertexSplitResult<CurveVertex> trimCurve(CurveVertex const &toVertex, double atLength, double curveLength, int maxSamples, double accuracy = 1.0) const {
        double currentPosition = atLength / curveLength;
        auto results = splitCurve(toVertex, currentPosition);
        
        if (maxSamples == 0) {
            return results;
        }
        
        for (int i = 1; i <= maxSamples; i++) {
            auto length = results.start.distanceTo(results.trimPoint);
            auto lengthDiff = atLength - length;
            /// Check if length is correct.
            if (lengthDiff < accuracy) {
                return results;
            }
            auto diffPosition = std::max(std::min((currentPosition / length) * lengthDiff, currentPosition * 0.5), currentPosition * (-0.5));
            currentPosition = diffPosition + currentPosition;
            results = splitCurve(toVertex, currentPosition);
        }
        return results;
    }
    
    /// The distance from the receiver to the provided vertex.
    ///
    /// For lines (zeroed tangents) the distance between the two points is measured.
    /// For curves the curve is iterated over by sample count and the points are measured.
    /// This is ~99% accurate at a sample count of 30
    double distanceTo(CurveVertex const &toVertex, int sampleCount = 25) const {
        if (outTangentRelative().isZero() && toVertex.inTangentRelative().isZero()) {
            /// Return a linear distance.
            return point.distanceTo(toVertex.point);
        }
        
        double distance = 0.0;
        
        auto previousPoint = point;
        for (int i = 0; i < sampleCount; i++) {
            auto pointOnCurve = splitCurve(toVertex, ((double)(i)) / ((double)(sampleCount))).trimPoint;
            distance = distance + previousPoint.distanceTo(pointOnCurve.point);
            previousPoint = pointOnCurve.point;
        }
        distance = distance + previousPoint.distanceTo(toVertex.point);
        return distance;
    }
};

}

#endif /* CurveVertex_hpp */
