/*
 * Copyright (c) 2018 Samsung Electronics Co., Ltd. All rights reserved.
 *
 * Licensed under the LGPL License, Version 2.1 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.gnu.org/licenses/
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

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
    std::shared_ptr<LOTModel> find(const std::string &key);
    void add(const std::string &key, std::shared_ptr<LOTModel> value);

private:
    LottieFileCache() = default;

    std::unordered_map<std::string, std::shared_ptr<LOTModel>> mHash;
};

std::shared_ptr<LOTModel> LottieFileCache::find(const std::string &key)
{
    auto search = mHash.find(key);
    if (search != mHash.end()) {
        return search->second;
    } else {
        return nullptr;
    }
}

void LottieFileCache::add(const std::string &key, std::shared_ptr<LOTModel> value)
{
    mHash[key] = std::move(value);
}

bool LottieLoader::load(const std::string &path)
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

bool LottieLoader::loadFromData(std::string &&jsonData, const std::string &key)
{
    LottieFileCache &fileCache = LottieFileCache::get();

    mModel = fileCache.find(key);
    if (mModel) return true;

    LottieParser parser(const_cast<char *>(jsonData.c_str()));
    mModel = parser.model();
    fileCache.add(key, mModel);

    return true;
}

std::shared_ptr<LOTModel> LottieLoader::model()
{
    return mModel;
}
