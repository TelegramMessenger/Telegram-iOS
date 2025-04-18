#include <metal_stdlib>

#pragma once

typedef struct {
    float4 pos [[position]];
    float2 texCoord;
    float2 localPos;
} RasterizerData;
