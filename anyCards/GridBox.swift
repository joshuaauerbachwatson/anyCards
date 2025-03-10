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

// A UIView that is larger than a Card to accommodate a legend area with additional information.  Designed to go behind
// a stack of cards.  Cards that overlap a GridBox may snap into it, being placed in accordance with the GridBox's rules.
// Note: GridBox is not Codable, but it is partly mirrored by GridBoxState, which does.  Changes to the stored properties
// of GridBox should require examining the implications for GridBoxState.
class GridBox : UIView {
    // Classifies the GridBox according to the rules that apply
    enum Kind : Codable, CaseIterable, Identifiable {
        case Deck     // All face down, remove only
        case Hand     // Locked, except for "Take Hand", touching will result in taking
        case Discard  // All face up, add at top only.  Removal allowed.
        case DiscardYield // Same as DIscard but adding the "automatic yield on discard" property
        case General  // Potentially mixed, face up added to top and face down to bottom.  Removal allowed.

        // Convenience methods to support display and modification dialogs
        var label: String {
            switch self {
            case .Deck:
                return "deck"
            case .Hand:
                return "hand"
            case .Discard:
                return "discard"
            case .DiscardYield:
                return "discard (yield)"
            case .General:
                return "general"
            }
        }
        
        // Conform to Identifiable
        var id: String {
            label
        }

        var symbol: String {
            switch self {
            case .Deck:
                return "↓"
            case .Hand:
                return "!"
            case .Discard, .DiscardYield:
                return "↑"
            case .General:
                return "↑↓"
            }
        }
        
        var canTurnOver: Bool {
            switch self {
            case .Hand, .General:
                return false
            default:
                return true
            }
        }
        
        static func settableCases(_ hasHands: Bool) -> [Kind] {
            if hasHands {
                return Self.allCases
            }
            return Self.allCases.filter { $0 != .Hand}
        }
    }

    // An variable to save the previous "kind" of a GridBox as it is being changed.
    var previousKind: Kind? = nil

    // The current Kind of this GridBox
    var kind: Kind = .General {
        willSet {
            previousKind = kind
        }
        didSet {
            kindLabel.text = kind.symbol
            switch kind {
            case .Deck, .Hand:
                makeIntoDeck()
            case .Discard, .DiscardYield:
                makeIntoDiscard()
            case .General:
                break
            }
        }
    }

    // The owner of the GridBox.  This is an index into the player labels (ie. a number from 0...5).  An unowned
    // GridBox is indicated by a special constant
    static let Unowned = -1
    var owner: Int = Unowned

    // Indicates whether adding to a box causes your turn to end
    var autoYield : Bool {
        kind == .DiscardYield
    }

    // Indicates whether the GridBox may be modified by this player.  This is possible if the GridBox is Unowned or if
    // it is owned by the current player
    var mayBeModified: Bool {
        owner == GridBox.Unowned || owner == host.model.thisPlayer
    }
    
    // Indicates that the GridBox is capable of supporting a deal.  It must have at least two cards and the
    // dealing area must be clear.
    var canDeal: Bool {
        cards.count > 1 && host.dealingAreaClear
    }

    // The "snap frame" subarea of the GridBox (where cards end up)
    var snapFrame : CGRect

    // A label containing the name of the GridBox
    let nameLabel : UILabel

    // A label containing the symbol for the "kind" of the GridBox
    let kindLabel : UILabel

    // A label containing the count of cards currently held by this GridBox
    let countLabel : UILabel
    
    // The PlayingView that this GridBox belongs to
    let host: PlayingSurface

    // The cards that are currently held by this GridBox.
    var cards : [Card] {
        return host.cardViews.filter { isHeld($0) }
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
    init(origin: CGPoint, size: CGSize, host: PlayingSurface) {
        nameLabel = UILabel()
        nameLabel.backgroundColor = LabelBackground
        nameLabel.textAlignment = .center
        nameLabel.adjustsFontSizeToFitWidth = true
        kindLabel = UILabel()
        kindLabel.backgroundColor = ButtonBackground
        kindLabel.textColor = .white
        kindLabel.textAlignment = .center
        kindLabel.font = UIFont.boldSystemFont(ofSize: getTextFont().pointSize)
        kindLabel.adjustsFontSizeToFitWidth = true
        kindLabel.text = kind.symbol
        countLabel = UILabel()
        countLabel.textColor = CountLabelColor
        countLabel.backgroundColor = LabelBackground
        countLabel.textAlignment = .center
        countLabel.adjustsFontSizeToFitWidth = true
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
    convenience init(center: CGPoint, size: CGSize, host: PlayingSurface) {
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
        if recognizer.state == .possible || !host.model.thisPlayersTurn {
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
                    host.model.transmit()
                    host.setCanDeal()
                }
            }
        }
    }

    // Respond to touching of the legend
    @objc func legendTouched() {
        if mayBeModified {
            host.gameHandle.boxMenu(self)
        } else {
            mayNotModify()
        }
    }

    // Other functions

    // Add the legend area, which is touchable and contains both the name label and the box count label
    // Called during initialization
    private func addLegend(_ gridFrame: CGRect, _ snapFrame: CGRect) {
        let legendHeight = gridFrame.height - snapFrame.height
        let legend = UIView(frame: CGRect(x: 0, y: snapFrame.height, width: gridFrame.width, height: legendHeight))
        // The nameLabel takes a large proportion of the legend area
        let nameWidth = snapFrame.width * GridBoxNamePortion
        // The kindLabel takes a portion of what remains
        let kindWidth = snapFrame.width * GridBoxKindPortion
        legend.addSubview(nameLabel)
        place(nameLabel, 0, 0, nameWidth, legendHeight)
        legend.addSubview(kindLabel)
        place(kindLabel, nameWidth, 0, kindWidth, legendHeight)
        // The countLabel occupies the rest of the expansion area
        legend.addSubview(countLabel)
        place(countLabel, after(kindLabel), 0, legend.bounds.width - nameWidth - kindWidth, legendHeight)
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

    // Decide if a card is "held" by this GridBox (the card is snapped in).  We do this by comparing the Card's frame origin
    // to the snapFrame origin; however, we do this fuzzily because the two can end up deviating by a fraction of a pixel.
    func isHeld(_ card: UIView) -> Bool {
        return abs(card.frame.minX - snapFrame.minX) < 0.5 && abs(card.frame.minY - snapFrame.minY) < 0.5
    }

    // Decide which of several cards should be snapped up by this GridBox and, snap up those that are appropriate
    func maybeSnapUp(_ cards: [Card]) {
        if kind == .Hand {
            return
        }
        for card in cards {
            if card.isPrivate {
                continue
            }
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
        case .Discard, .DiscardYield:
            card.turnFaceUp()
        case .Deck:
            card.turnFaceDown()
        case .General, .Hand:
            break
        }
        if card.isFaceUp {
            superview?.bringSubviewToFront(card)
        } else {
            superview?.sendSubviewToBack(card)
            superview?.sendSubviewToBack(self)
        }
    }

    // Set up the box in .Deck style (all cards faceDown and unable to be turned over).  If the deck was previously
    // a discard, then reverse the order of the cards so that it's as if the entire pile was turned over as a whole.
    private func makeIntoDeck() {
        for card in cards {
            card.turnFaceDown()
        }
        if previousKind == .Discard {
            reverseCardViews()
         }
        previousKind = nil
    }

    // Reverse the view order of the cards in the deck
    private func reverseCardViews() {
        var newCards = [Card]()
        for card in cards {
            card.removeFromSuperview()
            newCards.append(card)
        }
        for card in newCards.reversed() {
            host.addSubview(card)
        }
    }

    // Set up the box in .Discard style (all cards faceUp and unable to be turned over).  If the discard was previously
    // a deck, then reverse the order of the cards so that it's as if the entire pile was turned over as a whole.
    private func makeIntoDiscard() {
        for card in cards {
            card.turnFaceUp()
        }
        if previousKind == .Deck {
            reverseCardViews()
        }
        previousKind = nil
    }

    // Refresh the displayed count in the countLabel
    func refreshCount() {
        countLabel.text = String(cards.count)
        if name == MainDeckName {
            host.setCanDeal()
        }
    }

    // Display popup when an attempt is made to modify an owned gridbox by someone who isn't the owner
    func mayNotModify() {
        let message = String(format: OwnedGridBoxTemplate, host.model.getPlayer(index: owner))
        host.model.displayError(message)
    }
}
