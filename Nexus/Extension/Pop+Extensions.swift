//
//  Pop+Extensions.swift
//  Hi
//
//  Created by Murillo Nicacio de Maraes on 5/15/15.
//  Copyright (c) 2015 HappeningIn. All rights reserved.
//

import UIKit
import ReactiveCocoa
import Box
import pop

enum BasicCurve {
    case Default
    case Linear
    case EaseIn
    case EaseOut
    case EaseInAndOut

    var animation: POPBasicAnimation {
        switch self {
        case .Default:
            return POPBasicAnimation.defaultAnimation()
        case .Linear:
            return POPBasicAnimation.linearAnimation()
        case .EaseIn:
            return POPBasicAnimation.easeInAnimation()
        case .EaseOut:
            return POPBasicAnimation.easeOutAnimation()
        case .EaseInAndOut:
            return POPBasicAnimation.easeInEaseOutAnimation()
        }
    }
}

protocol AnimationDescriptor {
    func animation() -> POPPropertyAnimation
}

struct BasicDescriptor: AnimationDescriptor {
    let duration: CGFloat
    let curve: BasicCurve

    init(duration: CGFloat = 0.4, curve: BasicCurve = .Default) {
        self.duration = duration
        self.curve = curve
    }

    func animation() -> POPPropertyAnimation {
        let animation = self.curve.animation
        animation.duration = CFTimeInterval(self.duration)

        return animation
    }
}

struct SpringDescriptor: AnimationDescriptor {
    let bounciness: CGFloat
    let speed: CGFloat

    init(bounciness: CGFloat = 4.0, speed: CGFloat = 12.0) {
        self.bounciness = bounciness
        self.speed = speed
    }

    func animation() -> POPPropertyAnimation {
        let animation = POPSpringAnimation()

        animation.springBounciness = self.bounciness
        animation.springSpeed = self.speed

        return animation
    }

}

struct DecayDescriptor: AnimationDescriptor {
    let deceleration: CGFloat

    init(deceleration: CGFloat = 0.998) {
        self.deceleration = deceleration
    }

    func animation() -> POPPropertyAnimation {
        let animation = POPDecayAnimation()

        animation.deceleration = self.deceleration

        return animation
    }
}

//MARK: Animation Enums
enum AnimationDescription {
    case Alpha(to: CGFloat, velocity: CGFloat?)
    case Center(to: CGPoint, velocity: CGPoint?)
    case Bounds(to: CGRect, velocity: CGRect?)
    case Frame(to: CGRect, velocity: CGRect?)

    var name: String {
        switch self {
        case .Alpha(_):
            return kPOPViewAlpha
        case .Center(_):
            return kPOPViewCenter
        case .Bounds(_):
            return kPOPViewBounds
        case .Frame(_):
            return kPOPViewFrame
        }
    }

    var key: String {
        return self.name
    }

    var animatableProperty: POPAnimatableProperty {
        return POPAnimatableProperty.propertyWithName(self.name) as! POPAnimatableProperty
    }

    var toValue: AnyObject {
        switch self {
        case let .Alpha(to, _):
            return to
        case let .Center(to, _):
            return NSValue(CGPoint: to)
        case let .Bounds(to, _):
            return NSValue(CGRect: to)
        case let .Frame(to, _):
            return NSValue(CGRect: to)
        }
    }

    var velocity: AnyObject? {
        switch self {
        case let .Alpha(_, velocity) where velocity != nil:
            return velocity!
        case let .Center(_, velocity) where velocity != nil:
            return NSValue(CGPoint: velocity!)
        case let .Bounds(_, velocity) where velocity != nil:
            return NSValue(CGRect: velocity!)
        case let .Frame(_, velocity) where velocity != nil:
            return NSValue(CGRect: velocity!)
        default:
            return nil
        }
    }
}

public extension UIView {
    public func animateAlpha(to: Double) -> POPBasicAnimation {
        return UIView.animateObject(self, property: kPOPViewAlpha, withKey: "alpha", toValue: to)
    }

    public func animateCenter(to: CGPoint) -> POPBasicAnimation {
        return UIView.animateObject(self, property: kPOPViewCenter, withKey: "center", toValue: NSValue(CGPoint: to))
    }

    public func animateBackgroundColor(to: UIColor) -> POPBasicAnimation {
        return UIView.animateObject(self,
            property: kPOPViewBackgroundColor,
            withKey: "backgroundColor",
            toValue: to)
    }

    public func animateBounds(to: CGRect) -> POPBasicAnimation {
        return UIView.animateObject(self,
            property: kPOPViewBounds,
            withKey: "size",
            toValue: NSValue(CGRect: to))
    }

    public func animateFrame(to: CGRect) -> POPBasicAnimation {
        return UIView.animateObject(self,
            property: kPOPViewFrame,
            withKey: "frame",
            toValue: NSValue(CGRect: to))
    }

    public func animateSquareSize(to: CGFloat) -> POPBasicAnimation {
        let rect = CGRect(x: self.bounds.origin.x, y: self.bounds.origin.y, width: to, height: to)

        return self.animateBounds(rect)
    }
    
    static func animateObject(view: UIView, property: String, withKey: String, toValue: AnyObject) -> POPBasicAnimation {
        var maybeAnimation = view.pop_animationForKey(withKey) as? POPBasicAnimation
        
        if let animation = maybeAnimation {
            animation.toValue = toValue
        } else {
            maybeAnimation = POPBasicAnimation.easeOutAnimation()
            maybeAnimation?.property = POPAnimatableProperty.propertyWithName(property) as! POPAnimatableProperty
            maybeAnimation?.toValue = toValue
            
            view.pop_addAnimation(maybeAnimation, forKey: withKey)
        }
        
        return maybeAnimation!
    }

    internal func animate(descriptor: AnimationDescriptor, description: AnimationDescription) -> SignalProducer<Void, NoError> {


        return SignalProducer { [weak self] sink, disposable in
            let preparedAnimation: POPPropertyAnimation
            let doneBlock: (POPAnimation!, Bool) -> () = { _, finished in
                sendNext(sink, ())
                sendCompleted(sink)
            }

            preparedAnimation = descriptor.animation()
            preparedAnimation.property = description.animatableProperty
            preparedAnimation.toValue = description.toValue

            if let spring = preparedAnimation as? POPSpringAnimation,
                velocity: AnyObject = description.velocity {
                    
                    spring.velocity = velocity
            } else if let decay = preparedAnimation as? POPDecayAnimation,
                velocity: AnyObject = description.velocity {

                    decay.velocity = description.velocity
            }

            preparedAnimation.completionBlock = doneBlock

            self?.pop_addAnimation(preparedAnimation, forKey: description.key)
            
        }

    }
}

