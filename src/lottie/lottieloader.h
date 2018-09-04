#ifndef LOTTIELOADER_H
#define LOTTIELOADER_H

#include<sstream>
#include<memory>

class LOTModel;
class LottieLoader
{
public:
   bool load(std::string &filePath);
   bool loadFromData(const char *jsonData, const char *key);
   std::shared_ptr<LOTModel> model();
private:
   std::shared_ptr<LOTModel>    mModel;
};

#endif // LOTTIELOADER_H


