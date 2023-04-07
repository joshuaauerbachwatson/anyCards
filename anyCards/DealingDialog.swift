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

// Dialog for dealing cards in Any Old Card Game
class DealingDialog : UIViewController {
    // The main view controller (not necessarily the presenting controller for this controller)
    let vc : ViewController

    // Terser reference to settings
    var settings : OptionSettings {
        return OptionSettings.instance
    }

    // Model information
    let box: GridBox
    var hands = DealingHandsDefault
    var cards = DealingCardsDefault

    // Controls
    let header = UILabel()         // First row
    let handsStepper = Stepper()   // Second row, first half
    let handsLabel = UILabel()     // Second row, second half
    let cardsStepper = Stepper()   // Third row, first half
    let cardsLabel = UILabel()     // Third row, second half
    let errorLabel = UILabel()     // Fourth Row
    let confirmButton = UIButton() // Fourth Row
    let cancelButton = UIButton()  // Fifth Row

    init(_ box: GridBox, _ vc: ViewController) {
        self.box = box
        self.vc = vc
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
        if let name = box.name {
            header.text = String(format: DealingHeaderTemplate, name)
        } else {
            header.text = DealingHeaderUnnamed
        }

        // Steppers and their associated labels
        configureStepper(handsStepper, delegate: self, value: hands, parent: view)
        configureStepper(cardsStepper, delegate: self, value: cards, parent: view)
        configureLabel(handsLabel, LabelBackground, parent: view)
        handsLabel.text = HandsLabelText
        configureLabel(cardsLabel, LabelBackground, parent: view)
        cardsLabel.text = CardsLabelText
        handsStepper.minimumValue = DealingHandsMin
        handsStepper.maximumValue = DealingHandsMax
        cardsStepper.minimumValue = DealingCardsMin
        cardsStepper.maximumValue = DealingCardsMax

        // Error label and confirm button.  Only one will show but we don't decide which yet.
        configureLabel(errorLabel, LabelBackground, parent: view)
        errorLabel.textColor = .red
        configureButton(confirmButton, title: ConfirmButtonTitle, target: self, action: #selector(confirmTouched), parent: view)

        // Cancel button
        configureButton(cancelButton, title: CancelButtonTitle, target: self, action: #selector(cancelTouched), parent: view)
    }

    // When view appears, we do layout and validate the initial values
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let spacer = DialogSpacer
        let margin = DialogEdgeMargin
        let fullHeight = min(preferredContentSize.height, view.bounds.height) - 2 * margin
        let fullWidth = min(preferredContentSize.width, view.bounds.width) - 2 * margin
        let ctlHeight = (fullHeight - 4 * spacer - 2 * margin) / 5
        let ctlWidth = (fullWidth - spacer) / 2
        let startX = (view.bounds.width / 2) - (fullWidth / 2)
        let startY = (view.bounds.height / 2) - (fullHeight / 2)
        place(header, startX, startY, fullWidth, ctlHeight)
        place(handsStepper, startX, below(header), ctlWidth, ctlHeight)
        place(handsLabel, after(handsStepper), below(header), ctlWidth, ctlHeight)
        place(cardsStepper, startX, below(handsStepper), ctlWidth, ctlHeight)
        place(cardsLabel, after(cardsStepper), below(handsStepper), ctlWidth, ctlHeight)
        place(errorLabel, startX, below(cardsStepper), fullWidth, ctlHeight)
        confirmButton.frame = errorLabel.frame
        place(cancelButton, startX, below(confirmButton), fullWidth, ctlHeight)
        validate()
    }

    // Actions

    // Respond to touching of the confirm button
    @objc func confirmTouched() {
        performDeal()
        cancelTouched()
    }

    // Respond to touching of the cancel button
    @objc func cancelTouched() {
        if let vc = presentingViewController {
            Logger.logDismiss(self, host: vc, animated: false)
        }
    }

    // Subroutines

    // Validate the current settings for the deal and decide whether to post an error message.   Either the errorLabel or the confirmButton
    // will show, never both.
    private func validate() {
        if hands * cards > box.cards.count {
            postError(NotEnoughCards)
            return
        }
        if hands > handsCapacity(box.frame) {
            postError(TooManyHands)
            return
        }
        errorLabel.isHidden = true
        confirmButton.isHidden = false
    }

    // Post an error and inhibit dialog confirmation
    private func postError(_ msg: String) {
        errorLabel.text = msg
        errorLabel.isHidden = false
        confirmButton.isHidden = true
    }

    // Test whether there is enough room to place the hands
    private func handsCapacity(_ deckFrame: CGRect) -> Int {
        var ans = 0
        var next = deckFrame.offsetBy(dx: deckFrame.width, dy: 0)
        while canBePlaced(next) {
            ans += 1
            next = next.offsetBy(dx: deckFrame.width, dy: 0)
        }
        return ans
    }

    // Decide whether a box frame can be placed (does not overlap any other view)
    private func canBePlaced(_ frame: CGRect) -> Bool {
        if !vc.publicArea.contains(frame) {
            Logger.log("Frame is outside public area")
            return false
        }
        for view in vc.playingArea.subviews {
            if frame.intersects(view.frame) {
                Logger.log("Frame was found to intersect \(view.frame)")
                return false
            }
        }
        Logger.log("Frame can be placed")
        return true
    }

    // Perform the actual deal
    private func performDeal() {
        var origin = CGPoint(x: box.frame.maxX, y: box.frame.minY)
        for i in 0..<hands {
            let hand = GridBox(origin: origin, size: box.snapFrame.size, host: vc)
            origin.x += box.frame.width
            vc.playingArea.addSubview(hand)
            hand.name = "Hand \(i+1)"
            for _ in 0..<cards {
                hand.snapUp(box.cards[0])
            }
            hand.refreshCount()
        }
        box.refreshCount()
    }
}

extension DealingDialog: StepperDelegate {
    func valueChanged(_ stepper: Stepper) {
        cards = cardsStepper.value
        hands = handsStepper.value
        self.validate()
    }

    func displayText(_ value: Int) -> String {
        return String(value)
    }
}
