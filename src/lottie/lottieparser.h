#ifndef LOTTIEPARSER_H
#define LOTTIEPARSER_H

#include "lottiemodel.h"

class LottieParserImpl;
class LottieParser {
public:
    ~LottieParser();
    LottieParser(char* str);
    std::shared_ptr<LOTModel> model();
private:
   LottieParserImpl   *d;
};

#endif // LOTTIEPARSER_H
