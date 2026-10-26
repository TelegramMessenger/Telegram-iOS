// bind roughness   {label:"Roughness", default:0.25, min:0.001, max:1, step:0.001}
// bind dcolor      {label:"Diffuse Color",  r:1.0, g:1.0, b:1.0}
// bind scolor      {label:"Specular Color", r:0.23, g:0.23, b:0.23}
// bind intensity   {label:"Light Intensity", default:4, min:0, max:10}
// bind width       {label:"Width",  default: 8, min:0.1, max:15, step:0.1}
// bind height      {label:"Height", default: 8, min:0.1, max:15, step:0.1}
// bind roty        {label:"Rotation Y", default: 0, min:0, max:1, step:0.001}
// bind rotz        {label:"Rotation Z", default: 0, min:0, max:1, step:0.001}
// bind twoSided    {label:"Two-sided", default:false}
// bind groundTruth {label:"Ground Truth", default:false}

uniform float roughness;
uniform vec3  dcolor;
uniform vec3  scolor;

uniform float intensity;
uniform float width;
uniform float height;
uniform float roty;
uniform float rotz;

uniform bool groundTruth;

uniform bool twoSided;

uniform sampler2D ltc_1;
uniform sampler2D ltc_2;

uniform mat4  view;
uniform vec2  resolution;
uniform int   sampleCount;

const float LUT_SIZE  = 64.0;
const float LUT_SCALE = (LUT_SIZE - 1.0)/LUT_SIZE;
const float LUT_BIAS  = 0.5/LUT_SIZE;

const int   NUM_SAMPLES = 1;
const float pi = 3.14159265;
const float NO_HIT = 1e9;

// Tracing and intersection
///////////////////////////

struct Ray
{
    vec3 origin;
    vec3 dir;
};

struct Disk
{
    vec3  center;
    vec3  dirx;
    vec3  diry;
    float halfx;
    float halfy;

    vec4  plane;
};

float RayPlaneIntersect(Ray ray, vec4 plane)
{
    float t = -dot(plane, vec4(ray.origin, 1.0))/dot(plane.xyz, ray.dir);
    return (t > 0.0) ? t : NO_HIT;
}

float sqr(float x) { return x*x; }

float RayDiskIntersect(Ray ray, Disk disk)
{
    float t = RayPlaneIntersect(ray, disk.plane);
    if (t != NO_HIT)
    {
        vec3 pos  = ray.origin + ray.dir*t;
        vec3 lpos = pos - disk.center;

        float x = dot(lpos, disk.dirx);
        float y = dot(lpos, disk.diry);

        if (sqr(x/disk.halfx) + sqr(y/disk.halfy) > 1.0)
            t = NO_HIT;
    }

    return t;
}

// Camera functions
///////////////////

Ray GenerateCameraRay()
{
    Ray ray;

    vec2 xy = 2.0*gl_FragCoord.xy/resolution - vec2(1.0);

    ray.dir = normalize(vec3(xy, 2.0));

    float focalDistance = 2.0;
    float ft = focalDistance/ray.dir.z;
    vec3 pFocus = ray.dir*ft;

    ray.origin = vec3(0);
    ray.dir    = normalize(pFocus - ray.origin);

    // Apply camera transform
    ray.origin = (view*vec4(ray.origin, 1)).xyz;
    ray.dir    = (view*vec4(ray.dir,    0)).xyz;

    return ray;
}

// Matrix functions
///////////////////

vec3 mul(mat3 m, vec3 v)
{
    return m * v;
}

mat3 mul(mat3 m1, mat3 m2)
{
    return m1 * m2;
}

vec3 rotation_y(vec3 v, float a)
{
    vec3 r;
    r.x =  v.x*cos(a) + v.z*sin(a);
    r.y =  v.y;
    r.z = -v.x*sin(a) + v.z*cos(a);
    return r;
}

vec3 rotation_z(vec3 v, float a)
{
    vec3 r;
    r.x =  v.x*cos(a) - v.y*sin(a);
    r.y =  v.x*sin(a) + v.y*cos(a);
    r.z =  v.z;
    return r;
}

vec3 rotation_yz(vec3 v, float ay, float az)
{
    return rotation_z(rotation_y(v, ay), az);
}

mat3 mat3_from_columns(vec3 c0, vec3 c1, vec3 c2)
{
    mat3 m = mat3(c0, c1, c2);
    return m;
}

// Sample generation
////////////////////

float Halton(int index, float base)
{
    float result = 0.0;
    float f = 1.0/base;
    float i = float(index);
    for (int x = 0; x < 8; x++)
    {
        if (i <= 0.0) break;

        result += f*mod(i, base);
        i = floor(i/base);
        f = f/base;
    }

    return result;
}

void Halton2D(out vec2 s[NUM_SAMPLES], int offset)
{
    for (int i = 0; i < NUM_SAMPLES; i++)
    {
        s[i].x = Halton(i + offset, 2.0);
        s[i].y = Halton(i + offset, 3.0);
    }
}

// TODO: replace this
float rand(vec2 co)
{
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

// Scene helpers
////////////////

Disk InitDisk(vec3 center, vec3 dirx, vec3 diry, float halfx, float halfy)
{
    Disk disk;

    disk.center = center;
    disk.dirx   = dirx;
    disk.diry   = diry;
    disk.halfx  = halfx;
    disk.halfy  = halfy;

    vec3 diskNormal = cross(disk.dirx, disk.diry);
    disk.plane = vec4(diskNormal, -dot(diskNormal, disk.center));

    return disk;
}

void InitDiskPoints(Disk disk, out vec3 points[4])
{
    vec3 ex = disk.halfx*disk.dirx;
    vec3 ey = disk.halfy*disk.diry;

    points[0] = disk.center - ex - ey;
    points[1] = disk.center + ex - ey;
    points[2] = disk.center + ex + ey;
    points[3] = disk.center - ex + ey;
}

// Misc.
////////

// An extended version of the implementation from
// "How to solve a cubic equation, revisited"
// http://momentsingraphics.de/?p=105
vec3 SolveCubic(vec4 Coefficient)
{
    // Normalize the polynomial
    Coefficient.xyz /= Coefficient.w;
    // Divide middle coefficients by three
    Coefficient.yz /= 3.0;

    float A = Coefficient.w;
    float B = Coefficient.z;
    float C = Coefficient.y;
    float D = Coefficient.x;

    // Compute the Hessian and the discriminant
    vec3 Delta = vec3(
        -Coefficient.z*Coefficient.z + Coefficient.y,
        -Coefficient.y*Coefficient.z + Coefficient.x,
        dot(vec2(Coefficient.z, -Coefficient.y), Coefficient.xy)
    );

    float Discriminant = dot(vec2(4.0*Delta.x, -Delta.y), Delta.zy);

    vec3 RootsA, RootsD;

    vec2 xlc, xsc;

    // Algorithm A
    {
        float A_a = 1.0;
        float C_a = Delta.x;
        float D_a = -2.0*B*Delta.x + Delta.y;

        // Take the cubic root of a normalized complex number
        float Theta = atan(sqrt(Discriminant), -D_a)/3.0;

        float x_1a = 2.0*sqrt(-C_a)*cos(Theta);
        float x_3a = 2.0*sqrt(-C_a)*cos(Theta + (2.0/3.0)*pi);

        float xl;
        if ((x_1a + x_3a) > 2.0*B)
            xl = x_1a;
        else
            xl = x_3a;

        xlc = vec2(xl - B, A);
    }

    // Algorithm D
    {
        float A_d = D;
        float C_d = Delta.z;
        float D_d = -D*Delta.y + 2.0*C*Delta.z;

        // Take the cubic root of a normalized complex number
        float Theta = atan(D*sqrt(Discriminant), -D_d)/3.0;

        float x_1d = 2.0*sqrt(-C_d)*cos(Theta);
        float x_3d = 2.0*sqrt(-C_d)*cos(Theta + (2.0/3.0)*pi);

        float xs;
        if (x_1d + x_3d < 2.0*C)
            xs = x_1d;
        else
            xs = x_3d;

        xsc = vec2(-D, xs + C);
    }

    float E =  xlc.y*xsc.y;
    float F = -xlc.x*xsc.y - xlc.y*xsc.x;
    float G =  xlc.x*xsc.x;

    vec2 xmc = vec2(C*F - B*G, -B*F + C*E);

    vec3 Root = vec3(xsc.x/xsc.y, xmc.x/xmc.y, xlc.x/xlc.y);

    if (Root.x < Root.y && Root.x < Root.z)
        Root.xyz = Root.yxz;
    else if (Root.z < Root.x && Root.z < Root.y)
        Root.xyz = Root.xzy;

    return Root;
}

// Linearly Transformed Cosines
///////////////////////////////

vec3 LTC_Evaluate(
    vec3 N, vec3 V, vec3 P, mat3 Minv, vec3 points[4], bool twoSided, float u1, float u2)
{
    // construct orthonormal basis around N
    vec3 T1, T2;
    T1 = normalize(V - N*dot(V, N));
    T2 = cross(N, T1);

    // rotate area light in (T1, T2, N) basis
    mat3 R = transpose(mat3(T1, T2, N));

    // polygon (allocate 5 vertices for clipping)
    vec3 L_[3];
    L_[0] = mul(R, points[0] - P);
    L_[1] = mul(R, points[1] - P);
    L_[2] = mul(R, points[2] - P);

    vec3 Lo_i = vec3(0);

    // init ellipse
    vec3 C  = 0.5 * (L_[0] + L_[2]);
    vec3 V1 = 0.5 * (L_[1] - L_[2]);
    vec3 V2 = 0.5 * (L_[1] - L_[0]);

    C  = Minv * C;
    V1 = Minv * V1;
    V2 = Minv * V2;

    if(!twoSided && dot(cross(V1, V2), C) < 0.0)
        return vec3(0.0);

    // compute eigenvectors of ellipse
    float a, b;
    float d11 = dot(V1, V1);
    float d22 = dot(V2, V2);
    float d12 = dot(V1, V2);
    if (abs(d12)/sqrt(d11*d22) > 0.0001)
    {
        float tr = d11 + d22;
        float det = -d12*d12 + d11*d22;

        // use sqrt matrix to solve for eigenvalues
        det = sqrt(det);
        float u = 0.5*sqrt(tr - 2.0*det);
        float v = 0.5*sqrt(tr + 2.0*det);
        float e_max = sqr(u + v);
        float e_min = sqr(u - v);

        vec3 V1_, V2_;

        if (d11 > d22)
        {
            V1_ = d12*V1 + (e_max - d11)*V2;
            V2_ = d12*V1 + (e_min - d11)*V2;
        }
        else
        {
            V1_ = d12*V2 + (e_max - d22)*V1;
            V2_ = d12*V2 + (e_min - d22)*V1;
        }

        a = 1.0 / e_max;
        b = 1.0 / e_min;
        V1 = normalize(V1_);
        V2 = normalize(V2_);
    }
    else
    {
        a = 1.0 / dot(V1, V1);
        b = 1.0 / dot(V2, V2);
        V1 *= sqrt(a);
        V2 *= sqrt(b);
    }

    vec3 V3 = cross(V1, V2);
    if (dot(C, V3) < 0.0)
        V3 *= -1.0;

    float L  = dot(V3, C);
    float x0 = dot(V1, C) / L;
    float y0 = dot(V2, C) / L;

    float E1 = inversesqrt(a);
    float E2 = inversesqrt(b);

    a *= L*L;
    b *= L*L;

    float c0 = a*b;
    float c1 = a*b*(1.0 + x0*x0 + y0*y0) - a - b;
    float c2 = 1.0 - a*(1.0 + x0*x0) - b*(1.0 + y0*y0);
    float c3 = 1.0;

    vec3 roots = SolveCubic(vec4(c0, c1, c2, c3));
    float e1 = roots.x;
    float e2 = roots.y;
    float e3 = roots.z;

    vec3 avgDir = vec3(a*x0/(a - e2), b*y0/(b - e2), 1.0);

    mat3 rotate = mat3_from_columns(V1, V2, V3);

    avgDir = rotate*avgDir;
    avgDir = normalize(avgDir);

    float L1 = sqrt(-e2/e3);
    float L2 = sqrt(-e2/e1);

    float formFactor = L1*L2*inversesqrt((1.0 + L1*L1)*(1.0 + L2*L2));

    // use tabulated horizon-clipped sphere
    vec2 uv = vec2(avgDir.z*0.5 + 0.5, formFactor);
    uv = uv*LUT_SCALE + LUT_BIAS;
    float scale = texture(ltc_2, uv).w;

    float spec = formFactor*scale;

    if (groundTruth)
    {
        spec = 0.0;

        float diskArea = pi*E1*E2;

        // light sample
        {
            // random point on ellipse
            float rad = sqrt(u1);
            float phi = 2.0*pi*u2;
            float x = E1*rad*cos(phi);
            float y = E2*rad*sin(phi);

            vec3 p = x*V1 + y*V2 + C;
            vec3 v = normalize(p);

            float c2 = max(dot(V3, v), 0.0);
            float solidAngle = max(c2/dot(p, p), 1e-7);
            float pdfLight = 1.0/solidAngle/diskArea;

            float cosTheta = max(v.z, 0.0);
            float brdf = 1.0/pi;
            float pdfBRDF = cosTheta/pi;

            if (cosTheta > 0.0)
                spec += brdf*cosTheta/(pdfBRDF + pdfLight);
        }

        // BRDF sample
        {
            // generate a cosine-distributed direction
            float rad = sqrt(u1);
            float phi = 2.0*pi*u2;
            float x = rad*cos(phi);
            float y = rad*sin(phi);
            vec3 dir = vec3(x, y, sqrt(1.0 - u1));

            Ray ray;
            ray.origin = vec3(0, 0, 0);
            ray.dir = dir;

            Disk disk = InitDisk(C, V1, V2, E1, E2);

            vec3 diskNormal = V3;
            disk.plane = vec4(diskNormal, -dot(diskNormal, disk.center));

            float distToDisk = RayDiskIntersect(ray, disk);
            bool  intersect  = distToDisk != NO_HIT;

            float cosTheta = max(dir.z, 0.0);
            float brdf = 1.0/pi;
            float pdfBRDF = cosTheta/pi;

            float pdfLight = 0.0;
            if (intersect)
            {
                vec3 p = distToDisk*ray.dir;
                vec3 v = normalize(p);
                float c2 = max(dot(V3, v), 0.0);
                float solidAngle = max(c2/dot(p, p), 1e-7);
                pdfLight = 1.0/solidAngle/diskArea;
            }

            if (intersect)
                spec += brdf*cosTheta/(pdfBRDF + pdfLight);
        }
    }

    Lo_i = vec3(spec, spec, spec);

    return vec3(Lo_i);
}

// Misc. helpers
////////////////

float saturate(float v)
{
    return clamp(v, 0.0, 1.0);
}

vec3 PowVec3(vec3 v, float p)
{
    return vec3(pow(v.x, p), pow(v.y, p), pow(v.z, p));
}

const float gamma = 2.2;
vec3 ToLinear(vec3 v) { return PowVec3(v, gamma); }

out vec4 FragColor;

void main()
{
    float ay = 2.0*pi*roty;
    float az = 2.0*pi*rotz;

    Disk disk = InitDisk(
        vec3(0, 6, 32),
        rotation_yz(vec3(1, 0, 0), ay, az),
        rotation_yz(vec3(0, 1, 0), ay, az),
        0.5*width,
        0.5*height
    );

    vec3 points[4];
    InitDiskPoints(disk, points);

    vec4 floorPlane = vec4(0, 1, 0, 0);

    vec3 lcol = vec3(intensity);
    vec3 dcol = ToLinear(dcolor);
    vec3 scol = ToLinear(scolor);

    vec3 col = vec3(0);

    Ray ray = GenerateCameraRay();

    float dist = RayPlaneIntersect(ray, floorPlane);

    vec2 seq[NUM_SAMPLES];
    Halton2D(seq, sampleCount);

    float u1 = rand(gl_FragCoord.xy*0.01);
    float u2 = rand(gl_FragCoord.yx*0.01);

    u1 = fract(u1 + seq[0].x);
    u2 = fract(u2 + seq[0].y);

    if (dist != NO_HIT)
    {
        // Clamp distance to some sane maximum to prevent instability
        dist = min(dist, 10000.0);

        vec3 pos = ray.origin + dist*ray.dir;

        vec3 N = floorPlane.xyz;
        vec3 V = -ray.dir;

        float ndotv = saturate(dot(N, V));
        vec2 uv = vec2(roughness, sqrt(1.0 - ndotv));
        uv = uv*LUT_SCALE + LUT_BIAS;

        vec4 t1 = texture(ltc_1, uv);
        vec4 t2 = texture(ltc_2, uv);

        mat3 Minv = mat3(
            vec3(t1.x, 0, t1.y),
            vec3(  0,  1,    0),
            vec3(t1.z, 0, t1.w)
        );

        vec3 spec = LTC_Evaluate(N, V, pos, Minv, points, twoSided, u1, u2);
        // BRDF shadowing and Fresnel
        spec *= scol*t2.x + (1.0 - scol)*t2.y;

        vec3 diff = LTC_Evaluate(N, V, pos, mat3(1), points, twoSided, u1, u2);

        col = lcol*(spec + dcol*diff);
    }

    float distToDisk = RayDiskIntersect(ray, disk);
    if (distToDisk < dist)
        col = lcol;

    FragColor = vec4(col, 1.0);
}
