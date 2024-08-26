/**
 * Copyright (c) 2023-present, Joshua Auerbach
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
import AuerbachLook

// Menu which appears when you do a long press in an area that is not inside an existing GridBox.
// The general contract is to create a new GridBox.  The same menu is used as a submenu of the GridBox
// menu (which appears in response to a long press inside a GridBox or a tap in the legend area of the box).
class ModifyGridBox : UIViewController {

    // Parent view controller
    var vc : ViewController {
        if let ans = presentingViewController as? ViewController {
            return ans
        }
        Logger.logFatalError("Could not retrieve ViewController within ModifyGridBox dialog")
    }

    // The GridBox being acted upon
    let box: GridBox

    // Controls
    let header = UILabel()       // First row
    let nameLabel = UILabel()    // Second row, left
    let name = UITextField()     // Second row, right
    let kindLabel = UILabel()    // Third row, left
    let kind = TouchableLabel()  // third row, right
    let ownedLabel = UILabel()   // Fourth row, left
    let owned = TouchableLabel() // Fourth row, right
    let done = UIButton()        // Fifth row

    // Main initializer
    init?(_ box: GridBox) {
        if !box.mayBeModified {
            return nil
        }
        self.box = box
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = GameSetupSize
        modalPresentationStyle = UIModalPresentationStyle.formSheet
    }

    // Required but useless
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // When view loads, we finish initializing the controls (except for layout) and make them into subviews
    override func viewDidLoad() {
        view.backgroundColor = SettingsDialogBackground

        // Header
        configureLabel(header, SettingsDialogBackground, parent: view)
        header.text = GridBoxSpecifyTitle

        // Box name and label
        configureLabel(nameLabel, SettingsDialogBackground, parent: view)
        nameLabel.text = GridBoxNameTitle
        nameLabel.textAlignment = .right
        configureTextField(name, LabelBackground, parent: view)
        name.textColor = NormalTextColor
        name.font = getTextFont()
        name.delegate = self
        name.text = box.name
        name.placeholder = GridBoxNamePlaceholder

        // Box kind and label
        configureLabel(kindLabel, SettingsDialogBackground, parent: view)
        kindLabel.text = GridBoxKindTitle
        nameLabel.textAlignment = .right
        configureTouchableLabel(kind, target: self, action: #selector(kindTouched), parent: view)
        kind.text = box.kind.label
        kind.view.font = getTextFont()
        kind.view.backgroundColor = LabelBackground

        // Ownership and its label
        configureLabel(ownedLabel, SettingsDialogBackground, parent: view)
        ownedLabel.text = OwnedTitle
        ownedLabel.textAlignment = .right
        configureTouchableLabel(owned, target: self, action: #selector(ownedTouched), parent: view)
        owned.text = NoText
        owned.view.font = getTextFont()
        owned.view.backgroundColor = LabelBackground

        // Done button
        configureButton(done, title: DoneTitle, target: self, action: #selector(doneTouched), parent: view)
    }

    // When view appears, we do layout
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let fullHeight = min(preferredContentSize.height, view.bounds.height) - 2 * DialogEdgeMargin
        let fullWidth = min(preferredContentSize.width, view.bounds.width) - 2 * DialogEdgeMargin
        let ctlHeight = (fullHeight - 4 * DialogSpacer - 2 * DialogEdgeMargin) / 5
        let ctlWidth = (fullWidth - DialogSpacer) / 2
        let startX = (view.bounds.width / 2) - (fullWidth / 2)
        let startY = (view.bounds.height / 2) - (fullHeight / 2)
        place(header, startX, startY, fullWidth, ctlHeight)
        place(nameLabel, startX, below(header), ctlWidth, ctlHeight)
        place(name, after(nameLabel), below(header), ctlWidth, ctlHeight)
        place(kindLabel, startX, below(nameLabel), ctlWidth, ctlHeight)
        place(kind, after(kindLabel), below(name), ctlWidth, ctlHeight)
        place(ownedLabel, startX, below(kindLabel), ctlWidth, ctlHeight)
        place(owned, after(ownedLabel), below(kind), ctlWidth, ctlHeight)
        place(done, startX, below(ownedLabel), fullWidth, ctlHeight)
    }

    // Actions

    // Respond to touch of 'kind' field
    @objc func kindTouched() {
        let preferredSize = TableDialogController.getPreferredSize(GridBox.Kind.allCases.count)
        let anchor = CGPoint(x: kind.frame.midX, y: kind.frame.minY)
        let popup = BoxKindDialog(self, box, size: preferredSize, anchor: anchor)
        Logger.logPresent(popup, host: self, animated: true)
    }

    @objc func ownedTouched() {
        if box.owner == GridBox.Unowned {
            box.owner = vc.thisPlayer
            owned.text = YesText
        } else if box.owner == vc.thisPlayer {
            box.owner = GridBox.Unowned
            owned.text = NoText
        } else {
            Logger.logFatalError("GridBox ownership defenses have failed")
        }
    }

    // Respond to touch of 'done' button
    @objc func doneTouched() {
        Logger.logDismiss(self, host: vc, animated: true)
    }
}

// Conform to UITextFieldDelegate
extension ModifyGridBox: UITextFieldDelegate {
    // Store new value of the name field
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        if let newText = textField.text, reason == .committed {
            box.name = newText
            vc.transmit()
        }
    }

    // Allow the return key to end editing
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}
