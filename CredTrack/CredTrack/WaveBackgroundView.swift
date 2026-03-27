import MetalKit
import SwiftUI

struct WaveBackgroundView: UIViewRepresentable {

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = context.coordinator.device
        view.delegate = context.coordinator
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.framebufferOnly = true
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MTKViewDelegate {

        let device: MTLDevice
        private let commandQueue: MTLCommandQueue
        private let pipelineState: MTLRenderPipelineState
        private let startTime = Date()

        private struct Uniforms {
            var resolution: SIMD2<Float>
            var time: Float
            var xScale: Float
            var yScale: Float
            var distortion: Float
        }

        override init() {
            guard
                let dev = MTLCreateSystemDefaultDevice(),
                let queue = dev.makeCommandQueue(),
                let library = dev.makeDefaultLibrary()
            else {
                fatalError("Metal is not available on this device")
            }

            device = dev
            commandQueue = queue

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "waveVertex")
            descriptor.fragmentFunction = library.makeFunction(name: "waveFragment")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            pipelineState = try! dev.makeRenderPipelineState(descriptor: descriptor)
            super.init()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard
                let drawable = view.currentDrawable,
                let passDesc = view.currentRenderPassDescriptor,
                let cmdBuffer = commandQueue.makeCommandBuffer(),
                let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: passDesc)
            else { return }

            let size = view.drawableSize
            var uniforms = Uniforms(
                resolution: SIMD2<Float>(Float(size.width), Float(size.height)),
                time: Float(Date().timeIntervalSince(startTime)),
                xScale: 1.0,
                yScale: 0.5,
                distortion: 0.05
            )

            encoder.setRenderPipelineState(pipelineState)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()

            cmdBuffer.present(drawable)
            cmdBuffer.commit()
        }
    }
}
