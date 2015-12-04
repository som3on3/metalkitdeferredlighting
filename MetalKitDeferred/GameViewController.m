//
//  GameViewController.m
//  MetalKitDeferred
//
//  Created by Bogdan Adam on 12/1/15.
//  Copyright (c) 2015 Bogdan Adam. All rights reserved.
//

#import "GameViewController.h"
#import "SharedStructures.h"

#import "GBuffer.h"
#import "GPipeLine.h"
#import "LightBuffer.h"
#import "LightPipeLine.h"
#import "FairyPipeline.h"
#import "Quad.h"
#import "Light.h"
#import "math.h"

// The max number of command buffers in flight
static const NSUInteger kMaxInflightBuffers = 3;

// Max API memory buffer size.
static const size_t kMaxBytesPerFrame = 1024*1024;

@implementation GameViewController
{
    // view
    MTKView *_view;
    
    // controller
    dispatch_semaphore_t _inflight_semaphore;
    id <MTLBuffer> _dynamicConstantBuffer;
    uint8_t _constantDataBufferIndex;
    
    // renderer
    id <MTLDevice> _device;
    id <MTLCommandQueue> _commandQueue;
    id <MTLLibrary> _defaultLibrary;
    id <MTLRenderPipelineState> _pipelineState;
    id <MTLDepthStencilState> _depthState;
    
    // uniforms
    matrix_float4x4 _projectionMatrix;
    matrix_float4x4 _viewMatrix;
    uniforms_t _uniform_buffer;
    float _rotation;
    
    // meshes
    MTKMesh *_boxMesh;
    
    GBuffer *_gBuffer;
    LightBuffer *_lightBuffer;
    GPipeLine *_gPipeline;
    LightPipeline *_lightPipeline;
    FairyPipeline *_fairyPipeline;
    Quad *_quad;
    
    NSMutableArray *lights;
    id <MTLTexture> _fairyTexture;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _constantDataBufferIndex = 0;
    _inflight_semaphore = dispatch_semaphore_create(3);
    
    [self _setupMetal];
    if(_device)
    {
        [self _setupView];
        [self _loadAssets];
        [self _reshape];
    }
    else // Fallback to a blank NSView, an application could also fallback to OpenGL here.
    {
        NSLog(@"Metal is not supported on this device");
        self.view = [[NSView alloc] initWithFrame:self.view.frame];
    }
}

- (float)randomFloat:(float)min max:(float)max
{
    double mix = (double)random() / RAND_MAX;
    return min + (max - min) * mix;
}

- (vector_float3)randomColor
{
    vector_float3 color = (vector_float3){[self randomFloat:0.f max:1.f], [self randomFloat:0.f max:1.f], [self randomFloat:0.f max:1.f]};
    
    return vector_normalize(color);
}

- (void)_setupView
{
    _view = (MTKView *)self.view;
    _view.delegate = self;
    _view.device = _device;
    _view.clearColor = MTLClearColorMake(0.f, 0.f, 0.f, 1.f);
    
    // Setup the render target, choose values based on your app
    _view.sampleCount = 1;
    _view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
}

- (void)_setupMetal
{
    // Set the view to use the default device
    _device = MTLCreateSystemDefaultDevice();

    // Create a new command queue
    _commandQueue = [_device newCommandQueue];
    
    // Load all the shader files with a metal file extension in the project
    _defaultLibrary = [_device newDefaultLibrary];
}

- (void)_loadAssets
{
    lights = [[NSMutableArray alloc] init];
    
    vector_float2 screenSize = (vector_float2){self.view.bounds.size.width, self.view.bounds.size.height};
    _gBuffer = [[GBuffer alloc] initWithDepthEnabled:YES device:_device screensize:screenSize];
    _lightBuffer = [[LightBuffer alloc] initWithDepthEnabled:NO device:_device screensize:screenSize];
    _gPipeline = [[GPipeLine alloc] initWithDevice:_device library:_defaultLibrary];
    _lightPipeline = [[LightPipeline alloc] initWithDevice:_device library:_defaultLibrary];
    _fairyPipeline = [[FairyPipeline alloc] initWithDevice:_device library:_defaultLibrary];
    
    _quad = [[Quad alloc] initWithDevice:_device];
    
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *bundlePath = [bundle pathForResource:@"assets/fairy" ofType:@"png"];
    
    NSMutableString *URLString = [[NSMutableString alloc] initWithString:@"file://"];
    [URLString appendString:bundlePath];
    
    NSURL *textureURL = [NSURL URLWithString:URLString];
    
    //NSLog(@"%@", textureURL);
    //exit(-1);
    
    MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];
    
    
    
    NSError *error;
    _fairyTexture = [textureLoader newTextureWithContentsOfURL:textureURL options:@{MTKTextureLoaderOptionAllocateMipmaps:@YES} error:&error];
    
    if (!_fairyTexture) {
        [NSException raise:@"diffuse texture load" format:@"%@", error.localizedDescription];
    }
    
    for (int i=-5; i<5; i++)
    {
        Light *l = [[Light alloc] initWithDevice:_device color:[self randomColor]];
        [l setXpos:(float)i];
        [lights addObject:l];
    }
    
    
    // Generate meshes
    //MDLMesh *mdl = [MDLMesh newPlaneWithDimensions:(vector_float2){10,10} segments:(vector_uint2){1,1} geometryType:MDLGeometryTypeTriangles allocator:[[MTKMeshBufferAllocator alloc] initWithDevice: _device]];
    
    MDLMesh *mdl = [MDLMesh newBoxWithDimensions:(vector_float3){20,0.1,20} segments:(vector_uint3){1,1,1} geometryType:MDLGeometryTypeTriangles inwardNormals:NO allocator:[[MTKMeshBufferAllocator alloc] initWithDevice: _device]];
    
    _boxMesh = [[MTKMesh alloc] initWithMesh:mdl device:_device error:nil];
    
    // Allocate one region of memory for the uniform buffer
    _dynamicConstantBuffer = [_device newBufferWithLength:kMaxBytesPerFrame options:0];
    _dynamicConstantBuffer.label = @"UniformBuffer";
    
    // Load the fragment program into the library
    id <MTLFunction> fragmentProgram = [_defaultLibrary newFunctionWithName:@"quadFrag"];
    
    // Load the vertex program into the library
    id <MTLFunction> vertexProgram = [_defaultLibrary newFunctionWithName:@"quadVert"];
    
    // Create a vertex descriptor from the MTKMesh
    MTLVertexDescriptor *vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(_boxMesh.vertexDescriptor);
    vertexDescriptor.layouts[0].stepRate = 1;
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    
    // Create a reusable pipeline state
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"MyPipeline";
    pipelineStateDescriptor.sampleCount = _view.sampleCount;
    pipelineStateDescriptor.vertexFunction = vertexProgram;
    pipelineStateDescriptor.fragmentFunction = fragmentProgram;
    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = _view.colorPixelFormat;
    pipelineStateDescriptor.depthAttachmentPixelFormat = _view.depthStencilPixelFormat;
    pipelineStateDescriptor.stencilAttachmentPixelFormat = _view.depthStencilPixelFormat;
    
    error = NULL;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
    if (!_pipelineState) {
        NSLog(@"Failed to created pipeline state, error %@", error);
    }
    
    MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthStateDesc.depthCompareFunction = MTLCompareFunctionAlways;
    depthStateDesc.depthWriteEnabled = NO;
    _depthState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];
}

- (void)renderGBuffer:(id <MTLCommandBuffer>)commandBuffer
{
    MTLRenderPassDescriptor* renderPassDescriptor = [_gBuffer renderPassDescriptor];
    if(renderPassDescriptor != nil)
    {
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"gBufferEncoder";
        [renderEncoder setDepthStencilState:[_gBuffer _depthState]];
        
        // Set context state
        [renderEncoder pushDebugGroup:@"DrawCubeG"];
        [renderEncoder setRenderPipelineState:[_gPipeline _pipeline]];
        [renderEncoder setVertexBuffer:_boxMesh.vertexBuffers[0].buffer offset:_boxMesh.vertexBuffers[0].offset atIndex:0 ];
        [renderEncoder setVertexBuffer:_dynamicConstantBuffer offset:(sizeof(uniforms_t) * _constantDataBufferIndex) atIndex:1 ];
        
        MTKSubmesh* submesh = _boxMesh.submeshes[0];
        // Tell the render context we want to draw our primitives
        [renderEncoder drawIndexedPrimitives:submesh.primitiveType indexCount:submesh.indexCount indexType:submesh.indexType indexBuffer:submesh.indexBuffer.buffer indexBufferOffset:submesh.indexBuffer.offset];
        
        [renderEncoder popDebugGroup];
        
        // We're done encoding commands
        [renderEncoder endEncoding];
    }
}

- (void)renderLights:(id <MTLCommandBuffer>)commandBuffer
{
    MTLRenderPassDescriptor* renderPassDescriptor = [_lightBuffer renderPassDescriptor];
    if (renderPassDescriptor != nil)
    {
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"lightBufferEncoder";
        [renderEncoder pushDebugGroup:@"Lights"];
        [renderEncoder setDepthStencilState:[_lightBuffer _depthState]];
        [renderEncoder setRenderPipelineState:[_lightPipeline _pipeline]];
        
        [lights enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [(Light *)obj render:_constantDataBufferIndex encoder:renderEncoder withBufferData:_gBuffer];
        }];
        
        
        [renderEncoder popDebugGroup];
        [renderEncoder endEncoding];
    }
}

- (void)_render
{
    dispatch_semaphore_wait(_inflight_semaphore, DISPATCH_TIME_FOREVER);
    
    [self _update];

    // Create a new command buffer for each renderpass to the current drawable
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    // Call the view's completion handler which is required by the view since it will signal its semaphore and set up the next buffer
    __block dispatch_semaphore_t block_sema = _inflight_semaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        dispatch_semaphore_signal(block_sema);
    }];
    
    [self renderGBuffer:commandBuffer];
    
    [self renderLights:commandBuffer];
    
    // Obtain a renderPassDescriptor generated from the view's drawable textures
    MTLRenderPassDescriptor* renderPassDescriptor = _view.currentRenderPassDescriptor;

    if(renderPassDescriptor != nil) // If we have a valid drawable, begin the commands to render into it
    {
        // Create a render command encoder so we can render into something
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"QuadRenderEncoder";
        [renderEncoder setDepthStencilState:_depthState];
        
        // Set context state
        [renderEncoder pushDebugGroup:@"DrawCube"];
        [renderEncoder setRenderPipelineState:_pipelineState];
        
        [_quad render:_constantDataBufferIndex encoder:renderEncoder withTextures:@[[_gBuffer renderPassDescriptor].colorAttachments[0].texture, [_lightBuffer renderPassDescriptor].colorAttachments[0].texture, [_gBuffer renderPassDescriptor].colorAttachments[1].texture]];

        [renderEncoder popDebugGroup];
        
        
        [renderEncoder setRenderPipelineState:[_fairyPipeline _pipeline]];
        [lights enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [(Light *)obj renderFairy:_constantDataBufferIndex encoder:renderEncoder withTexture:_fairyTexture];
        }];
        
        // We're done encoding commands
        [renderEncoder endEncoding];
        
        // Schedule a present once the framebuffer is complete using the current drawable
        [commandBuffer presentDrawable:_view.currentDrawable];
    }

    // The render assumes it can now increment the buffer index and that the previous index won't be touched until we cycle back around to the same index
    _constantDataBufferIndex = (_constantDataBufferIndex + 1) % kMaxInflightBuffers;

    // Finalize rendering here & push the command buffer to the GPU
    [commandBuffer commit];
}

- (void)_reshape
{
    vector_float2 screenSize = (vector_float2){self.view.bounds.size.width, self.view.bounds.size.height};
    [_gBuffer setScreenSize:screenSize device:_device];
    [_lightBuffer setScreenSize:screenSize device:_device];
    
    [_quad _reshape:screenSize];
    
    [lights enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [(Light *)obj _reshape:screenSize];
    }];
    
    
    
    // When reshape is called, update the view and projection matricies since this means the view orientation or size changed
    float aspect = fabs(self.view.bounds.size.width / self.view.bounds.size.height);
    _projectionMatrix = matrix_from_perspective_fov_aspectLH(65.0f * (M_PI / 180.0f), aspect, 0.1f, 25.0f);
    
    _viewMatrix = matrix_from_translation(0.0f, -2.f, 14.0f);
}

- (void)_update
{
    [_quad update:_constantDataBufferIndex];
    
    [lights enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [(Light *)obj update:_viewMatrix projection:_projectionMatrix bufferIndex:_constantDataBufferIndex];
    }];
    //matrix_float4x4 base_model = matrix_multiply(matrix_from_translation(0.0f, 0.0f, 5.0f), matrix_from_rotation(_rotation, 0.0f, 1.0f, 0.0f));
    matrix_float4x4 base_model = matrix_from_translation(0, 0.0, 0);
    matrix_float4x4 modelViewMatrix = matrix_multiply(_viewMatrix, base_model);
    
    // Load constant buffer data into appropriate buffer at current index
    uniforms_t *uniforms = &((uniforms_t *)[_dynamicConstantBuffer contents])[_constantDataBufferIndex];

    uniforms->normal_matrix = modelViewMatrix;
    uniforms->modelview_matrix = modelViewMatrix;
    uniforms->modelview_projection_matrix = matrix_multiply(_projectionMatrix, modelViewMatrix);
    
    _rotation += 0.01f;
}

// Called whenever view changes orientation or layout is changed
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    [self _reshape];
}


// Called whenever the view needs to render
- (void)drawInMTKView:(nonnull MTKView *)view
{
    @autoreleasepool {
        [self _render];
    }
}

@end
