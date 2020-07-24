/* Copyright 2018 The KrakenCL Authors. All Rights Reserved.
 
 Created by Volodymyr Pavliukevych
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation
import ClibPNG

public typealias Pixel = UInt8

public enum LibPNGError: Error {
    case writeError
    case readError
    case incorrectDataSize
    case canNotComputeMaxValue
    case canNotComputeMinValue
}

public enum ColorType: Int32, RawRepresentable {
    
    case greyscale
    case greyscaleAlpha
    case rgb
    case rgba
    
    public var rawValue: Int32 {
        switch self {
        case .greyscale:
            return PNG_COLOR_TYPE_GRAY
        case .greyscaleAlpha:
            return PNG_COLOR_TYPE_GRAY_ALPHA
        case .rgb:
            return PNG_COLOR_TYPE_RGB
        case .rgba:
            return PNG_COLOR_TYPE_RGBA
        }
    }
    
    public var components: Int {
        switch self {
        case .greyscale:
            return 1
        case .greyscaleAlpha:
            return 2
        case .rgb:
            return 3
        case .rgba:
            return 4
        }
    }
}

public func encode(image: UnsafeBufferPointer<UInt8>, width: Int, height: Int, bitDepth: Int, colorType: ColorType) -> Data? {
  var imageData = Data()

  guard let ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, nil, nil, nil) else {
      return nil
  }
  
  let info_ptr = png_create_info_struct(ptr)
  png_set_IHDR(ptr,
                info_ptr,
                png_uint_32(width),
                png_uint_32(height),
                Int32(bitDepth),
                colorType.rawValue,
                PNG_INTERLACE_NONE,
                PNG_COMPRESSION_TYPE_DEFAULT,
                PNG_FILTER_TYPE_DEFAULT)
  
  png_set_write_fn(ptr, &imageData, { (pngPointer, data, length) in
      guard let container: UnsafeMutableRawPointer = png_get_io_ptr(pngPointer) else { return }
      guard let data = data else { return }
      
      let dataContainer = container.assumingMemoryBound(to: Data.self)
      dataContainer.pointee.append(data, count: length)
  }, nil)
  png_write_info(ptr, info_ptr)
  //        png_write_png(ptr, info_ptr, PNG_TRANSFORM_IDENTITY, nil)
  

  let pixels = image.baseAddress!
  let rowWidth = width * colorType.components
  for rowOffset in stride(from: 0, to: height * rowWidth, by: rowWidth) {
      png_write_row(ptr, pixels + rowOffset)
  }

  png_write_end(ptr, nil);
  return imageData
}

public class Image {
    
    var width: Int
    var height: Int
    var colorType: ColorType
    var bitDepth: Int
    var pixels: [Pixel]
    
    public convenience init<P: BinaryInteger>(width: Int, height: Int, colorType: ColorType, bitDepth: Int = 8, badColor: UInt8 = 0, pixelValues: [P]) throws {
        guard let maxPixelValue = pixelValues.max() else {
            throw LibPNGError.canNotComputeMaxValue
        }
        // Normalization
        var result = [Pixel]()
        pixelValues.forEach { (value) in
            let pixel = P(255) * value / maxPixelValue
            result.append(pixel > 255 ? 255 : UInt8(pixel))
        }
        
        try self.init(width: width, height: height, colorType: colorType, bitDepth: bitDepth, pixels: result)
    }
    
    public convenience init<P: BinaryFloatingPoint>(width: Int, height: Int, colorType: ColorType, bitDepth: Int = 8, badColor: UInt8 = 0, pixelValues: [P]) throws {
        var pixelValues = pixelValues
        let badPixelIndexes = pixelValues.enumerated().filter { $0.element.isNaN || $0.element.isInfinite }.map { $0.offset }
        
        var tmpArray = pixelValues
        for index in badPixelIndexes.reversed() {
            tmpArray.remove(at: index)
        }
        guard let maxPixelValue = tmpArray.max() else {
            throw LibPNGError.canNotComputeMaxValue
        }
        
        guard let minPixelValue = tmpArray.min() else {
            throw LibPNGError.canNotComputeMaxValue
        }
        
        if badPixelIndexes.count != 0 {
            for index in badPixelIndexes {
                let value = P(badColor) / P(255) * ((maxPixelValue - minPixelValue) - minPixelValue)
                pixelValues[index] = value
            }
        }
        
        // Normalization
        var result = [Pixel]()
        pixelValues.forEach { (value) in
            let pixel = P(255) * ((value - minPixelValue) / (maxPixelValue - minPixelValue))
            result.append(pixel > 255.0 ? 255 : UInt8(pixel))
        }
        
        try self.init(width: width, height: height, colorType: colorType, bitDepth: bitDepth, pixels: result)
    }
    
    public init(width: Int, height: Int, colorType: ColorType, bitDepth: Int, pixels: [Pixel]) throws {
        
        guard pixels.count == height * width * colorType.components else {
            throw LibPNGError.incorrectDataSize
        }
        
        self.width = width
        self.height = height
        self.colorType = colorType
        self.bitDepth = bitDepth
        self.pixels = pixels
        
    }
    
    public lazy var data: Data? = { 
      return pixels.withUnsafeBufferPointer {
        return encode(image: $0, width:self.width, height: self.height, bitDepth: self.bitDepth, colorType: self.colorType)
      }
    }()
}

extension Image {
  public func write(to url: URL) throws {
    guard let data = self.data else {
      throw LibPNGError.writeError
    }
    try data.write(to: url)
  }
}