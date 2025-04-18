#ifndef ValueInterpolators_hpp
#define ValueInterpolators_hpp

#include "Lottie/Public/Primitives/Vectors.hpp"
#include "Lottie/Public/Primitives/Color.hpp"
#include "Lottie/Private/Utility/Primitives/BezierPath.hpp"
#include "Lottie/Private/Model/Text/TextDocument.hpp"
#include "Lottie/Public/Primitives/GradientColorSet.hpp"
#include "Lottie/Public/Primitives/DashPattern.hpp"

#include <optional>
#include <cassert>

namespace lottie {

template<typename T>
struct ValueInterpolator {
};

template<>
struct ValueInterpolator<double> {
public:
    static double interpolate(double value, double to, double amount, std::optional<Vector2D> spatialOutTangent, std::optional<Vector2D> spatialInTangent) {
        return value + ((to - value) * amount);
    }
};

template<>
struct ValueInterpolator<Vector1D> {
public:
    static Vector1D interpolate(Vector1D const &value, Vector1D const &to, double amount, std::optional<Vector2D> spatialOutTangent, std::optional<Vector2D> spatialInTangent) {
        return Vector1D(ValueInterpolator<double>::interpolate(value.value, to.value, amount, spatialOutTangent, spatialInTangent));
    }
};

template<>
struct ValueInterpolator<Vector2D> {
public:
    static Vector2D interpolate(Vector2D const &value, Vector2D const &to, double amount, Vector2D spatialOutTangent, Vector2D spatialInTangent) {
        auto cp1 = value + spatialOutTangent;
        auto cp2 = to + spatialInTangent;
        
        return value.interpolate(to, cp1, cp2, amount);
    }
    
    static Vector2D interpolate(Vector2D const &value, Vector2D const &to, double amount) {
        return value.interpolate(to, amount);
    }
};

template<>
struct ValueInterpolator<Vector3D> {
public:
    static Vector3D interpolate(Vector3D const &value, Vector3D const &to, double amount, std::optional<Vector2D> spatialOutTangent, std::optional<Vector2D> spatialInTangent) {
        if (spatialOutTangent && spatialInTangent) {
            Vector2D from2d(value.x, value.y);
            Vector2D to2d(to.x, to.y);
            
            auto cp1 = from2d + spatialOutTangent.value();
            auto cp2 = to2d + spatialInTangent.value();
            
            Vector2D result2d = from2d.interpolate(to2d, cp1, cp2, amount);
            
            return Vector3D(
                result2d.x,
                result2d.y,
                ValueInterpolator<double>::interpolate(value.z, to.z, amount, spatialOutTangent, spatialInTangent)
            );
        }
        
        return Vector3D(
            ValueInterpolator<double>::interpolate(value.x, to.x, amount, spatialOutTangent, spatialInTangent),
            ValueInterpolator<double>::interpolate(value.y, to.y, amount, spatialOutTangent, spatialInTangent),
            ValueInterpolator<double>::interpolate(value.z, to.z, amount, spatialOutTangent, spatialInTangent)
        );
    }
};

template<>
struct ValueInterpolator<Color> {
public:
    static Color interpolate(Color const &value, Color const &to, double amount, std::optional<Vector2D> spatialOutTangent, std::optional<Vector2D> spatialInTangent) {
        return Color(
            ValueInterpolator<double>::interpolate(value.r, to.r, amount, spatialOutTangent, spatialInTangent),
            ValueInterpolator<double>::interpolate(value.g, to.g, amount, spatialOutTangent, spatialInTangent),
            ValueInterpolator<double>::interpolate(value.b, to.b, amount, spatialOutTangent, spatialInTangent),
            ValueInterpolator<double>::interpolate(value.a, to.a, amount, spatialOutTangent, spatialInTangent)
        );
    }
};

template<>
struct ValueInterpolator<CurveVertex> {
public:
    static CurveVertex interpolate(CurveVertex const &value, CurveVertex const &to, double amount, Vector2D spatialOutTangent, Vector2D spatialInTangent) {
        return CurveVertex::absolute(
            ValueInterpolator<Vector2D>::interpolate(value.point, to.point, amount, spatialOutTangent, spatialInTangent),
            ValueInterpolator<Vector2D>::interpolate(value.inTangent, to.inTangent, amount, spatialOutTangent, spatialInTangent),
            ValueInterpolator<Vector2D>::interpolate(value.outTangent, to.outTangent, amount, spatialOutTangent, spatialInTangent)
        );
    }
    
    static CurveVertex interpolate(CurveVertex const &value, CurveVertex const &to, double amount) {
        return CurveVertex::absolute(
            ValueInterpolator<Vector2D>::interpolate(value.point, to.point, amount),
            ValueInterpolator<Vector2D>::interpolate(value.inTangent, to.inTangent, amount),
            ValueInterpolator<Vector2D>::interpolate(value.outTangent, to.outTangent, amount)
        );
    }
};

template<>
struct ValueInterpolator<BezierPath> {
public:
    static BezierPath interpolate(BezierPath const &value, BezierPath const &to, double amount, std::optional<Vector2D> spatialOutTangent, std::optional<Vector2D> spatialInTangent) {
        BezierPath newPath;
        newPath.reserveCapacity(std::max(value.elements().size(), to.elements().size()));
        //TODO:probably a bug in the upstream code, uncomment
        //newPath.setClosed(value.closed());
        size_t elementCount = std::min(value.elements().size(), to.elements().size());
        
        if (spatialInTangent && spatialOutTangent) {
            Vector2D spatialInTangentValue = spatialInTangent.value();
            Vector2D spatialOutTangentValue = spatialOutTangent.value();
            
            for (size_t i = 0; i < elementCount; i++) {
                const auto &fromVertex = value.elements()[i].vertex;
                const auto &toVertex = to.elements()[i].vertex;
                
                newPath.addVertex(ValueInterpolator<CurveVertex>::interpolate(fromVertex, toVertex, amount, spatialOutTangentValue, spatialInTangentValue));
            }
        } else {
            for (size_t i = 0; i < elementCount; i++) {
                const auto &fromVertex = value.elements()[i].vertex;
                const auto &toVertex = to.elements()[i].vertex;
                
                newPath.addVertex(ValueInterpolator<CurveVertex>::interpolate(fromVertex, toVertex, amount));
            }
        }
        return newPath;
    }
    
    static void setInplace(BezierPath const &value, BezierPath &resultPath) {
        resultPath.reserveCapacity(value.elements().size());
        resultPath.setElementCount(value.elements().size());
        resultPath.invalidateLength();
        
        memcpy(resultPath.mutableElements().data(), value.elements().data(), value.elements().size() * sizeof(PathElement));
    }
    
    static void interpolateInplace(BezierPath const &value, BezierPath const &to, double amount, std::optional<Vector2D> spatialOutTangent, std::optional<Vector2D> spatialInTangent, BezierPath &resultPath) {
        /*if (value.elements().size() != to.elements().size()) {
            return to;
        }*/
        
        //TODO:probably a bug in the upstream code, uncomment
        //newPath.setClosed(value.closed());
        int elementCount = (int)std::min(value.elements().size(), to.elements().size());
        
        resultPath.reserveCapacity(std::max(value.elements().size(), to.elements().size()));
        resultPath.setElementCount(elementCount);
        resultPath.invalidateLength();
        
        if (spatialInTangent && spatialOutTangent) {
            Vector2D spatialInTangentValue = spatialInTangent.value();
            Vector2D spatialOutTangentValue = spatialOutTangent.value();
            
            for (int i = 0; i < elementCount; i++) {
                const auto &fromVertex = value.elements()[i].vertex;
                const auto &toVertex = to.elements()[i].vertex;
                
                auto vertex = ValueInterpolator<CurveVertex>::interpolate(fromVertex, toVertex, amount, spatialOutTangentValue, spatialInTangentValue);
                
                resultPath.updateVertex(vertex, i, false);
            }
        } else {
            for (int i = 0; i < elementCount; i++) {
                const auto &fromVertex = value.elements()[i].vertex;
                const auto &toVertex = to.elements()[i].vertex;
                
                auto vertex = ValueInterpolator<CurveVertex>::interpolate(fromVertex, toVertex, amount);
                
                resultPath.updateVertex(vertex, i, false);
            }
        }
    }
};

template<>
struct ValueInterpolator<TextDocument> {
public:
    static TextDocument interpolate(TextDocument const &value, TextDocument const &to, double amount, std::optional<Vector2D> spatialOutTangent, std::optional<Vector2D> spatialInTangent) {
        if (amount == 1.0) {
            return to;
        } else {
            return value;
        }
    }
};

template<>
struct ValueInterpolator<GradientColorSet> {
public:
    static GradientColorSet interpolate(GradientColorSet const &value, GradientColorSet const &to, double amount, std::optional<Vector2D> spatialOutTangent, std::optional<Vector2D> spatialInTangent) {
        assert(value.colors.size() == to.colors.size());
        std::vector<double> colors;
        size_t colorCount = std::min(value.colors.size(), to.colors.size());
        for (size_t i = 0; i < colorCount; i++) {
            colors.push_back(ValueInterpolator<double>::interpolate(value.colors[i], to.colors[i], amount, spatialOutTangent, spatialInTangent));
        }
        return GradientColorSet(colors);
    }
};

template<>
struct ValueInterpolator<DashPattern> {
public:
    static DashPattern interpolate(DashPattern const &value, DashPattern const &to, double amount, std::optional<Vector2D> spatialOutTangent, std::optional<Vector2D> spatialInTangent) {
        assert(value.values.size() == to.values.size());
        std::vector<double> values;
        size_t colorCount = std::min(value.values.size(), to.values.size());
        for (size_t i = 0; i < colorCount; i++) {
            values.push_back(ValueInterpolator<double>::interpolate(value.values[i], to.values[i], amount, spatialOutTangent, spatialInTangent));
        }
        return DashPattern(std::move(values));
    }
};

}

#endif /* ValueInterpolators_hpp */
