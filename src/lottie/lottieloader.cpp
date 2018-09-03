#include "lottieloader.h"
#include "lottieparser.h"

#include <fstream>
#include <unordered_map>

using namespace std;

class LottieFileCache {
public:
    static LottieFileCache &get()
    {
        static LottieFileCache CACHE;

        return CACHE;
    }
    std::shared_ptr<LOTModel> find(std::string &key);
    void add(std::string &key, std::shared_ptr<LOTModel> value);

private:
    LottieFileCache() = default;

    std::unordered_map<std::string, std::shared_ptr<LOTModel>> mHash;
};

std::shared_ptr<LOTModel> LottieFileCache::find(std::string &key)
{
    auto search = mHash.find(key);
    if (search != mHash.end()) {
        return search->second;
    } else {
        return nullptr;
    }
}

void LottieFileCache::add(std::string &key, std::shared_ptr<LOTModel> value)
{
    mHash[key] = std::move(value);
}

bool LottieLoader::load(std::string &path)
{
    LottieFileCache &fileCache = LottieFileCache::get();

    mModel = fileCache.find(path);
    if (mModel) return true;

    std::ifstream f;
    f.open(path);

    if (!f.is_open()) {
        vCritical << "failed to open file = " << path.c_str();
        return false;
    } else {
        std::stringstream buf;
        buf << f.rdbuf();

        LottieParser parser(const_cast<char *>(buf.str().data()));
        mModel = parser.model();
        fileCache.add(path, mModel);

        f.close();
    }

    return true;
}

std::shared_ptr<LOTModel> LottieLoader::model()
{
    return mModel;
}
