//
//  light.metal
//  MetalKitDeferredLighting
//
//  Created by Bogdan Adam on 12/2/15.
//  Copyright © 2015 Bogdan Adam. All rights reserved.
//

#include <metal_stdlib>
#include "SharedStructures.h"
using namespace metal;

struct VertexOutput
{
    float4 position [[position]];
    float3 v_view;
};

// This shader is used to render light primitives as geometry.  The runtime side manages
// the stencil buffer such that each light primitive shades single-sided (only the front face or back face contributes light).
// The fragment shader sources all of its input values from the current framebuffer attachments (G-buffer).
vertex VertexOutput lightVert(constant float4 *posData [[buffer(0)]],
                              constant LightModelMatrices *matrices [[buffer(1)]],
                              uint vid [[vertex_id]])

{
    VertexOutput output;
    
    float4 tempPosition = float4(float3(posData[vid].xyz), 1.0);
    output.position = matrices->mvpMatrix * tempPosition;
    output.v_view = (matrices->mvMatrix * tempPosition).xyz;
    
    return output;
}


fragment float4 lightFrag(VertexOutput in [[stage_in]],
                          constant LightFragmentInputs *lightData [[buffer(0)]],
                          texture2d<float> normalsAndDepth [[ texture(0) ]],
                          texture2d<float> lightColor [[ texture(1) ]])
{
    float2 txCoords = in.position.xy/lightData->screen_size;
    constexpr sampler texSampler;
    float4 gBuffers = normalsAndDepth.sample(texSampler, txCoords);
    float3 n_s = gBuffers.rgb;
    
    float scene_z = gBuffers.a;
    
    float3 n = n_s * 2.0 - 1.0;
    
    float3 v = in.v_view * (scene_z / in.v_view.z);
    
    float3 l = lightData->view_light_position.xyz - v;
    float n_ls = dot(n, n);
    float v_ls = dot(v, v);
    float l_ls = dot(l, l);
    float3 h = (l * rsqrt(l_ls / v_ls) - v);
    float h_ls = dot(h, h);
    float nl = dot(n, l) * rsqrt(n_ls * l_ls);
    float nh = dot(n, h) * rsqrt(n_ls * h_ls);
    float d_atten = sqrt(l_ls);
    float atten = fmax(1.0 - d_atten / lightData->light_color_radius.w, 0.0);
    float diffuse = fmax(nl, 0.0) * atten;
    
    //float4 light = gBuffers.light;
    //float4 light = lightColor.sample(texSampler, txCoords);
    float4 light = float4(0.0);
    light.rgb += lightData->light_color_radius.xyz * diffuse;
    light.a += pow(fmax(nh, 0.0), 32.0) * step(0.0, nl) * atten * 1.0001;
    
    return light;
}
