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

// Dialog for option setting in AnyCards
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
    let versionLabel = UILabel()              // Second Row
    let userNameLabel = UILabel()             // Third row, left
    let userName = UITextField()              // Third row, right
    let communicationLabel = UILabel()        // Fourth row, left
    let communicationStyle = TouchableLabel() // Fourth row, right
    let deckTypeLabel = UILabel()             // Fifth row, left
    let deckType = TouchableLabel()           // Fifth row, right
    let handAreaLabel = UILabel()             // Sixth row, left
    let handArea = TouchableLabel()           // Sixth row, right
    let numPlayersLabel = UILabel()           // Seventh row, left
    let numPlayers = Stepper()                // Seventh row, right
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

        // Header and version
        configureLabel(header, SettingsDialogBackground, parent: view)
        header.text = SettingsHeaderText
        configureLabel(versionLabel, SettingsDialogBackground, parent: view)
        versionLabel.text = generateVersionText()

        // userName and label
        configureLabel(userNameLabel, SettingsDialogBackground, parent: view)
        userNameLabel.text = UserNameText
        userNameLabel.textAlignment = .right
        configureTextField(userName, LabelBackground, parent: view)
        userName.textColor = NormalTextColor
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

        // Number of players and label
        configureStepperAndLabel(numPlayersLabel, numPlayers, NumPlayersText, settings.numPlayers)
        setStepperMinMax()

        // Done button
        configureButton(doneButton, title: DoneButtonTitle, target: self, action: #selector(doneButtonTouched), parent: view)

        // Suppress options that aren't applicable.   Assume the dialog won't show at all if NO options are applicable.
        if vc.communicator != nil {
            userName.isUserInteractionEnabled = false
            communicationStyle.isUserInteractionEnabled = false
            numPlayers.isUserInteractionEnabled = false
        }
    }

    // When view appears, we do layout
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let fullHeight = min(preferredContentSize.height, view.bounds.height) - 2 * OptionSettingsEdgeMargin
        let fullWidth = min(preferredContentSize.width, view.bounds.width) - 2 * OptionSettingsEdgeMargin
        let ctlHeight = (fullHeight - 7 * OptionSettingsSpacer - 2 * OptionSettingsEdgeMargin) / 8
        let ctlWidth = (fullWidth - OptionSettingsSpacer) / 2
        let startX = (view.bounds.width / 2) - (fullWidth / 2)
        let startY = (view.bounds.height / 2) - (fullHeight / 2)
        header.frame = CGRect(x: startX, y: startY, width: fullWidth, height: ctlHeight)
        versionLabel.frame = header.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        userNameLabel.frame = CGRect(x: startX, y: versionLabel.frame.maxY + OptionSettingsSpacer, width: ctlWidth, height: ctlHeight)
        userName.frame = userNameLabel.frame.offsetBy(dx: ctlWidth + OptionSettingsSpacer, dy: 0)
        communicationLabel.frame = userNameLabel.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        communicationStyle.frame = userName.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        deckTypeLabel.frame = communicationLabel.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        deckType.frame = communicationStyle.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        handAreaLabel.frame = deckTypeLabel.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        handArea.frame = deckType.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        numPlayersLabel.frame = handAreaLabel.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        numPlayers.frame = handArea.frame.offsetBy(dx: 0, dy: ctlHeight + OptionSettingsSpacer)
        doneButton.frame = CGRect(x: startX, y: numPlayers.frame.maxY + OptionSettingsSpacer, width: fullWidth, height: ctlHeight)
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

    // Generates the content of the version label based information baked into the app at build time.
    private func generateVersionText() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if appVersion == nil {
            return MissingVersionMessage
        } else if buildNumber == nil {
            return VersionPrefix + appVersion!
        } else {
            return "\(VersionPrefix)\(appVersion!)(\(buildNumber!))"
        }
    }

    // Finish initializing one of the two steppers
    private func configureStepperAndLabel(_ label: UILabel, _ stepper: Stepper, _ labelText: String, _ stepperValue: Int) {
        configureLabel(label, SettingsDialogBackground, parent: view)
        label.text = labelText
        label.textAlignment = .right
        configureStepper(stepper, delegate: self, value: stepperValue, parent: view)
    }

    // Set the limits of both steppers taking into account the value of the other (so that always min <= max)
    private func setStepperMinMax() {
        numPlayers.minimumValue = PlayersMin
        numPlayers.maximumValue = PlayersMax
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
        settings.numPlayers = numPlayers.value
        setStepperMinMax()
        vc.settingsChanged()
    }
    func displayText(_ value: Int) -> String {
        return String(value)
    }
}
