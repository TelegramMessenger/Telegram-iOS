#include <metal_stdlib>

using namespace metal;

half4 yuva(half4 rgba) {
    half y = (0.257f * rgba.r) + (0.504 * rgba.g) + (0.098 * rgba.b) + (16.0f / 256.0f);
    half v = (0.439 * rgba.r) - (0.368 * rgba.g) - (0.071 * rgba.b) + (128.0f / 256.0f);
    half u = -(0.148 * rgba.r) - (0.291 * rgba.g) + (0.439 * rgba.b) + (128.0f / 256.0f);
    
    return half4(y, u, v, rgba.a);
}

half4 rgb(half4 yuva) {
    half y = yuva.r - 16.0f / 256.0f;
    half u = yuva.g - 128.0f / 256.0f;
    half v = yuva.b - 128.0f / 256.0f;
    
    half b = 1.164 * y + 2.018 * u;
    half g = 1.164 * y - 0.813 * v - 0.391 * u;
    half r = 1.164 * y + 1.596 * v;
    
    return half4(r, g, b, yuva.a);
}

typedef struct {
    vector_float2 position;
    vector_float2 textureCoordinate;
} Vertex;

constant Vertex quadVertices[6] = {
    {{ 2.0, 0.0 }, { 1.0, 1.0 }},
    {{ 0.0, 0.0 }, { 0.0, 1.0 }},
    {{ 0.0, 2.0 }, { 0.0, 0.0 }},
    {{ 2.0, 0.0 }, { 1.0, 1.0 }},
    {{ 0.0, 2.0 }, { 0.0, 0.0 }},
    {{ 2.0, 2.0 }, { 1.0, 0.0 }}
};

struct RasterizerData {
    float4 clipSpacePosition [[position]];
    float2 textureCoordinate;
};

vertex RasterizerData vertexShader(
    uint vid [[vertex_id]]
) {
    RasterizerData out;

    float2 pixelSpacePosition = quadVertices[vid].position.xy;
    pixelSpacePosition.x -= 1.0f;
    pixelSpacePosition.y -= 1.0f;

    out.clipSpacePosition.xy = pixelSpacePosition;
    out.clipSpacePosition.z = 0.0f;
    out.clipSpacePosition.w = 1.0f;

    out.textureCoordinate = quadVertices[vid].textureCoordinate;

    return out;
}

fragment float4 samplingIdctShader(
    RasterizerData in [[stage_in]],
    texture2d<half, access::sample> colorTexture0 [[texture(0)]],
    texture2d<half, access::sample> colorTexture1 [[texture(1)]],
    texture2d<half, access::sample> colorTexture2 [[texture(2)]],
    texture2d<half, access::sample> colorTexture3 [[texture(3)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    const half color0 = colorTexture0.sample(textureSampler, in.textureCoordinate).r;
    const half color1 = colorTexture1.sample(textureSampler, in.textureCoordinate).r;
    const half color2 = colorTexture2.sample(textureSampler, in.textureCoordinate).r;
    const half color3 = colorTexture3.sample(textureSampler, in.textureCoordinate).r;
    
    const half4 yuva = half4(color0, color1, color2, color3);
    
    const half4 color = rgb(yuva);
    
    return float4(color.r * color.a, color.g * color.a, color.b * color.a, color.a);
}

fragment float4 samplingRgbShader(
    RasterizerData in [[stage_in]],
    texture2d<half, access::sample> colorTexture [[texture(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    half4 color = colorTexture.sample(textureSampler, in.textureCoordinate);
    
    color.r *= color.a;
    color.g *= color.a;
    color.b *= color.a;
    
    return float4(color.r, color.g, color.b, color.a);
}

half4 samplePoint(texture2d<half, access::sample> textureY, texture2d<half, access::sample> textureCbCr, sampler s, float2 texcoord) {
    half y;
    half2 uv;
    y = textureY.sample(s, texcoord).r;
    uv = textureCbCr.sample(s, texcoord).rg - half2(0.5, 0.5);

    // Conversion for YUV to rgb from http://www.fourcc.org/fccyvrgb.php
    half4 out = half4(y + 1.403 * uv.y, y - 0.344 * uv.x - 0.714 * uv.y, y + 1.770 * uv.x, 1.0);
    return out;
}

fragment float4 samplingYuvaShader(
    RasterizerData in [[stage_in]],
    texture2d<half, access::sample> yTexture [[texture(0)]],
    texture2d<half, access::sample> cbcrTexture [[texture(1)]],
    texture2d<uint, access::read> alphaTexture [[texture(2)]],
    constant uint2 &alphaSize [[buffer(3)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    half4 color = samplePoint(yTexture, cbcrTexture, textureSampler, in.textureCoordinate);
    
    int alphaX = (int)(in.textureCoordinate.x * alphaSize.x);
    int alphaY = (int)(in.textureCoordinate.y * alphaSize.y);
    
    uint32_t packedAlpha = alphaTexture.read(uint2(alphaX / 2, alphaY)).r;
    uint32_t a1 = (packedAlpha & (0xf0U));
    uint32_t a2 = (packedAlpha & (0x0fU)) << 4;
    
    uint32_t left = (a1 >> 4) | a1;
    uint32_t right = (a2 >> 4) | a2;
    
    uint32_t chooseLeft = alphaX % 2 == 0;
    uint32_t resolvedAlpha = chooseLeft * left + (1 - chooseLeft) * right;
    
    float alpha = resolvedAlpha / 255.0f;
    
    color.r *= alpha;
    color.g *= alpha;
    color.b *= alpha;
    
    color.a = alpha;
    
    return float4(color);
}

#define BLOCK_SIZE 8
#define BLOCK_SIZE2 BLOCK_SIZE * BLOCK_SIZE
#define BLOCK_SIZE_LOG2 3

#define chromaQp 60
#define lumaQp 70
#define alphaQp 60

constant float DCTv8matrix[] = {
    0.3535533905932738f,  0.4903926402016152f,  0.4619397662556434f,  0.4157348061512726f,  0.3535533905932738f,  0.2777851165098011f,  0.1913417161825449f,  0.0975451610080642f,
    0.3535533905932738f,  0.4157348061512726f,  0.1913417161825449f, -0.0975451610080641f, -0.3535533905932737f, -0.4903926402016152f, -0.4619397662556434f, -0.2777851165098011f,
    0.3535533905932738f,  0.2777851165098011f, -0.1913417161825449f, -0.4903926402016152f, -0.3535533905932738f,  0.0975451610080642f,  0.4619397662556433f,  0.4157348061512727f,
    0.3535533905932738f,  0.0975451610080642f, -0.4619397662556434f, -0.2777851165098011f,  0.3535533905932737f,  0.4157348061512727f, -0.1913417161825450f, -0.4903926402016153f,
    0.3535533905932738f, -0.0975451610080641f, -0.4619397662556434f,  0.2777851165098009f,  0.3535533905932738f, -0.4157348061512726f, -0.1913417161825453f,  0.4903926402016152f,
    0.3535533905932738f, -0.2777851165098010f, -0.1913417161825452f,  0.4903926402016153f, -0.3535533905932733f, -0.0975451610080649f,  0.4619397662556437f, -0.4157348061512720f,
    0.3535533905932738f, -0.4157348061512727f,  0.1913417161825450f,  0.0975451610080640f, -0.3535533905932736f,  0.4903926402016152f, -0.4619397662556435f,  0.2777851165098022f,
    0.3535533905932738f, -0.4903926402016152f,  0.4619397662556433f, -0.4157348061512721f,  0.3535533905932733f, -0.2777851165098008f,  0.1913417161825431f, -0.0975451610080625f
};

constant float baseQLuma[BLOCK_SIZE2] = {
    16.0f, 11.0f, 10.0f, 16.0f, 24.0f, 40.0f, 51.0f, 61.0f,
    12.0f, 12.0f, 14.0f, 19.0f, 26.0f, 58.0f, 60.0f, 55.0f,
    14.0f, 13.0f, 16.0f, 24.0f, 40.0f, 57.0f, 69.0f, 56.0f,
    14.0f, 17.0f, 22.0f, 29.0f, 51.0f, 87.0f, 80.0f, 62.0f,
    18.0f, 22.0f, 37.0f, 56.0f, 68.0f, 109.0f, 103.0f, 77.0f,
    24.0f, 35.0f, 55.0f, 64.0f, 81.0f, 104.0f, 113.0f, 92.0f,
    49.0f, 64.0f, 78.0f, 87.0f, 103.0f, 121.0f, 120.0f, 101.0f,
    72.0f, 92.0f, 95.0f, 98.0f, 112.0f, 100.0f, 103.0f, 99.0f
};

constant float baseQChroma[BLOCK_SIZE2] = {
    17, 18, 24, 47, 99, 99, 99, 99,
    18, 21, 26, 66, 99, 99, 99, 99,
    24, 26, 56, 99, 99, 99, 99, 99,
    47, 66, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99
};

float adjustQ(int qp, int index, bool isChroma) {
    float baseValue;
    if (isChroma) {
        baseValue = baseQChroma[index];
    } else {
        baseValue = baseQLuma[index];
    }
    
    float s = 0.0f;
    if (qp < 50) {
        s = 5000.0f / (float)qp;
    } else {
        s = 200.0 - (2.0 * (float)qp);
    }
    
    float r = floor(s * baseValue + 50.0f) / 100.0f;

    return r;
}

void copyTextureBlockIn(
    half4 inColorRgb,
    int colorPlane,
    uint2 blockPosition,
    threadgroup float *block
) {
    half4 inColor = yuva(inColorRgb);
    
    half color;
    if (colorPlane == 0) {
        color = inColor.r;
    } else if (colorPlane == 1) {
        color = inColor.g;
    } else if (colorPlane == 2) {
        color = inColor.b;
    } else {
        color = inColor.a;
    }
    
    block[(blockPosition.y << BLOCK_SIZE_LOG2) + blockPosition.x] = color;
}

void copyTextureBlockInDequantize(
    texture2d<half, access::read> texture,
    uint2 pixelPosition,
    uint2 blockPosition,
    threadgroup float *block,
    int qp,
    bool isChroma
) {
    half inColor = (half)texture.read(pixelPosition).r;
    
    int index = (blockPosition.y << BLOCK_SIZE_LOG2) + blockPosition.x;
    
    float q = adjustQ(qp, index, isChroma);
    float dequantized = inColor * q;
    
    block[index] = dequantized;
}

void copyTextureBlockOut(
    uint2 pixelPosition,
    uint2 blockPosition,
    threadgroup float *block,
    texture2d<half, access::write> texture
) {
    half result = block[(blockPosition.y << BLOCK_SIZE_LOG2) + blockPosition.x];
    texture.write(half4(result, result, result, 1.0), pixelPosition);
}

void copyTextureBlockOutFloat(
    uint2 pixelPosition,
    uint2 blockPosition,
    threadgroup float *block,
    texture2d<half, access::write> texture
) {
    int rawIndex = (blockPosition.y << BLOCK_SIZE_LOG2) + blockPosition.x;
    int index = rawIndex;
    
    half result = block[index];
    texture.write(half(result), pixelPosition);
}

void reorderBlockZigzag(threadgroup float *blockIn, threadgroup float *blockOut, uint2 blockPosition) {
    int rawIndex = (blockPosition.y << BLOCK_SIZE_LOG2) + blockPosition.x;
    int index = rawIndex;
    blockOut[index] = blockIn[rawIndex];
}

void DCT(
    uint2 blockPosition,
    threadgroup float *CurBlockLocal1,
    threadgroup float *CurBlockLocal2
) {
    int tx = blockPosition.x;
    int ty = blockPosition.y;
    
    float curelem = 0;
    int DCTv8matrixIndex = 0 * BLOCK_SIZE + ty;
    int CurBlockLocal1Index = 0 * BLOCK_SIZE + tx;
    
#pragma unroll
    for (int i=0; i < BLOCK_SIZE; i++)
    {
        curelem += DCTv8matrix[DCTv8matrixIndex] * (CurBlockLocal1[CurBlockLocal1Index] * 255.0f - 128.0f);
        DCTv8matrixIndex += BLOCK_SIZE;
        CurBlockLocal1Index += BLOCK_SIZE;
    }
    
    CurBlockLocal2[(ty << BLOCK_SIZE_LOG2) + tx] = curelem;
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    curelem = 0;
    int CurBlockLocal2Index = (ty << BLOCK_SIZE_LOG2) + 0;
    DCTv8matrixIndex = 0 * BLOCK_SIZE + tx;
    
#pragma unroll
    for (int i=0; i<BLOCK_SIZE; i++)
    {
        curelem += CurBlockLocal2[CurBlockLocal2Index] * DCTv8matrix[DCTv8matrixIndex];
        CurBlockLocal2Index += 1;
        DCTv8matrixIndex += BLOCK_SIZE;
    }
    
    CurBlockLocal1[(ty << BLOCK_SIZE_LOG2) + tx ] = curelem;
}

void IDCT(
    uint2 blockPosition,
    threadgroup float *CurBlockLocal1,
    threadgroup float *CurBlockLocal2
) {
    int tx = blockPosition.x;
    int ty = blockPosition.y;
    
    float curelem = 0;
    int DCTv8matrixIndex = (ty << BLOCK_SIZE_LOG2) + 0;
    int CurBlockLocal1Index = 0 * BLOCK_SIZE + tx;
    
#pragma unroll
    for (int i=0; i<BLOCK_SIZE; i++)
    {
        curelem += DCTv8matrix[DCTv8matrixIndex] * CurBlockLocal1[CurBlockLocal1Index];
        DCTv8matrixIndex += 1;
        CurBlockLocal1Index += BLOCK_SIZE;
    }
    
    CurBlockLocal2[(ty << BLOCK_SIZE_LOG2) + tx ] = curelem;
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    curelem = 0;
    int CurBlockLocal2Index = (ty << BLOCK_SIZE_LOG2) + 0;
    DCTv8matrixIndex = (tx << BLOCK_SIZE_LOG2) + 0;
    
#pragma unroll
    for (int i=0; i<BLOCK_SIZE; i++)
    {
        curelem += CurBlockLocal2[CurBlockLocal2Index] * DCTv8matrix[DCTv8matrixIndex];
        CurBlockLocal2Index += 1;
        DCTv8matrixIndex += 1;
    }
    
    CurBlockLocal1[(ty << BLOCK_SIZE_LOG2) + tx ] = (curelem + 128.0f) / 255.0f;
}

void quantize(
    int qp,
    threadgroup float *sourceBlock,
    threadgroup float *destinationBlock,
    int index,
    bool isChroma
) {
    float q = adjustQ(qp, index, isChroma);
    
    float value = sourceBlock[index];
    float quantized = round(value / q);
    destinationBlock[index] = quantized;
}

void dequantize(
    int qp,
    threadgroup float *sourceBlock,
    threadgroup float *destinationBlock,
    int index,
    bool isChroma
) {
    float q = adjustQ(qp, index, isChroma);
    
    float value = sourceBlock[index];
    float dequantized = value * q;
    destinationBlock[index] = dequantized;
}

kernel void dctKernel(
    texture2d<half, access::read> inTexture [[texture(0)]],
    texture2d<half, access::write> outTexture [[texture(1)]],
    uint2 pixelPosition [[thread_position_in_grid]],
    uint2 blockPosition [[thread_position_in_threadgroup]],
    constant int &colorPlane [[buffer(2)]]
) {
    threadgroup float CurBlockLocal1[BLOCK_SIZE2];
    threadgroup float CurBlockLocal2[BLOCK_SIZE2];
    
    half4 rgbPixelIn;
    int imageQp;
    bool isChroma = false;
    if (colorPlane == 1 || colorPlane == 2) {
        imageQp = chromaQp;
        isChroma = true;
        
        half4 rgbPixelIn0 = inTexture.read(uint2(pixelPosition.x * 2, pixelPosition.y * 2));
        half4 rgbPixelNextX = inTexture.read(uint2(pixelPosition.x * 2 + 1, pixelPosition.y * 2));
        half4 rgbPixelNextY = inTexture.read(uint2(pixelPosition.x * 2, pixelPosition.y * 2 + 1));
        half4 rgbPixelNextXY = inTexture.read(uint2(pixelPosition.x * 2 + 1, pixelPosition.y * 2 + 1));
        
        rgbPixelIn = mix(rgbPixelIn0, rgbPixelNextX, 0.5);
        rgbPixelIn = mix(rgbPixelIn, rgbPixelNextY, 0.5);
        rgbPixelIn = mix(rgbPixelIn, rgbPixelNextXY, 0.5);
    } else {
        if (colorPlane == 3) {
            imageQp = alphaQp;
        } else {
            imageQp = lumaQp;
        }
        
        rgbPixelIn = inTexture.read(pixelPosition);
    }
    
    copyTextureBlockIn(rgbPixelIn, colorPlane, blockPosition, CurBlockLocal1);
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    DCT(
        blockPosition,
        CurBlockLocal1,
        CurBlockLocal2
    );
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    int index = (blockPosition.y << BLOCK_SIZE_LOG2) + blockPosition.x;
    quantize(imageQp, CurBlockLocal1, CurBlockLocal2, index, isChroma);
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    reorderBlockZigzag(CurBlockLocal2, CurBlockLocal1, blockPosition);
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    copyTextureBlockOutFloat(
        pixelPosition,
        blockPosition,
        CurBlockLocal1,
        outTexture
    );
}

kernel void idctKernel(
    texture2d<half, access::read> inTexture [[texture(0)]],
    texture2d<half, access::write> outTexture [[texture(1)]],
    uint2 pixelPosition [[thread_position_in_grid]],
    uint2 blockPosition [[thread_position_in_threadgroup]],
    constant int &colorPlane [[buffer(2)]]
) {
    threadgroup float CurBlockLocal1[BLOCK_SIZE2];
    threadgroup float CurBlockLocal2[BLOCK_SIZE2];
    
    int imageQp;
    bool isChroma = false;
    if (colorPlane == 1 || colorPlane == 2) {
        isChroma = true;
        imageQp = chromaQp;
    } else {
        if (colorPlane == 3) {
            imageQp = alphaQp;
        } else {
            imageQp = lumaQp;
        }
    }
    
    copyTextureBlockInDequantize(inTexture, pixelPosition, blockPosition, CurBlockLocal1, imageQp, isChroma);
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    IDCT(
         blockPosition,
         CurBlockLocal1,
         CurBlockLocal2
    );
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    copyTextureBlockOut(
        pixelPosition,
        blockPosition,
        CurBlockLocal1,
        outTexture
    );
}
