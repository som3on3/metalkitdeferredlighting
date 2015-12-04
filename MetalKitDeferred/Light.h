//
//  Light.h
//  MetalKitDeferredLighting
//
//  Created by Bogdan Adam on 12/2/15.
//  Copyright © 2015 Bogdan Adam. All rights reserved.
//

#import <MetalKit/MetalKit.h>

@class GBuffer, LightBuffer;

@interface Light : NSObject

- (id)initWithDevice:(id<MTLDevice>)_device color:(vector_float3)color;
- (void)render:(uint8_t)_constantDataBufferIndex encoder:(id <MTLRenderCommandEncoder>)renderEncoder withBufferData:(GBuffer *)gBuffer;
- (void)renderFairy:(uint8_t)_constantDataBufferIndex encoder:(id <MTLRenderCommandEncoder>)renderEncoder withTexture:(id<MTLTexture>)txt;
- (void)_reshape:(vector_float2)screenSize;
- (void)update:(matrix_float4x4)parentMatrix projection:(matrix_float4x4)projection bufferIndex:(uint8_t)_constantDataBufferIndex;

@property (nonatomic, readonly) id<MTLBuffer> quadBuffer;
@property (nonatomic, readonly) id<MTLBuffer> vertexBuffer;
@property (nonatomic, readonly) id<MTLBuffer> indexBuffer;
@property (nonatomic, assign) NSUInteger vertexCount;
@property (nonatomic, assign) float xpos;

@end
