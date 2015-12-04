//
//  LightBuffer.m
//  MetalKitDeferredLighting
//
//  Created by Bogdan Adam on 12/2/15.
//  Copyright © 2015 Bogdan Adam. All rights reserved.
//

#import "LightBuffer.h"

@implementation LightBuffer
{
    BOOL _depthEnabled;
    id <MTLDepthStencilState> _dState;
    vector_float2 screenSize;
    MTLRenderPassDescriptor *_renderPassDesc;
}

- (id)initWithDepthEnabled:(BOOL)enabled device:(id<MTLDevice>)_device screensize:(vector_float2)sc
{
    self = [super init];
    if (self)
    {
        screenSize = sc;
        
        MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
        if (enabled)
        {
            depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
        }
        else
        {
            depthStateDesc.depthCompareFunction = MTLCompareFunctionAlways;
        }
        depthStateDesc.depthWriteEnabled = enabled;
        _dState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];
        
        [self buildBufferWithDevice:_device];
    }
    return self;
}

- (void)createTextureFor:(MTLRenderPassColorAttachmentDescriptor *)color size:(vector_float2)s withDevice:(id<MTLDevice>)_device
{
    MTLTextureDescriptor *d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatBGRA8Unorm
                                                                                 width: s.x
                                                                                height: s.y
                                                                             mipmapped: NO];
    d.sampleCount = 1;
    d.storageMode = MTLStorageModePrivate;
    d.textureType = MTLTextureType2D;
    d.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    
    id<MTLTexture> texture = [_device newTextureWithDescriptor: d];
    
    color.texture = texture;
    color.loadAction = MTLLoadActionClear;
    color.storeAction = MTLStoreActionStore;
}

- (void)buildBufferWithDevice:(id<MTLDevice>)_device
{
    MTLTextureDescriptor *textureDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatDepth32Float
                                                                                           width: screenSize.x
                                                                                          height: screenSize.y
                                                                                       mipmapped: NO];
    textureDesc.sampleCount = 1;
    textureDesc.storageMode = MTLStorageModePrivate;
    textureDesc.textureType = MTLTextureType2D;
    textureDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    id<MTLTexture> depth_texture = [_device newTextureWithDescriptor: textureDesc];
    
    _renderPassDesc = [[MTLRenderPassDescriptor alloc] init];
    
    //light
    _renderPassDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.f, 0.f, 0.f, 1.f);
    [self createTextureFor:_renderPassDesc.colorAttachments[0] size:screenSize withDevice:_device];
    
    //depth
    _renderPassDesc.depthAttachment.loadAction = MTLLoadActionClear;
    _renderPassDesc.depthAttachment.storeAction = MTLStoreActionDontCare;
    _renderPassDesc.depthAttachment.texture = depth_texture;
    _renderPassDesc.depthAttachment.clearDepth = 1.0;
}

- (MTLRenderPassDescriptor *)renderPassDescriptor
{
    return _renderPassDesc;
}

- (id <MTLDepthStencilState>) _depthState
{
    return _dState;
}

- (void)setScreenSize:(vector_float2)sc device:(id<MTLDevice>)_device
{
    screenSize = sc;
    
    _renderPassDesc.colorAttachments[0].texture = nil;
    _renderPassDesc.depthAttachment.texture = nil;
    _renderPassDesc = nil;
    
    [self buildBufferWithDevice:_device];
}

- (void)dealloc
{
    _renderPassDesc.colorAttachments[0].texture = nil;
    _renderPassDesc.depthAttachment.texture = nil;
    _dState = nil;
}

@end
