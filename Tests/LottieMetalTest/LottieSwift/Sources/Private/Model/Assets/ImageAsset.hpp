#ifndef ImageAsset_hpp
#define ImageAsset_hpp

#include "Lottie/Private/Model/Assets/Asset.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

namespace lottie {

class ImageAsset: public Asset {
public:
    ImageAsset(
        std::string id_,
        std::string name_,
        std::string directory_,
        double width_,
        double height_
    ) : Asset(id_),
    name(name_),
    directory(directory_),
    width(width_),
    height(height_) {
    }
    
    explicit ImageAsset(json11::Json::object const &json) noexcept(false) :
    Asset(json) {
        name = getString(json, "p");
        directory = getString(json, "u");
        width = getDouble(json, "w");
        height = getDouble(json, "h");
        
        _e = getOptionalInt(json, "e");
        _t = getOptionalString(json, "t");
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        Asset::toJson(json);
        
        json.insert(std::make_pair("p", name));
        json.insert(std::make_pair("u", directory));
        json.insert(std::make_pair("w", width));
        json.insert(std::make_pair("h", height));
        
        if (_e.has_value()) {
            json.insert(std::make_pair("e", _e.value()));
        }
        if (_t.has_value()) {
            json.insert(std::make_pair("t", _t.value()));
        }
    }
    
public:
    /// Image name
    std::string name;
    
    /// Image Directory
    std::string directory;
    
    /// Image Size
    double width;
    double height;
    
    std::optional<int> _e;
    std::optional<std::string> _t;
};

/*extension Data {
    
    // MARK: Lifecycle
    
    /// Initializes `Data` from an `ImageAsset`.
    ///
    /// Returns nil when the input is not recognized as valid Data URL.
    /// - parameter imageAsset: The image asset that contains Data URL.
    internal init?(imageAsset: ImageAsset) {
        self.init(dataString: imageAsset.name)
    }
    
    /// Initializes `Data` from a [Data URL](https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/Data_URIs) String.
    ///
    /// Returns nil when the input is not recognized as valid Data URL.
    /// - parameter dataString: The data string to parse.
    /// - parameter options: Options for the string parsing. Default value is `[]`.
    internal init?(dataString: String, options: DataURLReadOptions = []) {
        guard
        dataString.hasPrefix("data:"),
        let url = URL(string: dataString)
        else {
            return nil
        }
        // The code below is needed because Data(contentsOf:) floods logs
        // with messages since url doesn't have a host. This only fixes flooding logs
        // when data inside Data URL is base64 encoded.
        if
        let base64Range = dataString.range(of: ";base64,"),
        !options.contains(DataURLReadOptions.legacy)
        {
            let encodedString = String(dataString[base64Range.upperBound...])
            self.init(base64Encoded: encodedString)
        } else {
            try? self.init(contentsOf: url)
        }
    }
    
    // MARK: Internal
    
    internal struct DataURLReadOptions: OptionSet {
        let rawValue: Int
        
        /// Will read Data URL using Data(contentsOf:)
        static let legacy = DataURLReadOptions(rawValue: 1 << 0)
    }
    
};*/

}

#endif /* ImageAsset_hpp */
