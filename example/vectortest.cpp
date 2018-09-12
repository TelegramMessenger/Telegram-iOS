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
