#include "CompositionLayersInitializer.hpp"

#include "Lottie/Private/MainThread/LayerContainers/CompLayers/NullCompositionLayer.hpp"
#include "Lottie/Private/MainThread/LayerContainers/CompLayers/ShapeCompositionLayer.hpp"
#include "Lottie/Private/MainThread/LayerContainers/CompLayers/PreCompositionLayer.hpp"
#include "Lottie/Private/MainThread/LayerContainers/CompLayers/ImageCompositionLayer.hpp"
#include "Lottie/Private/MainThread/LayerContainers/CompLayers/TextCompositionLayer.hpp"

namespace lottie {

std::vector<std::shared_ptr<CompositionLayer>> initializeCompositionLayers(
    std::vector<std::shared_ptr<LayerModel>> const &layers,
    std::shared_ptr<AssetLibrary> const &assetLibrary,
    std::shared_ptr<LayerImageProvider> const &layerImageProvider,
    std::shared_ptr<AnimationTextProvider> const &textProvider,
    std::shared_ptr<AnimationFontProvider> const &fontProvider,
    double frameRate
) {
    std::vector<std::shared_ptr<CompositionLayer>> compositionLayers;
    std::map<int, std::shared_ptr<CompositionLayer>> layerMap;
    
    /// Organize the assets into a dictionary of [ID : ImageAsset]
    std::vector<std::shared_ptr<LayerModel>> childLayers;
    
    for (const auto &layer : layers) {
        if (layer->hidden) {
            auto genericLayer = std::make_shared<NullCompositionLayer>(layer);
            compositionLayers.push_back(genericLayer);
            if (layer->index) {
                layerMap.insert(std::make_pair(layer->index.value(), genericLayer));
            }
        } else if (layer->type == LayerType::Shape) {
            auto shapeContainer = std::make_shared<ShapeCompositionLayer>(std::static_pointer_cast<ShapeLayerModel>(layer));
            compositionLayers.push_back(shapeContainer);
            if (layer->index) {
                layerMap.insert(std::make_pair(layer->index.value(), shapeContainer));
            }
        } else if (layer->type == LayerType::Solid) {
            auto shapeContainer = std::make_shared<ShapeCompositionLayer>(std::static_pointer_cast<SolidLayerModel>(layer));
            compositionLayers.push_back(shapeContainer);
            if (layer->index) {
                layerMap.insert(std::make_pair(layer->index.value(), shapeContainer));
            }
        } else if (layer->type == LayerType::Precomp && assetLibrary) {
            auto precompLayer = std::static_pointer_cast<PreCompLayerModel>(layer);
            auto precompAssetIt = assetLibrary->precompAssets.find(precompLayer->referenceID);
            if (precompAssetIt != assetLibrary->precompAssets.end()) {
                auto precompContainer = std::make_shared<PreCompositionLayer>(
                    precompLayer,
                    *(precompAssetIt->second),
                    layerImageProvider,
                    textProvider,
                    fontProvider,
                    assetLibrary,
                    frameRate
                );
                compositionLayers.push_back(precompContainer);
                if (layer->index) {
                    layerMap.insert(std::make_pair(layer->index.value(), precompContainer));
                }
            }
        } else if (layer->type == LayerType::Image && assetLibrary) {
            auto imageLayer = std::static_pointer_cast<ImageLayerModel>(layer);
            auto imageAssetIt = assetLibrary->imageAssets.find(imageLayer->referenceID);
            if (imageAssetIt != assetLibrary->imageAssets.end()) {
                auto imageContainer = std::make_shared<ImageCompositionLayer>(
                    imageLayer,
                    Vector2D((*imageAssetIt->second).width, (*imageAssetIt->second).height)
                );
                compositionLayers.push_back(imageContainer);
                if (layer->index) {
                    layerMap.insert(std::make_pair(layer->index.value(), imageContainer));
                }
            }
        } else if (layer->type == LayerType::Text) {
            auto textContainer = std::make_shared<TextCompositionLayer>(std::static_pointer_cast<TextLayerModel>(layer), textProvider, fontProvider);
            compositionLayers.push_back(textContainer);
            if (layer->index) {
                layerMap.insert(std::make_pair(layer->index.value(), textContainer));
            }
        } else {
            auto genericLayer = std::make_shared<NullCompositionLayer>(layer);
            compositionLayers.push_back(genericLayer);
            if (layer->index) {
                layerMap.insert(std::make_pair(layer->index.value(), genericLayer));
            }
        }
        if (layer->parent) {
            childLayers.push_back(layer);
        }
    }
    
    /// Now link children with their parents
    for (const auto &layerModel : childLayers) {
        if (!layerModel->index.has_value()) {
            continue;
        }
        if (const auto parentID = layerModel->parent) {
            auto childLayerIt = layerMap.find(layerModel->index.value());
            if (childLayerIt != layerMap.end()) {
                auto parentLayerIt = layerMap.find(parentID.value());
                if (parentLayerIt != layerMap.end()) {
                    childLayerIt->second->transformNode()->setParentNode(parentLayerIt->second->transformNode());
                }
            }
        }
    }
    
    return compositionLayers;
}

}
