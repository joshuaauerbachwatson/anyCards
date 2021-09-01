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

// Various numeric promotions, provided by defining operators.  Currently, just promotions of Int or Double to CGFloat but could be expended.

// Int promotions

// Multiply
func * (_ left: CGFloat, _ right: Int) -> CGFloat {
    return left * CGFloat(right)
}
func * (_ left: Int, _ right: CGFloat) -> CGFloat {
    return CGFloat(left) * right
}

// Add
func + (_ left: CGFloat, _ right: Int) -> CGFloat {
    return left + CGFloat(right)
}
func + (_ left: Int, _ right: CGFloat) -> CGFloat {
    return CGFloat(left) + right
}

// Divide
func / (_ left: CGFloat, _ right: Int) -> CGFloat {
    return left / CGFloat(right)
}
func / (_ left: Int, _ right: CGFloat) -> CGFloat {
    return CGFloat(left) / right
}

// Subtract
func - (_ left: CGFloat, _ right: Int) -> CGFloat {
    return left - CGFloat(right)
}
func - (_ left: Int, _ right: CGFloat) -> CGFloat {
    return CGFloat(left) - right
}

// Double promotions

// Multiply
func * (_ left: CGFloat, _ right: Double) -> CGFloat {
    return left * CGFloat(right)
}
func * (_ left: Double, _ right: CGFloat) -> CGFloat {
    return CGFloat(left) * right
}

// Add
func + (_ left: CGFloat, _ right: Double) -> CGFloat {
    return left + CGFloat(right)
}
func + (_ left: Double, _ right: CGFloat) -> CGFloat {
    return CGFloat(left) + right
}

// Divide
func / (_ left: CGFloat, _ right: Double) -> CGFloat {
    return left / CGFloat(right)
}
func / (_ left: Double, _ right: CGFloat) -> CGFloat {
    return CGFloat(left) / right
}

// Subtract
func - (_ left: CGFloat, _ right: Double) -> CGFloat {
    return left - CGFloat(right)
}
func - (_ left: Double, _ right: CGFloat) -> CGFloat {
    return CGFloat(left) - right
}
