#pragma once
#include <algorithm>
#include <cmath>

namespace gift {
struct Vec2 { float x=0, y=0; };
struct Vec3 { float x=0, y=0, z=0; };
struct Vec4 { float x=0, y=0, z=0, w=0; };
inline Vec3 operator+(Vec3 a, Vec3 b) { return {a.x+b.x,a.y+b.y,a.z+b.z}; }
inline Vec3 operator-(Vec3 a, Vec3 b) { return {a.x-b.x,a.y-b.y,a.z-b.z}; }
inline Vec3 operator*(Vec3 a, float s) { return {a.x*s,a.y*s,a.z*s}; }
inline float dot(Vec3 a,Vec3 b) { return a.x*b.x+a.y*b.y+a.z*b.z; }
inline Vec3 cross(Vec3 a,Vec3 b) { return {a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x}; }
inline float length(Vec3 v) { return std::sqrt(dot(v,v)); }
inline Vec3 normalize(Vec3 v) { return v*(1/std::max(length(v),1e-12f)); }
inline Vec4 normalize(Vec4 q) { float n=std::sqrt(q.x*q.x+q.y*q.y+q.z*q.z+q.w*q.w); return n>1e-12f?Vec4{q.x/n,q.y/n,q.z/n,q.w/n}:Vec4{0,0,0,1}; }
inline Vec4 slerp(Vec4 a,Vec4 b,float t) {
    a=normalize(a); b=normalize(b);
    float d=a.x*b.x+a.y*b.y+a.z*b.z+a.w*b.w;
    if(d<0) { b={-b.x,-b.y,-b.z,-b.w}; d=-d; }
    float x=1-t,y=t;
    if(d<0.9995f) { float angle=std::acos(std::clamp(d,-1.f,1.f)); x=std::sin((1-t)*angle)/std::sin(angle); y=std::sin(t*angle)/std::sin(angle); }
    return normalize(Vec4{a.x*x+b.x*y,a.y*x+b.y*y,a.z*x+b.z*y,a.w*x+b.w*y});
}
struct Mat4 {
    float m[16] = {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1};
    float& at(int r,int c) { return m[c*4+r]; }
    float at(int r,int c) const { return m[c*4+r]; }
};
inline Mat4 operator*(const Mat4& a,const Mat4& b) {
    Mat4 r; for(int c=0;c<4;c++) for(int i=0;i<4;i++) { r.at(i,c)=0; for(int k=0;k<4;k++) r.at(i,c)+=a.at(i,k)*b.at(k,c); } return r;
}
inline Vec3 point(const Mat4& a,Vec3 v) {
    return {a.m[0]*v.x+a.m[4]*v.y+a.m[8]*v.z+a.m[12],a.m[1]*v.x+a.m[5]*v.y+a.m[9]*v.z+a.m[13],a.m[2]*v.x+a.m[6]*v.y+a.m[10]*v.z+a.m[14]};
}
inline Vec3 direction(const Mat4& a,Vec3 v) {
    return {a.m[0]*v.x+a.m[4]*v.y+a.m[8]*v.z,a.m[1]*v.x+a.m[5]*v.y+a.m[9]*v.z,a.m[2]*v.x+a.m[6]*v.y+a.m[10]*v.z};
}
inline Mat4 normalMatrix(const Mat4& a) {
    Vec3 x{a.m[0],a.m[1],a.m[2]}, y{a.m[4],a.m[5],a.m[6]}, z{a.m[8],a.m[9],a.m[10]};
    float det=dot(x,cross(y,z)); if(std::abs(det)<1e-12f) return {};
    Vec3 u=cross(y,z)*(1/det),v=cross(z,x)*(1/det),w=cross(x,y)*(1/det);
    Mat4 r; r.m[0]=u.x;r.m[1]=u.y;r.m[2]=u.z;r.m[4]=v.x;r.m[5]=v.y;r.m[6]=v.z;r.m[8]=w.x;r.m[9]=w.y;r.m[10]=w.z;return r;
}
inline Mat4 trs(Vec3 t,Vec4 q,Vec3 s) {
    q=normalize(q);float x=q.x,y=q.y,z=q.z,w=q.w;Mat4 r;
    r.m[0]=(1-2*(y*y+z*z))*s.x;r.m[1]=2*(x*y+z*w)*s.x;r.m[2]=2*(x*z-y*w)*s.x;
    r.m[4]=2*(x*y-z*w)*s.y;r.m[5]=(1-2*(x*x+z*z))*s.y;r.m[6]=2*(y*z+x*w)*s.y;
    r.m[8]=2*(x*z+y*w)*s.z;r.m[9]=2*(y*z-x*w)*s.z;r.m[10]=(1-2*(x*x+y*y))*s.z;
    r.m[12]=t.x;r.m[13]=t.y;r.m[14]=t.z;return r;
}
inline Mat4 lookAt(Vec3 eye,Vec3 target) {
    Vec3 z=normalize(eye-target),x=normalize(cross({0,1,0},z)),y=cross(z,x);Mat4 r;
    r.m[0]=x.x;r.m[4]=x.y;r.m[8]=x.z;r.m[12]=-dot(x,eye);
    r.m[1]=y.x;r.m[5]=y.y;r.m[9]=y.z;r.m[13]=-dot(y,eye);
    r.m[2]=z.x;r.m[6]=z.y;r.m[10]=z.z;r.m[14]=-dot(z,eye);return r;
}
inline Mat4 perspective(float fov,float aspect,float nearZ,float farZ) {
    Mat4 r;std::fill(r.m,r.m+16,0.f);float f=1/std::tan(fov/2);
    r.m[0]=f/aspect;r.m[5]=f;r.m[10]=farZ/(nearZ-farZ);r.m[11]=-1;r.m[14]=farZ*nearZ/(nearZ-farZ);return r;
}
inline Mat4 orthographic(float halfWidth,float halfHeight,float nearZ,float farZ) {
    Mat4 r;r.m[0]=1/halfWidth;r.m[5]=1/halfHeight;r.m[10]=1/(nearZ-farZ);
    r.m[14]=nearZ/(nearZ-farZ);return r;
}
struct Bounds {
    Vec3 min{1e30f,1e30f,1e30f},max{-1e30f,-1e30f,-1e30f};
    void add(Vec3 p) { min={std::min(min.x,p.x),std::min(min.y,p.y),std::min(min.z,p.z)};max={std::max(max.x,p.x),std::max(max.y,p.y),std::max(max.z,p.z)}; }
    Vec3 center() const { return (min+max)*.5f; }
    float radius() const { return std::max(length(max-min)*.5f,.001f); }
};
}
