//
//  ReactiveCocoa+Extensions.swift
//  ReactiveSearcher
//
//  Created by Murillo Nicacio de Maraes on 6/16/15.
//  Copyright (c) 2015 SuperUnreasonable. All rights reserved.
//

import Foundation
import ReactiveCocoa
import Result
import Box

/// Returns a new signal that reports events from both signals
/// Warning: May execute Signals side effects even after disposal. DO NOT apply to Signals with side effects.
public func mergedWith<T, E>(signal: Signal<T, E>)(original: Signal<T, E>) -> Signal<T, E> {
    let (newSignal, sink) = Signal<T, E>.pipe()

    signal |> observe(sink)
    original |> observe(sink)

    return newSignal
}

/// Useful for Transforming Error Events into Next Events.
public func mapResult<T, U, E: ErrorType>(transform: Result<T, E> -> U)(signal: Signal<T, E>) -> Signal<U, NoError> {
    return signal
        |> materialize
        |> map { (event: Event<T, E>) -> Event<U, NoError> in
            switch event {
            case .Next(let box):
                return .Next(box.map { transform(Result(value: $0)) })
            case .Error(let box):
                return .Next(box.map { transform(Result(error: $0)) })
            case .Completed:
                return .Completed
            case .Interrupted:
                return .Interrupted
            }
        }
        |> dematerialize
}


/// Completes without sending Error Events.
public func ignoreErrors<T, E: ErrorType>(signal: Signal<T, E>) -> Signal<T, NoError> {
    return signal |> mapResult { $0.value } |> ignoreNil
}

/// Zips Signals together but only sends updates when `signal` does
public func combineSampled<T, U, E: ErrorType>(signal: Signal<T, E>)(original: Signal<U, E>) -> Signal<(U, T), E> {
    return Signal { sink in
        let property = MutableProperty<T?>(nil)

        let signalDisposable = property <~ signal |> mapResult { $0.value } |> ignoreNil

        let originalDisposable = original
            |> map { ($0, property.value) }
            |> filter { $1 != nil }
            |> map { ($0, $1!) }
            |> observe(sink)

        let composite = CompositeDisposable([signalDisposable])

        if let originalDisposable = originalDisposable {
            composite.addDisposable(originalDisposable)
        }

        return composite
    }
}