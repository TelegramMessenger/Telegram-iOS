#ifndef AnyValue_hpp
#define AnyValue_hpp

#include <LottieCpp/Vectors.h>
#import <LottieCpp/Color.h>
#include <LottieCpp/BezierPath.h>
#include "Lottie/Private/Model/Text/TextDocument.hpp"
#include "Lottie/Private/Model/ShapeItems/GradientFill.hpp"
#include "Lottie/Private/Model/Objects/DashElement.hpp"

#include <memory>
#include <optional>

namespace lottie {

class AnyValue {
public:
    enum class Type {
        Float,
        Vector1D,
        Vector2D,
        Vector3D,
        Color,
        BezierPath,
        TextDocument,
        GradientColorSet,
        DashPattern
    };
    
public:
    AnyValue(float value) :
    _type(Type::Float),
    _floatValue(value) {
    }
    
    AnyValue(Vector1D const &value) :
    _type(Type::Vector1D),
    _vector1DValue(value) {
    }
    
    AnyValue(Vector2D const &value) :
    _type(Type::Vector2D),
    _vector2DValue(value) {
    }
    
    AnyValue(Vector3D const & value) :
    _type(Type::Vector3D),
    _vector3DValue(value) {
    }
    
    AnyValue(Color const &value) :
    _type(Type::Color),
    _colorValue(value) {
    }
    
    AnyValue(BezierPath const &value) :
    _type(Type::BezierPath),
    _bezierPathValue(value) {
    }
    
    AnyValue(TextDocument const &value) :
    _type(Type::TextDocument),
    _textDocumentValue(value) {
    }
    
    AnyValue(GradientColorSet const &value) :
    _type(Type::GradientColorSet),
    _gradientColorSetValue(value) {
    }
    
    AnyValue(DashPattern const &value) :
    _type(Type::DashPattern),
    _dashPatternValue(value) {
    }
    
    template<typename T, typename = std::enable_if_t<std::is_same<T, float>::value>>
    float get() {
        return asFloat();
    }
    
    template<typename T, typename = std::enable_if_t<std::is_same<T, Vector1D>::value>>
    Vector1D get() {
        return asVector1D();
    }
    
    template<typename T, typename = std::enable_if_t<std::is_same<T, Vector2D>::value>>
    Vector2D get() {
        return asVector2D();
    }
    
    template<typename T, typename = std::enable_if_t<std::is_same<T, Vector3D>::value>>
    Vector3D get() {
        return asVector3D();
    }
    
    template<typename T, typename = std::enable_if_t<std::is_same<T, Color>::value>>
    Color get() {
        return asColor();
    }
    
    template<typename T, typename = std::enable_if_t<std::is_same<T, BezierPath>::value>>
    BezierPath get() {
        return asBezierPath();
    }
    
    template<typename T, typename = std::enable_if_t<std::is_same<T, TextDocument>::value>>
    TextDocument get() {
        return asTextDocument();
    }
    
    template<typename T, typename = std::enable_if_t<std::is_same<T, GradientColorSet>::value>>
    GradientColorSet get() {
        return asGradientColorSet();
    }
    
    template<typename T, typename = std::enable_if_t<std::is_same<T, DashPattern>::value>>
    DashPattern get() {
        return asDashPattern();
    }
    
public:
    Type type() {
        return _type;
    }
    
    float asFloat() {
        return _floatValue.value();
    }
    
    Vector1D asVector1D() {
        return _vector1DValue.value();
    }
    
    Vector2D asVector2D() {
        return _vector2DValue.value();
    }
    
    Vector3D asVector3D() {
        return _vector3DValue.value();
    }
    
    Color asColor() {
        return _colorValue.value();
    }
    
    BezierPath asBezierPath() {
        return _bezierPathValue.value();
    }
    
    TextDocument asTextDocument() {
        return _textDocumentValue.value();
    }
    
    GradientColorSet asGradientColorSet() {
        return _gradientColorSetValue.value();
    }
    
    DashPattern asDashPattern() {
        return _dashPatternValue.value();
    }
    
private:
    Type _type;
    
    std::optional<float> _floatValue;
    std::optional<Vector1D> _vector1DValue;
    std::optional<Vector2D> _vector2DValue;
    std::optional<Vector3D> _vector3DValue;
    std::optional<Color> _colorValue;
    std::optional<BezierPath> _bezierPathValue;
    std::optional<TextDocument> _textDocumentValue;
    std::optional<GradientColorSet> _gradientColorSetValue;
    std::optional<DashPattern> _dashPatternValue;
};

template<typename T>
struct AnyValueType {
};

template<>
struct AnyValueType<float> {
    static AnyValue::Type type() {
        return AnyValue::Type::Float;
    }
};

template<>
struct AnyValueType<Vector1D> {
    static AnyValue::Type type() {
        return AnyValue::Type::Vector1D;
    }
};

template<>
struct AnyValueType<Vector2D> {
    static AnyValue::Type type() {
        return AnyValue::Type::Vector2D;
    }
};

template<>
struct AnyValueType<Vector3D> {
    static AnyValue::Type type() {
        return AnyValue::Type::Vector3D;
    }
};

template<>
struct AnyValueType<Color> {
    static AnyValue::Type type() {
        return AnyValue::Type::Color;
    }
};

template<>
struct AnyValueType<BezierPath> {
    static AnyValue::Type type() {
        return AnyValue::Type::BezierPath;
    }
};

template<>
struct AnyValueType<TextDocument> {
    static AnyValue::Type type() {
        return AnyValue::Type::TextDocument;
    }
};

template<>
struct AnyValueType<GradientColorSet> {
    static AnyValue::Type type() {
        return AnyValue::Type::GradientColorSet;
    }
};

template<>
struct AnyValueType<DashPattern> {
    static AnyValue::Type type() {
        return AnyValue::Type::DashPattern;
    }
};

}

#endif /* AnyValue_hpp */
