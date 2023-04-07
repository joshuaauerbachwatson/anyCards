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
        Logger.logFatalError("Could not retrieve ViewController within OptionSettingsDialog")
    }

    // Terser referene to settings
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
    // TODO add controls to name the current configuration, save it, retrieve it
    let doneButton = UIButton()               // Fifth row

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

        // Done button
        configureButton(doneButton, title: DoneTitle, target: self, action: #selector(doneTouched), parent: view)
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
        place(deckTypeLabel, startX, below(header), ctlWidth, ctlHeight)
        place(deckType, after(deckTypeLabel), below(header), ctlWidth, ctlHeight)
        place(handAreaLabel, startX, below(deckType), ctlWidth, ctlHeight)
        place(handArea, after(handAreaLabel), below(deckType), ctlWidth, ctlHeight)
        place(dealButton, startX, below(handArea), fullWidth, ctlHeight)
        place(doneButton, startX, below(dealButton), fullWidth, ctlHeight)
    }

    // Actions

    // Respond to touch of the deck type label by cycling through the available options
    @objc func deckTypeTouched() {
        let newDeckType = Decks.next(settings.deckType.displayName)
        deckType.text = newDeckType.displayName
        settings.deckType = newDeckType
        vc.newShuffle()
    }

    // Respond to touch of the 'hand area" touchable label by toggling between present and absent
    @objc func handAreaTouched() {
        let newValue = !settings.hasHands
        settings.hasHands = newValue
        handArea.text = newValue ? HandAreaYes : HandAreaNo
        vc.newShuffle()
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

    // Respond to touch of done button.  Just does a self-dismiss
    @objc func doneTouched() {
        Logger.logDismiss(self, host: vc, animated: true)
    }
}
