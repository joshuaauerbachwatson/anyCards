/**
 * Copyright (c) 2023-present, Joshua Auerbach
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

// Menu which appears when you do a long press inside an existing GridBox
class GridBoxMenu : UIViewController {

    // Parent view controller
    var vc : ViewController {
        if let ans = presentingViewController as? ViewController {
            return ans
        }
        Logger.logFatalError("Could not retrieve ViewController within GridBoxMenu")
    }

    // Terser reference to settings
    var settings : OptionSettings {
        return OptionSettings.instance
    }

    // The GridBox being acted upon
    let box: GridBox

    // Controls
    let header = UILabel()
    let takeHand = UIButton()
    let turnOver = UIButton()
    let shuffle = UIButton()
    let deal = UIButton()
    let newName = UIButton()
    let delete = UIButton()
    let done = UIButton()

    // Constructor
    init(_ box: GridBox) {
        self.box = box
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = PlayerManagementSize
        modalPresentationStyle = UIModalPresentationStyle.formSheet
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // When view loads, we finish initializing the controls (except for layout) and make them into subviews
    override func viewDidLoad() {
        view.backgroundColor = SettingsDialogBackground

        configureLabel(header, SettingsDialogBackground, parent: view)
        if let name = box.name {
            header.text = String(format: GridBoxMenuHeaderTemplate, name)
        } else {
            header.text = GridBoxMenuHeaderUnnamed
        }
        configureButton(takeHand, title: TakeHandTitle, target: self, action: #selector(takeHandTouched), parent: view)
        if !settings.hasHands {
            takeHand.isHidden = true
        }
        configureButton(turnOver, title: TurnOverTitle, target: self, action: #selector(turnOverTouched), parent: view)
        configureButton(shuffle, title: ShuffleTitle, target: self, action: #selector(shuffleTouched), parent: view)
        configureButton(deal, title: DealTitle, target: self, action: #selector(dealTouched), parent: view)
        configureButton(newName, title: NewNameTitle, target: self, action: #selector(newNameTouched), parent: view)
        configureButton(delete, title: DeleteTitle, target: self, action: #selector(deleteTouched), parent: view)
        configureButton(done, title: DoneTitle, target: self, action: #selector(doneTouched), parent: view)
    }

    // When view appears, we do layout
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let fullHeight = min(preferredContentSize.height, view.bounds.height) - 2 * DialogEdgeMargin
        let width = min(preferredContentSize.width, view.bounds.width) - 2 * DialogEdgeMargin
        let height = (fullHeight - 7 * DialogSpacer - 2 * DialogEdgeMargin) / 8
        let startX = (view.bounds.width / 2) - (width / 2)
        let startY = (view.bounds.height / 2) - (fullHeight / 2)
        header.frame = CGRect(x: startX, y: startY, width: width, height: height)
        place(takeHand, startX, below(header), width, height)
        if turnOver.isHidden {
            // Since this is a short-lived dialog we don't have to place hidden controls; they will never be unhidden
            place(shuffle, startX, below(takeHand), width, height)
        } else {
            place(turnOver, startX, below(takeHand), width, height)
            place(shuffle, startX, below(turnOver), width, height)
        }
        place(deal, startX, below(shuffle), width, height)
        place(newName, startX, below(deal), width, height)
        place(delete, startX, below(newName), width, height)
        place(done, startX, below(delete), width, height)
    }

    // Actions

    // Respond to touch of take hand button
    @objc func takeHandTouched() {
        // Calculate the placement points in the private area
        let width = vc.playingArea.bounds.width
        let step = width / box.cards.count
        var currentX = vc.playingArea.bounds.minX
        let fixedY = vc.handAreaMarker.frame.maxY
        // Move the cards, turning face up and fanning according to the placement points
        for card in box.cards {
            card.frame.origin = CGPoint(x: currentX, y: fixedY)
            card.turnFaceUp()
            currentX += step
        }
        // Delete the box
        box.removeFromSuperview()
        Logger.logDismiss(self, host: vc, animated: true)
    }

    // Respond to touch of turn over button
    @objc func turnOverTouched() {
        switch box.kind {
        case .FaceUp:
            box.turnFaceDown()
        case .FaceDown:
            box.turnFaceUp()
        }
        Logger.logDismiss(self, host: vc, animated: true)
    }

    // Respond to touch of shuffle button
    @objc func shuffleTouched() {
        var cards = box.cards
        cards.forEach() { $0.removeFromSuperview() }
        cards = anyCards.shuffle(cards)
        cards.forEach() { vc.playingArea.addSubview($0) }
        Logger.logDismiss(self, host: vc, animated: true)
    }

    // Respond to touch of deal button
    @objc func dealTouched() {
        let dialog = DealingDialog(box, vc)
        Logger.logDismiss(self, host: vc, animated: true)
        Logger.logPresent(dialog, host: vc, animated: true)
    }

    // Respond to touch of new name button
    @objc func newNameTouched() {
        box.promptForName()
        Logger.logDismiss(self, host: vc, animated: true)
    }

    // Respond to touch of delete button
    @objc func deleteTouched() {
        box.removeFromSuperview()
        Logger.logDismiss(self, host: vc, animated: true)
    }

    // Respond to touch of done button
    @objc func doneTouched() {
        Logger.logDismiss(self, host: vc, animated: true)
    }
}