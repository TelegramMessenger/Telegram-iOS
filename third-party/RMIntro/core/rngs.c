#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include "rngs.h"


float frand(float from, float to)
{
    // srand(time(NULL));
    return (float)(((double)random()/RAND_MAX)*(to-from)+from);
}

int irand(int from, int to)
{
    // srand(time(NULL));
    return (int)(((double)random()/RAND_MAX)*(to-from+1)+from);
}

int signrand()
{
    // srand(time(NULL));
    return irand(0, 1)*2-1;
}





