//
//  Light.m
//  MetalKitDeferredLighting
//
//  Created by Bogdan Adam on 12/2/15.
//  Copyright © 2015 Bogdan Adam. All rights reserved.
//

#import "Light.h"
#import "math.h"
#import "GBuffer.h"
#import "LightBuffer.h"
#import "SharedStructures.h"

static const float fQuadVertices[] =
{
    -0.5f,  -0.5f, 0.0f, 0.0f, 0.0f,
    0.5f,  -0.5f, 0.0f, 1.0f, 0.0f,
    -0.5f,   0.5f, 0.0f, 0.0f, 1.0f,
    
    0.5f,  -0.5f, 0.0f, 1.0f, 0.0f,
    -0.5f,   0.5f, 0.0f, 0.0f, 1.0f,
    0.5f,   0.5f, 0.0f, 1.0f, 1.0f
};

@implementation Light
{
    id <MTLBuffer> _modelMatrixBuffers[3];
    id <MTLBuffer> _lightBuffers[3];
    vector_float2 screen_size;
    vector_float3 _color;
    float ypos;
}

- (id)initWithDevice:(id<MTLDevice>)_device color:(vector_float3)color
{
    self = [super init];
    if (self)
    {
        screen_size = (vector_float2){0.f, 0.f};
        ypos = 8.0;
        _xpos = 0.0;
        
        _color = color;
        
        float X = 0.5 / 0.755761314076171f;
        float Z = X * (1.0 + sqrtf(5.0)) / 2.0;
        float lightVdata[12][4] =
        {
            { -X, 0.0, Z, 1.0f }
            ,
            { X, 0.0, Z, 1.0f }
            ,
            { -X, 0.0, -Z, 1.0f }
            ,
            { X, 0.0, -Z, 1.0f }
            ,
            { 0.0, Z, X, 1.0f }
            ,
            { 0.0, Z, -X, 1.0f }
            ,
            { 0.0, -Z, X, 1.0f }
            ,
            { 0.0, -Z, -X, 1.0f }
            ,
            { Z, X, 0.0, 1.0f }
            ,
            { -Z, X, 0.0, 1.0f }
            ,
            { Z, -X, 0.0, 1.0f }
            ,
            { -Z, -X, 0.0, 1.0f }
        };
        unsigned short tindices[20][3] =
        {
            { 0, 1, 4 }
            ,
            { 0, 4, 9 }
            ,
            { 9, 4, 5 }
            ,
            { 4, 8, 5 }
            ,
            { 4, 1, 8 }
            ,
            { 8, 1, 10 }
            ,
            { 8, 10, 3 }
            ,
            { 5, 8, 3 }
            ,
            { 5, 3, 2 }
            ,
            { 2, 3, 7 }
            ,
            { 7, 3, 10 }
            ,
            { 7, 10, 6 }
            ,
            { 7, 6, 11 }
            ,
            { 11, 6, 0 }
            ,
            { 0, 6, 1 }
            ,
            { 6, 10, 1 }
            ,
            { 9, 11, 0 }
            ,
            { 9, 2, 11 }
            ,
            { 9, 5, 2 }
            ,
            { 7, 11, 2 }
        };
        
        
        
        _vertexBuffer = [_device newBufferWithBytes:lightVdata length:sizeof(lightVdata) options:MTLResourceOptionCPUCacheModeDefault];
        
        _indexBuffer = [_device newBufferWithBytes:tindices length:sizeof(tindices) options:MTLResourceOptionCPUCacheModeDefault];
        
        for (int i = 0; i < 3; i++)
        {
            _modelMatrixBuffers[i] = [_device newBufferWithLength:sizeof(LightModelMatrices) options:MTLResourceOptionCPUCacheModeDefault];
            _modelMatrixBuffers[i].label = [NSString stringWithFormat:@"lightBuffer%i", i];
            
            
            _lightBuffers[i] = [_device newBufferWithLength:sizeof(LightFragmentInputs) options:MTLResourceOptionCPUCacheModeDefault];
            _lightBuffers[i].label = [NSString stringWithFormat:@"lightFragBuffer%i", i];
        }
        
        _quadBuffer = [_device newBufferWithBytes:fQuadVertices length:sizeof(fQuadVertices) options:MTLResourceOptionCPUCacheModeDefault];
        
        
        _vertexCount = 60;
    }
    return self;
}

- (void)_reshape:(vector_float2)screenSize
{
    screen_size = screenSize;
}

- (void)update:(matrix_float4x4)parentMatrix projection:(matrix_float4x4)projection bufferIndex:(uint8_t)_constantDataBufferIndex
{
    
    ypos -= 0.03;
    vector_float4 position = (vector_float4){sinf(ypos)*2.5 + _xpos, 0.25, cosf(ypos) - 5.f, 1.0};
    
    matrix_float4x4 modelView = matrix_multiply(parentMatrix, matrix_from_translation(position.x, position.y, position.z));
    
    LightModelMatrices *matrixState = (LightModelMatrices *)[_modelMatrixBuffers[_constantDataBufferIndex] contents];
    matrixState->mvMatrix = modelView;
    matrixState->mvpMatrix = matrix_multiply(projection, modelView);
    
    
    LightFragmentInputs *light = (LightFragmentInputs *)[_lightBuffers[_constantDataBufferIndex] contents];
    light->screen_size = screen_size;
    light->light_color_radius = (vector_float4){_color.x, _color.y, _color.z, 1.0};
    
    
    light->view_light_position = matrix_multiply(parentMatrix, position);
}

- (void)render:(uint8_t)_constantDataBufferIndex encoder:(id <MTLRenderCommandEncoder>)renderEncoder withBufferData:(GBuffer *)gBuffer
{
    if (_vertexCount > 0)
    {
        MTLRenderPassDescriptor *d = [gBuffer renderPassDescriptor];
        
        [renderEncoder pushDebugGroup:NSStringFromClass([self class])];
        [renderEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0 ];
        [renderEncoder setVertexBuffer:_modelMatrixBuffers[_constantDataBufferIndex] offset:0 atIndex:1 ];
        [renderEncoder setFragmentBuffer:_lightBuffers[_constantDataBufferIndex] offset:0 atIndex:0 ];
        
        [renderEncoder setFragmentTexture:d.colorAttachments[1].texture atIndex:0];
        
        [renderEncoder drawIndexedPrimitives: MTLPrimitiveTypeTriangle indexCount: _vertexCount indexType: MTLIndexTypeUInt16 indexBuffer: _indexBuffer indexBufferOffset: 0];
        
        [renderEncoder popDebugGroup];
    }
    
}

- (void)renderFairy:(uint8_t)_constantDataBufferIndex encoder:(id <MTLRenderCommandEncoder>)renderEncoder withTexture:(id<MTLTexture>)txt
{
    [renderEncoder pushDebugGroup:@"Fairy"];
    [renderEncoder setVertexBuffer:self.quadBuffer offset:0 atIndex:0 ];
    [renderEncoder setVertexBuffer:_modelMatrixBuffers[_constantDataBufferIndex] offset:0 atIndex:1 ];
    [renderEncoder setFragmentBuffer:_lightBuffers[_constantDataBufferIndex] offset:0 atIndex:0 ];
    [renderEncoder setFragmentTexture:txt atIndex:0];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    [renderEncoder popDebugGroup];
}

@end
