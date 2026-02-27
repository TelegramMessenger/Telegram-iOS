#ifndef Animation_hpp
#define Animation_hpp

#include "Lottie/Public/Primitives/AnimationTime.hpp"
#include "Lottie/Private/Utility/Primitives/CoordinateSpace.hpp"
#include "Lottie/Private/Model/Layers/LayerModel.hpp"
#include "Lottie/Private/Model/Text/Glyph.hpp"
#include "Lottie/Private/Model/Text/Font.hpp"
#include "Lottie/Private/Model/Objects/Marker.hpp"
#include "Lottie/Private/Model/Assets/AssetLibrary.hpp"
#include "Lottie/Private/Model/Objects/FitzModifier.hpp"

#include "json11/json11.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"
#include "Lottie/Private/Model/Layers/LayerModelSerialization.hpp"

#include <string>
#include <vector>
#include <map>
#include <memory>

namespace lottie {

/// The `Animation` model is the top level model object in Lottie.
///
/// An `Animation` holds all of the animation data backing a Lottie Animation.
/// Codable, see JSON schema [here](https://github.com/airbnb/lottie-web/tree/master/docs/json).
class Animation {
public:
    Animation(
        std::optional<std::string> name_,
        std::optional<int> tgs_,
        AnimationFrameTime startFrame_,
        AnimationFrameTime endFrame_,
        double framerate_,
        std::string const &version_,
        std::optional<CoordinateSpace> type_,
        int width_,
        int height_,
        std::vector<std::shared_ptr<LayerModel>> const &layers_,
        std::optional<std::vector<std::shared_ptr<Glyph>>> glyphs_,
        std::optional<std::shared_ptr<FontList>> fonts_,
        std::shared_ptr<AssetLibrary> assetLibrary_,
        std::optional<std::vector<Marker>> markers_,
        std::optional<std::vector<FitzModifier>> fitzModifiers_,
        std::optional<json11::Json> meta_,
        std::optional<json11::Json> comps_
    ) :
    name(name_),
    tgs(tgs_),
    startFrame(startFrame_),
    endFrame(endFrame_),
    framerate(framerate_),
    version(version_),
    type(type_),
    width(width_),
    height(height_),
    layers(layers_),
    glyphs(glyphs_),
    fonts(fonts_),
    assetLibrary(assetLibrary_),
    markers(markers_),
    fitzModifiers(fitzModifiers_),
    meta(meta_),
    comps(comps_) {
        if (markers) {
            std::map<std::string, Marker> parsedMarkerMap;
            for (const auto &marker : markers.value()) {
                parsedMarkerMap.insert(std::make_pair(marker.name, marker));
            }
            markerMap = std::move(parsedMarkerMap);
        }
    }
    
    Animation(const Animation&) = delete;
    Animation& operator=(Animation&) = delete;
    
    static std::shared_ptr<Animation> fromJson(json11::Json::object const &json) noexcept(false) {
        auto name = getOptionalString(json, "nm");
        auto version = getString(json, "v");
        
        auto tgs = getOptionalInt(json, "tgs");
        
        std::optional<CoordinateSpace> type;
        if (const auto typeRawValue = getOptionalInt(json, "ddd")) {
            if (typeRawValue.value() == 0) {
                type = CoordinateSpace::Type2d;
            } else {
                type = CoordinateSpace::Type3d;
            }
        }
        
        AnimationFrameTime startFrame = getDouble(json, "ip");
        AnimationFrameTime endFrame = getDouble(json, "op");
        
        double framerate = getDouble(json, "fr");
        
        int width = getInt(json, "w");
        int height = getInt(json, "h");
        
        auto layerDictionaries = getObjectArray(json, "layers");
        std::vector<std::shared_ptr<LayerModel>> layers;
        for (size_t i = 0; i < layerDictionaries.size(); i++) {
            try {
                auto layer = parseLayerModel(layerDictionaries[i]);
                layers.push_back(layer);
            } catch(...) {
                throw LottieParsingException();
            }
        }
        
        std::optional<std::vector<std::shared_ptr<Glyph>>> glyphs;
        if (const auto glyphDictionaries = getOptionalObjectArray(json, "chars")) {
            glyphs = std::vector<std::shared_ptr<Glyph>>();
            for (const auto &glyphDictionary : glyphDictionaries.value()) {
                glyphs->push_back(std::make_shared<Glyph>(glyphDictionary));
            }
        } else {
            glyphs = std::nullopt;
        }
        
        std::optional<std::shared_ptr<FontList>> fonts;
        if (const auto fontsDictionary = getOptionalObject(json, "fonts")) {
            fonts = std::make_shared<FontList>(fontsDictionary.value());
        }
        
        std::shared_ptr<AssetLibrary> assetLibrary;
        if (const auto assetLibraryData = getOptionalAny(json, "assets")) {
            assetLibrary = std::make_shared<AssetLibrary>(assetLibraryData.value());
        }
        
        std::optional<std::vector<Marker>> markers;
        if (const auto markerDictionaries = getOptionalObjectArray(json, "markers")) {
            markers = std::vector<Marker>();
            for (const auto &markerDictionary : markerDictionaries.value()) {
                markers->push_back(Marker(markerDictionary));
            }
        }
        std::optional<std::vector<FitzModifier>> fitzModifiers;
        if (const auto fitzModifierDictionaries = getOptionalObjectArray(json, "fitz")) {
            fitzModifiers = std::vector<FitzModifier>();
            for (const auto &fitzModifierDictionary : fitzModifierDictionaries.value()) {
                fitzModifiers->push_back(FitzModifier(fitzModifierDictionary));
            }
        }
        
        auto meta = getOptionalAny(json, "meta");
        auto comps = getOptionalAny(json, "comps");
        
        return std::make_shared<Animation>(
            name,
            tgs,
            startFrame,
            endFrame,
            framerate,
            version,
            type,
            width,
            height,
            std::move(layers),
            std::move(glyphs),
            std::move(fonts),
            assetLibrary,
            std::move(markers),
            fitzModifiers,
            meta,
            comps
        );
    }
    
    json11::Json::object toJson() const {
        json11::Json::object result;
        
        if (name.has_value()) {
            result.insert(std::make_pair("nm", name.value()));
        }
        
        result.insert(std::make_pair("v", json11::Json(version)));
        
        if (tgs.has_value()) {
            result.insert(std::make_pair("tgs", tgs.value()));
        }
        
        if (type.has_value()) {
            switch (type.value()) {
                case CoordinateSpace::Type2d:
                    result.insert(std::make_pair("ddd", json11::Json(0)));
                    break;
                case CoordinateSpace::Type3d:
                    result.insert(std::make_pair("ddd", json11::Json(1)));
                    break;
            }
        }
        
        result.insert(std::make_pair("ip", json11::Json(startFrame)));
        result.insert(std::make_pair("op", json11::Json(endFrame)));
        result.insert(std::make_pair("fr", json11::Json(framerate)));
        result.insert(std::make_pair("w", json11::Json(width)));
        result.insert(std::make_pair("h", json11::Json(height)));
        
        json11::Json::array layersArray;
        for (const auto &layer : layers) {
            json11::Json::object layerJson;
            layer->toJson(layerJson);
            layersArray.push_back(layerJson);
        }
        result.insert(std::make_pair("layers", json11::Json(layersArray)));
        
        if (glyphs.has_value()) {
            json11::Json::array glyphArray;
            for (const auto &glyph : glyphs.value()) {
                glyphArray.push_back(glyph->toJson());
            }
            result.insert(std::make_pair("chars", json11::Json(glyphArray)));
        }
        
        if (fonts.has_value()) {
            result.insert(std::make_pair("fonts", fonts.value()->toJson()));
        }
        
        if (assetLibrary) {
            result.insert(std::make_pair("assets", assetLibrary->toJson()));
        }
        
        if (markers.has_value()) {
            json11::Json::array markerArray;
            for (const auto &marker : markers.value()) {
                markerArray.push_back(marker.toJson());
            }
            result.insert(std::make_pair("markers", json11::Json(markerArray)));
        }
        
        if (fitzModifiers.has_value()) {
            json11::Json::array fitzModifierArray;
            for (const auto &fitzModifier : fitzModifiers.value()) {
                fitzModifierArray.push_back(fitzModifier.toJson());
            }
            result.insert(std::make_pair("fitz", json11::Json(fitzModifierArray)));
        }
        
        if (meta.has_value()) {
            result.insert(std::make_pair("meta", meta.value()));
        }
        if (comps.has_value()) {
            result.insert(std::make_pair("comps", comps.value()));
        }
        
        return result;
    }
    
public:
    /// The start time of the composition in frameTime.
    AnimationFrameTime startFrame;
    
    /// The end time of the composition in frameTime.
    AnimationFrameTime endFrame;
    
    /// The frame rate of the composition.
    double framerate;
    
    /// Return all marker names, in order, or an empty list if none are specified
    std::vector<std::string> markerNames() {
        if (!markers.has_value()) {
            return {};
        }
        std::vector<std::string> result;
        for (const auto &marker : markers.value()) {
            result.push_back(marker.name);
        }
        return result;
    }
    
    /// Animation name
    std::optional<std::string> name;
    
    /// The version of the JSON Schema.
    std::string version;
    
    std::optional<int> tgs;
    
    /// The coordinate space of the composition.
    std::optional<CoordinateSpace> type;
    
    /// The height of the composition in points.
    int width;
    
    /// The width of the composition in points.
    int height;
    
    /// The list of animation layers
    std::vector<std::shared_ptr<LayerModel>> layers;
    
    /// The list of glyphs used for text rendering
    std::optional<std::vector<std::shared_ptr<Glyph>>> glyphs;
    
    /// The list of fonts used for text rendering
    std::optional<std::shared_ptr<FontList>> fonts;
    
    /// Asset Library
    std::shared_ptr<AssetLibrary> assetLibrary;
    
    /// Markers
    std::optional<std::vector<Marker>> markers;
    std::optional<std::map<std::string, Marker>> markerMap;
    
    std::optional<std::vector<FitzModifier>> fitzModifiers;
    
    std::optional<json11::Json> meta;
    std::optional<json11::Json> comps;
};

}

#endif /* Animation_hpp */
