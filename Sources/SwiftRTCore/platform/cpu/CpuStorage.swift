//******************************************************************************
// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

//==============================================================================
/// SyncStorage
/// A synchronous host memory element storage buffer
public final class CpuStorage<Element>: StorageBuffer
{
    public let count: Int
    public let hostBuffer: UnsafeMutableBufferPointer<Element>
    public let id: Int
    public let isReadOnly: Bool
    public let isReference: Bool
    public var name: String
    public var element: Element
    
    //--------------------------------------------------------------------------
    // init(count:
    @inlinable public init(count: Int) {
        self.count = count
        self.hostBuffer = UnsafeMutableBufferPointer.allocate(capacity: count)
        self.id = Context.nextBufferId
        self.isReadOnly = false
        self.isReference = false
        self.name = "Tensor"
        self.element = hostBuffer[0]

        #if DEBUG
        diagnostic("\(createString) \(diagnosticName) " +
            "\(Element.self)[\(count)]", categories: .dataAlloc)
        #endif
    }

    //--------------------------------------------------------------------------
    // init(element:
    @inlinable public init(single element: Element) {
        self.count = 1
        self.element = element
        self.id = Context.nextBufferId
        self.isReadOnly = false
        self.isReference = true
        self.name = "Tensor"

        // point buffer to `element` member variable
        // this should be safe since this is a class
        let p = withUnsafeMutablePointer(to: &self.element) { $0 }
        self.hostBuffer = UnsafeMutableBufferPointer(start: p, count: 1)

        #if DEBUG
        diagnostic("\(createString) \(diagnosticName) " +
            "\(Element.self)[1]", categories: .dataAlloc)
        #endif
    }

    //--------------------------------------------------------------------------
    // init(other:
    @inlinable public init(copying other: CpuStorage) {
        self.count = other.count
        self.id = other.id
        self.isReadOnly = other.isReadOnly
        self.isReference = other.isReference
        self.name = other.name
        if isReference {
            hostBuffer = other.hostBuffer
        } else {
            hostBuffer = UnsafeMutableBufferPointer
                .allocate(capacity: other.hostBuffer.count)
            _ = hostBuffer.initialize(from: other.hostBuffer)
        }
        element = hostBuffer[0]
    }

    //--------------------------------------------------------------------------
    // init(buffer:
    @inlinable public init(referenceTo buffer: UnsafeBufferPointer<Element>) {
        self.count = buffer.count
        self.hostBuffer = UnsafeMutableBufferPointer(mutating: buffer)
        self.id = Context.nextBufferId
        self.isReadOnly = true
        self.isReference = true
        self.name = "Tensor"
        self.element = hostBuffer[0]

        #if DEBUG
        diagnostic("\(createString) Reference \(diagnosticName) " +
            "\(Element.self)[\(hostBuffer.count)]", categories: .dataAlloc)
        #endif
    }
    
    //--------------------------------------------------------------------------
    // init(buffer:
    @inlinable
    public init(referenceTo buffer: UnsafeMutableBufferPointer<Element>)
    {
        self.count = buffer.count
        self.hostBuffer = buffer
        self.id = Context.nextBufferId
        self.isReadOnly = false
        self.isReference = true
        self.name = "Tensor"
        self.element = hostBuffer[0]

        #if DEBUG
        diagnostic("\(createString) Reference \(diagnosticName) " +
            "\(Element.self)[\(hostBuffer.count)]", categories: .dataAlloc)
        #endif
    }
    
    //--------------------------------------------------------------------------
    // streaming
    @inlinable
    public init<S, Stream>(block shape: S, bufferedBlocks: Int, stream: Stream)
        where S: TensorShape, Stream: BufferStream
    {
        fatalError()
    }
    
    //--------------------------------------------------------------------------
    // deinit
    @inlinable
    deinit {
        if !isReference {
            hostBuffer.deallocate()
            #if DEBUG
            diagnostic("\(releaseString) \(diagnosticName) ",
                categories: .dataAlloc)
            #endif
        }
    }
    
    @inlinable
    public func element(at offset: Int) -> Element {
        hostBuffer[offset]
    }
    
    @inlinable
    public func setElement(value: Element, at offset: Int) {
        hostBuffer[offset] = value
    }
    
    //--------------------------------------------------------------------------
    // read
    @inlinable
    public func read(at offset: Int, count: Int) -> UnsafeBufferPointer<Element>
    {
        let start = hostBuffer.baseAddress!.advanced(by: offset)
        return UnsafeBufferPointer(start: start, count: count)
    }
    
    //--------------------------------------------------------------------------
    // read
    @inlinable
    public func read(at offset: Int, count: Int,
                     using queue: PlatformType.Device.Queue)
        -> UnsafeBufferPointer<Element>
    {
        let start = hostBuffer.baseAddress!.advanced(by: offset)
        return UnsafeBufferPointer(start: start, count: count)
    }
    
    //--------------------------------------------------------------------------
    // readWrite
    @inlinable
    public func readWrite(at offset: Int, count: Int)
        -> UnsafeMutableBufferPointer<Element>
    {
        let start = hostBuffer.baseAddress!.advanced(by: offset)
        return UnsafeMutableBufferPointer(start: start, count: count)
    }
    
    //--------------------------------------------------------------------------
    // readWrite
    @inlinable
    public func readWrite(at offset: Int, count: Int, willOverwrite: Bool,
                          using queue: PlatformType.Device.Queue)
        -> UnsafeMutableBufferPointer<Element>
    {
        let start = hostBuffer.baseAddress!.advanced(by: offset)
        return UnsafeMutableBufferPointer(start: start, count: count)
    }
}

