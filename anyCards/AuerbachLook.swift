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

// Constants and functions to help get a uniform appearance across various apps

//
// Layout constants
//

/* The minimal border (in points) between things on the screen; even at the edges if you need the space */
let border = CGFloat(3)

/* The pixel width of the shorter dimension of a tablet (used only to calibrate font sizes) */
let tabletShortDimension = CGFloat(768)

/* The font size used for text on a tablet */
let baseHelpFontSize = CGFloat(30)

//
// Color constants
//

/* The background color to use for textual buttons */
let ButtonBackground = UIColor.black

/* The normal text color to use except when you are using something else */
let NormalTextColor = UIColor.black

/* The normal text color for TouchableLabels */
let TouchableTextColor = UIColor.blue

/* The background color for touchable labels */
let TouchableBackground = UIColor(white: 0.8, alpha: 1)

//
// Text constants
//

/* Title for the dismiss button of the "bummer" dialog */
let BummerButtonTitle = "Bummer"

//
// Functions (alphabetical)
//

// Display an error message modally, with a single "Bummer" button to dismiss the popup
func bummer(title: String, message: String, host: UIViewController) {
    let action = UIAlertAction(title: BummerButtonTitle, style: .cancel, handler: nil)
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(action)
    Logger.logPresent(alert, host: host, animated: true)
}

// Configure a button given a title and action and add it to a view
func configureButton(_ button: UIButton, title: String, target: AnyObject, action: Selector, parent: UIView) {
    button.setTitle(title, for: .normal)
    button.titleLabel?.adjustsFontSizeToFitWidth = true
    button.titleLabel?.font = getTextFont()
    button.backgroundColor = ButtonBackground
    button.addTarget(target, action: action, for: .touchUpInside)
    button.layer.cornerRadius = 8
    parent.addSubview(button)
}

// Configure a label with a given a background color.  Text alignment is always centered and the initial text color is the ScoreNormal color
// Adds the label to a view
func configureLabel(_ label: UILabel, _ color: UIColor, parent: UIView) {
    label.backgroundColor = color
    label.textColor = NormalTextColor
    label.font = getTextFont()
    label.textAlignment = .center
    label.adjustsFontSizeToFitWidth = true
    parent.addSubview(label)
}

// Configure a Text Field in a generally useful way, given a background color and a parent
func configureTextField(_ ans: UITextField, _ color: UIColor, parent: UIView) {
    ans.font = getTextFont()
    ans.textAlignment = .center
    ans.backgroundColor = color
    ans.keyboardType = .alphabet
    ans.enablesReturnKeyAutomatically = true
    ans.autocorrectionType = .no
    parent.addSubview(ans)
}

// Configure a TouchableLabel given a background color and an action.  Add to a view
func configureTouchableLabel(_ ans: TouchableLabel, target: AnyObject, action: Selector, tag: Int = 0, parent: UIView) {
    ans.view.backgroundColor = TouchableBackground
    ans.view.textColor = TouchableTextColor
    ans.view.textAlignment = .center
    ans.view.adjustsFontSizeToFitWidth = true
    ans.addTarget(target: target, action: action, tag: tag)
    parent.addSubview(ans)
}

// Get the appropriate font to use in a label, based on a base font size which is good for iPads.  Phones use a reduced font based on the
// ratio of their shortest dimension to the iPad's shortest dimension.
func getTextFont() -> UIFont {
    let bounds = UIScreen.main.bounds
    let shortDimension = bounds.width < bounds.height ? bounds.width : bounds.height
    let fontRatio = min(shortDimension / tabletShortDimension, 1.0)
    return UIFont.systemFont(ofSize: baseHelpFontSize * fontRatio)
}

// Make a label configured in the standard way
func makeLabel(_ color: UIColor, parent: UIView) -> UILabel {
    let label = UILabel()
    configureLabel(label, color, parent: parent)
    return label
}
