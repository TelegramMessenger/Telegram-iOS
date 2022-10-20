#include <math.h>

static inline float deg_to_radf(float deg) {
	return deg * (float)M_PI / 180.0f;
}

static inline double MAXf(float a, float b) {
	return a > b ? a : b;
}

static inline double MINf(float a, float b) {
	return a < b ? a : b;
}