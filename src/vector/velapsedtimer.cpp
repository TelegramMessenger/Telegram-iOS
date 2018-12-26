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

#include "velapsedtimer.h"

void VElapsedTimer::start()
{
    clock = std::chrono::high_resolution_clock::now();
    m_valid = true;
}

double VElapsedTimer::restart()
{
    double elapsedTime = elapsed();
    start();
    return elapsedTime;
}

double VElapsedTimer::elapsed() const
{
    if (!isValid()) return 0;
    return std::chrono::duration<double, std::milli>(
               std::chrono::high_resolution_clock::now() - clock)
        .count();
}

bool VElapsedTimer::hasExpired(double time)
{
    double elapsedTime = elapsed();
    if (elapsedTime > time) return true;
    return false;
}
