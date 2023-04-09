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
    enum Kind {
        case Deck
        case Discard
        case General

        var label: String {
            switch self {
            case .Deck:
                return "deck"
            case .Discard:
                return "discard"
            case .General:
                return "general"
            }
        }

        var next: Kind {
            switch self {
            case .Deck:
                return .Discard
            case .Discard:
                return .General
            case .General:
                return .Deck
            }
        }
    }

    var kind: Kind = .General {
        didSet {
            switch kind {
            case .Deck:
                turnFaceDown()
            case .Discard:
                turnFaceUp()
            case .General:
                break
            }
        }
    }

    // The "snap frame" subarea of the GridBox (where cards end up)
    var snapFrame : CGRect

    // A label containing the name of the GridBox
    let nameLabel : UILabel

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
        nameLabel = UILabel()
        nameLabel.backgroundColor = LabelBackground
        countLabel = UILabel()
        countLabel.textColor = CountLabelColor
        countLabel.backgroundColor = LabelBackground
        self.host = host
        snapFrame = CGRect(origin: origin, size: size)
        let gridFrame = CGRect(x: snapFrame.minX, y: snapFrame.minY, width: snapFrame.width,
                               height: snapFrame.height * GridBoxExpansion)
        super.init(frame: gridFrame)
        backgroundColor = GridBackgroundColor
        addLegend(gridFrame, snapFrame)
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
                if recognizer.state == .ended {
                    host.transmit(false)
                }
            }
        }
    }

    // Respond to touching of the legend
    @objc func legendTouched() {
        let menu = GridBoxMenu(self)
        Logger.logPresent(menu, host: host, animated: true)
    }

    // Other functions

    // Add the legend area, which is touchable and contains both the name label and the box count label
    // Called during initialization
    private func addLegend(_ gridFrame: CGRect, _ snapFrame: CGRect) {
        let legendHeight = gridFrame.height - snapFrame.height
        let legend = UIView(frame: CGRect(x: 0, y: snapFrame.height, width: gridFrame.width, height: legendHeight))
        // The nameLabel takes a large proportion of the legend area
        let nameWidth = snapFrame.width * GridBoxNamePortion
        legend.addSubview(nameLabel)
        place(nameLabel, 0, 0, nameWidth, legendHeight)
        // The countLabel occupies the rest of the expansion area
        legend.addSubview(countLabel)
        place(countLabel, nameWidth, 0, legend.bounds.width - nameWidth, legendHeight)
        let touchableLegend = TouchableView(legend, target: self, action: #selector(legendTouched))
        addSubview(touchableLegend)
    }

    // Deterimine if a new frame for this GridBox is legal.  It must be within the public area and may not overlap with
    // another GridBox
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
        switch kind {
        case .Discard:
            card.turnFaceUp()
        case .Deck:
            card.turnFaceDown()
        case .General:
            break
        }
        if card.isFaceUp {
            superview?.bringSubviewToFront(card)
        } else {
            superview?.sendSubviewToBack(card)
            superview?.sendSubviewToBack(self)
        }
    }

    // Turn the entire deck face down.  If the deck is already face down, no-op.  If the deck is currently face-up, the view order
    // of the cards is reversed while turning them over so that the effect is as if the entire pile was turned over.
    func turnFaceDown() {
        switch kind {
        case .Discard:
            var newCards = [Card]()
            for card in cards {
                card.turnFaceDown()
                card.removeFromSuperview()
                newCards.append(card)
            }
            kind = .Deck
            for card in newCards.reversed() {
                host.playingArea.addSubview(card)
            }
        case .Deck:
            break
        case .General:
            for card in cards {
                card.turnFaceDown()
            }
        }
    }

    // Turn the entire deck face up.  If the deck is already face up, no-op.  If the deck is currently face-down, the view order
    // of the cards is reversed while turning them over so that the effect is as if the entire pile was turned over.
    func turnFaceUp() {
        switch kind {
        case .Discard:
            break
        case .Deck:
            var newCards = [Card]()
            for card in cards {
                card.turnFaceUp()
                card.removeFromSuperview()
                newCards.append(card)
            }
            kind = .Discard
            for card in newCards.reversed() {
                host.playingArea.addSubview(card)
            }
        case .General:
            for card in cards {
                card.turnFaceUp()
            }
        }
    }

    // Refresh the displayed count in the countLabel
    func refreshCount() {
        countLabel.text = String(cards.count)
    }
}
