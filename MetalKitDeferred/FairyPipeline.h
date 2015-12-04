//
//  FairyPipeline.h
//  MetalKitDeferredLighting
//
//  Created by Bogdan Adam on 12/4/15.
//  Copyright © 2015 Bogdan Adam. All rights reserved.
//

#import <MetalKit/MetalKit.h>

@interface FairyPipeline : NSObject

- (id)initWithDevice:(id<MTLDevice>)_device library:(id <MTLLibrary>)_library;
- (id <MTLRenderPipelineState>)_pipeline;

@end
