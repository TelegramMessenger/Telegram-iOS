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

#include<iostream>

#include "vinterpolator.h"

int main()
{
    VInterpolator ip({0.667, 1}, {0.333 , 0});
    for (float i = 0.0 ; i < 1.0 ; i+=0.05) {
        std::cout<<ip.value(i)<<"\t";
    }
    std::cout<<std::endl;
    return 0;
}
