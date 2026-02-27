#ifndef JsonParsing_hpp
#define JsonParsing_hpp

#include "json11/json11.hpp"

#include <exception>
#include <string>
#include <vector>

namespace lottie {

class LottieParsingException: public std::exception {
public:
    class Guard {
    public:
        Guard();
        ~Guard();
    };
    
public:
    LottieParsingException();
    
    virtual const char* what() const throw();
};

json11::Json getAny(json11::Json::object const &object, std::string const &key) noexcept(false);
std::optional<json11::Json> getOptionalAny(json11::Json::object const &object, std::string const &key) noexcept(false);

json11::Json::object getObject(json11::Json::object const &object, std::string const &key) noexcept(false);
std::optional<json11::Json::object> getOptionalObject(json11::Json::object const &object, std::string const &key) noexcept(false);

std::vector<json11::Json::object> getObjectArray(json11::Json::object const &object, std::string const &key) noexcept(false);
std::optional<std::vector<json11::Json::object>> getOptionalObjectArray(json11::Json::object const &object, std::string const &key) noexcept(false);

std::vector<json11::Json> getAnyArray(json11::Json::object const &object, std::string const &key) noexcept(false);
std::optional<std::vector<json11::Json>> getOptionalAnyArray(json11::Json::object const &object, std::string const &key) noexcept(false);

std::string getString(json11::Json::object const &object, std::string const &key) noexcept(false);
std::optional<std::string> getOptionalString(json11::Json::object const &object, std::string const &key) noexcept(false);

int32_t getInt(json11::Json::object const &object, std::string const &key) noexcept(false);
std::optional<int32_t> getOptionalInt(json11::Json::object const &object, std::string const &key) noexcept(false);

double getDouble(json11::Json::object const &object, std::string const &key) noexcept(false);
std::optional<double> getOptionalDouble(json11::Json::object const &object, std::string const &key) noexcept(false);

bool getBool(json11::Json::object const &object, std::string const &key) noexcept(false);
std::optional<bool> getOptionalBool(json11::Json::object const &object, std::string const &key) noexcept(false);

}

#endif /* JsonParsing_hpp */
