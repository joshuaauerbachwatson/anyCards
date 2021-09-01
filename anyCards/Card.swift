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

// Represents a Card as a view, with animated flipping from front to back. The two images for front and back are stored in the card (typically,
// the cards of a deck would share a common back image by reference).
class Card : UIView {
    // The index of the card in its "deck" when that deck is in its normal (not shuffled) order.  The index is used to identify cards
    // unambiguously across player views but does not necessarily have a predictable relationship to the card's denomination or suit.
    let index : Int

    // Says whether the card is face up or not
    var isFaceUp : Bool

    // Store the two images
    private let front: UIImage
    private let back: UIImage

    // Make a new card.  Typically, called as part of deck construction, after which the cards of the deck are kept in the deck array.
    init (_ index: Int, front: UIImage, back: UIImage) {
        self.index = index
        self.front = front
        self.back = back
        isFaceUp = false
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

    // Determine which GridBoxes should snap up this card (if any) and execute the snap action
    func maybeBeSnapped(_ boxes: [GridBox]) {
        let overlap : (CGRect, CGRect) -> CGFloat = { (r1, r2) in
            let intersect = r1.intersection(r2)
            if intersect.width > SnapThreshhold || intersect.height > SnapThreshhold {
                return intersect.width * intersect.height
            } else {
                return 0
            }
        }
        let overlaps = boxes.map { overlap($0.snapFrame, frame) }
        let maxOverlap = overlaps.max()
        if maxOverlap == 0 {
            return
        }
        for (box, overlap) in zip(boxes, overlaps) {
            if overlap == maxOverlap {
                box.snapUp(self)
                return
            }
        }
    }

    // Turn the card face down.  Does nothing if the card is already face down.
    func turnFaceDown() {
        if isFaceUp {
            UIView.transition(from: subviews[0], to: makeImageView(back), duration: FlipTime, options: .transitionFlipFromRight)
            isFaceUp = false
        }
    }

    // Turn the card face up.  Does nothing if the card is already face up.
    func turnFaceUp() {
        if !isFaceUp {
            UIView.transition(from: subviews[0], to: makeImageView(front), duration: FlipTime, options: .transitionFlipFromLeft)
            isFaceUp = true
        }
    }

    // Make a new image view from an image, sizing it to fill the view.  The result is intended to be used as the sole subview of the card, replacing the
    // previous sole subview.  Thus there should be no storage leak if use correctly.
    private func makeImageView(_ image: UIImage) -> UIImageView {
        let ans = UIImageView()
        ans.image = image
        ans.frame = bounds
        return ans
    }
}

