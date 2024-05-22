#ifndef BezierPaths_h
#define BezierPaths_h

#include "Lottie/Private/Model/ShapeItems/Ellipse.hpp"
#include <LottieCpp/BezierPath.h>
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
    float cornerRadius,
    PathDirection direction
);

BezierPath makeStarBezierPath(
    Vector2D const &position,
    float outerRadius,
    float innerRadius,
    float inputOuterRoundedness,
    float inputInnerRoundedness,
    float numberOfPoints,
    float rotation,
    PathDirection direction
);

CompoundBezierPath trimCompoundPath(CompoundBezierPath sourcePath, float start, float end, float offset, TrimType type);

}

#endif /* BezierPaths_h */
