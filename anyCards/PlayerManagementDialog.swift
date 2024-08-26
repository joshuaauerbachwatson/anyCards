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
import AuerbachLook

// Dialog for managing players in the AnyCards Game
class PlayerManagementDialog : UIViewController {

    // Parent view controller
    var vc : ViewController {
        if let ans = presentingViewController as? ViewController {
            return ans
        }
        Logger.logFatalError("Could not retrieve ViewController within PlayerManagementDialog")
    }

    // Controls
    let header = UILabel()              // 1st row
    let version = UILabel()             // 2nd row
    let userNameLabel = UILabel()       // 3rd row left
    let userName = UITextField()        // 3rd row right
    let leaderStatusLabel = UILabel()   // 4th row left
    let leaderStatus = TouchableLabel() // 4th row right
    let numPlayersLabel = UILabel()     // 5th row left
    let numPlayers = Stepper()          // 5th row right
    let localRemoteLabel = UILabel()    // 6th row left
    let localRemote = TouchableLabel()  // 6th row right
    let tokenLabel = UILabel()          // 7th row left
    let token = UITextField()           // 7th row right
    let useSavedToken = UIButton()      // 8th row
    let findPlayersButton = UIButton()  // 9th row

    // editable field tags
    let UserNameTag = 0
    let TokenTag = 1

    init() {
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = PlayerManagementSize
        modalPresentationStyle = UIModalPresentationStyle.formSheet
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Convenient check for whether playing is currently recorded as local or remote
    var isRemoteRecorded: Bool {
        get {
            switch vc.communication {
            case .ServerBased(_):
                return true
            case .MultiPeer:
                return false
            }
        }
    }

    // Convenient check for whether playing is currently intended to be local or remote (can be true when isRemoteRecorded is
    // false because a valid token may not exist yet).
    var isRemoteIntended: Bool {
        get {
            return localRemote.text == RemoteText
        }
    }

    // When view loads, we finish initializing the controls (except for layout) and make them into subviews
    override func viewDidLoad() {
        view.backgroundColor = SettingsDialogBackground

        // Header and version
        configureLabel(header, SettingsDialogBackground, parent: view)
        header.text = PlayersHeaderText
        configureLabel(version, SettingsDialogBackground, parent: view)
        version.text = generateVersionText()

        // userName and label
        configureLeftLabel(userNameLabel, UserNameText)
        configureEditableField(userName, UserNameTag)
        userName.text = vc.userName

        // Leader status and its label
        configureLeftLabel(leaderStatusLabel, LeaderStatusLabelText)
        configureTouchableLabel(leaderStatus, target: self, action: #selector(leaderStatusTouched), parent: view)
        leaderStatus.text = vc.leadPlayer ? YesText : NoText

        // Num Players and its label
        configureLeftLabel(numPlayersLabel, NumPlayersText)
        configureStepper(numPlayers, delegate: self, value: vc.numPlayers, parent: view)
        numPlayers.minimumValue = PlayersMin
        numPlayers.maximumValue = PlayersMax
        if vc.leadPlayer {
            unhide(vc.gameSetupButton, numPlayersLabel, numPlayers)
        } else {
            hide(vc.gameSetupButton, numPlayersLabel, numPlayers)
        }

        // Local/remote
        configureLeftLabel(localRemoteLabel, LocalRemoteLabelText)
        configureTouchableLabel(localRemote, target:self, action: #selector(localRemoteTouched), parent: view)
        localRemote.text = isRemoteRecorded ? RemoteText : LocalText

        // Game Token and its label
        configureLeftLabel(tokenLabel, TokenLabelText)
        configureEditableField(token, TokenTag)
        if case let CommunicatorKind.ServerBased(savedToken) = vc.communication {
            token.text = savedToken
        }

        // Use saved token button
        configureButton(useSavedToken, title: UseSavedTokenTitle, target: self, action: #selector(useSavedTokenTouched), parent: view)

        // find players button
        configureButton(findPlayersButton, title: FindPlayersTitle, target: self, action: #selector(findPlayersTouched), parent: view)

        // Set remote controls showing or not
        setRemoteControlsHidden(!isRemoteRecorded)
    }

    // When view appears, we do layout
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let spacer = DialogSpacer
        let margin = DialogEdgeMargin
        let fullHeight = min(preferredContentSize.height, view.bounds.height) - 2 * margin
        let fullWidth = min(preferredContentSize.width, view.bounds.width) - 2 * margin
        let ctlHeight = (fullHeight - 10 * spacer - 2 * margin) / 11
        let startX = (view.bounds.width / 2) - (fullWidth / 2)
        let startY = (view.bounds.height / 2) - (fullHeight / 2)
        let thirdWidth = (fullWidth - 2 * spacer) / 3
        let twoThirdsWidth = 2 * thirdWidth + spacer
        place(header, startX, startY, fullWidth, ctlHeight)
        place(version, startX, below(header), fullWidth, ctlHeight)
        place(userNameLabel, startX, below(version), thirdWidth, ctlHeight)
        place(userName, after(userNameLabel), below(version), twoThirdsWidth, ctlHeight)
        place(leaderStatusLabel, startX, below(userName), thirdWidth, ctlHeight)
        place(leaderStatus, after(leaderStatusLabel), below(userName), twoThirdsWidth, ctlHeight)
        place(numPlayersLabel, startX, below(leaderStatus), thirdWidth, ctlHeight)
        place(numPlayers, after(numPlayersLabel), below(leaderStatus), twoThirdsWidth, ctlHeight)
        place(localRemoteLabel, startX, below(numPlayers), thirdWidth, ctlHeight)
        place(localRemote,after(localRemoteLabel), below(numPlayers), twoThirdsWidth, ctlHeight)
        place(tokenLabel, startX, below(localRemote), thirdWidth, ctlHeight)
        place(token, after(tokenLabel), below(localRemote), twoThirdsWidth,  ctlHeight)
        place(useSavedToken, startX, below(token), fullWidth, ctlHeight)
        place(findPlayersButton, startX, below(useSavedToken), fullWidth, ctlHeight)
    }

    // Actions

    // Respond to touch of the leaderStatus control by changing the value in the control and the settings and adjusting other elements
    // of the game accordingly
    @objc func leaderStatusTouched() {
        if vc.leadPlayer {
            // Was on, toggle off
            vc.leadPlayer = false
            leaderStatus.text = NoText
            hide(vc.gameSetupButton, numPlayersLabel, numPlayers)
        } else {
            // Was off, toggle on
            vc.leadPlayer = true
            leaderStatus.text = YesText
            unhide(vc.gameSetupButton, numPlayersLabel, numPlayers)
        }
    }

    // Respond to touch of the local/remote control by changing the value in the control and the settings and adjusting other elements
    // of the game accordingly.
    @objc func localRemoteTouched() {
        if localRemote.text == RemoteText {
            // Was remote, toggle to local
            vc.communication = .MultiPeer
            setRemoteControlsHidden(true)
            localRemote.text = LocalText
        } else {
            // was local, toggle to remote
            setRemoteControlsHidden(false) // shows initial token
            localRemote.text = RemoteText
        }
    }

    // Respond to touch of the use saved button
    @objc func useSavedTokenTouched() {
        let preferredSize = TableDialogController.getPreferredSize(gameTokens.values.count)
        let anchor = CGPoint(x: token.frame.midX, y: token.frame.minY)
        let popup = RestoreTokenDialog(self, size: preferredSize, anchor: anchor)
        token.resignFirstResponder()
        Logger.logPresent(popup, host: self, animated: true)
     }

    // Respond to touch of the find players button
    @objc func findPlayersTouched() {
        Logger.log("Find Players Touched")
        if isRemoteIntended {
            token.resignFirstResponder()
            let currentToken = token.text ?? ""
            if validToken(currentToken) {
                vc.communication = .ServerBased(currentToken)
            } else {
                bummer(title: InvalidTokenTitle, message: InvalidTokenMessage, host: self)
                return
            }
        }
        vc.startPlayerSearch()
        Logger.logDismiss(self, host: vc, animated: true)
    }

    // Subroutines

    // Show a specific token in this dialog (assumes isRemote is true and that the labels are showing)
    // Argument is the token to show.
    func showToken(_ tokenArg: String) {
        unhide(useSavedToken)
        token.text = tokenArg
        vc.communication = .ServerBased(tokenArg)
    }

    // Show a blank token to be filled in by the user (assumes remote and that the labels are showing)
    func showBlankToken() {
        token.text = nil
        token.becomeFirstResponder()
    }

    // Show the appropriate initial token (assuming remote and that the labels are showing)
    func showInitialToken() {
        unhide(token)
        if let firstToken = gameTokens.first {
            showToken(firstToken)
        } else {
            showBlankToken()
            hide(useSavedToken)
        }
    }

    // Set the remote controls hidden or not
    func setRemoteControlsHidden(_ hidden: Bool) {
        if hidden {
            hide(token, tokenLabel, useSavedToken)
        } else {
            unhide(tokenLabel)
            showInitialToken()
        }
    }

    // Configure a label for the left hand area
    func configureLeftLabel(_ label: UILabel, _ text: String) {
        configureLabel(label, SettingsDialogBackground, parent: view)
        label.text = text
        label.textAlignment = .right
    }

    // Configure a text field for our purposes
    func configureEditableField(_ field: UITextField, _ tag: Int) {
        configureTextField(field, LabelBackground, parent: view)
        field.textColor = NormalTextColor
        field.font = getTextFont()
        field.tag = tag
        field.delegate = self
        field.enablesReturnKeyAutomatically = false
    }

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

    // Determines if token is valid
    func validToken(_ text: String?) -> Bool {
        guard let token = text else {
            return false
        }
        return token.count >= GameTokenMinLength && validTokenChars(token)
    }

    // Determines if characters are valid for inclusion in a token
    func validTokenChars(_ chars: String) -> Bool {
        return (try? Regex("^[a-zA-Z0-9_-]*$").wholeMatch(in: chars)) != nil
    }
}

// Conform to UITextFieldDelegate
extension PlayerManagementDialog: UITextFieldDelegate {
    // Prevent erroneous characters from entering the editToken field.
    func textField(_ field: UITextField, shouldChangeCharactersIn range: NSRange, replacementString chars: String) -> Bool {
        if field.tag != TokenTag {
            return true
        }
        return validTokenChars(chars)
    }

    // Don't allow invalid token to be left in the token field
    func textFieldShouldEndEditing(_ field: UITextField) -> Bool {
        if field.tag != TokenTag {
            return true
        }
        if let token = field.text, token.count > 0 {
            if validToken(token) {
                return true
            } else {
                bummer(title: InvalidTokenTitle, message: InvalidTokenMessage, host: self)
                return false
            }
        } // if valid or if currently clear
        return true
    }

    // Store new value of the player name field and/or end token editing
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        if let newText = textField.text, reason == .committed, newText.count > 0 {
            if textField.tag == UserNameTag {
                vc.userName = newText
                vc.configurePlayerLabels()
            } else {
                gameTokens.storeToken(newText)
                vc.communication = .ServerBased(newText)
                unhide(useSavedToken)
            }
        }
    }

    // For all fields, allow the return key to end editing
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

// Conform to StepperDelegate
extension PlayerManagementDialog: StepperDelegate {
    func valueChanged(_ stepper: Stepper) {
        vc.numPlayers = stepper.value
        findPlayersButton.isHidden = vc.numPlayers < 2
        vc.configurePlayerLabels()
    }

    func displayText(_ value: Int) -> String {
        return String(value)
    }
}
