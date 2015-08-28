//
//  ScrollViewHideManager.swift
//  Nexus
//
//  Created by Murillo Nicacio de Maraes on 6/22/15.
//  Copyright (c) 2015 Unreasonable. All rights reserved.
//

import UIKit
import ReactiveCocoa

class ScrollViewHideManager: NSObject {
    //MARK: Managed Views
    @IBOutlet weak var scrollView: UIScrollView! {
        didSet {
            watch()
        }
    }
    @IBOutlet var hideViews: [UIView]!

    //MARK: Properties
    @IBInspectable var resetsOnTop: Bool = true
    @IBInspectable var fadeDistance: CGFloat = 100.0
    @IBInspectable var disappearResistance: CGFloat = 0.0
    @IBInspectable var appearResistance: CGFloat = 50.0

    //MARK: Helper Methods
    func watch() {
        if scrollView == nil {
            return
        }

        let initialValue = (fadeDistance + disappearResistance) / fadeDistance

        scrollView.offsetSignal()
            |> map { $0.y }
            |> combinePrevious(0.0)
            |> map { ($0 - $1, $1) }
            |> scan(initialValue) { [weak self] accumulated, next in
                let (delta, offset) = next

                if self == nil { return 0.0 }

                let maximum = (self!.fadeDistance + self!.disappearResistance) / self!.fadeDistance
                let minimum = -(self!.appearResistance / self!.fadeDistance)

                if offset <= 0.0 && self!.resetsOnTop {
                    return maximum
                }

                let newValue = accumulated + delta / self!.fadeDistance

                return max(minimum, min(maximum, newValue))
            }
            |> observe(next: { [weak self] alpha in
                for view in (self?.hideViews ?? []) {
                    view.animateAlpha(Double(alpha))
                }
            })
    }
}
