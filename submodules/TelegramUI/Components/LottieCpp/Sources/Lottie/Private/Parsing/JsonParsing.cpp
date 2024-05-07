#include "JsonParsing.hpp"

#include <cassert>

namespace lottie {

thread_local int isExceptionExpectedLevel = 0;

LottieParsingException::Guard::Guard() {
    assert(isExceptionExpectedLevel >= 0);
    isExceptionExpectedLevel++;
}

LottieParsingException::Guard::~Guard() {
    assert(isExceptionExpectedLevel - 1 >= 0);
    isExceptionExpectedLevel--;
}

LottieParsingException::LottieParsingException() {
    if (isExceptionExpectedLevel == 0) {
        assert(true);
    }
}

const char* LottieParsingException::what() const throw() {
    return "Lottie parsing exception";
}

lottiejson11::Json getAny(lottiejson11::Json::object const &object, std::string const &key) noexcept(false) {
    auto value = object.find(key);
    if (value == object.end()) {
        throw LottieParsingException();
    }
    return value->second;
}

std::optional<lottiejson11::Json> getOptionalAny(lottiejson11::Json::object const &object, std::string const &key) noexcept(false) {
    auto value = object.find(key);
    if (value == object.end()) {
        return std::nullopt;
    }
    return value->second;
}

lottiejson11::Json::object getObject(lottiejson11::Json::object const &object, std::string const &key) noexcept(false) {
    auto value = object.find(key);
    if (value == object.end()) {
        throw LottieParsingException();
    }
    if (!value->second.is_object()) {
        throw LottieParsingException();
    }
    return value->second.object_items();
}

std::optional<lottiejson11::Json::object> getOptionalObject(lottiejson11::Json::object const &object, std::string const &key) noexcept(false) {
    auto value = object.find(key);
    if (value == object.end()) {
        return std::nullopt;
    }
    if (!value->second.is_object()) {
        throw LottieParsingException();
    }
    return value->second.object_items();
}

std::vector<lottiejson11::Json::object> getObjectArray(lottiejson11::Json::object const &object, std::string const &key) noexcept(false) {
    auto value = object.find(key);
    if (value == object.end()) {
        throw LottieParsingException();
    }
    if (!value->second.is_array()) {
        throw LottieParsingException();
    }
    
    std::vector<lottiejson11::Json::object> result;
    for (const auto &item : value->second.array_items()) {
        if (!item.is_object()) {
            throw LottieParsingException();
        }
        result.push_back(item.object_items());
    }
    
    return result;
}

std::optional<std::vector<lottiejson11::Json::object>> getOptionalObjectArray(lottiejson11::Json::object const &object, std::string const &key) noexcept(false) {
    auto value = object.find(key);
    if (value == object.end()) {
        return std::nullopt;
    }
    if (!value->second.is_array()) {
        throw LottieParsingException();
    }
    
    std::vector<lottiejson11::Json::object> result;
    for (const auto &item : value->second.array_items()) {
        if (!item.is_object()) {
            throw LottieParsingException();
        }
        result.push_back(item.object_items());
    }
    
    return result;
}

std::vector<lottiejson11::Json> getAnyArray(lottiejson11::Json::object const &object, std::string const &key) noexcept(false) {
    auto value = object.find(key);
    if (value == object.end()) {
        throw LottieParsingException();
    }
    if (!value->second.is_array()) {
        throw LottieParsingException();
    }
    
    return value->second.array_items();
}

std::optional<std::vector<lottiejson11::Json>> getOptionalAnyArray(lottiejson11::Json::object const &object, std::string const &key) noexcept(false) {
    auto value = object.find(key);
    if (value == object.end()) {
        throw std::nullopt;
    }
    if (!value->second.is_array()) {
        throw LottieParsingException();
    }
    
    return value->second.array_items();
}

std::string getString(lottiejson11::Json::object const &object, std::string const &key) noexcept(false) {
    auto value = object.find(key);
    if (value == object.end()) {
        throw LottieParsingException();
    }
    if (!value->second.is_string()) {
        throw LottieParsingException();
    }
    return value->second.string_value();
}

std::optional<std::string> getOptionalString(lottiejson11::Json::object const &object, std::string const &key) noexcept(false) {
    auto value = object.find(key);
    if (value == object.end()) {
        return std::nullopt;
    }
    if (!value->second.is_string()) {
        throw LottieParsingException();
    }
    return value->second.string_value();
}

int32_t getInt(lottiejson11::Json::object const &object, std::string const &key) noexcept(false) {
    auto value = object.find(key);
    if (value == object.end()) {
        throw LottieParsingException();
    }
    if (!value->second.is_number()) {
        throw LottieParsingException();
    }
    return value->second.int_value();
}

std::optional<int32_t> getOptionalInt(lottiejson11::Json::object const &object, std::string const &key) noexcept(false) {
    auto value = object.find(key);
    if (value == object.end()) {
        return std::nullopt;
    }
    if (!value->second.is_number()) {
        throw LottieParsingException();
    }
    return value->second.int_value();
}

double getDouble(lottiejson11::Json::object const &object, std::string const &key) noexcept(false) {
    auto value = object.find(key);
    if (value == object.end()) {
        throw LottieParsingException();
    }
    if (!value->second.is_number()) {
        throw LottieParsingException();
    }
    return value->second.number_value();
}

std::optional<double> getOptionalDouble(lottiejson11::Json::object const &object, std::string const &key) noexcept(false) {
    auto value = object.find(key);
    if (value == object.end()) {
        return std::nullopt;
    }
    if (!value->second.is_number()) {
        throw LottieParsingException();
    }
    return value->second.number_value();
}

bool getBool(lottiejson11::Json::object const &object, std::string const &key) noexcept(false) {
    auto value = object.find(key);
    if (value == object.end()) {
        throw LottieParsingException();
    }
    if (!value->second.is_bool()) {
        throw LottieParsingException();
    }
    return value->second.bool_value();
}

std::optional<bool> getOptionalBool(lottiejson11::Json::object const &object, std::string const &key) noexcept(false) {
    auto value = object.find(key);
    if (value == object.end()) {
        return std::nullopt;
    }
    if (!value->second.is_bool()) {
        throw LottieParsingException();
    }
    return value->second.bool_value();
}

}
