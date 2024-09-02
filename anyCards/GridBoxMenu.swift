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
import AuerbachLook

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
    let modify = UIButton()
    let delete = UIButton()
    let done = UIButton()

    // Constructor
    init?(_ box: GridBox) {
        if !box.mayBeModified {
            return nil
        }
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
        takeHand.isHidden = !settings.hasHands
        configureButton(turnOver, title: TurnOverTitle, target: self, action: #selector(turnOverTouched), parent: view)
        turnOver.isHidden = box.kind == .General
        configureButton(shuffle, title: ShuffleTitle, target: self, action: #selector(shuffleTouched), parent: view)
        configureButton(deal, title: DealTitle, target: self, action: #selector(dealTouched), parent: view)
        deal.isHidden = !vc.canDeal
        configureButton(modify, title: ModifyTitle, target: self, action: #selector(modifyTouched), parent: view)
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
        // We can skip placing hidden controls since the dialog is short-lived and nothing will unhide the controls
        var previous = place(header, startX, startY, width, height)
        func next(_ subview: UIView) {
            if !subview.isHidden {
                previous = place(subview, startX, below(previous), width, height)
            }
        }
        next(takeHand)
        next(turnOver)
        next(shuffle)
        next(deal)
        next(modify)
        next(delete)
        next(done)
    }

    // Actions

    // Respond to touch of take hand button
    @objc func takeHandTouched() {
        Logger.logDismiss(self, host: vc, animated: true)
        vc.takeHand(box)
    }

    // Respond to touch of turn over button
    @objc func turnOverTouched() {
        switch box.kind {
        case .Discard, .DiscardYield:
            box.kind = .Deck
        case .Deck:
            box.kind = .Discard
        case .General, .Hand:
            break // should be ruled out by hiding the control
        }
        Logger.logDismiss(self, host: vc, animated: true)
        vc.transmit()
    }

    // Respond to touch of shuffle button
    @objc func shuffleTouched() {
        var cards = box.cards
        cards.forEach() { $0.removeFromSuperview() }
        cards = anyCards.shuffle(cards)
        cards.forEach() { vc.playingArea.addSubview($0) }
        Logger.logDismiss(self, host: vc, animated: true)
        vc.transmit()
    }

    // Respond to touch of deal button
    @objc func dealTouched() {
        let dialog = DealingDialog(box, vc)
        Logger.logDismiss(self, host: vc, animated: true)
        Logger.logPresent(dialog, host: vc, animated: true)
    }

    // Respond to touch of modify button
    @objc func modifyTouched() {
        Logger.logDismiss(self, host: vc, animated: true)
        guard let menu = ModifyGridBox(box) else {
            // Shouldn't happen since this menu shouldn't have been created unless the box could be modified
            Logger.log("ModifyGridBox constructor failed in a context where it shouldn't have")
            return
        }
        Logger.logPresent(menu, host: vc, animated: true)
    }

    // Respond to touch of delete button
    @objc func deleteTouched() {
        box.removeFromSuperview()
        Logger.logDismiss(self, host: vc, animated: true)
        vc.transmit()
    }

    // Respond to touch of done button
    @objc func doneTouched() {
        Logger.logDismiss(self, host: vc, animated: true)
    }
}
