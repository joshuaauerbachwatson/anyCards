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
import UIKit.UIGestureRecognizerSubclass

// A small variant on UIPanGestureRecognizer that fires separate closures for touch and tap recognition
class TouchTapAndDragRecognizer : UIPanGestureRecognizer {
    // Closure to call when a touch is recognized.  The closure can activate tap recognition (on touch end) or not as it sees fit.  But note that tap
    // recognition is cancelled if there is any finger movement regardless of what the touch closure decided.
    // May be omitted.
    let onTouch : ((UITouch) -> Bool)?

    // Closure to call when tap is recognized.  May be omitted.
    let onTap : ((UITouch) -> ())?

    // Indicates whether we are looking for a tap
    var lookForTap = false

    // Initializer extends UIPanGestureRecognizer syntax with extra parameters for touch and tap; these may be nil but presumably if both are nil you would
    // want to just use the base class.
    init(target: Any, onDrag: Selector, onTouch: ((UITouch)->Bool)?, onTap: ((UITouch)->())?) {
        self.onTouch = onTouch
        self.onTap = onTap
        super.init(target: target, action: onDrag)
    }

    // Catch touchesBegan to act as a trivial touch recognizer.  Let the supplied closure decide whether to monitor for a tap; otherwise, after delivering
    // the touch recognition we simply behave like UIPanGestureRecognizer
    override func touchesBegan(_ touches: Set<UITouch>, with: UIEvent) {
        super.touchesBegan(touches, with: with)
        if let touch = touches.first {
            lookForTap = onTouch?(touch) ?? false
        }
    }

    // Catch touchesMoved so we can cancel any outstanding tap monitoring
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        if state == .began {
            lookForTap = false
        }
    }

    // Catch touches ended to see if we need to deliver a tap recognition
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        if lookForTap, let touch = touches.first {
            lookForTap = false
            onTap?(touch)
        }
    }
}
