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

// Dialog for managing players in the AnyCards Game
class PlayerManagementDialog : UIViewController {

    // Parent view controller
    var vc : ViewController {
        if let ans = presentingViewController as? ViewController {
            return ans
        }
        Logger.logFatalError("Could not retrieve ViewController within PlayerManagementDialog")
    }

    // Terser reference to settings
    var settings : OptionSettings {
        return OptionSettings.instance
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
    let token = UILabel()               // 7th row right
    let editToken = UITextField()       // == token
    let nickNameLabel = UILabel()       // 8th row left
    let nickName = UILabel()            // 8th row right
    let editNickName = UITextField()    // == nickName
    let nextButton = UIButton()         // 9th row
    let rememberForgetButton = UIButton() // 10th row
    let findPlayersButton = UIButton()  // 11th row

    init() {
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = OptionSettingsSize // borrowed
        modalPresentationStyle = UIModalPresentationStyle.formSheet
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Convenient check for whether playing is currently local or remote
    var isRemote: Bool {
        get {
            switch settings.communication {
            case .ServerBased(_):
                return true
            case .MultiPeer:
                return false
            }
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
        configureTextField(userName, LabelBackground, parent: view)
        userName.textColor = NormalTextColor
        userName.text = settings.userName
        userName.delegate = self

        // Leader status and its label
        configureLeftLabel(leaderStatusLabel, LeaderStatusLabelText)
        configureTouchableLabel(leaderStatus, target: self, action: #selector(leaderStatusTouched), parent: view)
        leaderStatus.text = settings.leadPlayer ? LeaderText : NonleaderText

        // Num Players and its label
        configureLeftLabel(numPlayersLabel, NumPlayersText)
        configureStepper(numPlayers, delegate: self, value: settings.numPlayers, parent: view)
        if settings.leadPlayer {
            unhide(vc.optionsButton, numPlayersLabel, numPlayers)
        } else {
            hide(vc.optionsButton, numPlayersLabel, numPlayers)
        }

        // Local/remote
        configureLeftLabel(localRemoteLabel, LocalRemoteLabelText)
        configureTouchableLabel(localRemote, target:self, action: #selector(localRemoteTouched), parent: view)
        localRemote.text = isRemote ? RemoteText : LocalText

        // Token and its label
        configureLeftLabel(tokenLabel, TokenLabelText)
        configureLabel(token, LabelBackground, parent: view)
        configureEditableField(editToken, 0)

        // Nickname and its label
        configureLeftLabel(nickNameLabel, NickNameLabelText)
        configureLabel(nickName, LabelBackground, parent: view)
        configureEditableField(editNickName, 1)

        // next button
        configureButton(nextButton, title: NextTitle, target: self, action: #selector(nextTouched), parent: view)

        // forget button (title will be set/reset elsewhere)
        configureButton(rememberForgetButton, title: ForgetTitle, target: self, action: #selector(rememberForgetTouched), parent: view)

        // find players button
        configureButton(findPlayersButton, title: FindPlayersTitle, target: self, action: #selector(findPlayersTouched), parent: view)

        // Set remote controls showing or not
        setRemoteControlsHidden(!isRemote)
    }

    // When view appears, we do layout
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let spacer = OptionSettingsSpacer // borrowed
        let margin = OptionSettingsEdgeMargin // borrowed
        let fullHeight = min(preferredContentSize.height, view.bounds.height) - 2 * margin
        let fullWidth = min(preferredContentSize.width, view.bounds.width) - 2 * margin
        let ctlHeight = (fullHeight - 10 * spacer - 2 * margin) / 11
        let startX = (view.bounds.width / 2) - (fullWidth / 2)
        let startY = (view.bounds.height / 2) - (fullHeight / 2)
        let thirdWidth = (fullWidth - 2 * spacer) / 3
        let twoThirdsWidth = 2 * thirdWidth + spacer
        place(header, startX, startY, fullWidth, ctlHeight)
        place(version, startX, below(header), fullWidth, ctlHeight)
        place(leaderStatusLabel, startX, below(version), thirdWidth, ctlHeight)
        place(leaderStatus, after(leaderStatusLabel), below(version), twoThirdsWidth, ctlHeight)
        place(numPlayersLabel, startX, below(leaderStatus), thirdWidth, ctlHeight)
        place(numPlayers, after(numPlayersLabel), below(leaderStatus), twoThirdsWidth, ctlHeight)
        place(localRemoteLabel, startX, below(numPlayers), thirdWidth, ctlHeight)
        place(localRemote,after(localRemoteLabel), below(numPlayers), twoThirdsWidth, ctlHeight)
        place(tokenLabel, startX, below(localRemote), thirdWidth, ctlHeight)
        place(token, after(tokenLabel), below(localRemote), twoThirdsWidth,  ctlHeight)
        editToken.frame = token.frame
        nickNameLabel.frame = tokenLabel.frame.offsetBy(dx: 0, dy: ctlHeight + spacer)
        nickName.frame = token.frame.offsetBy(dx: 0, dy: ctlHeight + spacer)
        editNickName.frame = nickName.frame
        place(nextButton, startX, below(nickName), fullWidth, ctlHeight)
        rememberForgetButton.frame = nextButton.frame.offsetBy(dx: 0, dy: ctlHeight + spacer)
        findPlayersButton.frame = rememberForgetButton.frame.offsetBy(dx: 0, dy: ctlHeight + spacer)
    }

    // Actions

    // Respond to touch of the leaderStatus control by changing the value in the control and the settings and adjusting other elements
    // of the game accordingly
    @objc func leaderStatusTouched() {
        if settings.leadPlayer {
            // Was on, toggle off
            settings.leadPlayer = false
            leaderStatus.text = NonleaderText
            hide(vc.optionsButton, numPlayersLabel, numPlayers)
        } else {
            // Was off, toggle on
            settings.leadPlayer = true
            leaderStatus.text = LeaderText
            unhide(vc.optionsButton, numPlayersLabel, numPlayers)
        }
    }

    // Respond to touch of the local/remote control by changing the value in the control and the settings and adjusting other elements
    // of the game accordingly.
    @objc func localRemoteTouched() {
        if localRemote.text == RemoteText {
            // Was remote, toggle to local
            settings.communication = .MultiPeer
            setRemoteControlsHidden(true)
            localRemote.text = LocalText
        } else {
            // was local, toggle to remote
            setRemoteControlsHidden(false) // shows initial group
            localRemote.text = RemoteText
        }
    }

    // Respond to touch of the next button by going to the next remembered token
    @objc func nextTouched() {
        nextGroup()
    }

    // Respond to touch of the remember / forget button
    @objc func rememberForgetTouched() {
        if rememberForgetButton.titleLabel?.text == ForgetTitle {
            doForget()
        } else {
            doGroupSave()
        }
    }

    // Logic for saving what the user has entered when editing a group defintion
    func doGroupSave() {
        guard let token = editToken.text, token.count > 0 else {
            bummer(title: MissingToken, message: MissingToken, host: self)
            return
        }
        serverGames.storeEntry(token, editNickName.text)
        settings.communication = .ServerBased(token)
        showGroup(editNickName.text, token)
        editToken.text = nil
        editNickName.text = nil
    }

    // Logic for moving to the next group when a group is displayed (assumes the group is not being edited)
    func nextGroup() {
        if let current = token.text, current.count > 0 {
            if let nextPair = serverGames.next(current) {
                showGroup(nextPair.nickName, nextPair.token)
            } else {
                showBlankGroup()
            }
        } else if let initialGroup = serverGames.first {
            showGroup(initialGroup.nickName, initialGroup.token)
        } // else no group was showing and there is no group to show so 'next' is a no-op
    }

    // Respond to touch of the rememberForget button when it's titled "forget"
    func doForget() {
        if token.isHidden {
            // In edit mode, not yet saved
            editToken.text = nil
            editNickName.text = nil
        } else {
            // Delete the present entry
            guard let current = token.text else {
                return // strange situation, but be robust
            }
            nextGroup()
            serverGames.remove(current)
            if let next = token.text {
                settings.communication = .ServerBased(next)
            }
        }
    }

    // Respond to touch of the find players button
    @objc func findPlayersTouched() {
        Logger.log("Find Players Touched")
        vc.startPlayerSearch()
        Logger.logDismiss(self, host: vc, animated: true)
    }

    // Subroutines

    // Hide some controls
    func hide(_ ctls: UIView...) {
        for ctl in ctls {
            ctl.isHidden = true
        }
    }

    // Unhide some controls
    func unhide(_ ctls: UIView...) {
        for ctl in ctls {
            ctl.isHidden = false
        }
    }

    // Show a specific remote in this dialog (assumes isRemote is true and that the labels are showing)
    func showGroup(_ name: String?, _ tokenText: String) {
        unhide(nickName, token)
        hide(editNickName, editToken)
        editNickName.text = nil
        editToken.text = nil
        nickName.text = name
        token.text = tokenText
        rememberForgetButton.setTitle(ForgetTitle, for: .normal)
    }

    // Show a blank group to be filled in by the user (assumes remote and that the labels are showing)
    func showBlankGroup() {
        unhide(editNickName, editToken)
        hide(nickName, token)
        nickName.text = nil
        token.text = nil
        editNickName.placeholder = NickNamePlaceholder
        editToken.placeholder = TokenPlaceholder
        rememberForgetButton.setTitle(SaveTitle, for: .normal)
    }

    // Show the appropriate initial group (assuming remote and that the labels are showing)
    func showInitialGroup() {
        if let pair = serverGames.first {
            settings.communication = .ServerBased(pair.token)
            showGroup(pair.nickName, pair.token)
        } else {
            // settings not modified in this case; will be modified later when editing completes
            showBlankGroup()
        }
    }

    // Set the remote controls hidden or not
    func setRemoteControlsHidden(_ hidden: Bool) {
        if hidden {
            hide(token, nickName, tokenLabel, nickNameLabel, editNickName, editToken, nextButton, rememberForgetButton)
        } else {
            unhide(tokenLabel, nickNameLabel, nextButton, rememberForgetButton)
            showInitialGroup()
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
}

// Conform to UITextFieldDelegate
extension PlayerManagementDialog: UITextFieldDelegate {

}

// Conform to StepperDelegate
extension PlayerManagementDialog: StepperDelegate {
    func valueChanged(_ stepper: Stepper) {
        settings.numPlayers = stepper.value
        findPlayersButton.isHidden = settings.numPlayers < 2
    }

    func displayText(_ value: Int) -> String {
        return String(value)
    }
}
