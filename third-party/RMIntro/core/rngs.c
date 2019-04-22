#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include "rngs.h"

float frand(float from, float to)
{
    return (float)(((double)random()/RAND_MAX)*(to-from)+from);
}

int irand(int from, int to)
{
    return (int)(((double)random()/RAND_MAX)*(to-from+1)+from);
}

int signrand()
{
    return irand(0, 1)*2-1;
}
