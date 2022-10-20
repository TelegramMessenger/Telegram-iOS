#include "timing.h"

static inline float evaluateAtParameterWithCoefficients(float t, float coefficients[])
{
    return coefficients[0] + t*coefficients[1] + t*t*coefficients[2] + t*t*t*coefficients[3];
}

static inline float evaluateDerivationAtParameterWithCoefficients(float t, float coefficients[])
{
    return coefficients[1] + 2*t*coefficients[2] + 3*t*t*coefficients[3];
}

static inline float calcParameterViaNewtonRaphsonUsingXAndCoefficientsForX(float x, float coefficientsX[])
{
    // see http://en.wikipedia.org/wiki/Newton's_method
    
    // start with X being the correct value
    float t = x;
    
    // iterate several times
    //const float epsilon = 0.00001;
    int i;
    for(i = 0; i < 10; i++)
    {
        float x2 = evaluateAtParameterWithCoefficients(t, coefficientsX) - x;
        float d = evaluateDerivationAtParameterWithCoefficients(t, coefficientsX);
        
        float dt = x2/d;
        
        t = t - dt;
    }
    
    return t;
}

static inline float calcParameterUsingXAndCoefficientsForX (float x, float coefficientsX[])
{
    // for the time being, we'll guess Newton-Raphson always
    // returns the correct value.
    
    // if we find it doesn't find the solution often enough,
    // we can add additional calculation methods.
    
    float t = calcParameterViaNewtonRaphsonUsingXAndCoefficientsForX(x, coefficientsX);
    
    return t;
}

static int is_initialized=0;

static float _coefficientsX[TIMING_NUM][4], _coefficientsY[TIMING_NUM][4];

static const float _c0x = 0.0;
static const float _c0y = 0.0;
static const float _c3x = 1.0;
static const float _c3y = 1.0;

float timing(float x, timing_type type)
{

    if (is_initialized==0) {
        is_initialized=1;
        
        float c[TIMING_NUM][4];
        
        c[Default][0]=0.25f;
        c[Default][1]=0.1f;
        c[Default][2]=0.25f;
        c[Default][3]=1.0f;
        
        c[EaseInEaseOut][0]=0.42f;
        c[EaseInEaseOut][1]=0.0f;
        c[EaseInEaseOut][2]=0.58f;
        c[EaseInEaseOut][3]=1.0f;
        
        c[EaseIn][0]=0.42f;
        c[EaseIn][1]=0.0f;
        c[EaseIn][2]=1.0f;
        c[EaseIn][3]=1.0f;
        
        c[EaseOut][0]=0.0f;
        c[EaseOut][1]=0.0f;
        c[EaseOut][2]=0.58f;
        c[EaseOut][3]=1.0f;


        c[EaseOutBounce][0]=0.0;
        c[EaseOutBounce][1]=0.0;
        c[EaseOutBounce][2]=0.;
        c[EaseOutBounce][3]=1.25;

        
        c[Linear][0]=0.0;
        c[Linear][1]=0.0;
        c[Linear][2]=1.0;
        c[Linear][3]=1.0;
        
        

        
        int i;
        for (i=0; i<TIMING_NUM; i++) {
            float _c1x = c[i][0];
            float _c1y = c[i][1];
            float _c2x = c[i][2];
            float _c2y = c[i][3];
            
            _coefficientsX[i][0] = _c0x; // t^0
            _coefficientsX[i][1] = -3.0f*_c0x + 3.0f*_c1x; // t^1
            _coefficientsX[i][2] = 3.0f*_c0x - 6.0f*_c1x + 3.0f*_c2x;  // t^2
            _coefficientsX[i][3] = -_c0x + 3.0f*_c1x - 3.0f*_c2x + _c3x; // t^3
            
            _coefficientsY[i][0] = _c0y; // t^0
            _coefficientsY[i][1] = -3.0f*_c0y + 3.0f*_c1y; // t^1
            _coefficientsY[i][2] = 3.0f*_c0y - 6.0f*_c1y + 3.0f*_c2y;  // t^2
            _coefficientsY[i][3] = -_c0y + 3.0f*_c1y - 3.0f*_c2y + _c3y; // t^3
        }

    }
    
    if (x==0.0 || x==1.0) {
        return x;
    }

    float t = calcParameterUsingXAndCoefficientsForX(x, _coefficientsX[type]);
    float y = evaluateAtParameterWithCoefficients(t, _coefficientsY[type]);
 
    return y;
    
}
