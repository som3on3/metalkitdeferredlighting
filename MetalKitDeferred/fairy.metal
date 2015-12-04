//
//  fairy.metal
//  MetalKitDeferredLighting
//
//  Created by Bogdan Adam on 12/4/15.
//  Copyright © 2015 Bogdan Adam. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "SharedStructures.h"

using namespace metal;

typedef struct
{
    packed_float3 position;
    packed_float2 texCoords;
} vertex_t;

typedef struct {
    float4 position [[position]];
    float2 texCoord [[user(texturecoord)]];
} ColorInOut;

// Vertex shader function
vertex ColorInOut fairyVertex(device vertex_t* vertex_array [[ buffer(0) ]],
                              constant QuadMatrices& matrices [[buffer(1)]],
                              uint vid [[vertex_id]])
{
    ColorInOut out;
    
    float4 tempPosition = float4(float3(vertex_array[vid].position), 1.0);
    out.position = matrices.modelview_projection_matrix * tempPosition;
    out.texCoord = vertex_array[vid].texCoords;
    
    return out;
}

// Fragment shader function
fragment float4 fairyFragment(ColorInOut in [[stage_in]],
                         constant LightFragmentInputs *lightData [[buffer(0)]],
                         texture2d<float> txt [[ texture(0) ]])
{
    constexpr sampler texSampler(min_filter::linear, mag_filter::linear);
    
    return float4(lightData->light_color_radius.xyz, 1.0) * txt.sample(texSampler, in.texCoord);
}

