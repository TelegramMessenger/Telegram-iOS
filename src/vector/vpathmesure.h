/*
 * Copyright (c) 2018 Samsung Electronics Co., Ltd. All rights reserved.
 *
 * Licensed under the Flora License, Version 1.1 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://floralicense.org/license/
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef VPATHMESURE_H
#define VPATHMESURE_H

#include "vpath.h"

V_BEGIN_NAMESPACE

class VPathMesure {
public:
    void  setStart(float start){mStart = start;}
    void  setEnd(float end){mEnd = end;}
    VPath trim(const VPath &path);
private:
    float mStart{0.0f};
    float mEnd{1.0f};
};

V_END_NAMESPACE

#endif  // VPATHMESURE_H
