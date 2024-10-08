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

// Dialog for dealing cards in Any Old Card Game
class DealingDialog : UIViewController {
    // The main view controller (not necessarily the presenting controller for this controller)
    let vc : ViewController
    
    // The selected "target kind" (initially "Hands")
    var targetKind = TargetKind.Hands

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
    let handsLabel = UILabel()     // Second row, first half
    let handsStepper = Stepper()   // Second row, second half
    let cardsLabel = UILabel()     // Third row, first half
    let cardsStepper = Stepper()   // Third row, second half
    let targetLabel = UILabel()     // Fourth row, left
    let target = TouchableLabel()   // Fourth row, right
    let errorLabel = UILabel()     // Fifth Row
    let confirmButton = UIButton() // Fifth Row
    let cancelButton = UIButton()  // Sixth Row

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
        configureLabel(handsLabel, SettingsDialogBackground, parent: view)
        handsLabel.text = "# Targets"
        configureLabel(cardsLabel, SettingsDialogBackground, parent: view)
        cardsLabel.text = "Cards per Target"
        handsStepper.minimumValue = DealingHandsMin
        handsStepper.maximumValue = DealingHandsMax
        cardsStepper.minimumValue = DealingCardsMin
        cardsStepper.maximumValue = DealingCardsMax

        // Owned indicator and its label
        configureLabel(targetLabel, SettingsDialogBackground, parent: view)
        targetLabel.text = "Target Type"
        targetLabel.textAlignment = .right
        configureTouchableLabel(target, target: self, action: #selector(targetTouched), parent: view)
        target.text = targetKind.display
        target.view.font = getTextFont()
        target.view.backgroundColor = LabelBackground

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
        let ctlHeight = (fullHeight - 5 * spacer - 2 * margin) / 6
        let ctlWidth = (fullWidth - spacer) / 2
        let startX = (view.bounds.width / 2) - (fullWidth / 2)
        let startY = (view.bounds.height / 2) - (fullHeight / 2)
        place(header, startX, startY, fullWidth, ctlHeight)
        place(handsLabel, startX, below(header), ctlWidth, ctlHeight)
        place(handsStepper, after(handsLabel), below(header), ctlWidth, ctlHeight)
        place(cardsLabel, startX, below(handsStepper), ctlWidth, ctlHeight)
        place(cardsStepper, after(cardsLabel), below(handsStepper), ctlWidth, ctlHeight)
        place(targetLabel, startX, below(cardsLabel), ctlWidth, ctlHeight)
        place(target, after(targetLabel), below(cardsStepper), ctlWidth, ctlHeight)
        place(errorLabel, startX, below(target), fullWidth, ctlHeight)
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

    // Respond to touching of the target label
    @objc func targetTouched() {
        let preferredSize = TableDialogController.getPreferredSize(TargetKind.allCases.count)
        let anchor = CGPoint(x: target.frame.midX, y: target.frame.minY)
        let dialog = DealingTargetDialog(self, size: preferredSize, anchor: anchor)
        Logger.logPresent(dialog, host: self, animated: false)
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
        errorLabel.isHidden = true
        confirmButton.isHidden = false
    }
    
    // Sets the target kind (called from subsidiary dialog)
    func setTargetKind(_ row: Int) {
        targetKind = TargetKind.allCases[row]
        target.text = targetKind.display
    }

    // Post an error and inhibit dialog confirmation
    private func postError(_ msg: String) {
        errorLabel.text = msg
        errorLabel.isHidden = false
        confirmButton.isHidden = true
    }

    // Make an animation function for dealing single card to a specific hand
    private func makeOneCardDealFunction(_ hand: GridBox) -> ()->Void {
        func once() {
            UIView.animate(withDuration: DealCardDuration) {
                hand.snapUp(self.box.cards[0])
                hand.refreshCount()
                self.box.refreshCount()
            }
        }
        return once
    }

    // Perform the actual deal
    private func performDeal() {
        let step = vc.dealingArea.width / hands
        let start = (step - vc.cardSize.width) / 2
        var origin = CGPoint(x: vc.dealingArea.minX + start, y: vc.dealingArea.minY)
        var dealt = [GridBox]()
        for i in 0..<hands {
            let hand = GridBox(origin: origin, size: box.snapFrame.size, host: vc)
            hand.kind = targetKind.boxKind
            hand.owner = targetKind.isOwned ? i : GridBox.Unowned
            dealt.append(hand)
            origin.x += step
            vc.playingArea.addSubview(hand)
            hand.name = targetKind.isOwned ? vc.getPlayer(index: i) : "\(i)"
        }
        var animations = [()->Void]()
        for _ in 0..<cards {
            for hand in dealt {
                animations.append(makeOneCardDealFunction(hand))
            }
        }
        runAnimationSequence(animations) {
            if self.targetKind == .Piles {
                for hand in dealt {
                    hand.removeFromSuperview()
                }
            }
            self.vc.transmit()
        }
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
