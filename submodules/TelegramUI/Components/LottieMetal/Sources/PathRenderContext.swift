import Foundation
import MetalKit
import LottieCpp

final class PathRenderContext {
    let device: MTLDevice
    let msaaSampleCount: Int
    
    let prepareBezierPipelineState: MTLComputePipelineState
    let shapePipelineState: MTLRenderPipelineState
    let clearPipelineState: MTLRenderPipelineState
    let mergeColorFillPipelineState: MTLRenderPipelineState
    let mergeLinearGradientFillPipelineState: MTLRenderPipelineState
    let mergeRadialGradientFillPipelineState: MTLRenderPipelineState
    let strokeTerminalPipelineState: MTLRenderPipelineState
    let strokeInnerPipelineState: MTLRenderPipelineState
    let drawOffscreenPipelineState: MTLRenderPipelineState
    let drawOffscreenWithMaskPipelineState: MTLRenderPipelineState
    
    let maximumThreadGroupWidth: Int
    
    init?(device: MTLDevice, msaaSampleCount: Int) {
        self.device = device
        self.msaaSampleCount = msaaSampleCount
        
        self.maximumThreadGroupWidth = device.maxThreadsPerThreadgroup.width
        
        guard let library = metalLibrary(device: device) else {
            return nil
        }
        
        guard let quadVertexFunction = library.makeFunction(name: "quad_vertex_shader") else {
            print("Unable to find vertex function. Are you sure you defined it and spelled the name right?")
            return nil
        }
        guard let shapeVertexFunction = library.makeFunction(name: "fill_vertex_shader") else {
            print("Unable to find vertex function. Are you sure you defined it and spelled the name right?")
            return nil
        }
        guard let shapeFragmentFunction = library.makeFunction(name: "fragment_shader") else {
            print("Unable to find fragment function. Are you sure you defined it and spelled the name right?")
            return nil
        }
        guard let clearFragmentFunction = library.makeFunction(name: "clear_mask_fragment") else {
            print("Unable to find fragment function. Are you sure you defined it and spelled the name right?")
            return nil
        }
        guard let mergeColorFillFragmentFunction = library.makeFunction(name: "merge_color_fill_fragment_shader") else {
            print("Unable to find fragment function. Are you sure you defined it and spelled the name right?")
            return nil
        }
        guard let mergeLinearGradientFillFragmentFunction = library.makeFunction(name: "merge_linear_gradient_fill_fragment_shader") else {
            print("Unable to find fragment function. Are you sure you defined it and spelled the name right?")
            return nil
        }
        guard let mergeRadialGradientFillFragmentFunction = library.makeFunction(name: "merge_radial_gradient_fill_fragment_shader") else {
            print("Unable to find fragment function. Are you sure you defined it and spelled the name right?")
            return nil
        }
        guard let strokeFragmentFunction = library.makeFunction(name: "stroke_fragment_shader") else {
            print("Unable to find fragment function. Are you sure you defined it and spelled the name right?")
            return nil
        }
        guard let strokeTerminalVertexFunction = library.makeFunction(name: "strokeTerminalVertex") else {
            print("Unable to find fragment function. Are you sure you defined it and spelled the name right?")
            return nil
        }
        guard let strokeInnerVertexFunction = library.makeFunction(name: "strokeInnerVertex") else {
            print("Unable to find fragment function. Are you sure you defined it and spelled the name right?")
            return nil
        }
        guard let prepareBezierPipelineFunction = library.makeFunction(name: "evaluateBezier") else {
            print("Unable to find fragment function. Are you sure you defined it and spelled the name right?")
            return nil
        }
        guard let quadOffscreenFragmentFunction = library.makeFunction(name: "quad_offscreen_fragment") else {
            print("Unable to find fragment function. Are you sure you defined it and spelled the name right?")
            return nil
        }
        guard let quadOffscreenWithMaskFragmentFunction = library.makeFunction(name: "quad_offscreen_fragment_with_mask") else {
            print("Unable to find fragment function. Are you sure you defined it and spelled the name right?")
            return nil
        }
        
        self.prepareBezierPipelineState = try! device.makeComputePipelineState(function: prepareBezierPipelineFunction)
        
        let shapePipelineDescriptor = MTLRenderPipelineDescriptor()
        shapePipelineDescriptor.vertexFunction = shapeVertexFunction
        shapePipelineDescriptor.fragmentFunction = shapeFragmentFunction
        
        shapePipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        shapePipelineDescriptor.colorAttachments[0].writeMask = []
        shapePipelineDescriptor.colorAttachments[1].pixelFormat = .bgra8Unorm
        shapePipelineDescriptor.colorAttachments[1].writeMask = [.all]
        shapePipelineDescriptor.rasterSampleCount = msaaSampleCount

        guard let shapePipelineState = try? device.makeRenderPipelineState(descriptor: shapePipelineDescriptor) else {
            preconditionFailure()
        }
        self.shapePipelineState = shapePipelineState
        
        let clearPipelineDescriptor = MTLRenderPipelineDescriptor()
        clearPipelineDescriptor.vertexFunction = quadVertexFunction
        clearPipelineDescriptor.fragmentFunction = clearFragmentFunction
        
        clearPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        clearPipelineDescriptor.colorAttachments[0].writeMask = []
        clearPipelineDescriptor.colorAttachments[1].pixelFormat = .bgra8Unorm
        clearPipelineDescriptor.colorAttachments[1].writeMask = .all
        clearPipelineDescriptor.rasterSampleCount = msaaSampleCount

        guard let clearPipelineState = try? device.makeRenderPipelineState(descriptor: clearPipelineDescriptor) else {
            preconditionFailure()
        }
        self.clearPipelineState = clearPipelineState
        
        let mergePipelineDescriptor = MTLRenderPipelineDescriptor()
        mergePipelineDescriptor.vertexFunction = quadVertexFunction
        mergePipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        mergePipelineDescriptor.colorAttachments[0].writeMask = [.all]
        mergePipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        mergePipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        mergePipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        mergePipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        mergePipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        mergePipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        mergePipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        mergePipelineDescriptor.rasterSampleCount = msaaSampleCount
        
        mergePipelineDescriptor.colorAttachments[1].pixelFormat = .bgra8Unorm
        mergePipelineDescriptor.colorAttachments[1].writeMask = []
        
        mergePipelineDescriptor.fragmentFunction = mergeColorFillFragmentFunction
        guard let mergeColorFillPipelineState = try? device.makeRenderPipelineState(descriptor: mergePipelineDescriptor) else {
            preconditionFailure()
        }
        self.mergeColorFillPipelineState = mergeColorFillPipelineState
        
        mergePipelineDescriptor.fragmentFunction = mergeLinearGradientFillFragmentFunction
        guard let mergeLinearGradientFillPipelineState = try? device.makeRenderPipelineState(descriptor: mergePipelineDescriptor) else {
            preconditionFailure()
        }
        self.mergeLinearGradientFillPipelineState = mergeLinearGradientFillPipelineState
        
        mergePipelineDescriptor.fragmentFunction = mergeRadialGradientFillFragmentFunction
        guard let mergeRadialGradientFillPipelineState = try? device.makeRenderPipelineState(descriptor: mergePipelineDescriptor) else {
            preconditionFailure()
        }
        self.mergeRadialGradientFillPipelineState = mergeRadialGradientFillPipelineState
        
        let strokePipelineDescriptor = MTLRenderPipelineDescriptor()
        strokePipelineDescriptor.fragmentFunction = strokeFragmentFunction
        strokePipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        strokePipelineDescriptor.colorAttachments[0].writeMask = [.all]
        strokePipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        strokePipelineDescriptor.colorAttachments[0].rgbBlendOperation = mergePipelineDescriptor.colorAttachments[0].rgbBlendOperation
        strokePipelineDescriptor.colorAttachments[0].alphaBlendOperation = mergePipelineDescriptor.colorAttachments[0].alphaBlendOperation
        strokePipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = mergePipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor
        strokePipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = mergePipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor
        strokePipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = mergePipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor
        strokePipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = mergePipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor
        strokePipelineDescriptor.rasterSampleCount = msaaSampleCount
        
        strokePipelineDescriptor.colorAttachments[1].pixelFormat = .bgra8Unorm
        strokePipelineDescriptor.colorAttachments[1].writeMask = []
        strokePipelineDescriptor.vertexFunction = strokeTerminalVertexFunction
        guard let strokeTerminalPipelineState = try? device.makeRenderPipelineState(descriptor: strokePipelineDescriptor) else {
            preconditionFailure()
        }
        self.strokeTerminalPipelineState = strokeTerminalPipelineState
        
        strokePipelineDescriptor.vertexFunction = strokeInnerVertexFunction
        guard let strokeInnerPipelineState = try? device.makeRenderPipelineState(descriptor: strokePipelineDescriptor) else {
            preconditionFailure()
        }
        self.strokeInnerPipelineState = strokeInnerPipelineState
        
        let drawOffscreenPipelineDescriptor = MTLRenderPipelineDescriptor()
        drawOffscreenPipelineDescriptor.vertexFunction = quadVertexFunction
        
        drawOffscreenPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        drawOffscreenPipelineDescriptor.colorAttachments[0].writeMask = [.all]
        drawOffscreenPipelineDescriptor.colorAttachments[1].pixelFormat = .bgra8Unorm
        drawOffscreenPipelineDescriptor.colorAttachments[1].writeMask = []
        drawOffscreenPipelineDescriptor.rasterSampleCount = msaaSampleCount
        
        drawOffscreenPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        drawOffscreenPipelineDescriptor.colorAttachments[0].rgbBlendOperation = mergePipelineDescriptor.colorAttachments[0].rgbBlendOperation
        drawOffscreenPipelineDescriptor.colorAttachments[0].alphaBlendOperation = mergePipelineDescriptor.colorAttachments[0].alphaBlendOperation
        drawOffscreenPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = mergePipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor
        drawOffscreenPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = mergePipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor
        drawOffscreenPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = mergePipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor
        drawOffscreenPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = mergePipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor
        
        drawOffscreenPipelineDescriptor.fragmentFunction = quadOffscreenFragmentFunction
        guard let drawOffscreenPipelineState = try? device.makeRenderPipelineState(descriptor: drawOffscreenPipelineDescriptor) else {
            preconditionFailure()
        }
        self.drawOffscreenPipelineState = drawOffscreenPipelineState
        
        drawOffscreenPipelineDescriptor.fragmentFunction = quadOffscreenWithMaskFragmentFunction
        guard let drawOffscreenWithMaskPipelineState = try? device.makeRenderPipelineState(descriptor: drawOffscreenPipelineDescriptor) else {
            preconditionFailure()
        }
        self.drawOffscreenWithMaskPipelineState = drawOffscreenWithMaskPipelineState
    }
}

