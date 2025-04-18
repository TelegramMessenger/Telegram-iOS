#ifndef AssetLibrary_hpp
#define AssetLibrary_hpp

#include "Lottie/Private/Model/Assets/Asset.hpp"
#include "Lottie/Private/Model/Assets/ImageAsset.hpp"
#include "Lottie/Private/Model/Assets/PrecompAsset.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <map>

namespace lottie {

class AssetLibrary {
public:
    AssetLibrary(
        std::map<std::string, std::shared_ptr<Asset>> const &assets_,
        std::map<std::string, std::shared_ptr<ImageAsset>> const &imageAssets_,
        std::map<std::string, std::shared_ptr<PrecompAsset>> const &precompAssets_
    ) :
    assets(assets_),
    imageAssets(imageAssets_),
    precompAssets(precompAssets_) {
    }
    
    explicit AssetLibrary(json11::Json const &json) noexcept(false) {
        if (!json.is_array()) {
            throw LottieParsingException();
        }
        
        for (const auto &item : json.array_items()) {
            if (!item.is_object()) {
                throw LottieParsingException();
            }
            if (item.object_items().find("layers") != item.object_items().end()) {
                auto asset = std::make_shared<PrecompAsset>(item.object_items());
                assets.insert(std::make_pair(asset->id, asset));
                assetList.push_back(asset);
                precompAssets.insert(std::make_pair(asset->id, asset));
            } else {
                auto asset = std::make_shared<ImageAsset>(item.object_items());
                assets.insert(std::make_pair(asset->id, asset));
                assetList.push_back(asset);
                imageAssets.insert(std::make_pair(asset->id, asset));
            }
        }
    }
    
    json11::Json::array toJson() const {
        json11::Json::array result;
        
        for (const auto &asset : assetList) {
            json11::Json::object assetJson;
            asset->toJson(assetJson);
            result.push_back(assetJson);
        }
        
        return result;
    }
    
public:
    /// The Assets
    std::vector<std::shared_ptr<Asset>> assetList;
    std::map<std::string, std::shared_ptr<Asset>> assets;
    
    std::map<std::string, std::shared_ptr<ImageAsset>> imageAssets;
    std::map<std::string, std::shared_ptr<PrecompAsset>> precompAssets;
};

}

#endif /* AssetLibrary_hpp */
