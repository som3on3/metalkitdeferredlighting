//
//  FairyPipeline.m
//  MetalKitDeferredLighting
//
//  Created by Bogdan Adam on 12/4/15.
//  Copyright © 2015 Bogdan Adam. All rights reserved.
//

#import "FairyPipeline.h"

@implementation FairyPipeline
{
    id <MTLRenderPipelineState> _pipelineState;
}

- (id)initWithDevice:(id<MTLDevice>)_device library:(id <MTLLibrary>)_library
{
    self = [super init];
    if (self)
    {
        id <MTLFunction> fragmentProgram = [_library newFunctionWithName:@"fairyFragment"];
        if(!fragmentProgram)
            NSLog(@">> ERROR: Couldn't load fragment function from default library");
        
        id <MTLFunction> vertexProgram = [_library newFunctionWithName:@"fairyVertex"];
        if(!vertexProgram)
            NSLog(@">> ERROR: Couldn't load vertex function from default library");
        
        
        
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        
        pipelineStateDescriptor.label                           = @"fairyPipeline";
        pipelineStateDescriptor.sampleCount                     = 1;
        pipelineStateDescriptor.vertexFunction                  = vertexProgram;
        pipelineStateDescriptor.fragmentFunction                = fragmentProgram;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        pipelineStateDescriptor.depthAttachmentPixelFormat      = MTLPixelFormatDepth32Float_Stencil8;
        pipelineStateDescriptor.stencilAttachmentPixelFormat    = MTLPixelFormatDepth32Float_Stencil8;
        
        
        pipelineStateDescriptor.colorAttachments[0].blendingEnabled = YES;
        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
        pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor =
        MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor =
        MTLBlendFactorOneMinusSourceAlpha;
        
        NSError *error = nil;
        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        if(!_pipelineState) {
            NSLog(@">> ERROR: Failed Aquiring pipeline state: %@", error);
        }
    }
    return self;
}

- (id <MTLRenderPipelineState>)_pipeline
{
    return _pipelineState;
}

@end
