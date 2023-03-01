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

// Dialog for managing groups in the AnyCards Game
// Note: groups are associated with the backend server.  When using MultiPeer, there is implicitly
// just one group, consisting of those who are "nearby."
class GroupManagementDialog : UIViewController, UITextFieldDelegate {
    // Parent view controller
    var vc : ViewController {
        if let ans = presentingViewController as? ViewController {
            return ans
        }
        Logger.logFatalError("Could not retrieve ViewController within GroupManagementDialog")
    }

    // Terser reference to settings
    var settings : OptionSettings {
        return OptionSettings.instance
    }

    // Place to save group name during rename dialog
    var savedGroupName: String = ""

    // Controls
    let currentGroup = UILabel()
    let nextButton = UIButton()
    let groupNameLabel = UILabel()
    let groupName = UITextField()
    let tokenLabel = UILabel()
    let token = UITextField()
    let copyToken = UIButton()
    let renameGroup = UIButton()
    let deleteGroup = UIButton()
    let joinGroup = UIButton()
    let createGroup = UIButton()
    let confirmButton = UIButton()
    let cancelButton = UIButton()
    let doneButton = UIButton()

    // Flags to control writeable status of the text fields
    var writeable: [Bool] = [ false, false ]

    init() {
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = OptionSettingsSize // borrowed
        modalPresentationStyle = UIModalPresentationStyle.formSheet
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Convenience utilities for setting text fields writeable or readonly
    func setWriteable(_ field: UITextField) {
        writeable[field.tag] = true
        field.backgroundColor = .yellow
    }

    func setReadOnly(_ field: UITextField) {
        writeable[field.tag] = false
        field.backgroundColor = LabelBackground
        field.endEditing(true)
    }

    // Enforce readonly / writeable distinction for text fields using UITextFieldDelegate protocol
    func textFieldShouldBeginEditing(_ field: UITextField) -> Bool {
        return writeable[field.tag]
    }

    // Get the initial group to show, if any.  Used when the dialog starts up and when the next button is
    // pressed when no group is showing.  Returns a tuple consisting of name and token.
    func getInitialGroup() -> (String, String)? {
        switch settings.communication {
        case .MultiPeer:
            if let firstGroup = serverGames.names.first, let firstToken = serverGames.getToken(firstGroup) {
                return (firstGroup, firstToken)
            } else {
                return nil
            }
        case .ServerBased(let firstGroup):
            // Start with the current active group
            if let firstToken = serverGames.getToken(firstGroup) {
                return (firstGroup, firstToken)
            } else {
                return nil
            }
        }
    }

    // Show a specific group in this dialog
    func showGroup(_ name: String, _ tokenText: String) {
        groupName.text = name
        setReadOnly(groupName)
        token.text = tokenText
        setReadOnly(token)
        copyToken.isHidden = false
        renameGroup.isHidden = false
        deleteGroup.isHidden = false
        confirmButton.isHidden = true
        cancelButton.isHidden = true
        joinGroup.isHidden = true
        createGroup.isHidden = true
        nextButton.isHidden = false
        doneButton.isHidden = false
        vc.groupLabel.text = name
        currentGroup.text = CurrentGroupPrefix + name
    }

    // Setup the dialog for creating groups or joining groups
    func setupForNewGroup() {
        groupName.text = nil
        groupName.placeholder = NoGroupPlaceholder
        setReadOnly(groupName)
        token.text = nil
        token.placeholder = NoGroupPlaceholder
        setReadOnly(token)
        copyToken.isHidden = true
        renameGroup.isHidden = true
        deleteGroup.isHidden = true
        confirmButton.isHidden = true
        cancelButton.isHidden = true
        joinGroup.isHidden = false
        createGroup.isHidden = false
        nextButton.isHidden = false
        doneButton.isHidden = false
        vc.groupLabel.text = LocalOnly
        currentGroup.text = CurrentGroupPrefix + LocalOnly
    }

    // Enumerate the operations that use the confirm/cancel state
    enum ConfirmOp : Int {
        case JoinGroup, CreateGroup, RenameGroup
    }

    // Set the dialog into confirm/cancel mode
    func setConfirmCancel(_ tag: ConfirmOp) {
        confirmButton.isHidden = false
        confirmButton.tag = tag.rawValue
        cancelButton.isHidden = false
        cancelButton.tag = tag.rawValue
        copyToken.isHidden = true
        renameGroup.isHidden = true
        deleteGroup.isHidden = true
        joinGroup.isHidden = true
        createGroup.isHidden = true
        nextButton.isHidden = true
        doneButton.isHidden = true
    }

    // When view loads, we finish initializing the controls (except for layout) and make them into subviews
    override func viewDidLoad() {
        view.backgroundColor = SettingsDialogBackground // borrowed

        // Current group
        configureLabel(currentGroup, SettingsDialogBackground, parent: view)

        // group name and label (excepting the name itself)
        configureLabel(groupNameLabel, SettingsDialogBackground, parent: view)
        groupNameLabel.text = GroupNameLabelText
        groupNameLabel.textAlignment = .right
        configureTextField(groupName, LabelBackground, parent: view)
        groupName.font = getTextFont()
        groupName.tag = 0
        groupName.delegate = self

        // token and label (excepting the token itself)
        configureLabel(tokenLabel, SettingsDialogBackground, parent: view)
        tokenLabel.text = TokenLabelText
        tokenLabel.textAlignment = .right
        configureTextField(token, LabelBackground, parent: view)
        token.font = getTextFont()
        token.tag = 1
        token.delegate = self

        // Determine if there is a group to display and set up the dialog either to edit that group or
        // to show only the join and create functions, whichever is more appropriate.
        if let firstGroup = getInitialGroup() {
            showGroup(firstGroup.0, firstGroup.1)
        } else {
            setupForNewGroup()
        }

        // Buttons
        configureButton(nextButton, title: NextButtonTitle, target: self, action: #selector(nextButtonTouched),
                        parent: view)
        configureButton(copyToken, title: CopyTokenTitle, target: self, action: #selector(copyTokenTouched),
                        parent: view)
        configureButton(joinGroup, title: JoinGroupTitle, target: self, action: #selector(joinGroupTouched),
                        parent: view)
        configureButton(createGroup, title: CreateGroupTitle, target: self, action: #selector(createGroupTouched),
                        parent: view)
        configureButton(renameGroup, title: RenameGroupTitle, target: self, action: #selector(renameGroupTouched),
                        parent: view)
        configureButton(deleteGroup, title: DeleteGroupTitle, target: self, action: #selector(deleteGroupTouched),
                        parent: view)
        configureButton(doneButton, title: DoneButtonTitle, target: self, action: #selector(doneButtonTouched),
                        parent: view)
        configureButton(confirmButton, title: ConfirmButtonTitle, target: self, action: #selector(confirmButtonTouched), parent: view)
        configureButton(cancelButton, title: CancelButtonTitle, target: self, action: #selector(cancelButtonTouched), parent: view)
    }

    // When view appears, we do layout
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let spacer = OptionSettingsSpacer // borrowed
        let margin = OptionSettingsEdgeMargin // borrowed
        let ctlHeight = (view.bounds.height - 7 * spacer - 2 * margin) / 8
        let fullWidth = view.bounds.width - 2 * margin
        let quarterWidth = (fullWidth - 3 * spacer) / 4
        let threeQuarterWidth = 3 * quarterWidth + 2 * spacer
        currentGroup.frame = CGRect(x: view.bounds.minX + margin, y: view.bounds.minY + margin, width: fullWidth,
                              height: ctlHeight)
        nextButton.frame = currentGroup.frame.offsetBy(dx: 0, dy: ctlHeight + spacer)
        groupNameLabel.frame = CGRect(x: view.bounds.minX + margin, y: nextButton.frame.maxY + spacer, width: quarterWidth, height: ctlHeight)
        groupName.frame = CGRect(x: groupNameLabel.frame.maxX + spacer, y: nextButton.frame.maxY + spacer,
                                 width: threeQuarterWidth, height: ctlHeight)
        tokenLabel.frame = groupNameLabel.frame.offsetBy(dx: 0, dy: ctlHeight + spacer)
        token.frame = groupName.frame.offsetBy(dx: 0, dy: ctlHeight + spacer)
        copyToken.frame = CGRect(x: view.bounds.minX + margin, y: tokenLabel.frame.maxY + spacer, width: fullWidth,
                                 height: ctlHeight)
        renameGroup.frame = copyToken.frame.offsetBy(dx: 0, dy: ctlHeight + spacer)
        deleteGroup.frame = renameGroup.frame.offsetBy(dx: 0, dy: ctlHeight + spacer)
        doneButton.frame = deleteGroup.frame.offsetBy(dx: 0, dy: ctlHeight + spacer)
        joinGroup.frame = renameGroup.frame
        createGroup.frame = deleteGroup.frame
        confirmButton.frame = renameGroup.frame
        cancelButton.frame = deleteGroup.frame
    }

    // Actions

    // Respond to touch of the next button.  When the dialog is set up for new group creation, the "next" group
    // is the initial group, if any, or else there is no "next" (the button is a no-op).  When the dialog is set
    // up with an actual group, the next group is defined by the serverGames.next function, or, if there is
    // no "next" according to that function, we set up fo new group creation.
    @objc func nextButtonTouched() {
        if let current = groupName.text, current.count > 0 {
            if let nextGroup = serverGames.next(current), let nextToken = serverGames.getToken(nextGroup) {
                showGroup(nextGroup, nextToken)
            } else {
                setupForNewGroup()
            }
        } else if let initialGroup = getInitialGroup() {
            showGroup(initialGroup.0, initialGroup.1)
        } // else no group was showing and there is no group to show so 'next' is a no-op
    }

    // Respond to touch of the copyToken button.  The requirement to copy the token to the pasteboard
    // can be met with a trivial one-liner but we need some visual confirmation to the user that this
    // has been done.  We flash the text color of the token red for one second.
    @objc func copyTokenTouched() {
        // Do the action
        UIPasteboard.general.string = token.text
        // Show the user
        let textColor = token.textColor
        token.textColor = UIColor.red
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.token.textColor = textColor
        }
    }

    // Respond to touch of joinGroup button
    @objc func joinGroupTouched() {
        groupName.placeholder = GroupNamePlaceholder
        setWriteable(groupName)
        token.placeholder = TokenPlaceholder
        setWriteable(token)
        setConfirmCancel(.JoinGroup)
    }

    // Respond to touch of the createGroup button
    @objc func createGroupTouched() {
        groupName.placeholder = GroupNamePlaceholder
        setWriteable(groupName)
        token.placeholder = GenerateTokenPlaceholder
        setReadOnly(token)
        setConfirmCancel(.CreateGroup)
    }

    // Respond to touch of the renameGroup button
    @objc func renameGroupTouched() {
        groupName.placeholder = GroupNamePlaceholder
        setWriteable(groupName)
        savedGroupName = groupName.text?.trim() ?? ""
        setReadOnly(token)
        setConfirmCancel(.RenameGroup)
    }

    // Respond to touch of the deleteGroup button
    @objc func deleteGroupTouched() {
        guard let groupName = self.groupName.text?.trim() else {
            self.vc.error(ServerError("There is no group shown.  Deletion not possible."), false)
            return
        }
        let currentToken = token.text?.trim()
        showDeleteDialog(host: self) { (remote, force) in
            serverGames.remove(groupName)
            self.settings.communication = self.settings.communication.next
            if let nextGroup = serverGames.next(groupName), let nextToken = serverGames.getToken(nextGroup) {
                self.showGroup(nextGroup, nextToken)
            } else {
                self.setupForNewGroup()
            }
            if remote {
                guard let token = currentToken else {
                    self.vc.error(ServerError("There is no token shown.  Only local deletion was performed."), false)
                    return
                }
                let errHandler = self.vc.error
                var arg: Data
                do {
                    arg = try JSONEncoder().encode([ "gameToken": token, "force": String(force) ])
                } catch {
                    errHandler(error, false)
                    return
                }
                postAnAction(pathDelete, arg) { (data, response, err ) in
                    _ = validateResponse(data,response, err, Dictionary<String,String>.self, errHandler)
                }
            }
        }
    }

    // Respond to touch of the 'done' button
    @objc func doneButtonTouched() {
        if let vc = presentingViewController {
            Logger.logDismiss(self, host: vc, animated: true)
        }
    }

    // Respond to touch of the 'confirm' button
    @objc func confirmButtonTouched(_ button: UIButton) {
        func bail() {
            let insufficient = ServerError("Insufficient information was given make the requested change")
            vc.error(insufficient, true)
            cancelButtonTouched(button)
        }
        guard let name = groupName.text?.trim() else {
            bail()
            return
        }
        if button.tag == ConfirmOp.CreateGroup.rawValue {
            generateNewGroupToken(name)
        } else {
            guard let token = token.text?.trim() else {
                bail()
                return
            }
            serverGames.storeEntry(name, token, false)
            settings.communication = .ServerBased(name)
            showGroup(name, token)
        }
    }

    // Function to create a new game in the backend, returning a token
    func generateNewGroupToken(_ groupName: String) {
        let errHandler = self.vc.error
        var arg: Data
        do {
            arg = try JSONEncoder().encode([ argAppToken: AppToken ])
        } catch {
            errHandler(error, false)
            return
        }
        postAnAction(pathCreate, arg) { (data, response, err ) in
            guard let result = validateResponse(data,response, err, Dictionary<String,String>.self, errHandler) else {
                // Error already displayed by validator
                DispatchQueue.main.async {
                    self.cancelButtonTouched(self.cancelButton)
                }
                return
            }
            if let token = result[argGameToken] {
                serverGames.storeEntry(groupName, token, true)
                self.settings.communication = .ServerBased(groupName)
                DispatchQueue.main.async {
                    self.showGroup(groupName, token)
                }
            } else {
                DispatchQueue.main.async {
                    errHandler(ServerError("No gameToken in response or response was invalid"), false)
                    self.cancelButtonTouched(self.cancelButton)
                }
            }
        }
    }

    // Respond to touch of the 'cancel' button
    @objc func cancelButtonTouched(_ button: UIButton) {
        switch button.tag {
        case ConfirmOp.JoinGroup.rawValue, ConfirmOp.CreateGroup.rawValue:
            setupForNewGroup()
        case ConfirmOp.RenameGroup.rawValue:
            guard let token = token.text?.trim() else {
                Logger.logFatalError("Internal error: token not present during rename")
            }
            guard savedGroupName.count > 0 else {
                Logger.logFatalError("Internal error: Group name not saved during rename")
            }
            showGroup(savedGroupName, token)
            savedGroupName = ""
        default:
            Logger.logFatalError("Internal error: button tagged with \(button.tag) in cancel handler")
        }
    }

    // Subroutines

    // Build the special delete dialog with separate actions for self-only, all, force
    func showDeleteDialog(host: UIViewController, _ handler: @escaping (Bool, Bool) -> Void) {
        let alert = UIAlertController(title: DeleteGroupTitle, message: DeleteGroupMessage, preferredStyle: .alert)
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            // Do nothing
        }
        let selfOnly = UIAlertAction(title: SelfOnlyTitle, style: .default) { _ in
            handler(false, false)
        }
        let forAll = UIAlertAction(title: ForAllTitle, style: .default) { _ in
            handler(true, false)
        }
        let withForce = UIAlertAction(title: WithForceTitle, style: .default) { _ in
            handler(true, true)
        }
        alert.addAction(cancel)
        alert.addAction(selfOnly)
        alert.addAction(forAll)
        alert.addAction(withForce)
        Logger.logPresent(alert, host: host, animated: true)
    }
}
