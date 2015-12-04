//
//  SharedStructures.h
//  MetalKitDeferred
//
//  Created by Bogdan Adam on 12/1/15.
//  Copyright (c) 2015 Bogdan Adam. All rights reserved.
//

#ifndef SharedStructures_h
#define SharedStructures_h

#include <simd/simd.h>

typedef struct __attribute__((__aligned__(256)))
{
    matrix_float4x4 modelview_projection_matrix;
    matrix_float4x4 modelview_matrix;
    matrix_float4x4 normal_matrix;
} uniforms_t;

typedef struct __attribute__((__aligned__(256)))
{
    matrix_float4x4  modelview_projection_matrix;
} QuadMatrices;

typedef struct __attribute__((__aligned__(256)))
{
    matrix_float4x4 mvpMatrix;
    matrix_float4x4 mvMatrix;
} LightModelMatrices;

typedef struct __attribute__((__aligned__(256)))
{
    vector_float4   view_light_position;
    vector_float4   light_color_radius;
    vector_float2   screen_size;
} LightFragmentInputs;

typedef struct __attribute__((__aligned__(256)))
{
    vector_float4   con_scale_intensity;
} SpriteData;

#endif /* SharedStructures_h */

