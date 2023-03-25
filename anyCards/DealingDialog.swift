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
    let sources: Dictionary<String,GridBox>
    let sourceOrder: [String]
    var hands = DealingHandsDefault
    var cards = DealingCardsDefault

    // Controls
    let header = UILabel()         // First row
    let handsStepper = Stepper()   // Second row, first half
    let handsLabel = UILabel()     // Second row, second half
    let cardsStepper = Stepper()   // Third row, first half
    let cardsLabel = UILabel()     // Third row, second half
    let fromLabel = UILabel()      // Fourth row, first half
    let sourceLabel = TouchableLabel() // Fourth row, second Half
    let errorLabel = UILabel()     // Fifth Row
    let confirmButton = UIButton() // Fifth Row
    let cancelButton = UIButton()  // Sixth Row

    init(_ sources: Dictionary<String,GridBox>, _ vc: ViewController) {
        self.sources = sources
        self.sourceOrder = orderSources(sources.keys.map { String($0) })
        self.vc = vc
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
        header.text = DealingHeaderText

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

        // Source information
        configureLabel(fromLabel, LabelBackground, parent: view)
        fromLabel.text = FromLabelText
        configureTouchableLabel(sourceLabel, target: self, action: #selector(sourceLabelTouched), parent: view)
        sourceLabel.text = sourceOrder[0]
        sourceLabel.view.font = getTextFont()
        sourceLabel.view.backgroundColor = LabelBackground

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
        let spacer = OptionSettingsSpacer // borrowed
        let margin = OptionSettingsEdgeMargin // borrowed
        let fullHeight = min(preferredContentSize.height, view.bounds.height) - 2 * margin
        let fullWidth = min(preferredContentSize.width, view.bounds.width) - 2 * margin
        let ctlHeight = (fullHeight - 5 * spacer - 2 * margin) / 6
        let ctlWidth = (fullWidth - spacer) / 2
        let startX = (view.bounds.width / 2) - (fullWidth / 2)
        let startY = (view.bounds.height / 2) - (fullHeight / 2)
        header.frame = CGRect(x: startX, y: startY, width: fullWidth, height: ctlHeight)
        handsStepper.frame = CGRect(x: startX, y: header.frame.maxY + spacer, width: ctlWidth, height: ctlHeight)
        handsLabel.frame = handsStepper.frame.offsetBy(dx: ctlWidth + spacer, dy: 0)
        cardsStepper.frame = handsStepper.frame.offsetBy(dx: 0, dy: ctlHeight + spacer)
        cardsLabel.frame = cardsStepper.frame.offsetBy(dx: ctlWidth + spacer, dy: 0)
        fromLabel.frame = cardsStepper.frame.offsetBy(dx: 0, dy: ctlHeight + spacer)
        sourceLabel.frame = cardsLabel.frame.offsetBy(dx: 0, dy: ctlHeight + spacer)
        errorLabel.frame = CGRect(x: startX, y: fromLabel.frame.maxY + spacer, width: fullWidth, height: ctlHeight)
        confirmButton.frame = errorLabel.frame
        cancelButton.frame = confirmButton.frame.offsetBy(dx: 0, dy: ctlHeight + spacer)
        validate()
    }

    // Actions

    // Respond to touching of the source label
    @objc func sourceLabelTouched() {
        if let currentSource = sourceLabel.text, let currentIndex = sourceOrder.firstIndex(of: currentSource) {
            // Will be true if source label was initialized and the sourceOrder is not empty.  These pre-conditiona
            // should always be met in practice.
            let nextIndex = currentIndex + 1 % sourceOrder.count
            sourceLabel.text = sourceOrder[nextIndex]
        }
    }

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
        guard let deckName = sourceLabel.text, let deck = sources[deckName] else {
            // The source label should always have valid text and that text should denote a deck in sources.
            Logger.logFatalError(InternalDealingError)
        }
        if hands * cards > deck.cards.count {
            postError(NotEnoughCards)
            return
        }
        if hands > handsCapacity(deck.frame) {
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
        Logger.log("Testing placement of \(frame)")
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
        guard let deckName = sourceLabel.text, let deck = sources[deckName] else {
            // The source label should always have valid text and that text should denote a deck in sources.
            Logger.logFatalError(InternalDealingError)
        }
        var origin = CGPoint(x: deck.frame.maxX, y: deck.frame.minY)
        for i in 0..<hands {
            let hand = GridBox(origin: origin, size: deck.snapFrame.size, host: vc)
            origin.x += deck.frame.width
            vc.playingArea.addSubview(hand)
            hand.name = "Hand \(i+1)"
            for _ in 0..<cards {
                hand.snapUp(deck.cards[0])
            }
            hand.refreshCount()
        }
        deck.refreshCount()
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

// Order the source names so that "Deck" is first if present and the others are sorted alphabetically.
// Since this dialog should not have been created with an empty source Dictionary, the argument, and hence
// the result, should have at least one member.
private func orderSources(_ sources: [String]) -> [String] {
    var answer = sources
    answer.sort()
    if let deckBoxIndex = answer.firstIndex(of: DeckBoxName) {
        answer.remove(at: deckBoxIndex)
        answer.insert(DeckBoxName, at: 0)
    }
    return answer
}

