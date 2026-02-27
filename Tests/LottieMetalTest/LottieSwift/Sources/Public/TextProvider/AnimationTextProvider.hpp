#ifndef AnimationTextProvider_hpp
#define AnimationTextProvider_hpp

#include <string>
#include <map>

namespace lottie {

/// Text provider is a protocol that is used to supply text to `AnimationView`.
class AnimationTextProvider {
public:
    virtual std::string textFor(std::string const &keypathName, std::string const &sourceText) = 0;
};

/// Text provider that simply map values from dictionary
class DictionaryTextProvider: public AnimationTextProvider {
public:
    DictionaryTextProvider(std::map<std::string, std::string> const &values) :
    _values(values) {
    }
    
    virtual std::string textFor(std::string const &keypathName, std::string const &sourceText) override {
        const auto it = _values.find(keypathName);
        if (it != _values.end()) {
            return it->second;
        } else {
            return sourceText;
        }
    }
    
private:
    std::map<std::string, std::string> _values;
};

/// Default text provider. Uses text in the animation file
class DefaultTextProvider: public AnimationTextProvider {
public:
    DefaultTextProvider() {
    }

    virtual std::string textFor(std::string const &keypathName, std::string const &sourceText) override {
        return sourceText;
    }
};

}

#endif /* AnimationTextProvider_hpp */
