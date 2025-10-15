#ifndef PathElement_hpp
#define PathElement_hpp

#include "Lottie/Private/Utility/Primitives/CurveVertex.hpp"

namespace lottie {

template<typename T>
struct PathSplitResultSpan {
    T start;
    T end;
    
    explicit PathSplitResultSpan(T const &start_, T const &end_) :
    start(start_), end(end_) {
    }
};

template<typename T>
struct PathSplitResult {
    PathSplitResultSpan<T> leftSpan;
    PathSplitResultSpan<T> rightSpan;
    
    explicit PathSplitResult(PathSplitResultSpan<T> const &leftSpan_, PathSplitResultSpan<T> const &rightSpan_) :
    leftSpan(leftSpan_), rightSpan(rightSpan_) {
    }
};

/// A path section, containing one point and its length to the previous point.
///
/// The relationship between this path element and the previous is implicit.
/// Ideally a path section would be defined by two vertices and a length.
/// We don't do this however, as it would effectively double the memory footprint
/// of path data.
///
struct PathElement {
    /// Initializes a new path with length of 0
    explicit PathElement(CurveVertex const &vertex_) :
    vertex(vertex_) {
    }
    
    /// Initializes a new path with length
    explicit PathElement(std::optional<double> length_, CurveVertex const &vertex_) :
    vertex(vertex_) {
    }
    
    /// The vertex of the element
    CurveVertex vertex;
    
    /// Returns a new path element define the span from the receiver to the new vertex.
    PathElement pathElementTo(CurveVertex const &toVertex) const {
        return PathElement(std::nullopt, toVertex);
    }
    
    PathElement updateVertex(CurveVertex const &newVertex) const {
        return PathElement(newVertex);
    }
    
    /// Splits an element span defined by the receiver and fromElement to a position 0-1
    PathSplitResult<PathElement> splitElementAtPosition(PathElement const &fromElement, double atLength) {
        /// Trim the span. Start and trim go into the first, trim and end go into second.
        auto trimResults = fromElement.vertex.trimCurve(vertex, atLength, length(fromElement), 3);
        
        /// Create the elements for the break
        auto spanAStart = PathElement(
            std::nullopt,
            CurveVertex::absolute(
                fromElement.vertex.point,
                fromElement.vertex.inTangent,
                trimResults.start.outTangent
        ));
        /// Recalculating the length here is a waste as the trimCurve function also accurately calculates this length.
        auto spanAEnd = spanAStart.pathElementTo(trimResults.trimPoint);
        
        auto spanBStart = PathElement(trimResults.trimPoint);
        auto spanBEnd = spanBStart.pathElementTo(trimResults.end);
        return PathSplitResult<PathElement>(
            PathSplitResultSpan<PathElement>(spanAStart, spanAEnd),
            PathSplitResultSpan<PathElement>(spanBStart, spanBEnd)
        );
    }
    
    double length(PathElement const &previous) {
        double result = previous.vertex.distanceTo(vertex);
        return result;
    }
};

}

#endif /* PathElement_hpp */
