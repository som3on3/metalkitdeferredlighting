//
//  gBuffer.metal
//  MetalKitDeferredLighting
//
//  Created by Bogdan Adam on 12/1/15.
//  Copyright © 2015 Bogdan Adam. All rights reserved.
//

#include <metal_stdlib>
#include "SharedStructures.h"
using namespace metal;

// Variables in constant address space
constant float3 light_position = float3(0.0, 1.0, -1.0);
constant float4 ambient_color  = float4(0.18, 0.24, 0.8, 1.0);
constant float4 diffuse_color  = float4(0.4, 0.4, 1.0, 1.0);

typedef struct
{
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
} vertex_t;

typedef struct {
    float4 position [[position]];
    float4  color;
    float4 normals;
    float v_lineardepth;
} ColorInOut;

// Vertex shader function
vertex ColorInOut gBufferVert(vertex_t vertex_array [[stage_in]],
                              constant uniforms_t& uniforms [[ buffer(1) ]])
{
    ColorInOut out;
    
    float4 in_position = float4(vertex_array.position, 1.0);
    out.position = uniforms.modelview_projection_matrix * in_position;
    
    float4 eye_normal = normalize(uniforms.normal_matrix * float4(vertex_array.normal, 0.0));
    float n_dot_l = dot(eye_normal.rgb, normalize(light_position));
    n_dot_l = fmax(0.0, n_dot_l);
    
    out.color = float4(ambient_color + diffuse_color * n_dot_l);
    out.normals = eye_normal;
    out.v_lineardepth = (uniforms.modelview_matrix * in_position).z;
    return out;
}

typedef struct {
    float4 albedo [[color(0)]];
    float4 normals [[color(1)]];
} GBufferOut;

// Fragment shader function
fragment GBufferOut gBufferFrag(ColorInOut in [[stage_in]])
{
    float3 world_normal = in.normals.xyz;
    float scale = rsqrt(dot(world_normal, world_normal)) * 0.5;
    world_normal = world_normal * scale + 0.5;
    
    GBufferOut out;
    out.albedo = in.color;
    out.normals.xyz = world_normal;
    out.normals.a = in.v_lineardepth;
    return out;
}
