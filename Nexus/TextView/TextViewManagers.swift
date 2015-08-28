//
//  TextViewManagers.swift
//  Nexus
//
//  Created by Murillo Nicacio de Maraes on 6/26/15.
//  Copyright (c) 2015 Unreasonable. All rights reserved.
//

import UIKit

import Base
import ReactiveCocoa

public final class TextViewManager: UIControl, UITextViewDelegate {
    //MARK: Outlets
    @IBOutlet weak var textView: UITextView? {
        didSet {
            self.watch()
        }
    }

    //MARK: Properties
    @IBInspectable var placeholder: String = ""
    @IBInspectable var placeholderColor: UIColor = .lightGrayColor()

    @IBInspectable var textColor: UIColor = .blackColor()

    public var currentText =  MutableProperty<String>("")
    internal var maximumCount: Int? = nil

    var disposable: Disposable?

    var isEditing: Bool = false

    //MARK: Set Up
    func watch() {
        self.disposable?.dispose()

        textView?.delegate = self

        self.setPlacehoderText()
        self.disposable = self.currentText.producer
            |> start(next: {[weak self] next in
                self?.textView?.text = next
                self?.sendActionsForControlEvents(.ValueChanged)

                if let isEditing = self?.isEditing where isEditing && next == "" {
                    self?.setPlacehoderText()
                }
            })
    }

    func setPlacehoderText() {
        textView?.text = placeholder
        textView?.textColor = placeholderColor
    }

    //MARK: Delegate Methods
    public func textViewDidBeginEditing(textView: UITextView) {
        self.isEditing = true

        if textView.text == placeholder && textView.textColor == placeholderColor {
            textView.text = ""
            textView.textColor = self.textColor
        }
    }

    public func textView(textView: UITextView, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
        if let maximum = self.maximumCount where count(textView.text + text) > maximum {
            return false
        }

        return true
    }

    public func textViewDidChange(textView: UITextView) {
        UIView.animateWithDuration(0.6) {
            self.textView?.layoutIfNeeded()
        }

        if self.textColor != self.placeholderColor {
            self.currentText.put(textView.text)
        }
    }

    public func textViewDidEndEditing(textView: UITextView) {
        self.isEditing = false

        if textView.text == "" {
            self.setPlacehoderText()
        }
    }
}

public final class WordCounter: NSObject {
    //MARK: Outlets
    @IBOutlet weak var label: UILabel?

    //MARK: Properties
    @IBInspectable var countsBackwards: Bool = false
    @IBInspectable var countsWords: Bool = false
    @IBInspectable var maximum: Int = 0
    @IBInspectable var prefix: String = ""
    @IBInspectable var postfix: String = ""

    //MARK: Action
    @IBAction func updated(sender: UIControl) {

        if let manager = sender as? TextViewManager {
            self.updateLabel(manager.currentText.value)
            manager.maximumCount = maximum >= 0 ? maximum : nil
        } else if let field = sender as? UITextField {
            let words = field.text.words

            field.text = !countsWords && count(field.text) > maximum && maximum > 1 ?
            (field.text as NSString).substringToIndex(maximum) :
            countsWords && words.count > maximum && maximum > 1 ?
            ", ".join(words[0..<maximum]):
            field.text
            
            self.updateLabel(field.text)
        } else {
            self.updateLabel("")
        }
    }

    //MARK: Helper
    func updateLabel(text: String) {
        let elementCount = countsWords ?
            text.words.count :
            count(text)
        let displayCount = countsBackwards ? maximum - elementCount : elementCount

        self.label?.text = prefix + "\(displayCount)" + postfix
    }


}