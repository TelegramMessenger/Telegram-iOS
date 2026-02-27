#ifndef TextLayerModel_hpp
#define TextLayerModel_hpp

#include "Lottie/Private/Model/Layers/LayerModel.hpp"
#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include "Lottie/Private/Model/Text/TextDocument.hpp"
#include "Lottie/Private/Model/Text/TextAnimator.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

namespace lottie {

/// A layer that holds text.
class TextLayerModel: public LayerModel {
public:
    TextLayerModel(json11::Json::object const &json) :
    LayerModel(json),
    text(KeyframeGroup<TextDocument>(TextDocument(
        "",
        0.0,
        "",
        TextJustification::Left,
        0,
        0.0,
        std::nullopt,
        std::nullopt,
        std::nullopt,
        std::nullopt,
        std::nullopt,
        std::nullopt,
        std::nullopt
    ))) {
        auto textContainer = getObject(json, "t");
        
        auto textData = getObject(textContainer, "d");
        text = KeyframeGroup<TextDocument>(textData);
        
        if (auto animatorsData = getOptionalObjectArray(textContainer, "a")) {
            for (const auto &animatorData : animatorsData.value()) {
                animators.push_back(std::make_shared<TextAnimator>(animatorData));
            }
        }
        
        _extraM = getOptionalAny(textContainer, "m");
        _extraP = getOptionalAny(textContainer, "p");
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        LayerModel::toJson(json);
        
        json11::Json::object textContainer;
        textContainer.insert(std::make_pair("d", text.toJson()));
        if (_extraM.has_value()) {
            textContainer.insert(std::make_pair("m", _extraM.value()));
        }
        if (_extraP.has_value()) {
            textContainer.insert(std::make_pair("p", _extraP.value()));
        }
        json11::Json::array animatorArray;
        for (const auto &animator : animators) {
            animatorArray.push_back(animator->toJson());
        }
        textContainer.insert(std::make_pair("a", animatorArray));
        
        json.insert(std::make_pair("t", textContainer));
    }
    
public:
    /// The text for the layer
    KeyframeGroup<TextDocument> text;
    
    /// Text animators
    std::vector<std::shared_ptr<TextAnimator>> animators;
    
    std::optional<json11::Json> _extraM;
    std::optional<json11::Json> _extraP;
    std::optional<json11::Json> _extraA;
};

}

#endif /* TextLayerModel_hpp */
