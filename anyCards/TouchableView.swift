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

// Pairs a transparent button with a view, making the view touchable without the complexity of an explicit gesture recognizer

class TouchableView<View: UIView> : UIView {
    let view : View
    let button : UIButton
    
    init(_ view: View) {
        self.view = view
        self.button = UIButton()
        super.init(frame: view.frame)
        view.frame = bounds
        button.frame = bounds
        button.backgroundColor = .clear
        addSubview(view)
        addSubview(button)
    }

    convenience init(_ view: View, target: AnyObject, action: Selector, tag: Int = 0) {
        self.init(view)
        addTarget(target: target, action: action, tag: tag)
    }

    func addTarget(target: AnyObject, action: Selector, tag: Int = 0) {
        button.addTarget(target, action: action, for: .touchUpInside)
        button.tag = tag
        view.tag = tag
        self.tag = tag
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var frame : CGRect {
        didSet {
            view.frame = bounds
            button.frame = bounds
        }
    }

    override var tag: Int {
        didSet {
            view.tag = tag
            button.tag = tag
        }
    }
}

// Variant which wants the view to be a UILabel.  Provides convenient access to 'text' property
class TouchableLabel : TouchableView<UILabel> {
    init() {
        super.init(UILabel())
    }

    convenience init(target: AnyObject, action: Selector, tag: Int = 0) {
        self.init()
        addTarget(target: target, action: action, tag: tag)
    }


    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var text : String? {
        get {
            return view.text
        }
        set {
            view.text = newValue
        }
    }
}
