//
//  UIKitExtension.swift
//  HiApp
//
//  Created by Murillo Nicacio de Maraes on 6/19/15.
//  Copyright (c) 2015 Hi. All rights reserved.
//

import UIKit
import ReactiveCocoa

private func getRootController() -> UIViewController {
    return UIApplication.sharedApplication().keyWindow!.rootViewController!
}

//MARK: Inspectable
public extension UIView {
    @IBInspectable public var cornerRadius: CGFloat {
        get {
            return self.layer.cornerRadius
        } set {
            layer.cornerRadius = newValue
        }
    }

    @IBInspectable public var borderWidth: CGFloat {
        get {
            return self.layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }

    @IBInspectable public var borderColor: UIColor! {
        get {
            return UIColor(CGColor: layer.borderColor)
        }
        set {
            layer.borderColor = newValue.CGColor
        }
    }

    @IBInspectable public var showsShadow: Bool {
        get {
            return layer.shadowOpacity > 0.0
        } set {
            layer.shadowOffset = CGSize(width: -1.0, height: 1.0)
            layer.shadowRadius = 1.0
            layer.shadowOpacity = newValue ? 0.3 : 0.0
            layer.masksToBounds = false
        }
    }
}

enum AnimationError: ErrorType {
    case AnimationIncomplete

    var nsError: NSError {
        return NSError(domain: "Animation Error: ",
            code: 322,
            userInfo: [NSLocalizedDescriptionKey: "Animation Incomplete"])
    }
}

//MARK: NSObject
public extension NSObject {
    public func willDeallocSignal() -> SignalProducer<(), NoError> {
        return self.rac_willDeallocSignal().toSignalProducer()
            |> ignoreErrors
            |> map { _ in }
    }
}

//MARK: UIView
extension UIView {
    static func prepareTransition(fromView: UIView,
        toView: UIView,
        withOption options: UIViewAnimationOptions,
        andDuration duration: NSTimeInterval = 0.6) -> SignalProducer<(), AnimationError> {

            return SignalProducer { sink, disposable in

                UIView.transitionFromView(fromView,
                    toView: toView,
                    duration: duration,
                    options: options) { completed in

                        if !completed {
                            sendError(sink, .AnimationIncomplete)
                        } else {
                            sendNext(sink, ())
                            sendCompleted(sink)
                        }
                }
            }
    }

}

//MARK: UIControl
public extension UIControl {
    public func controlSignal<T>(events: UIControlEvents = .AllEvents) -> Signal<T, NoError> {
        let (signal, sink) = Signal<T, NoError>.pipe()

        self.rac_signalForControlEvents(events).toSignalProducer()
            |> ignoreErrors
            |> map { $0 as? T }
            |> ignoreNil
            |> takeUntil(self.willDeallocSignal())
            |> start(sink)

        return signal
    }

    public func emptyControlSignal(events: UIControlEvents = .AllEvents) -> Signal<Void, NoError> {
        let (signal, sink) = Signal<Void, NoError>.pipe()

        self.rac_signalForControlEvents(events).toSignalProducer()
            |> ignoreErrors
            |> map { _ in return () }
            |> takeUntil(self.willDeallocSignal())
            |> start(sink)

        return signal
    }
}

public extension UIButton {
    public func actionSignal() -> Signal<Void, NoError> {
        return self.emptyControlSignal(events: .TouchUpInside)
    }

    public func outputSignal<T>(output: T) -> Signal<T, NoError> {
        return self.emptyControlSignal(events: .TouchUpInside) |> map { _ in output }
    }
}

public extension UITextField {
    public func textSignal() -> Signal<String, NoError> {
        let (signal, sink) = Signal<String, NoError>.pipe()

        self.rac_textSignal().toSignalProducer()
            |> ignoreErrors
            |> map { $0 as? String ?? "" }
            |> takeUntil(self.willDeallocSignal())
            |> start(sink)

        return signal
    }
}

public extension UITextView {
    public func textSignal() -> Signal<String, NoError> {
        let (signal, sink) = Signal<String, NoError>.pipe()

        self.rac_textSignal().toSignalProducer()
            |> ignoreErrors
            |> map { $0 as? String ?? "" }
            |> takeUntil(self.willDeallocSignal())
            |> start(sink)

        return signal
    }
}

public extension UIScrollView {
    public func offsetSignal() -> Signal<CGPoint, NoError> {
        let (signal, sink) = Signal<CGPoint, NoError>.pipe()

        self.rac_valuesForKeyPath("contentOffset", observer: self).toSignalProducer()
            |> ignoreErrors
            |> map { $0 as? NSValue }
            |> ignoreNil
            |> map { $0.CGPointValue() }
            |> takeUntil(self.willDeallocSignal())
            |> start(sink)

        return signal
    }
}

//MARK: User Prompting
public extension UIAlertController {
    
}