//******************************************************************************
// Copyright 2019 Google LLC
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
/// concatenate(_:axis:into:
/// Join a sequence of arrays along an existing axis.
/// - Parameters:
///  - tensors: the tensors to concatenate. The tensors must have the same shape,
///    except in the dimension corresponding to axis (the first, by default).
///  - axis: The axis along which the tensors will be joined.
///  - into: the destination to place the result. The shape must be correct.
///
@differentiable(where E.Value: DifferentiableNumeric)
@inlinable public func concatenate<S,E>(
    _ tensors: [Tensor<S,E>],
    axis: Int = 0,
    into result: inout Tensor<S,E>
) {
    let axis = axis < 0 ? axis + S.rank : axis
    assert(tensors.count > 1)
    assert(result.shape == concatenatedShape(tensors,axis),
           "result shape does not match expected shape")
    
    var lower = S.zero
    for tensor in tensors {
        result[lower, lower &+ tensor.shape] = tensor
        lower[axis] += tensor.shape[axis]
    }
}

@differentiable(where E.Value: DifferentiableNumeric)
@inlinable public func concatenate<S,E>(
    _ tensors: [Tensor<S,E>],
    axis: Int = 0
) -> Tensor<S,E> {
    let axis = axis < 0 ? axis + S.rank : axis
    var result = withoutDerivative(
            at: Tensor<S,E>(shape: concatenatedShape(tensors,axis)))
    concatenate(tensors, axis: axis, into: &result)
    return result
}

@differentiable(where E.Value: DifferentiableNumeric)
@inlinable public func concatenate<S,E>(
    _ tensors: Tensor<S,E>...,
    axis: Int = 0
) -> Tensor<S,E> {
    concatenate(tensors, axis: axis)
}

public extension Tensor {
    @differentiable(where TensorElement.Value: DifferentiableNumeric)
    @inlinable func concatenated(
        with others: Self...,
        alongAxis axis: Int = 0
    ) -> Self {
        guard others.count > 1 else { return self }
        return SwiftRTCore.concatenate([self] + others, axis: axis)
    }
}

@inlinable public func concatenatedShape<S,E>(
    _ tensors: [Tensor<S,E>],
    _ axis: Int
) -> S {
    assert(axis >= 0)
    var shape = tensors[0].shape
    for i in 1..<tensors.count {
        shape[axis] += tensors[i].shape[axis]
    }
    return shape
}

//==============================================================================
// vjpConcat
@derivative(of: concatenate)
@inlinable func vjpConcat<S,E>(
    _ tensors: [Tensor<S,E>],
    axis: Int = 0,
    into result: inout Tensor<S,E>
) -> (value: (), pullback: (inout Tensor<S, E>.TangentVector)
        -> Array<Tensor<S,E>>.TangentVector)
{
    let shapes = tensors.map { $0.shape }
    func pullback(_ resultTangent: inout Tensor<S,E>.TangentVector)
    -> Array<Tensor<S, E>>.TangentVector
    {
        // Fill `tensorTangents` with slices of `resultTangent` of shape
        // `tensorShapes[0]`, `tensorShapes[1]`, etc.
        var tensorTangents: [Tensor<S,E>] = []
        var lower = S.zero
        for shape in shapes {
            let upper = lower &+ shape
            tensorTangents.append(resultTangent[lower, upper])
            lower[axis] += upper[axis]
        }

        // Set `resultTangent` to zero.
        // Note: We can't use `fill(_:with:)` because `resultTangent` aliases
        // `tensorTangents`.
        // TODO: track and fix
        // Note: https://bugs.swift.org/browse/TF-1250 will allow us to make
        // this pullback more efficient. How:
        // - Set the wrt parameters and results to
        //     @differentiable(wrt: (tensors), results: (result))
        // - This makes `resultTangent` not be inout, so we don't need to set
        //   it any more.
        resultTangent = Tensor(zeros: resultTangent.shape,
                               order: resultTangent.order)

        return Array.DifferentiableView(tensorTangents)
    }
    return (concatenate(tensors, axis: axis, into: &result), pullback)
}

//==============================================================================
/// copy
/// copies the elements from `source` to `destination`
/// - Parameter source: tensor to be copied
/// - Parameter destination: the tensor where the result will be written
@inlinable public func copy<S,E>(
    from source: Tensor<S,E>,
    to destination: inout Tensor<S,E>
) {
    currentQueue.copy(from: source, to: &destination)
}

//==============================================================================
/// delayQueue
/// adds a time delay into the current queue for testing purposes``
/// - Parameter interval: the number of seconds to delay
@inlinable public func delayQueue(atLeast interval: TimeInterval) {
    currentQueue.delay(interval)
}

//==============================================================================
// initializer extensions
@inlinable func fill<S,E>(
    randomUniform x: inout Tensor<S,E>,
    from lower: E.Value,
    to upper: E.Value,
    seed: RandomSeed
) where E.Value: BinaryFloatingPoint {
    currentQueue.fill(randomUniform: &x, lower, upper, seed)
}

//-------------------------------------
@inlinable func fill<S,E>(
    randomNormal x: inout Tensor<S,E>,
    mean: E.Value,
    std: E.Value,
    seed: RandomSeed
) where E.Value: BinaryFloatingPoint {
    currentQueue.fill(randomNormal: &x, mean, std, seed)
}

@inlinable func fill<S,E>(
    randomNormal x: inout Tensor<S,E>,
    mean: Tensor<S,E>,
    std: Tensor<S,E>,
    seed: RandomSeed
) where E.Value: BinaryFloatingPoint {
    currentQueue.fill(randomNormal: &x, mean, std, seed)
}

//-------------------------------------
@inlinable func fill<S,E>(
    randomTruncatedNormal x: inout Tensor<S,E>,
    mean: E.Value,
    std: E.Value,
    seed: RandomSeed
) where E.Value: BinaryFloatingPoint {
    currentQueue.fill(randomTruncatedNormal: &x, mean, std, seed)
}

@inlinable func fill<S,E>(
    randomTruncatedNormal x: inout Tensor<S,E>,
    mean: Tensor<S,E>,
    std: Tensor<S,E>,
    seed: RandomSeed
) where E.Value: BinaryFloatingPoint {
    currentQueue.fill(randomTruncatedNormal: &x, mean, std, seed)
}

//==============================================================================
/// fill<S,E>(x:value:
/// fills the view with the specified value
@inlinable public func fill<S, E: StorageElement>(
    _ out: inout Tensor<S,E>,
    with element: E.Value
) {
    currentQueue.fill(&out, with: element)
}

@inlinable public func fill<S,E>(
    _ out: inout Tensor<S,E>,
    from first: E.Value,
    to last: E.Value,
    by step: E.Value
) where E.Value: Numeric {
    currentQueue.fill(&out, from: first, to: last, by: step)
}

@inlinable public func fill<S,E: StorageElement>(
    _ out: inout Tensor<S,E>,
    with range: Range<Int>
) where E.Value: Numeric {
    fill(&out,
         from: E.Value(exactly: range.lowerBound)!,
         to: E.Value(exactly: range.upperBound - 1)!,
         by: E.Value(exactly: 1)!)
}


//==============================================================================
/// fillWithIndex
/// a convenience function to fill the tensor with index values from
/// `0..<count`. If a different range is desired, use `fill(with range:`
@inlinable func fillWithIndex<S,E>(
    _ x: inout Tensor<S,E>
) where E.Value: Comparable & Numeric {
    fill(&x, with: 0..<x.count)
}

//==============================================================================
/// replace(x:with:result:
/// fills the view with the specified value
@inlinable public func replace<S,E>(
    x: Tensor<S,E>,
    with y: Tensor<S,E>,
    where condition: Tensor<S,Bool>
) -> Tensor<S,E> {
    var result = Tensor(like: x)
    currentQueue.replace(x, y, condition, &result)
    return result
}
