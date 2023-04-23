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

// A small variant on UIPanGestureRecognizer that fires a separate closure for a tap (touch ends without movement)
class TapAndDragRecognizer : UIPanGestureRecognizer {
    // Closure to call when tap is recognized
    let onTap : ((UITouch) -> ())

    // Indicates whether we are looking for a tap.  This is true in the quiescent state but becomes false when
    // a drag begins.
    var lookForTap = true

    // Initializer extends UIPanGestureRecognizer syntax with an extra parameter for tap.
    init(target: Any, onDrag: Selector, onTap: @escaping ((UITouch)->())) {
        self.onTap = onTap
        super.init(target: target, action: onDrag)
    }

    // Catch touchesMoved so we can suppress monitoring for tap
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
            onTap(touch)
        }
        lookForTap = true // reset for next time
    }
}
