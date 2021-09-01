/**
 * Copyright (c) 2021-present, Joshua Auerbach
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import UIKit

// A simple stepper which, unlike UIStepper, actually displays its value
protocol StepperDelegate {
    func valueChanged(_ stepper: Stepper)
    func displayText(_ value: Int) -> String
}
class Stepper : UIView {
    let decr : UIButton
    let display : UILabel
    let incr : UIButton
    var value : Int {
        didSet {
            display.text = delegate?.displayText(value)
        }
    }
    var delegate : StepperDelegate?
    var minimumValue : Int? = nil
    var maximumValue : Int? = nil

    // Make a new Stepper
    init() {
        value = -1          // Placeholder
        decr = UIButton()
        incr = UIButton()
        display = UILabel()
        super.init(frame: CGRect.zero)
        configureButton(decr, title: "-", target: self, action: #selector(decrement), parent: self)
        configureLabel(display, UIColor.white, parent: self)
        configureButton(incr, title: "+", target: self, action: #selector(increment), parent: self)
    }

    // Useless but required
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Perform layout of parts when self is layed out
    override var frame : CGRect {
        didSet {
            let width = bounds.width / 3
            decr.frame = CGRect(x: bounds.minX, y: bounds.minY, width: width, height: bounds.height)
            display.frame = decr.frame.offsetBy(dx: width, dy: 0)
            incr.frame = display.frame.offsetBy(dx: width, dy: 0)
        }
    }

    // Actions

    // Respond to touch of increment button
    @objc func increment() {
        if value < (maximumValue ?? Int.max) {
            value += 1
            delegate?.valueChanged(self)
        }
    }

    // Respond to touch of decrement button
    @objc func decrement() {
        if value > (minimumValue ?? Int.min) {
            value -= 1
            delegate?.valueChanged(self)
        }
    }
}
