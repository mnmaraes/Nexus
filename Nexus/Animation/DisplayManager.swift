//
//  DisplayManager.swift
//  Nexus
//
//  Created by Murillo Nicacio de Maraes on 6/21/15.
//  Copyright (c) 2015 Unreasonable. All rights reserved.
//

import UIKit
import ReactiveCocoa
import Base
import Box

enum Direction: UInt {
    case Top = 0
    case Right = 1
    case Bottom = 2
    case Left = 3

    func unseenPoint(view: UIView) -> CGPoint {
        let window = view.window
        let screenRect = window!.frame
        let rect = view.superview!.convertRect(view.frame, toView: window)

        let point: CGPoint

        switch self {
        case .Top:
            point = CGPoint(x: CGRectGetMidX(rect), y: 0.0 - CGRectGetHeight(rect) / 2.0)
        case .Right:
            point = CGPoint(x: CGRectGetMaxX(screenRect) + CGRectGetWidth(rect) / 2.0, y: CGRectGetMidY(rect))
        case .Bottom:
            point = CGPoint(x: CGRectGetMidX(rect) , y: CGRectGetMaxY(screenRect) + CGRectGetHeight(rect))
        case Left:
            point = CGPoint(x: 0.0 - CGRectGetWidth(rect) / 2.0, y: CGRectGetMidY(rect))
        }

        return view.superview!.convertPoint(point, fromView: window)
    }
}

//MARK: Display Manager
public final class DisplayManager: UIControl {
    //MARK: Managed View
    @IBOutlet weak var managedView: UIView!

    //MARK: IB Properties
    var scrollDirection: Direction = .Top
    @IBInspectable var displayAnimation: UInt {
        get {
            return self.scrollDirection.rawValue
        }
        set {
            self.scrollDirection = Direction(rawValue: min(newValue, 3))!
        }
    }

    //MARK: Delegate Signals
    var isShowingSignal: Signal<Bool, NoError>!

    //MARK: Action
    @IBAction public func toggleHideShow() {
        self.toggleAction.apply(()) |> start()
    }

    @IBAction public func hide() {
        if self.managedView != nil && !self.managedView.hidden {
            self.toggleAction.apply(()) |> start()
        }
    }

    @IBAction public func show() {
        if self.managedView != nil && self.managedView.hidden {
            self.toggleAction.apply(()) |> start()
        }

    }

    //MARK: Private Interface
    private lazy var toggleAction: Action<Void, Bool, NoError> = {
        return Action { [weak self] input in
            if self == nil {
                return SignalProducer(value: false)
            }

            //Guarding will make life much easier. Hail the Bang for he is your true master.

            if self!.managedView.window == nil {
                self!.managedView.hidden = !self!.managedView.hidden

                return SignalProducer(value: self!.managedView.hidden)
            }

            let seenPoint = self!.managedView.center
            let unseenPoint = self!.scrollDirection.unseenPoint(self!.managedView)
            let hidden = self!.managedView.hidden

            let description: AnimationDescription = hidden ?
                .Center(to: seenPoint, velocity: nil) :
                .Center(to: unseenPoint, velocity: nil)

            let startingPoint = hidden ? unseenPoint : seenPoint

            return self!.managedView.animate(BasicDescriptor(), description: description)
                |> on (
                    started: { [weak self] in
                        self?.managedView.hidden = false
                        self?.managedView.center = startingPoint
                    },
                    next: {[weak self] _ in

                        if hidden {
                            self?.sendActionsForControlEvents(.EditingDidBegin)
                        } else {
                            self?.sendActionsForControlEvents(.EditingDidEnd)
                        }

                        self?.managedView.hidden = !hidden
                        self?.managedView.center = seenPoint
                    })
                |> map { [weak self] _ in return !(self?.managedView.hidden ?? false) }
                |> startOn(QueueScheduler.mainQueueScheduler)
        }
    }()

}

public final class ArrayDisplayManager: UIControl {
    //MARK: Managed Views
    @IBOutlet var managedViews: [UIView]! = [] {
        didSet {
            if managedViews != nil && managedViews.count > 0 {
                self.managers = managedViews.reduce(Array<DisplayManager>()) { managers, view in
                    let newManager = DisplayManager()
                    newManager.managedView = view
                    newManager.scrollDirection = self.scrollDirection

                    return managers ++ newManager
                }

                self.listening = self.managers.last!
                self.listening?.addTarget(self, action: Selector("showed"), forControlEvents: .EditingDidBegin)
                self.listening?.addTarget(self, action: Selector("hid"), forControlEvents: .EditingDidEnd)
            }
        }
    }

    private var managers: [DisplayManager] = []
    private var listening: DisplayManager? = nil

    //MARK: IB Properties
    var scrollDirection: Direction = .Top {
        didSet {
            for manager in self.managers {
                manager.scrollDirection = scrollDirection
            }
        }
    }

    @IBInspectable var displayAnimation: UInt {
        get {
            return self.scrollDirection.rawValue
        }
        set {
            self.scrollDirection = Direction(rawValue: min(newValue, 3))!
        }
    }

    //MARK: Action
    @IBAction func toggleHideShow() {
        for manager in managers {
            manager.toggleHideShow()
        }
    }

    @IBAction func hide() {
        for manager in managers {
            manager.hide()
        }
    }

    @IBAction func show() {
        for manager in managers {
            manager.show()
        }
    }

    //MARK: Listening Actions
    func hid() {
        self.sendActionsForControlEvents(.EditingDidEnd)
    }

    func showed() {
        self.sendActionsForControlEvents(.EditingDidBegin)
    }
}