#ifndef JsonParsing_hpp
#define JsonParsing_hpp

#include <LottieCpp/lottiejson11.hpp>

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

lottiejson11::Json getAny(lottiejson11::Json::object const &object, std::string const &key) noexcept(false);
std::optional<lottiejson11::Json> getOptionalAny(lottiejson11::Json::object const &object, std::string const &key) noexcept(false);

lottiejson11::Json::object getObject(lottiejson11::Json::object const &object, std::string const &key) noexcept(false);
std::optional<lottiejson11::Json::object> getOptionalObject(lottiejson11::Json::object const &object, std::string const &key) noexcept(false);

std::vector<lottiejson11::Json::object> getObjectArray(lottiejson11::Json::object const &object, std::string const &key) noexcept(false);
std::optional<std::vector<lottiejson11::Json::object>> getOptionalObjectArray(lottiejson11::Json::object const &object, std::string const &key) noexcept(false);

std::vector<lottiejson11::Json> getAnyArray(lottiejson11::Json::object const &object, std::string const &key) noexcept(false);
std::optional<std::vector<lottiejson11::Json>> getOptionalAnyArray(lottiejson11::Json::object const &object, std::string const &key) noexcept(false);

std::string getString(lottiejson11::Json::object const &object, std::string const &key) noexcept(false);
std::optional<std::string> getOptionalString(lottiejson11::Json::object const &object, std::string const &key) noexcept(false);

int32_t getInt(lottiejson11::Json::object const &object, std::string const &key) noexcept(false);
std::optional<int32_t> getOptionalInt(lottiejson11::Json::object const &object, std::string const &key) noexcept(false);

double getDouble(lottiejson11::Json::object const &object, std::string const &key) noexcept(false);
std::optional<double> getOptionalDouble(lottiejson11::Json::object const &object, std::string const &key) noexcept(false);

bool getBool(lottiejson11::Json::object const &object, std::string const &key) noexcept(false);
std::optional<bool> getOptionalBool(lottiejson11::Json::object const &object, std::string const &key) noexcept(false);

}

#endif /* JsonParsing_hpp */
