#ifndef BezierPaths_h
#define BezierPaths_h

#include "Lottie/Private/Model/ShapeItems/Ellipse.hpp"
#include "Lottie/Private/Utility/Primitives/BezierPath.hpp"
#include "Lottie/Private/Utility/Primitives/CompoundBezierPath.hpp"
#include "Lottie/Private/Model/ShapeItems/Trim.hpp"

namespace lottie {

BezierPath makeEllipseBezierPath(
    Vector2D const &size,
    Vector2D const &center,
    PathDirection direction
);

BezierPath makeRectangleBezierPath(
    Vector2D const &position,
    Vector2D const &inputSize,
    double cornerRadius,
    PathDirection direction
);

BezierPath makeStarBezierPath(
    Vector2D const &position,
    double outerRadius,
    double innerRadius,
    double inputOuterRoundedness,
    double inputInnerRoundedness,
    double numberOfPoints,
    double rotation,
    PathDirection direction
);

CompoundBezierPath trimCompoundPath(CompoundBezierPath sourcePath, double start, double end, double offset, TrimType type);

}

#endif /* BezierPaths_h */
