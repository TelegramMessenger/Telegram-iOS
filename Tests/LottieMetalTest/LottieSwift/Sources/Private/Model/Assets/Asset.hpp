#ifndef Asset_hpp
#define Asset_hpp

#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <string>
#include <sstream>

namespace lottie {

class Asset {
public:
    Asset(std::string id_) :
    id(id_) {
    }
    
    explicit Asset(json11::Json::object const &json) noexcept(false) {
        auto idData = getAny(json, "id");
        if (idData.is_string()) {
            id = idData.string_value();
        } else if (idData.is_number()) {
            std::ostringstream idString;
            idString << idData.int_value();
            id = idString.str();
        }
        
        objectName = getOptionalString(json, "nm");
    }
    
    Asset(const Asset&) = delete;
    Asset& operator=(Asset&) = delete;
    
    virtual void toJson(json11::Json::object &json) const {
        json.insert(std::make_pair("id", id));
        
        if (objectName.has_value()) {
            json.insert(std::make_pair("nm", objectName.value()));
        }
    }
    
public:
    /// The ID of the asset
    std::string id;
    
    std::optional<std::string> objectName;
};

}

#endif /* Asset_hpp */
