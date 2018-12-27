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
