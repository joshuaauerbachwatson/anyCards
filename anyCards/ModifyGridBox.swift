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

// Menu which appears when you do a long press in an area that is not inside an existing GridBox.
// The general contract is to create a new GridBox
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
    let header = UILabel()    // First row
    let nameLabel = UILabel() // Second row, left
    let name = UITextField()  // Second row, right
    let kindLabel = UILabel() // Third row, left
    let kind = TouchableLabel() // third row, right
    let done = UIButton()     // Fourth row

    // Main initializer
    init(_ box: GridBox) {
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

        // Done button
        configureButton(done, title: DoneTitle, target: self, action: #selector(doneTouched), parent: view)
    }

    // When view appears, we do layout
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let fullHeight = min(preferredContentSize.height, view.bounds.height) - 2 * DialogEdgeMargin
        let fullWidth = min(preferredContentSize.width, view.bounds.width) - 2 * DialogEdgeMargin
        let ctlHeight = (fullHeight - 3 * DialogSpacer - 2 * DialogEdgeMargin) / 4
        let ctlWidth = (fullWidth - DialogSpacer) / 2
        let startX = (view.bounds.width / 2) - (fullWidth / 2)
        let startY = (view.bounds.height / 2) - (fullHeight / 2)
        place(header, startX, startY, fullWidth, ctlHeight)
        place(nameLabel, startX, below(header), ctlWidth, ctlHeight)
        place(name, after(nameLabel), below(header), ctlWidth, ctlHeight)
        place(kindLabel, startX, below(nameLabel), ctlWidth, ctlHeight)
        place(kind, after(kindLabel), below(name), ctlWidth, ctlHeight)
        place(done, startX, below(kindLabel), fullWidth, ctlHeight)
    }

    // Actions

    // Respond to touch of 'kind' field
    @objc func kindTouched() {
        let next = box.kind.next
        box.kind = next
        kind.text = next.label
        vc.transmit()
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
