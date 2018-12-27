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

#ifndef VELAPSEDTIMER_H
#define VELAPSEDTIMER_H

#include <chrono>
#include "vglobal.h"

class VElapsedTimer {
public:
    double      elapsed() const;
    bool        hasExpired(double millsec);
    void        start();
    double      restart();
    inline bool isValid() const { return m_valid; }

private:
    std::chrono::high_resolution_clock::time_point clock;
    bool                                           m_valid{false};
};
#endif  // VELAPSEDTIMER_H
