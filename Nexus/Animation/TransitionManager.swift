//
//  TransitionManager.swift
//  Nexus
//
//  Created by Murillo Nicacio de Maraes on 6/21/15.
//  Copyright (c) 2015 Unreasonable. All rights reserved.
//

import UIKit
import ReactiveCocoa

//MARK: Transition Errors
public enum TransitionError: String, ErrorType {
    case ShowingViewNotFound = "Showing view not set."
    case HiddenViewNotFound = "Hidden view not set."
    case AnimationIncomplete = "Couldn't complete animation."

    public var nsError: NSError {
        return NSError(domain: "Flip Manager Error: ",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: self.rawValue])
    }
}

//MARK: Flip Manager
public final class TransitionManager: NSObject {
    //MARK: Managed Views
    @IBOutlet public weak var showingView: UIView!
    @IBOutlet public weak var hiddenView: UIView!

    //MARK: Properties
    @IBInspectable public var transitionAnimation: UInt {
        get {
            return self.animationOption.rawValue >> 20
        }
        set {
            self.animationOption = UIViewAnimationOptions(rawValue: min(newValue, 7) << 20)
        }
    }

    //MARK: Delegate Signals
    public var showingViewSignal: Signal<UIView, NoError> {
        return self.action.values
    }

    public var errorsSignal: Signal<TransitionError, NoError> {
        return self.action.errors
    }

    //MARK: Actions
    @IBAction public func toggleViewsAnimated()  {
        let input: (UIView?, UIView?) = (self.showingView, self.hiddenView)
        self.action.apply(input) |> start()
    }

    //MARK: Private Interface
    private var animationOption: UIViewAnimationOptions = .TransitionNone

    private lazy var action: Action<(UIView?, UIView?), UIView, TransitionError> = {
        return Action { [weak self] input in
            if input.0 == nil {
                return SignalProducer(error: .ShowingViewNotFound)
            }

            if input.1 == nil {
                return SignalProducer(error: .HiddenViewNotFound)
            }

            self?.showingView.endEditing(true)

            if let showingView = self?.showingView, hiddenView = self?.hiddenView, animationOption = self?.animationOption {
                return UIView.prepareTransition(showingView,
                    toView: hiddenView,
                    withOption: animationOption | .ShowHideTransitionViews)
                    |> on(next: {[weak self] _ in self?.switchViews() })
                    |> map {[weak self] _ in return self?.showingView }
                    |> ignoreNil
                    |> mapError { _ in return .AnimationIncomplete }
                    |> startOn(QueueScheduler.mainQueueScheduler)
            }

            return SignalProducer(error: .AnimationIncomplete)
        }
    }()

    private func switchViews() {
        let holder = self.showingView
        self.showingView = self.hiddenView
        self.hiddenView = holder
    }
}

public final class ConstraintTransitionManager: UIControl {
    //MARK: Managed Constraint
    @IBOutlet public weak var animatingView: UIView!
    @IBOutlet public weak var constraint: NSLayoutConstraint!

    //MARK: Properties
    @IBInspectable var compactValue: CGFloat = 0
    @IBInspectable var expandedValue: CGFloat = 8

    @IBInspectable var isExpanded: Bool = false

    //MARK: Action
    @IBAction public func toggleExpanded() {
        let toValue = self.isExpanded ? compactValue : expandedValue
        self.isExpanded = !self.isExpanded

        self.animateContraint(toValue)
    }

    @IBAction public func expand() {
        let toValue = expandedValue
        self.isExpanded = true

        self.animateContraint(toValue)
    }

    @IBAction public func contract() {
        let toValue = compactValue
        self.isExpanded = false

        self.animateContraint(toValue)
    }

    //MARK: Helper
    func animateContraint(value: CGFloat) {
        animatingView.layoutIfNeeded()
        constraint.constant = value
        UIView.animateWithDuration(0.6, animations: { self.animatingView.layoutIfNeeded() }) { _ in
            let event: UIControlEvents = self.isExpanded ? .EditingDidBegin : .EditingDidEnd
            self.sendActionsForControlEvents(event)
        }
    }
}

public final class ConstraintSwitchManager: UIControl {
    //MARK: Managed Constraint
    @IBOutlet public weak var animatingView: UIView!
    @IBOutlet public var expandedConstraintSet: [NSLayoutConstraint]!
    @IBOutlet public var compactConstraintSet: [NSLayoutConstraint]!

    //MARK: Properties
    @IBInspectable var isExpanded: Bool = false 

    //MARK: Action
    @IBAction public func toggleExpanded() {
        let activate = self.isExpanded ? compactConstraintSet : expandedConstraintSet
        let deactivate = self.isExpanded ? expandedConstraintSet : compactConstraintSet
        self.isExpanded = !self.isExpanded

        self.animateContraints(activate, deactivate: deactivate)
    }

    @IBAction public func expand() {
        self.isExpanded = true

        self.animateContraints(expandedConstraintSet, deactivate: compactConstraintSet)
    }

    @IBAction public func contract() {
        self.isExpanded = false

        self.animateContraints(compactConstraintSet, deactivate: expandedConstraintSet)
    }

    //MARK: Helper
    func animateContraints(activate: [NSLayoutConstraint], deactivate: [NSLayoutConstraint]) {
        animatingView.layoutIfNeeded()
        NSLayoutConstraint.deactivateConstraints(deactivate)
        NSLayoutConstraint.activateConstraints(activate)
        UIView.animateWithDuration(0.6, animations: { self.animatingView.layoutIfNeeded() }) { _ in
            let event: UIControlEvents = self.isExpanded ? .EditingDidBegin : .EditingDidEnd
            self.sendActionsForControlEvents(event)
        }
    }
}