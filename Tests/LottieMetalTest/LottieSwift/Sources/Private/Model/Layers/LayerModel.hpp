#ifndef LayerModel_hpp
#define LayerModel_hpp

#include "Lottie/Private/Model/Objects/Transform.hpp"
#include "Lottie/Private/Model/Objects/Mask.hpp"
#include "Lottie/Private/Utility/Primitives/CoordinateSpace.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <string>
#include <optional>
#include <random>

namespace lottie {

enum class LayerType {
    Precomp,
    Solid,
    Image,
    Null,
    Shape,
    Text
};

LayerType parseLayerType(json11::Json::object const &json, std::string const &key);
int serializeLayerType(LayerType value);

enum class MatteType: int {
    None = 0,
    Add = 1,
    Invert = 2,
    Unknown = 3
};

enum class BlendMode: int {
    Normal = 0,
    Multiply = 1,
    Screen = 2,
    Overlay = 3,
    Darken = 4,
    Lighten = 5,
    ColorDodge = 6,
    ColorBurn = 7,
    HardLight = 8,
    SoftLight = 9,
    Difference = 10,
    Exclusion = 11,
    Hue = 12,
    Saturation = 13,
    Color = 14,
    Luminosity = 15
};

/// A base top container for shapes, images, and other view objects.
class LayerModel {
public:
    explicit LayerModel(json11::Json::object const &json) noexcept(false) {
        name = getOptionalString(json, "nm");
        index = getOptionalInt(json, "ind");
        
        type = parseLayerType(json, "ty");
        
        autoOrient = getOptionalInt(json, "ao");
        
        if (const auto typeRawValue = getOptionalInt(json, "ddd")) {
            if (typeRawValue.value() == 0) {
                coordinateSpace = CoordinateSpace::Type2d;
            } else {
                coordinateSpace = CoordinateSpace::Type3d;
            }
        } else {
            coordinateSpace = std::nullopt;
        }
        
        inFrame = getDouble(json, "ip");
        outFrame = getDouble(json, "op");
        startTime = getDouble(json, "st");
        
        transform = std::make_shared<Transform>(getObject(json, "ks"));
        parent = getOptionalInt(json, "parent");
        
        if (const auto blendModeRawValue = getOptionalInt(json, "bm")) {
            switch (blendModeRawValue.value()) {
                case 0:
                    blendMode = BlendMode::Normal;
                    break;
                case 1:
                    blendMode = BlendMode::Multiply;
                    break;
                case 2:
                    blendMode = BlendMode::Screen;
                    break;
                case 3:
                    blendMode = BlendMode::Overlay;
                    break;
                case 4:
                    blendMode = BlendMode::Darken;
                    break;
                case 5:
                    blendMode = BlendMode::Lighten;
                    break;
                case 6:
                    blendMode = BlendMode::ColorDodge;
                    break;
                case 7:
                    blendMode = BlendMode::ColorBurn;
                    break;
                case 8:
                    blendMode = BlendMode::HardLight;
                    break;
                case 9:
                    blendMode = BlendMode::SoftLight;
                    break;
                case 10:
                    blendMode = BlendMode::Difference;
                    break;
                case 11:
                    blendMode = BlendMode::Exclusion;
                    break;
                case 12:
                    blendMode = BlendMode::Hue;
                    break;
                case 13:
                    blendMode = BlendMode::Saturation;
                    break;
                case 14:
                    blendMode = BlendMode::Color;
                    break;
                case 15:
                    blendMode = BlendMode::Luminosity;
                    break;
                default:
                    throw LottieParsingException();
            }
        }
        
        if (const auto maskDictionaries = getOptionalObjectArray(json, "masksProperties")) {
            masks = std::vector<std::shared_ptr<Mask>>();
            for (const auto &maskDictionary : maskDictionaries.value()) {
                masks->push_back(std::make_shared<Mask>(maskDictionary));
            }
        }
        
        if (const auto timeStretchData = getOptionalDouble(json, "sr")) {
            _timeStretch = timeStretchData.value();
        }
        
        if (const auto matteRawValue = getOptionalInt(json, "tt")) {
            switch (matteRawValue.value()) {
                case 0:
                    matte = MatteType::None;
                    break;
                case 1:
                    matte = MatteType::Add;
                    break;
                case 2:
                    matte = MatteType::Invert;
                    break;
                case 3:
                    matte = MatteType::Unknown;
                    break;
                default:
                    throw LottieParsingException();
            }
        }
        
        if (const auto hiddenData = getOptionalBool(json, "hd")) {
            hidden = hiddenData.value();
        }
        
        hasMask = getOptionalBool(json, "hasMask");
        td = getOptionalInt(json, "td");
        effectsData = getOptionalAny(json, "ef");
        layerClass = getOptionalString(json, "cl");
        _extraHidden = getOptionalAny(json, "hidden");
    }
    
    LayerModel(const LayerModel&) = delete;
    LayerModel& operator=(LayerModel&) = delete;
    
    virtual void toJson(json11::Json::object &json) const {
        if (name.has_value()) {
            json.insert(std::make_pair("nm", name.value()));
        }
        if (index.has_value()) {
            json.insert(std::make_pair("ind", index.value()));
        }
        
        if (autoOrient.has_value()) {
            json.insert(std::make_pair("ao", autoOrient.value()));
        }
        
        json.insert(std::make_pair("ty", serializeLayerType(type)));
        
        if (coordinateSpace.has_value()) {
            switch (coordinateSpace.value()) {
                case CoordinateSpace::Type2d:
                    json.insert(std::make_pair("ddd", 0));
                    break;
                case CoordinateSpace::Type3d:
                    json.insert(std::make_pair("ddd", 1));
                    break;
            }
        }
        
        json.insert(std::make_pair("ip", inFrame));
        json.insert(std::make_pair("op", outFrame));
        json.insert(std::make_pair("st", startTime));
        
        json.insert(std::make_pair("ks", transform->toJson()));
        
        if (parent.has_value()) {
            json.insert(std::make_pair("parent", parent.value()));
        }
        
        if (blendMode.has_value()) {
            json.insert(std::make_pair("bm", (int)blendMode.value()));
        }
        
        if (masks.has_value()) {
            json11::Json::array maskArray;
            for (const auto &mask : masks.value()) {
                maskArray.push_back(mask->toJson());
            }
            json.insert(std::make_pair("masksProperties", maskArray));
        }
        
        if (_timeStretch.has_value()) {
            json.insert(std::make_pair("sr", _timeStretch.value()));
        }
        
        if (matte.has_value()) {
            json.insert(std::make_pair("tt", (int)matte.value()));
        }
        
        if (hidden.has_value()) {
            json.insert(std::make_pair("hd", hidden.value()));
        }
        
        if (hasMask.has_value()) {
            json.insert(std::make_pair("hasMask", hasMask.value()));
        }
        if (td.has_value()) {
            json.insert(std::make_pair("td", td.value()));
        }
        if (effectsData.has_value()) {
            json.insert(std::make_pair("ef", effectsData.value()));
        }
        if (layerClass.has_value()) {
            json.insert(std::make_pair("cl", layerClass.value()));
        }
        if (_extraHidden.has_value()) {
            json.insert(std::make_pair("hidden", _extraHidden.value()));
        }
    }
    
    double timeStretch() {
        if (_timeStretch.has_value()) {
            return _timeStretch.value();
        } else {
            return 1.0;
        }
    }
    
public:
    /// The readable name of the layer
    std::optional<std::string> name;
    
    /// The index of the layer
    std::optional<int> index;
    
    /// The type of the layer.
    LayerType type;
    
    std::optional<int> autoOrient;
    
    /// The coordinate space
    std::optional<CoordinateSpace> coordinateSpace;
    
    /// The in time of the layer in frames.
    double inFrame;
    /// The out time of the layer in frames.
    double outFrame;
    
    /// The start time of the layer in frames.
    double startTime;
    
    /// The transform of the layer
    std::shared_ptr<Transform> transform;
    
    /// The index of the parent layer, if applicable.
    std::optional<int> parent;
    
    /// The blending mode for the layer
    std::optional<BlendMode> blendMode;
    
    /// An array of masks for the layer.
    std::optional<std::vector<std::shared_ptr<Mask>>> masks;
    
    /// A number that stretches time by a multiplier
    std::optional<double> _timeStretch;
    
    /// The type of matte if any.
    std::optional<MatteType> matte;
    
    std::optional<bool> hidden;
    
    std::optional<bool> hasMask;
    std::optional<int> td;
    std::optional<json11::Json> effectsData;
    std::optional<std::string> layerClass;
    std::optional<json11::Json> _extraHidden;
};

}

#endif /* LayerModel_hpp */
