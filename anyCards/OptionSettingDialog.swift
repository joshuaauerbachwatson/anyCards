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

// Dialog for option setting in Any Old Card Game
class OptionSettingsDialog : UIViewController {
    // Parent view controller
    var vc : ViewController {
        if let ans = presentingViewController as? ViewController {
            return ans
        }
        Logger.logFatalError("Could not retrieve ViewController within OptionSettingsDialog")
    }

    // Terser referene to settings
    var settings : OptionSettings {
        return OptionSettings.instance
    }

    // Controls
    let header = UILabel()                    // First Row
    let userNameLabel = UILabel()             // Second row, left
    let userName = UITextField()              // Second row, right
    let communicationLabel = UILabel()        // Third row, left
    let communicationStyle = TouchableLabel() // Third row, right
    let deckTypeLabel = UILabel()             // Fourth row, left
    let deckType = TouchableLabel()           // Fourth row, right
    let handAreaLabel = UILabel()             // Fifth row, left
    let handArea = TouchableLabel()           // Fifth row, right
    let minPlayersLabel = UILabel()           // Sixth row, left
    let minPlayers = Stepper()                // Sixth row, right
    let maxPlayersLabel = UILabel()           // Seventh row, left
    let maxPlayers = Stepper()                // Seventh row, right
    let doneButton = UIButton()               // Eighth row

    init() {
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = OptionSettingsSize
        modalPresentationStyle = UIModalPresentationStyle.formSheet
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // When view loads, we finish initializing the controls (except for layout) and make them into subviews
    override func viewDidLoad() {
        view.backgroundColor = SettingsDialogBackground

        // Header
        configureLabel(header, SettingsDialogBackground, parent: view)
        header.text = SettingsHeaderText

        // userName and label
        configureLabel(userNameLabel, SettingsDialogBackground, parent: view)
        userNameLabel.text = UserNameText
        userNameLabel.textAlignment = .right
        configureTextField(userName, LabelBackground, parent: view)
        userName.text = settings.userName
        userName.delegate = self

        // communicationStyle and label
        configureLabel(communicationLabel, SettingsDialogBackground, parent: view)
        communicationLabel.text = CommunicationLabelText
        communicationLabel.textAlignment = .right
        configureTouchableLabel(communicationStyle, target: self, action: #selector(communicationStyleTouched), parent: view)
        communicationStyle.text = settings.communication.displayName
        communicationStyle.view.font = getTextFont()
        communicationStyle.view.backgroundColor = LabelBackground

        // deckType and label
        configureLabel(deckTypeLabel, SettingsDialogBackground, parent: view)
        deckTypeLabel.text = DeckTypeText
        deckTypeLabel.textAlignment = .right
        configureTouchableLabel(deckType, target: self, action: #selector(deckTypeTouched), parent: view)
        deckType.text = settings.deckType.displayName
        deckType.view.font = getTextFont()
        deckType.view.backgroundColor = LabelBackground

        // handArea and label
        configureLabel(handAreaLabel, SettingsDialogBackground, parent: view)
        handAreaLabel.text = HandAreaText
        handAreaLabel.textAlignment = .right
        configureTouchableLabel(handArea, target: self, action: #selector(handAreaTouched), parent: view)
        handArea.text = settings.hasHands ? HandAreaYes : HandAreaNo
        handArea.view.font = getTextFont()
        handArea.view.backgroundColor = LabelBackground

        // Min and max players and their labels
        configureStepper(minPlayersLabel, minPlayers, MinPlayersText, settings.minPlayers)
        configureStepper(maxPlayersLabel, maxPlayers, MaxPlayersText, settings.maxPlayers)
        setSteppersMinMax()

        // Done button
        configureButton(doneButton, title: DoneButtonTitle, target: self, action: #selector(doneButtonTouched), parent: view)

        // Suppress options that aren't applicable.   Assume the dialog won't show at all if NO options are applicable.
        if vc.communicator != nil {
            userName.isUserInteractionEnabled = false
            communicationStyle.isUserInteractionEnabled = false
            minPlayers.isUserInteractionEnabled = false
            maxPlayers.isUserInteractionEnabled = false
        }
    }

    // When view appears, we do layout
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let ctlHeight = (view.bounds.height - 7 * OptionSettingsSpacer - 2 * OptionSettingsEdgeMargin) / 8
        let fullWidth = view.bounds.width - 2 * OptionSettingsEdgeMargin
        let ctlWidth = (fullWidth - OptionSettingsSpacer) / 2
        header.frame = CGRect(x: view.bounds.minX + OptionSettingsEdgeMargin, y: view.bounds.minY + OptionSettingsEdgeMargin, width: fullWidth,
                              height: ctlHeight)
        userNameLabel.frame = CGRect(x: view.bounds.minX + OptionSettingsEdgeMargin, y: header.frame.maxY + OptionSettingsSpacer,                             width: ctlWidth, height: ctlHeight)
        userName.frame = userNameLabel.frame.offsetBy(dx: ctlWidth + OptionSettingsSpacer, dy: 0)
        communicationLabel.frame = userNameLabel.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        communicationStyle.frame = userName.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        deckTypeLabel.frame = communicationLabel.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        deckType.frame = communicationStyle.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        handAreaLabel.frame = deckTypeLabel.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        handArea.frame = deckType.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        minPlayersLabel.frame = handAreaLabel.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        minPlayers.frame = handArea.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        maxPlayersLabel.frame = minPlayersLabel.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        maxPlayers.frame = minPlayers.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        doneButton.frame = CGRect(x: view.bounds.minX + OptionSettingsEdgeMargin, y: maxPlayers.frame.maxY + OptionSettingsSpacer, width: fullWidth, height: ctlHeight)
    }

    // Actions

    // Respond to touch of the communication style label by toggling the style
    @objc func communicationStyleTouched() {
        let newStyle = settings.communication.next
        communicationStyle.text = newStyle.displayName
        settings.communication = newStyle
        vc.settingsChanged()
    }

    // Respond to touch of the deck type label by cycling through the available options
    @objc func deckTypeTouched() {
        let newDeckType = Decks.next(settings.deckType.displayName)
        deckType.text = newDeckType.displayName
        settings.deckType = newDeckType
        vc.settingsChanged()
    }

    // Respond to touch of the 'done' button
    @objc func doneButtonTouched() {
        if let vc = presentingViewController {
            Logger.logDismiss(self, host: vc, animated: false)
        }
    }

    // Respond to touch of the 'hand area" touchable label by toggling between present and absent
    @objc func handAreaTouched() {
        let newValue = !settings.hasHands
        settings.hasHands = newValue
        handArea.text = newValue ? HandAreaYes : HandAreaNo
        vc.settingsChanged()
    }

    // Subroutines

    // Finish initializing one of the two steppers
    private func configureStepper(_ label: UILabel, _ stepper: Stepper, _ labelText: String, _ stepperValue: Int) {
        configureLabel(label, SettingsDialogBackground, parent: view)
        label.text = labelText
        label.textAlignment = .right
        stepper.delegate = self
        stepper.value = stepperValue
        view.addSubview(stepper)
    }

    // Set the limits of both steppers taking into account the value of the other (so that always min <= max)
    private func setSteppersMinMax() {
        minPlayers.minimumValue = PlayersMin
        minPlayers.maximumValue = min(maxPlayers.value, PlayersMax)
        maxPlayers.minimumValue = max(minPlayers.value, PlayersMin)
        maxPlayers.maximumValue = PlayersMax
    }
}

// Conform to UITextFieldDelegate
extension OptionSettingsDialog : UITextFieldDelegate {
    // React to a change in the text field containing the user name
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        if let newText = textField.text, reason == .committed {
            settings.userName = newText
            vc.settingsChanged()
        }
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

// Conform to StepperDelegate
extension OptionSettingsDialog : StepperDelegate {
    func valueChanged(_ stepper: Stepper) {
        settings.minPlayers = minPlayers.value
        settings.maxPlayers = maxPlayers.value
        setSteppersMinMax()
        vc.settingsChanged()
    }
    func displayText(_ value: Int) -> String {
        return String(value)
    }
}
