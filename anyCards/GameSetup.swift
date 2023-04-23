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

// Dialog for game setup in AnyCards
class GameSetupDialog : UIViewController {
    // Parent view controller
    var vc : ViewController {
        if let ans = presentingViewController as? ViewController {
            return ans
        }
        Logger.logFatalError("Could not retrieve ViewController within GameSetupDialog")
    }

    // Terser reference to settings
    var settings : OptionSettings {
        return OptionSettings.instance
    }

    // Controls
    let header = UILabel()                    // First Row
    let deckTypeLabel = UILabel()             // Second row, left
    let deckType = TouchableLabel()           // Second row, right
    let handAreaLabel = UILabel()             // Third row, left
    let handArea = TouchableLabel()           // Third row, right
    let dealButton = UIButton()               // Fourth row
    let saveButton = UIButton()               // Fifth row
    let useButton = UIButton()                // Sixth row
    let resetButton = UIButton()              // Seventh row
    let doneButton = UIButton()               // Eighth row

    init() {
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = GameSetupSize
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

        // Deal button
        configureButton(dealButton, title: DealTitle, target: self, action: #selector(dealTouched), parent: view)
        if !vc.canDeal || !vc.boxViews.contains(where: { $0.name == DeckBoxName }) {
            dealButton.isHidden = true
        }

        // Save button
        configureButton(saveButton, title: SaveSetupTitle, target: self, action: #selector(saveTouched), parent: view)

        // Use button
        configureButton(useButton, title: UseButtonTitle, target: self, action: #selector(useTouched), parent: view)
        if savedSetups.setups.count == 0 {
            useButton.isHidden = true
        }

        // Reset
        configureButton(resetButton, title: ResetTitle, target: self, action: #selector(resetTouched), parent: view)

        // Done button
        configureButton(doneButton, title: DoneTitle, target: self, action: #selector(doneTouched), parent: view)
    }

    // When view appears, we do layout
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let fullHeight = min(preferredContentSize.height, view.bounds.height) - 2 * DialogEdgeMargin
        let fullWidth = min(preferredContentSize.width, view.bounds.width) - 2 * DialogEdgeMargin
        let ctlHeight = (fullHeight - 7 * DialogSpacer - 2 * DialogEdgeMargin) / 8
        let ctlWidth = (fullWidth - DialogSpacer) / 2
        let startX = (view.bounds.width / 2) - (fullWidth / 2)
        let startY = (view.bounds.height / 2) - (fullHeight / 2)
        place(header, startX, startY, fullWidth, ctlHeight)
        place(deckTypeLabel, startX, below(header), ctlWidth, ctlHeight)
        place(deckType, after(deckTypeLabel), below(header), ctlWidth, ctlHeight)
        place(handAreaLabel, startX, below(deckType), ctlWidth, ctlHeight)
        place(handArea, after(handAreaLabel), below(deckType), ctlWidth, ctlHeight)
        place(dealButton, startX, below(handArea), fullWidth, ctlHeight)
        place(saveButton, startX, below(dealButton), fullWidth, ctlHeight)
        place(useButton, startX, below(saveButton), fullWidth, ctlHeight)
        place(resetButton, startX, below(useButton), fullWidth, ctlHeight)
        place(doneButton, startX, below(resetButton), fullWidth, ctlHeight)
    }

    // Actions

    // Respond to touch of the deck type label by cycling through the available options
    @objc func deckTypeTouched() {
        let newDeckType = Decks.next(settings.deckType.displayName)
        deckType.text = newDeckType.displayName
        settings.deckType = newDeckType
        vc.newShuffle()
        vc.transmit()
    }

    // Respond to touch of the 'hand area" touchable label by toggling between present and absent
    @objc func handAreaTouched() {
        let newValue = !settings.hasHands
        settings.hasHands = newValue
        handArea.text = newValue ? HandAreaYes : HandAreaNo
        vc.transmit()
    }

    // Respond to touch of deal button.  Opens the dialog for dividing the contents of a gridbox (default "deck") into other gridboxes.
    @objc func dealTouched() {
        guard let deck = vc.boxViews.first(where: { $0.name == DeckBoxName }) else {
            return // shouldn't happen because deal button should be hidden if there is no deck
        }
        let dialog = DealingDialog(deck, vc)
        Logger.logDismiss(self, host: vc, animated: true)
        Logger.logPresent(dialog, host: vc, animated: false)
    }

    // Respond to touch of save button.  Prompts for a name.  May also prompt for overwrite if the name is in use
    @objc func saveTouched() {
        let host = vc
        Logger.logDismiss(self, host: vc, animated: true)
        promptForName(host)
    }

    // Respond to touch of use button.  Brings up a table dialog with a list of saved setups
    @objc func useTouched() {
        let preferredSize = TableDialogController.getPreferredSize(savedSetups.setups.count)
        let buttonFrame = vc.gameSetupButton.frame
        let anchor = CGPoint(x: buttonFrame.midX, y: buttonFrame.maxY)
        let popup = RestoreSetupDialog(vc, size: preferredSize, anchor: anchor)
        Logger.logDismiss(self, host: vc, animated: true)
        Logger.logPresent(popup, host: vc, animated: true)
    }

    // Respond to touch of reset button.  Returns the setup to the initial state implied by decktype and hand area
    @objc func resetTouched() {
        vc.newShuffle()
    }

    // Respond to touch of done button.  Just does a self-dismiss
    @objc func doneTouched() {
        Logger.logDismiss(self, host: vc, animated: true)
    }

    // Other functions

    // Prompt for a saved setup name.  Storing the saved setup will first fail if the name conflicts with an existing
    // saved setup.  In that case there is a second prompt asking if you want to overwrite and the setup will be saved
    // (overwriting) if you agree.
    func promptForName(_ vc: ViewController) {
        let alert = UIAlertController(title: SaveSetupTitle, message: ChooseNameMessage, preferredStyle: .alert)
        let cancel = UIAlertAction(title: CancelButtonTitle, style: .cancel) { _ in
            // Do nothing
        }
        let useName = UIAlertAction(title: ConfirmButtonTitle, style: .default) { _ in
            if let newName = alert.textFields?.first?.text {
                let state = vc.saveGameState()
                let ok = savedSetups.storeEntry(newName, state, false)
                if !ok {
                    Logger.logDismiss(alert, host: vc, animated: true)
                    self.promptForOverwrite(vc, newName, state)
                }
            }
        }
        alert.addTextField() { field in
            field.placeholder = ChooseNameMessage
        }
        alert.addAction(cancel)
        alert.addAction(useName)
        Logger.logPresent(alert, host: vc, animated: true)
    }

    // Secondary prompt if a saved setup would overwrite an existing one
    func promptForOverwrite(_ vc: ViewController, _ name: String, _ state: GameState) {
        let overwriteMessage = String(format: OverwriteSetupTemplate, name)
        let alert = UIAlertController(title: OverwriteSetupTitle, message: overwriteMessage, preferredStyle: .alert)
        let cancel = UIAlertAction(title: CancelButtonTitle, style: .cancel) { _ in
            // Do nothing
        }
        let useName = UIAlertAction(title: ConfirmButtonTitle, style: .default) { _ in
             savedSetups.storeEntry(name, state, true)
        }
        alert.addAction(cancel)
        alert.addAction(useName)
        Logger.logPresent(alert, host: vc, animated: true)
    }
}
