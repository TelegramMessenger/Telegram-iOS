/*
 * Copyright (c) 2018 Samsung Electronics Co., Ltd. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA
 */

#include "lottieloader.h"
#include "lottieparser.h"

#include <cstring>
#include <fstream>

#ifdef LOTTIE_CACHE_SUPPORT

#include <unordered_map>
#include <mutex>

class LottieModelCache {
public:
    static LottieModelCache &instance()
    {
        static LottieModelCache CACHE;
        return CACHE;
    }
    std::shared_ptr<LOTModel> find(const std::string &key)
    {
        std::lock_guard<std::mutex> guard(mMutex);

        auto search = mHash.find(key);

        return (search != mHash.end()) ? search->second : nullptr;

    }
    void add(const std::string &key, std::shared_ptr<LOTModel> value)
    {
        std::lock_guard<std::mutex> guard(mMutex);
        mHash[key] = std::move(value);
    }

private:
    LottieModelCache() = default;

    std::unordered_map<std::string, std::shared_ptr<LOTModel>>  mHash;
    std::mutex                                                  mMutex;
};

#else

class LottieModelCache {
public:
    static LottieModelCache &instance()
    {
        static LottieModelCache CACHE;
        return CACHE;
    }
    std::shared_ptr<LOTModel> find(const std::string &) { return nullptr; }
    void add(const std::string &, std::shared_ptr<LOTModel>) {}
};

#endif

static std::string dirname(const std::string &path)
{
    const char *ptr = strrchr(path.c_str(), '/');
#ifdef _WIN32
    if (ptr) ptr = strrchr(ptr + 1, '\\');
#endif
    int         len = int(ptr + 1 - path.c_str());  // +1 to include '/'
    return std::string(path, 0, len);
}

bool LottieLoader::load(const std::string &path)
{
    mModel = LottieModelCache::instance().find(path);
    if (mModel) return true;

    std::ifstream f;
    f.open(path);

    if (!f.is_open()) {
        vCritical << "failed to open file = " << path.c_str();
        return false;
    } else {
        std::stringstream buf;
        buf << f.rdbuf();

        LottieParser parser(const_cast<char *>(buf.str().data()),
                            dirname(path).c_str());
        mModel = parser.model();

        if (!mModel) return false;

        LottieModelCache::instance().add(path, mModel);

        f.close();
    }

    return true;
}

bool LottieLoader::loadFromData(std::string &&jsonData, const std::string &key,
                                const std::string &resourcePath)
{
    mModel = LottieModelCache::instance().find(key);
    if (mModel) return true;

    LottieParser parser(const_cast<char *>(jsonData.c_str()),
                        resourcePath.c_str());
    mModel = parser.model();

    if (!mModel) return false;

    LottieModelCache::instance().add(key, mModel);

    return true;
}

std::shared_ptr<LOTModel> LottieLoader::model()
{
    return mModel;
}
