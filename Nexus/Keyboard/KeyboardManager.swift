//
//  KeyboardManager.swift
//  Nexus
//
//  Created by Murillo Nicacio de Maraes on 6/21/15.
//  Copyright (c) 2015 Unreasonable. All rights reserved.
//

import UIKit
import ReactiveCocoa

class SimpleDismissManager: NSObject {
    //MARK: Managed View
    @IBOutlet weak var editingView: UIView?

    //MARK: Action
    @IBAction func dismiss() {
        editingView?.endEditing(true)
    }
}

class ScrollViewKeyboardManager: NSObject {
    //MARK: Managed View
    @IBOutlet weak var managedView: UIScrollView? {
        didSet {
            self.bottomInset = managedView?.contentInset.bottom ?? 0.0
        }
    }
    @IBOutlet weak var controller: UIViewController?

    var bottomInset: CGFloat = 0.0

    //MARK: Properties
    private var disposable: Disposable!

    //MARK: Set Up
    override func awakeFromNib() {
        let (showSignal, showDisposable) = NSNotificationCenter.defaultCenter().keyboardSignal()
        let (hideSignal, hideDisposable) = NSNotificationCenter.defaultCenter().keyboardWillHideSignal()

        showSignal
            |> map { $0.keyboardFrame.height }
            |> observe(next: { [weak self] next in
                if let weakSelf = self {
                    weakSelf.managedView?.contentInset.bottom = next - (weakSelf.controller?.bottomLayoutGuide.length ?? 0 )
                }
            })

        hideSignal
            |> observe(next: {[weak self] next in
                self?.managedView?.contentInset.bottom = 0.0
            })

        self.disposable = CompositeDisposable([showDisposable, hideDisposable])
    }

    deinit {
        disposable.dispose()
    }

}

class ConstraintKeyboardManager: NSObject {
    //MARK: Managed View
    @IBOutlet weak var managedView: UIView?
    @IBOutlet weak var managedConstraint: NSLayoutConstraint? {
        didSet {
            self.bottomInset = self.managedConstraint?.constant ?? 0.0
        }
    }

    var bottomInset: CGFloat = 0.0

    //MARK: Properties
    @IBInspectable var shouldConsiderTabBar: Bool = true
    private var disposable: Disposable!

    //MARK: Set Up
    override func awakeFromNib() {
        let (showSignal, showDisposable) = NSNotificationCenter.defaultCenter().keyboardSignal()
        let (hideSignal, hideDisposable) = NSNotificationCenter.defaultCenter().keyboardWillHideSignal()

        showSignal
            |> map { $0.keyboardFrame.height }
            |> observe(next: { [weak self] next in
                if let weakSelf = self {
                    weakSelf.updateConstraint(next - (weakSelf.shouldConsiderTabBar ? 49.0 : 0.0  ))
                }
            })

        hideSignal
            |> observe(next: {[weak self] next in
                if let weakSelf = self {
                    weakSelf.updateConstraint(weakSelf.bottomInset)
                }
            })

        self.disposable = CompositeDisposable([showDisposable, hideDisposable])
    }

    func updateConstraint(newValue: CGFloat) {
        self.managedView?.layoutIfNeeded()
        self.managedConstraint?.constant = newValue
        UIView.animateWithDuration(0.6) {
            self.managedView?.layoutIfNeeded()
        }
    }

    deinit {
        disposable.dispose()
    }

}

class DismissViewKeyboardManager: UIControl {
    //MARK: Managed View
    @IBOutlet weak var managedView: UIView?

    //MARK: Properties
    private lazy var dismissRecognizer: UITapGestureRecognizer = { return UITapGestureRecognizer(target: self, action: "dismissKeyboard") }()
    private var disposable: Disposable!

    //MARK: Set Up
    override func awakeFromNib() {
        let (showSignal, showDisposable) = NSNotificationCenter.defaultCenter().keyboardWillShowSignal()
        let (hideSignal, hideDisposable) = NSNotificationCenter.defaultCenter().keyboardWillHideSignal()

        showSignal
            |> observe(next: { [weak self] _ in
                if let weakSelf = self {
                    weakSelf.sendActionsForControlEvents(.EditingDidBegin)
                    weakSelf.managedView?.addGestureRecognizer(weakSelf.dismissRecognizer)
                }
            })

        hideSignal
            |> observe(next: { [weak self] _ in
                if let weakSelf = self {
                    weakSelf.sendActionsForControlEvents(.EditingDidEnd)
                    weakSelf.managedView?.removeGestureRecognizer(weakSelf.dismissRecognizer)
                }
            })

        self.disposable = CompositeDisposable([showDisposable, hideDisposable])
    }

    deinit {
        disposable.dispose()
    }

    func dismissKeyboard() {
        self.managedView?.window?.endEditing(true)
    }
}

class DismissOnReturnKeyboardManager: NSObject {
    //MARK: Managed View
    @IBOutlet var managedViews: [UITextField]? {
        willSet {
            if let views = self.managedViews {
                for view in views {
                    view.removeTarget(view,
                        action: Selector("resignFirstResponder"),
                        forControlEvents: .EditingDidEndOnExit)
                }
            }
        }
        didSet {
            if let views = self.managedViews {
                for view in views {
                    view.addTarget(view,
                        action: Selector("resignFirstResponder"),
                        forControlEvents: .EditingDidEndOnExit)
                }
            }
        }
    }
}

extension NSNotification {
    var keyboardFrame: CGRect {
        get {
            let keyboardValue: NSValue! = self.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue

            return keyboardValue.CGRectValue()
        }
    }
}

extension NSNotificationCenter {
    func keyboardSignal() -> (Signal<NSNotification, NoError>, Disposable) {
        let (signal, sink) = Signal<NSNotification, NoError>.pipe()

       let firstObserver = self.addObserverForName(UIKeyboardWillShowNotification, object: nil, queue: NSOperationQueue.mainQueue()) { sendNext(sink, $0) }
        let secondObserver = self.addObserverForName(UIKeyboardWillHideNotification, object: nil, queue: NSOperationQueue.mainQueue()) { sendNext(sink, $0) }

        return (signal, ActionDisposable {
            self.removeObserver(firstObserver)
            self.removeObserver(secondObserver)
        })
    }


    func keyboardWillShowSignal() -> (Signal<NSNotification, NoError>, Disposable) {
        let (signal, sink) = Signal<NSNotification, NoError>.pipe()

       let observer = self.addObserverForName(UIKeyboardWillShowNotification, object: nil, queue: NSOperationQueue.mainQueue()) { sendNext(sink, $0) }

        return (signal, ActionDisposable {
            self.removeObserver(observer)
        })
    }

    func keyboardWillHideSignal() -> (Signal<NSNotification, NoError>, Disposable) {
        let (signal, sink) = Signal<NSNotification, NoError>.pipe()

        let observer = self.addObserverForName(UIKeyboardWillHideNotification, object: nil, queue: NSOperationQueue.mainQueue()) { sendNext(sink, $0) }

        return (signal, ActionDisposable {
            self.removeObserver(observer)
        })
    }

}