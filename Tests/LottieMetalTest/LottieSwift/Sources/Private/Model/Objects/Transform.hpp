#ifndef Transform_hpp
#define Transform_hpp

#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <optional>

namespace lottie {

class Transform {
public:
    enum class PositionInternalRepresentation {
        None,
        TopLevelXY,
        TopLevelCombined,
        NestedXY
    };
    
    enum class RotationZInternalRepresentation {
        RZ,
        R
    };
    
public:
    Transform(
        std::optional<KeyframeGroup<Vector3D>> anchorPoint_,
        std::optional<KeyframeGroup<Vector3D>> position_,
        std::optional<KeyframeGroup<Vector1D>> positionX_,
        std::optional<KeyframeGroup<Vector1D>> positionY_,
        std::optional<KeyframeGroup<Vector3D>> scale_,
        std::optional<KeyframeGroup<Vector1D>> rotation_,
        std::optional<KeyframeGroup<Vector1D>> &opacity_,
        std::optional<KeyframeGroup<Vector1D>> rotationZ_
    ) :
    _anchorPoint(anchorPoint_),
    _position(position_),
    _positionX(positionX_),
    _positionY(positionY_),
    _scale(scale_),
    _rotation(rotation_),
    _opacity(opacity_),
    _rotationZ(rotationZ_) {
    }
    
    explicit Transform(json11::Json::object const &json) noexcept(false) {
        // AnchorPoint
        if (const auto anchorPointDictionary = getOptionalObject(json, "a")) {
            _anchorPoint = KeyframeGroup<Vector3D>(anchorPointDictionary.value());
        }
        
        try {
            auto xDictionary = getOptionalObject(json, "px");
            auto yDictionary = getOptionalObject(json, "py");
            if (xDictionary.has_value() && yDictionary.has_value()) {
                _positionX = KeyframeGroup<Vector1D>(xDictionary.value());
                _positionY = KeyframeGroup<Vector1D>(yDictionary.value());
                _position = std::nullopt;
                _positionInternalRepresentation = PositionInternalRepresentation::TopLevelXY;
            } else if (const auto positionData = getOptionalObject(json, "p")) {
                try {
                    LottieParsingException::Guard expectedGuard;
                    
                    _position = KeyframeGroup<Vector3D>(positionData.value());
                    _positionX = std::nullopt;
                    _positionX = std::nullopt;
                    _positionInternalRepresentation = PositionInternalRepresentation::TopLevelCombined;
                } catch(...) {
                    auto xData = getObject(positionData.value(), "x");
                    auto yData = getObject(positionData.value(), "y");
                    _positionX = KeyframeGroup<Vector1D>(xData);
                    _positionY = KeyframeGroup<Vector1D>(yData);
                    _position = std::nullopt;
                    _positionInternalRepresentation = PositionInternalRepresentation::NestedXY;
                    _extra_positionS = getOptionalBool(positionData.value(), "s");
                }
            } else {
                _position = std::nullopt;
                _positionX = std::nullopt;
                _positionY = std::nullopt;
                _positionInternalRepresentation = PositionInternalRepresentation::None;
            }
        } catch(...) {
            throw LottieParsingException();
        }

        try {
        // Scale
        if (const auto scaleData = getOptionalObject(json, "s")) {
            _scale = KeyframeGroup<Vector3D>(scaleData.value());
        }

        // Rotation
        if (const auto rotationZData = getOptionalObject(json, "rz")) {
            _rotationZ = KeyframeGroup<Vector1D>(rotationZData.value());
            _rotationZInternalRepresentation = RotationZInternalRepresentation::RZ;
        } else if (const auto rotationData = getOptionalObject(json, "r")) {
            _rotation = KeyframeGroup<Vector1D>(rotationData.value());
            _rotationZInternalRepresentation = RotationZInternalRepresentation::R;
        }

        // Opacity
        if (const auto opacityData = getOptionalObject(json, "o")) {
            _opacity = KeyframeGroup<Vector1D>(opacityData.value());
        }
        } catch(...) {
            throw LottieParsingException();
        }
        
        _extraTy = getOptionalString(json, "ty");
        _extraSa = getOptionalAny(json, "sa");
        _extraSk = getOptionalAny(json, "sk");
    }
    
    json11::Json::object toJson() const {
        json11::Json::object result;
        
        if (_anchorPoint.has_value()) {
            result.insert(std::make_pair("a", _anchorPoint->toJson()));
        }
        
        switch (_positionInternalRepresentation) {
            case PositionInternalRepresentation::None:
                assert(!_positionX.has_value());
                assert(!_positionY.has_value());
                assert(!_position.has_value());
                break;
            case PositionInternalRepresentation::TopLevelXY:
                assert(_positionX.has_value());
                assert(_positionY.has_value());
                assert(!_position.has_value());
                result.insert(std::make_pair("x", _positionX->toJson()));
                result.insert(std::make_pair("y", _positionY->toJson()));
                break;
            case PositionInternalRepresentation::TopLevelCombined:
                assert(_position.has_value());
                assert(!_positionX.has_value());
                assert(!_positionY.has_value());
                result.insert(std::make_pair("p", _position->toJson()));
                break;
            case PositionInternalRepresentation::NestedXY:
                json11::Json::object nestedPosition;
                assert(_positionX.has_value());
                assert(_positionY.has_value());
                assert(!_position.has_value());
                nestedPosition.insert(std::make_pair("x", _positionX->toJson()));
                nestedPosition.insert(std::make_pair("y", _positionY->toJson()));
                if (_extra_positionS.has_value()) {
                    nestedPosition.insert(std::make_pair("s", _extra_positionS.value()));
                }
                result.insert(std::make_pair("p", nestedPosition));
                break;
        }
        
        if (_scale.has_value()) {
            result.insert(std::make_pair("s", _scale->toJson()));
        }
        
        if (_rotation.has_value()) {
            switch (_rotationZInternalRepresentation) {
                case RotationZInternalRepresentation::RZ:
                    result.insert(std::make_pair("rz", _rotation->toJson()));
                    break;
                case RotationZInternalRepresentation::R:
                    result.insert(std::make_pair("r", _rotation->toJson()));
                    break;
            }
        }
        
        if (_opacity.has_value()) {
            result.insert(std::make_pair("o", _opacity->toJson()));
        }
        
        if (_extraTy.has_value()) {
            result.insert(std::make_pair("ty", _extraTy.value()));
        }
        if (_extraSa.has_value()) {
            result.insert(std::make_pair("sa", _extraSa.value()));
        }
        if (_extraSk.has_value()) {
            result.insert(std::make_pair("sk", _extraSk.value()));
        }
        
        return result;
    }
    
    KeyframeGroup<Vector3D> anchorPoint() {
        if (_anchorPoint.has_value()) {
            return _anchorPoint.value();
        } else {
            return KeyframeGroup<Vector3D>(Vector3D(0.0, 0.0, 0.0));
        }
    }
    
    KeyframeGroup<Vector3D> scale() const {
        if (_scale) {
            return _scale.value();
        } else {
            return KeyframeGroup<Vector3D>(Vector3D(100.0, 100.0, 100.0));
        }
    }
    
    KeyframeGroup<Vector1D> rotation() const {
        if (_rotation) {
            return _rotation.value();
        } else {
            return KeyframeGroup<Vector1D>(Vector1D(0.0));
        }
    }
    
    KeyframeGroup<Vector1D> opacity() const {
        if (_opacity) {
            return _opacity.value();
        } else {
            return KeyframeGroup<Vector1D>(Vector1D(100.0));
        }
    }
    
    std::optional<KeyframeGroup<Vector3D>> const &position() const {
        return _position;
    }
    
    std::optional<KeyframeGroup<Vector1D>> const &positionX() const {
        return _positionX;
    }
    
    std::optional<KeyframeGroup<Vector1D>> const &positionY() const {
        return _positionY;
    }
    
private:
    /// The anchor point of the transform.
    std::optional<KeyframeGroup<Vector3D>> _anchorPoint;
    
    /// The position of the transform. This is nil if the position data was split.
    std::optional<KeyframeGroup<Vector3D>> _position;
    
    /// The positionX of the transform. This is nil if the position property is set.
    std::optional<KeyframeGroup<Vector1D>> _positionX;
    
    /// The positionY of the transform. This is nil if the position property is set.
    std::optional<KeyframeGroup<Vector1D>> _positionY;
    
    PositionInternalRepresentation _positionInternalRepresentation = PositionInternalRepresentation::None;
    
    /// The scale of the transform
    std::optional<KeyframeGroup<Vector3D>> _scale;
    
    /// The rotation of the transform. Note: This is single dimensional rotation.
    std::optional<KeyframeGroup<Vector1D>> _rotation;
    
    /// The opacity of the transform.
    std::optional<KeyframeGroup<Vector1D>> _opacity;
    
    /// Should always be nil.
    std::optional<KeyframeGroup<Vector1D>> _rotationZ;
    RotationZInternalRepresentation _rotationZInternalRepresentation;
    
    std::optional<bool> _extra_positionS;
    std::optional<std::string> _extraTy;
    std::optional<json11::Json> _extraSa;
    std::optional<json11::Json> _extraSk;
};

}

#endif /* Transform_hpp */
