//
//  ViewController.swift
//  metal-study
//
//  Created by idt on 2020/12/23.
//

import UIKit
import MetalKit
class ViewController: UIViewController {
    private let xTileN: Int = 12
    private let yTileN: Int = 16

    private let imageView = UIImageView.init(frame: UIScreen.main.bounds)

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.addSubview(imageView)

        guard let device = MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue() else {
            return
        }

        let renderTargetDesc = MTLRenderPassDescriptor()
        let colorAttachment = renderTargetDesc.colorAttachments[0]
        colorAttachment?.loadAction = MTLLoadAction.clear
        colorAttachment?.storeAction = MTLStoreAction.store
        colorAttachment?.clearColor = MTLClearColorMake(0, 0, 0, 1)

        //  顶点索引
        var index = 0
        var indices = [UInt32](repeating: 0, count: xTileN * yTileN * 2 * 3)
        for j in 0..<yTileN {
            for i in 0..<xTileN {
                let value: UInt32 = UInt32(0 + (xTileN + 1) * j + i)
                indices[index] = value
                indices[index + 1] = value + 1
                indices[index + 2] = value + (UInt32(xTileN) + 1) + 1
                indices[index + 3] = value
                indices[index + 4] = value + UInt32((xTileN + 1))
                indices[index + 5] = value + (UInt32(xTileN) + 1) + 1
                index += 6
            }
        }
        guard let indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * 4, options: .storageModeShared) else {
            return
        }

        //  pipelineState
//        let bundle = Bundle.init(for: self.classForCoder)
//        let metallibpath = bundle.url(forResource: "default", withExtension: "metallib")!
//        let library2 = device.makeLibrary(filepath: metallibpath.path)
        guard let library = device.makeDefaultLibrary(),
            let vertexFunc = library.makeFunction(name: "vertexShader"),
            let fragmentFunc = library.makeFunction(name: "fragmentShader") else {
            return
        }
        let pipelineDesc = MTLRenderPipelineDescriptor.init()
        pipelineDesc.label = "pipeline 1"
        pipelineDesc.vertexFunction = vertexFunc
        pipelineDesc.fragmentFunction = fragmentFunc
        pipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        let renderPipelineState: MTLRenderPipelineState
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDesc)
        } catch {
            print(error.localizedDescription)
            return
        }

        //  创建目标空纹理
        let targetTextDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(view.bounds.width),
            height: Int(view.bounds.height),
            mipmapped: false)
        targetTextDesc.usage = MTLTextureUsage.init(rawValue: MTLTextureUsage.shaderRead.rawValue | MTLTextureUsage.renderTarget.rawValue)
        guard let targetTexture = device.makeTexture(descriptor: targetTextDesc) else {
            return
        }
        
        //  load Texture
        let texture: MTLTexture
        do {
            let loader = MTKTextureLoader.init(device: device)
            let image = UIImage.init(named: "aa.jpg")!
            let options = [
                MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
                MTKTextureLoader.Option.SRGB: false
            ]
            texture = try loader.newTexture(cgImage: image.cgImage!, options: options)
        } catch {
            print(error.localizedDescription)
            return
        }

        //  创建顶点坐标、纹理坐标
        var position = [Float].init(repeating: 0, count: (xTileN + 1) * (yTileN + 1) * 2)
        var texturePosition = [Float].init(repeating: 0, count: (xTileN + 1) * (yTileN + 1) * 2)
        index = 0
        for i in 0...yTileN {
            let y: Float = -1 + (2.0 / Float.init(yTileN)) * Float(i)
            let texY: Float = 0 + (1.0 / Float.init(yTileN)) * Float(i)
            for j in 0...xTileN {
                let x: Float = -1 + (2.0 / Float.init(xTileN)) * Float(j)
                let texX: Float = 0 + (1.0 / Float.init(xTileN)) * Float(j)

                position[index] = x
                position[index + 1] = y

                texturePosition[index] = texX
                texturePosition[index + 1] = texY

                index += 2
            }
        }

        //  render
        renderTargetDesc.colorAttachments[0].texture = targetTexture
        guard let commandBuffer = queue.makeCommandBuffer() else {
            return
        }
        commandBuffer.label = "Command Buffer"

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderTargetDesc) else {
            return
        }
        encoder.label = "Command Encoder"
        encoder.setViewport(
            MTLViewport.init(
                originX: 0,
                originY: 0,
                width: Double(view.bounds.width),
                height: Double(view.bounds.height),
                znear: 0,
                zfar: 1))


        encoder.setRenderPipelineState(renderPipelineState)

        encoder.setVertexBytes(position, length: position.count * 4, index: 0)
        encoder.setVertexBytes(texturePosition, length: texturePosition.count * 4, index: 1)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: indices.count,
            indexType: .uint32, indexBuffer: indexBuffer, indexBufferOffset: 0)

        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        //  create Image
        toImage(texture: targetTexture)
    }

    private func toImage(texture: MTLTexture) {
        //  适配iPhone 5s
        if UIScreen.main.bounds.height == 568 {
            let bytesPerPixel = 4
            let imageByteCount = texture.width * texture.height * bytesPerPixel
            let bytesPerRow = texture.width * bytesPerPixel
            var src = [UInt8].init(repeating: 0, count: imageByteCount)
            let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
            texture.getBytes(&src, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let ctx = CGContext.init(
                data: &src,
                width: texture.width,
                height: texture.height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Little.rawValue
                        | CGImageAlphaInfo.noneSkipFirst.rawValue)).rawValue)

            let cgImage = (ctx?.makeImage())!
            UIGraphicsBeginImageContext(CGSize.init(width: cgImage.width, height: cgImage.height))
            let context = UIGraphicsGetCurrentContext()
            context?.draw(cgImage, in: CGRect.init(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
            let newCGImage = context?.makeImage()
            UIGraphicsEndImageContext()
            let image = UIImage.init(cgImage: newCGImage!)
            imageView.image = image
        } else {
            let ciImage = CIImage.init(mtlTexture: texture, options: [CIImageOption.colorSpace: CGColorSpaceCreateDeviceRGB()])!
            let ciContext = CIContext.init()
            let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)
            let image = UIImage.init(cgImage: cgImage!)
            imageView.image = image
        }
    }
}

