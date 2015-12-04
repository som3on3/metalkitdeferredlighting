//
//  Shaders.metal
//  MetalKitDeferred
//
//  Created by Bogdan Adam on 12/1/15.
//  Copyright (c) 2015 Bogdan Adam. All rights reserved.
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
vertex ColorInOut quadVert(device vertex_t* vertex_array [[ buffer(0) ]],
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
fragment float4 quadFrag(ColorInOut in [[stage_in]],
                         texture2d<float> albedo [[ texture(0) ]],
                         texture2d<float> lightData [[ texture(1) ]],
                         texture2d<float> normals [[ texture(2) ]])
{
    constexpr sampler texSampler(min_filter::linear, mag_filter::linear);
    
    float4 light = lightData.sample(texSampler, in.texCoord);
    
    float3 diffuse = light.rgb;
    float3 n_s = normals.sample(texSampler, in.texCoord).rgb;
    float sun_diffuse = fmax(dot(n_s * 2.0 - 1.0, float3(0.0, 0.1, 0.0)), 0.0);
    
    diffuse += float3(0.75) * sun_diffuse;
    diffuse *= albedo.sample(texSampler, in.texCoord).rgb;
    
    diffuse += diffuse;
    
    return float4(diffuse, 1.0);
}