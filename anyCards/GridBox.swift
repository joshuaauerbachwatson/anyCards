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

// A UIView that is larger than a Card to accommodate a name label and a count label.  Designed to go behind a stack of cards.
// Cards that overlap a GridBox snap into it, being placed either on top of other cards (if faceup) in the GridBox or behind
// if (facedown).
class GridBox : UIView {
    // The "snap frame" subarea of the GridBox (where cards end up)
    var snapFrame : CGRect

    // A label containing the name of the GridBox when not being edited (hidden when nameField is shown)
    let nameLabel : TouchableLabel

    // A TextField containing the name of the GridBox while being edited (normally hidden in favor of nameLabel, revealed on touch)
    let nameField : UITextField

    // A label containing the count of cards currently "on" this GridBox
    let countLabel : UILabel

    // The main view controller, to be consulted for various purposes
    let host : ViewController

    // The cards that are currently "on" this GridBox.
    var cards : [Card] {
        return host.cardViews.filter { isOwned($0) }
    }

    // The name assigned to this GridBox or nil if none
    var name : String? {
        get {
            return nameLabel.text
        }
        set {
            nameLabel.text = newValue
        }
    }

    // Make a GridBox from frame information, provided as an origin and a size
    init(origin: CGPoint, size: CGSize, host: ViewController) {
        snapFrame = CGRect(origin: origin, size: size)
        let gridFrame = CGRect(x: snapFrame.minX, y: snapFrame.minY, width: snapFrame.width,
                               height: snapFrame.height * GridBoxExpansion)
        let legendHeight = gridFrame.height - snapFrame.height
        // The nameLabel takes a large proportion of the legend area at the bottom
        let nameWidth = snapFrame.width * GridBoxNamePortion
        nameLabel = TouchableLabel()
        nameLabel.frame = CGRect(x: 0, y: snapFrame.height, width: nameWidth, height: legendHeight)
        // The (editable) nameField has the same frame as the nameLabel but is hidden when not editing
        nameField = UITextField(frame: nameLabel.frame)
        nameField.isHidden = true
        // The countLabel occupies the rest of the expansion area
        countLabel = UILabel(frame: CGRect(x: nameWidth, y: snapFrame.height, width: snapFrame.width - nameWidth, height: legendHeight))
        self.host = host
        super.init(frame: gridFrame)
        // Finish configuring widgets
        backgroundColor = GridBackgroundColor
        configureLabel(countLabel, LabelBackground, parent: self)
        configureTouchableLabel(nameLabel, target: self, action: #selector(nameTouched), parent: self)
        countLabel.textColor = CountLabelColor
        configureTextField(nameField, LabelBackground, parent: self)
        nameField.delegate = self
        nameField.textColor = NormalTextColor
        // Add drag support to the view as a whole
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(boxDragged))
        addGestureRecognizer(recognizer)
    }

    // Make a GridBox from frame information, provided as a center and a size
    convenience init(center: CGPoint, size: CGSize, host: ViewController) {
        let adjust = CGPoint(x: size.width / 2, y: size.height / 2)
        self.init(origin: center - adjust, size: size, host: host)
    }

    // Useless but required
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Actions

    // Respond to dragging of the entire box
    @objc func boxDragged(recognizer: UIPanGestureRecognizer) {
        if recognizer.state == .possible || !host.thisPlayersTurn {
            return
        }
        if let view = recognizer.view {
            let newFrame = CGRect(origin: view.frame.origin + recognizer.translation(in: view), size: frame.size)
            if canAssignFrame(newFrame) {
                recognizer.setTranslation(CGPoint.zero, in: view)
                let cards = self.cards
                let cardFrame = CGRect(origin: newFrame.origin, size: snapFrame.size)
                CATransaction.withNoAnimation {
                    view.frame = newFrame
                    snapFrame = cardFrame
                    cards.forEach { $0.frame = cardFrame }
                }
            }
        }
    }

    // Respond to touch of name label (request to edit)
    @objc func nameTouched() {
        nameLabel.isHidden = true
        nameField.text = nameLabel.text
        nameField.isHidden = false
        nameField.becomeFirstResponder()
    }

    // Other functions

    // Deterimine if a new frame for this GridBox is legal.  It must be within the public and and may not overlap with another GridBox
    private func canAssignFrame(_ newFrame: CGRect) -> Bool {
        if !host.publicArea.contains(newFrame) {
            return false
        }
        let otherBoxes = host.boxViews.filter { $0 !== self }
        for box in otherBoxes {
            if newFrame.intersects(box.frame) {
                return false
            }
        }
        return true
    }

    // Decide if a card is "owned" by this GridBox (the card is snapped in).  We do this by comparing the Card's frame origin
    // to the snapFrame origin; however, we do this fuzzily because the two can end up deviating by a fraction of a pixel.
    func isOwned(_ card: UIView) -> Bool {
        return abs(card.frame.minX - snapFrame.minX) < 0.5 && abs(card.frame.minY - snapFrame.minY) < 0.5
    }

    // Decide which of several cards should be snapped up by this GridBox and, snap up those that are appropriate
    func maybeSnapUp(_ cards: [Card]) {
        for card in cards {
            let overlap = card.frame.intersection(snapFrame).size
            if overlap.height > SnapThreshhold || overlap.width > SnapThreshhold {
                snapUp(card)
            }
        }
    }

    // Snap up a card after determining that it is appropriate.  A new GridBox snaps up cards that overlap it (via "maybeSnapUp").
    // After card movement or some other more general rearrangement, cards are snapped by the GridBox that they overlap "the most".
    func snapUp(_ card: Card) {
        card.frame = snapFrame
        if card.isFaceUp {
            superview?.bringSubviewToFront(card)
        } else {
            superview?.sendSubviewToBack(card)
            superview?.sendSubviewToBack(self)
        }
    }

    // Refresh the displayed count in the countLabel
    func refreshCount() {
        countLabel.text = String(cards.count)
    }
}

// Conform to UITextFieldDelegate
extension GridBox : UITextFieldDelegate {
    // React to a change in the text field containing the box's name
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        if let newText = textField.text, reason == .committed {
            nameLabel.text = newText
            nameLabel.isHidden = false
            textField.isHidden = true
        }
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

