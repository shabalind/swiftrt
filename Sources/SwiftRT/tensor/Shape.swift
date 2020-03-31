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
import Foundation

//==============================================================================
// Shapes
public typealias Shape1 = SIMD1<Int>
public typealias Shape2 = SIMD2<Int>
public typealias Shape3 = SIMD3<Int>
public typealias Shape4 = SIMD4<Int>
public typealias Shape5 = SIMD5<Int>
public typealias Shape6 = SIMD6<Int>

//==============================================================================
// messages
@usableFromInline
let _messageInvalidShape = "shape dimensions must be greater than 0"

//==============================================================================
// TensorShape
public protocol TensorShape: SIMD where Scalar == Int {
    // a ranked tuple convenience type used for api parameters
    associatedtype Tuple
    
    /// conversion to DeviceIndex to support drivers
    var asDeviceIndex: [DeviceIndex] { get }
    /// the number of bounding dimensions
    static var rank: Int { get }
    /// a tuple of ones
    static var oneTuple: Tuple { get }
    /// a tuple of zeros
    static var zeroTuple: Tuple { get }

    //---------------------------------
    // initializers
    init(_ shape: Tuple)
    init?(_ shape: Tuple?)

    //---------------------------------
    /// - Returns: the number of elements described by the bounded space,
    /// which is the product of the dimensions
    func elementCount() -> Int

    /// used to iterate the n-dimensional range `lower..<upper` as
    /// a linear sequence of positions in spatial order
    /// - Parameters:
    ///  - lower: the lower bound of the iteration range
    ///  - upper: the upper bound of the iteration range
    func incremented(between lower: Self, and upper: Self) -> Self
    
    /// - Returns: row major sequential srtides for the shape
    func sequentialStrides() -> Self
}

//==============================================================================
// TensorShape extensions
public extension TensorShape {
    /// init with optional tuple shape
    @inlinable @_transparent
    init?(_ shape: Tuple?) {
        guard let shape = shape else { return nil }
        self.init(shape)
    }

    /// instance member access
    @inlinable @_transparent
    var count: Int { Self.rank }
    
    /// conversion to DeviceIndex array to support marshalling to drivers
    @inlinable @_transparent
    var asDeviceIndex: [DeviceIndex] {
        var index = [DeviceIndex]()
        indices.forEach { index.append(DeviceIndex(self[$0])) }
        return index
    }

    /// helper
    @inlinable @_transparent
    mutating func swapAt(_ a: Int, _ b: Int) {
        let tmp = self[a]
        self[a] = self[b]
        self[b] = tmp
    }
    
    // generic n-dimensional position increment function
    @inlinable
    func incremented(between lower: Self, and upper: Self) -> Self {
        var next = self
        var dim = Self.rank - 1
        while true {
            next[dim] += 1
            if next[dim] < upper[dim] {
                break
            } else if dim > 0 {
                next[dim] = lower[dim]
                dim -= 1
            } else {
                break
            }
        }
        return next
    }
    
    //--------------------------------------------------------------------------
    /// `reduce`
    @inlinable
    func reduce(
        into initialResult: Scalar,
        _ updateAccumulatingResult: (inout Scalar, Scalar) -> ()) -> Scalar
    {
        indices.reduce(into: initialResult) {
            updateAccumulatingResult(&$0, self[$1])
        }
    }

    @inlinable
    func elementCount() -> Int {
        self.reduce(into: 1, *=)
    }
    
    @inlinable func linearIndex(with strides: Self) -> Int {
        (self &* strides).wrappedSum()
    }
    
    @inlinable func spanCount(with strides: Self) -> Int {
        ((self &- 1) &* strides).wrappedSum() + 1
    }
    
    //--------------------------------------------------------------------------
    /// `sequentialStrides`
    /// computes the row major sequential strides
    @inlinable
    func sequentialStrides() -> Self {
        var strides = Self.one
        for i in stride(from: Self.rank - 1, through: 1, by: -1) {
            strides[i - 1] = self[i] * strides[i]
        }
        return strides
    }
}

//==============================================================================
// SIMD1
extension SIMD1: TensorShape where Scalar == Int {
    //--------------------------------------------------------------------------
    // tuple initialization support
    public typealias Tuple = (Scalar)
    public static var oneTuple: Tuple { (1) }
    public static var zeroTuple: Tuple { (0) }

    @inlinable @_transparent
    public init(_ shape: Tuple) {
        self.init()
        self[0] = shape
    }

    //--------------------------------------------------------------------------
    @inlinable @_transparent
    public static var rank: Int { 1 }
    
    @inlinable public func elementCount() -> Int {
        self[0]
    }
    
    @inlinable public func sequentialStrides() -> Self {
        Self(1)
    }
    
    @inlinable
    public func incremented(between lower: Self, and upper: Self) -> Self {
        assert(self[0] >= lower[0])
        var next = self
        next[0] += 1
        return next
    }
}

//==============================================================================
// SIMD2
extension SIMD2: TensorShape where Scalar == Int {
    //--------------------------------------------------------------------------
    // tuple initialization support
    public typealias Tuple = (Scalar, Scalar)
    public static var oneTuple: Tuple { (1, 1) }
    public static var zeroTuple: Tuple { (0, 0) }

    @inlinable @_transparent
    public init(_ shape: Tuple) {
        self.init()
        self[0] = shape.0
        self[1] = shape.1
    }

    //--------------------------------------------------------------------------
    @inlinable @_transparent
    public static var rank: Int { 2 }
    
    @inlinable
    public func elementCount() -> Int {
        self[0] * self[1]
    }

    @inlinable
    public func sequentialStrides() -> Self {
        Self(self[1], 1)
    }

    @inlinable
    public func incremented(between lower: Self, and upper: Self) -> Self {
        assert(self[0] >= lower[0] && self[1] >= lower[1])
        var next = self
        next[1] += 1
        if next[1] == upper[1] {
            next[1] = lower[1]
            next[0] += 1
        }
        return next
    }
}

//==============================================================================
// SIMD3
extension SIMD3: TensorShape where Scalar == Int {
    //--------------------------------------------------------------------------
    // tuple initialization support
    public typealias Tuple = (Scalar, Scalar, Scalar)
    public static var oneTuple: Tuple { (1, 1, 1) }
    public static var zeroTuple: Tuple { (0, 0, 0) }

    @inlinable @_transparent
    public init(_ shape: Tuple) {
        self.init()
        self[0] = shape.0
        self[1] = shape.1
        self[2] = shape.2
    }

    //--------------------------------------------------------------------------
    @inlinable @_transparent
    public static var rank: Int { 3 }
    
    @inlinable
    public func incremented(between lower: Self, and upper: Self) -> Self {
        assert({for i in 0..<Self.rank { if self[i] < lower[i] { return false }}
            return true}())
        var next = self

        next[2] += 1
        if next[2] == upper[2] {
            next[2] = lower[2]
            next[1] += 1
            
            if next[1] == upper[1] {
                next[1] = lower[1]
                next[0] += 1
            }
        }
        return next
    }
}

//==============================================================================
// SIMD4
extension SIMD4: TensorShape where Scalar == Int {
    //--------------------------------------------------------------------------
    // tuple initialization support
    public typealias Tuple = (Scalar, Scalar, Scalar, Scalar)
    public static var oneTuple: Tuple { (1, 1, 1, 1) }
    public static var zeroTuple: Tuple { (0, 0, 0, 0) }

    @inlinable @_transparent
    public init(_ shape: Tuple) {
        self.init()
        self[0] = shape.0
        self[1] = shape.1
        self[2] = shape.2
        self[3] = shape.3
    }

    //--------------------------------------------------------------------------
    @inlinable @_transparent
    public static var rank: Int { 4 }

    @inlinable
    public func incremented(between lower: Self, and upper: Self) -> Self {
        assert({for i in 0..<Self.rank { if self[i] < lower[i] { return false }}
            return true}())
        var next = self

        next[3] += 1
        if next[3] == upper[3] {
            next[3] = lower[3]
            next[2] += 1
            
            if next[2] == upper[2] {
                next[2] = lower[2]
                next[1] += 1
                
                if next[1] == upper[1] {
                    next[1] = lower[1]
                    next[0] += 1
                }
            }
        }
        return next
    }
}

//==============================================================================
// SIMD5
extension SIMD5: TensorShape where Scalar == Int {
    //--------------------------------------------------------------------------
    // tuple initialization support
    public typealias Tuple = (Scalar, Scalar, Scalar, Scalar, Scalar)
    public static var oneTuple: Tuple { (1, 1, 1, 1, 1) }
    public static var zeroTuple: Tuple { (0, 0, 0, 0, 0) }

    @inlinable @_transparent
    public init(_ shape: Tuple) {
        self.init()
        self[0] = shape.0
        self[1] = shape.1
        self[2] = shape.2
        self[3] = shape.3
        self[4] = shape.4
    }

    //--------------------------------------------------------------------------
    @inlinable @_transparent
    public static var rank: Int { 5 }

    @inlinable
    public func incremented(between lower: Self, and upper: Self) -> Self {
        assert({for i in 0..<Self.rank { if self[i] < lower[i] { return false }}
            return true}())
        var next = self

        next[4] += 1
        if next[4] == upper[4] {
            next[4] = lower[4]
            next[3] += 1
            
            if next[3] == upper[3] {
                next[3] = lower[3]
                next[2] += 1
                
                if next[2] == upper[2] {
                    next[2] = lower[2]
                    next[1] += 1
                    
                    if next[1] == upper[1] {
                        next[1] = lower[1]
                        next[0] += 1
                    }
                }
            }
        }
        return next
    }
}

//==============================================================================
// SIMD6
extension SIMD6: TensorShape where Scalar == Int {
    //--------------------------------------------------------------------------
    // tuple initialization support
    public typealias Tuple = (Scalar, Scalar, Scalar, Scalar, Scalar, Scalar)
    public static var oneTuple: Tuple { (1, 1, 1, 1, 1, 1) }
    public static var zeroTuple: Tuple { (0, 0, 0, 0, 0, 0) }

    @inlinable @_transparent
    public init(_ shape: Tuple) {
        self.init()
        self[0] = shape.0
        self[1] = shape.1
        self[2] = shape.2
        self[3] = shape.3
        self[4] = shape.4
        self[5] = shape.5
    }

    //--------------------------------------------------------------------------
    @inlinable @_transparent
    public static var rank: Int { 6 }
    
    @inlinable
    public func incremented(between lower: Self, and upper: Self) -> Self {
        assert({for i in 0..<Self.rank { if self[i] < lower[i] { return false }}
            return true}())
        var next = self

        next[5] += 1
        if next[5] == upper[4] {
            next[5] = lower[5]
            next[4] += 1
            
            if next[4] == upper[4] {
                next[4] = lower[4]
                next[3] += 1
                
                if next[3] == upper[3] {
                    next[3] = lower[3]
                    next[2] += 1
                    
                    if next[2] == upper[2] {
                        next[2] = lower[2]
                        next[1] += 1
                        
                        if next[1] == upper[1] {
                            next[1] = lower[1]
                            next[0] += 1
                        }
                    }
                }
            }
        }
        return next
    }
}

//==============================================================================
// additional SIMD types to fill in range
// https://github.com/apple/swift/blob/master/stdlib/public/core/SIMDVectorTypes.swift.gyb
// This isn't actually used to do SIMD operations, but merely as
// a placeholder to satisfy Shape1 Bounds conformance
@frozen public struct SIMD1<Scalar>: SIMD where Scalar: SIMDScalar {
    public var _storage: Scalar.SIMD2Storage
    public typealias MaskStorage = SIMD1<Scalar.SIMDMaskScalar>
    
    /// The number of scalars in the vector.
    @_transparent
    public var scalarCount: Int { 1 }
    
    /// Creates a vector with zero in all lanes.
    @_transparent
    public init() {
        _storage = Scalar.SIMD2Storage()
    }
    
    @_transparent
    public init(_ v0: Scalar) {
        self.init()
        self[0] = v0
    }
    
    /// Accesses the scalar at the specified position.
    public subscript(index: Int) -> Scalar {
        @_transparent get {
            assert(indices.contains(index))
            return _storage[index]
        }
        @_transparent set {
            assert(indices.contains(index))
            _storage[index] = newValue
        }
    }

}

// to support 5D tensors
@frozen public struct SIMD5<Scalar>: SIMD where Scalar: SIMDScalar {
    public var _storage: Scalar.SIMD8Storage
    public typealias MaskStorage = SIMD5<Scalar.SIMDMaskScalar>
    
    /// The number of scalars in the vector.
    @_transparent
    public var scalarCount: Int { 5 }
    
    /// Creates a vector with zero in all lanes.
    @_transparent
    public init() {
        _storage = Scalar.SIMD8Storage()
    }

    @_transparent
    public init(_ v0: Scalar, _ v1: Scalar, _ v2: Scalar,
                _ v3: Scalar, _ v4: Scalar
    ) {
        self.init()
        self[0] = v0
        self[1] = v1
        self[2] = v2
        self[3] = v3
        self[4] = v4
    }
    
    /// Accesses the scalar at the specified position.
    public subscript(index: Int) -> Scalar {
        @_transparent get {
            assert(indices.contains(index))
            return _storage[index]
        }
        @_transparent set {
            assert(indices.contains(index))
            _storage[index] = newValue
        }
    }
}

// to support 6D tensors
@frozen public struct SIMD6<Scalar>: SIMD where Scalar: SIMDScalar {
    public var _storage: Scalar.SIMD8Storage
    public typealias MaskStorage = SIMD6<Scalar.SIMDMaskScalar>
    
    /// The number of scalars in the vector.
    @_transparent
    public var scalarCount: Int { 6 }
    
    /// Creates a vector with zero in all lanes.
    @_transparent
    public init() {
        _storage = Scalar.SIMD8Storage()
    }

    @_transparent
    public init(_ v0: Scalar, _ v1: Scalar, _ v2: Scalar, _ v3: Scalar,
                _ v4: Scalar, _ v5: Scalar
    ) {
        self.init()
        self[0] = v0
        self[1] = v1
        self[2] = v2
        self[3] = v3
        self[4] = v4
        self[5] = v5
    }
    
    /// Accesses the scalar at the specified position.
    public subscript(index: Int) -> Scalar {
        @_transparent get {
            assert(indices.contains(index))
            return _storage[index]
        }
        @_transparent set {
            assert(indices.contains(index))
            _storage[index] = newValue
        }
    }
}
