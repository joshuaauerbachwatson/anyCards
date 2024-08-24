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

// Represents a Card as a view, with animated flipping from front to back. The two images for front and back are stored in the
// card (typically, the cards of a deck would share a common back image by reference).
// Note: although this class is not Codable it is partly mirrored by CardState, which is.  So, when changing the
// stored properties of this class, be sure to visit CardState as well.
class Card : UIView {
    // The index of the card in its "deck" when that deck is in its normal (not shuffled) order.  The index is used to 
    // identify cards unambiguously across player views but does not necessarily have a predictable relationship to the card's
    // denomination or suit.
    let index : Int

    // Says whether the card is face up or not
    var isFaceUp = false
    
    // Says whether the card is in the private hand area
    var isPrivate = false

    // Provide the owning box or nil if none
    var box: GridBox? {
        guard let playingArea = self.superview else {
            Logger.log("Card has no box because card has no superview")
            return nil
        }
        //Logger.log("Looking for containing box with origin \(self.frame.origin)")
        if let subview = playingArea.subviews.first(where: {
            if let box = $0 as? GridBox {
                if box.isHeld(self) {
                    return true
                } else {
                    //Logger.log("rejecting possible box because its origin is \(box.snapFrame.origin)")
                }
            }
            return false
        }) {
            //Logger.log("Card is held by box")
            return subview as? GridBox
        }
        return nil
    }

    // Says whether the card is allowed to turn over.  A card that belongs to a .Deck or .Discard box may not be turned
    // over until it is dragged from the box.
    var mayTurnOver: Bool {
        if let box = box {
            return box.kind == .General
        }
        return true
    }

    // Store the two images
    private let front: UIImage
    private let back: UIImage

    // Place to cache the cards that are being dragged with this card (includes and starts with this card).
    // Ignored except during a drag.
    var dragSet: [Card] = []

    // Make a new card.  Typically, called as part of deck construction, after which the cards of the deck are kept in the
    // deck array.
    init (_ index: Int, front: UIImage, back: UIImage) {
        self.index = index
        self.front = front
        self.back = back
        super.init(frame: CGRect.zero)
        addSubview(makeImageView(back))
    }

    // Make a new card based on an existing card, taking the front and back images from the existing card.  The index is given
    // as an argument and other fields are initialized to defaults.   This method is used when building non-standard decks (other
    // than the normal 52 cards).
    convenience init(_ index: Int, card: Card) {
        self.init(index, front: card.front, back: card.back)
        card.gestureRecognizers?.forEach { self.addGestureRecognizer($0) }
    }

    // Useless but required
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Ensure that the subview always fills the card view after a layout operation
    override var frame : CGRect {
        didSet {
            if subviews.count > 0 {
                assert(subviews.count == 1)
                subviews[0].frame = bounds
            }
        }
    }

    // Determine which GridBoxes should snap up this card (if any) and execute the snap action.
    // If the card is snapped, returns an empty array.  If the card is not snapped, returns
    // the sequence of .Deck boxes (ineligible for snapping) that are overlapped by the card.
    @discardableResult
    func maybeBeSnapped(_ boxes: [GridBox]) -> [GridBox] {
        func overlapArea(_ r1: CGRect, _ r2: CGRect) -> CGFloat {
            let intersect = r1.intersection(r2)
            if intersect.width > SnapThreshhold || intersect.height > SnapThreshhold {
                return intersect.width * intersect.height
            } else {
                return 0
            }
        }
        func overlaps(_ r1: CGRect, _ r2: CGRect) -> Bool {
            let intersect = r1.intersection(r2)
            return intersect.width > SnapThreshhold || intersect.height > SnapThreshhold
        }
        func rejects(_ boxes: [GridBox]) -> [GridBox] {
            let nonSnapBoxes = boxes.filter { $0.kind == .Deck || !$0.mayBeModified }
            let rejectedBoxes = nonSnapBoxes.filter { overlaps($0.snapFrame, self.frame) }
            if rejectedBoxes.isEmpty {
                Logger.log("No boxes were rejected")
            } else {
                let rejectedNames = rejectedBoxes.map { $0.name ?? "unknown" }
                Logger.log("Rejected boxes: \(rejectedNames)")
            }
            return rejectedBoxes

        }
        if isPrivate {
            return []
        }
        let snapBoxes = boxes.filter { $0.kind != .Deck && $0.mayBeModified }
        let overlapAreas = snapBoxes.map { overlapArea($0.snapFrame, self.frame) }
        let maxOverlap = overlapAreas.max()
        if maxOverlap == 0 {
            return rejects(boxes)
        }
        for (box, overlap) in zip(snapBoxes, overlapAreas) {
            if overlap == maxOverlap {
                Logger.log("Card with origin \(self.frame.origin) will be snapped by box \(box.name ?? "unknown"), " +
                           "overlap is \(overlap)")
                box.snapUp(self)
                return []
            }
        }
        return rejects(boxes)
    }

    // Turn the card face down.  Does nothing if the card is already face down.
    // The byUser flag says whether the turn was user initiated.
    func turnFaceDown(_ byUser: Bool = false) {
        if isFaceUp {
            guard let duration = checkUserInitiated(byUser) else {
                return
            }
            UIView.transition(from: subviews[0], to: makeImageView(back), duration: duration, options: .transitionFlipFromRight)
            isFaceUp = false
        }
    }

    // Turn the card face up.  Does nothing if the card is already face up.
    // The byUser flag says whether the turn was user initiated.
    func turnFaceUp(_ byUser: Bool = false) {
        if !isFaceUp {
            guard let duration = checkUserInitiated(byUser) else {
                return
            }
            UIView.transition(from: subviews[0], to: makeImageView(front), duration: duration, options: .transitionFlipFromLeft)
            isFaceUp = true
        }
    }

    // Checks whether a card flip operation was user initiated and returns either an appropriate animation duration
    // (0 will suppress animation) or nil if the card may not be flipped.  If the card is not flipped, it is dithered
    // making it no longer a part of the deck and allowing it to be turned over with a second click.
    func checkUserInitiated(_ byUser: Bool) -> TimeInterval? {
        if !byUser {
            return 0 // no animation when not user initiated but always allowed
        }
        if let box = box, !box.mayBeModified {
            box.mayNotModify()
            return nil
        }
        if mayTurnOver {
            // If user initiated, must be allowed to turn over
            return FlipTime
        }
        // User initiated and not authorized.  Dither the card instead of turning it over
        ditherCard()
        return nil
    }

    // "Dither" a card (move it slightly, for the purpose of dissociating itself from a deck),
    // after which it is eligible to turn over
    func ditherCard() {
        frame.origin = frame.origin + CGPoint(x: SnapThreshhold, y: SnapThreshhold)
    }

    // Make a new image view from an image, sizing it to fill the view.  The result is intended to be used as the sole 
    // subview of the card, replacing the previous sole subview.  Thus there should be no storage leak if use correctly.
    private func makeImageView(_ image: UIImage) -> UIImageView {
        let ans = UIImageView()
        ans.image = image
        ans.frame = bounds
        return ans
    }
}

