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

// Represents all card decks (via a protocol) and the default deck (which implements the protocol).
// Players do not have to use the same Deck implementation but do have to agree on the playing Card array, which must be formed from
// the cards of a Deck, either directly (standard 52 card deck) or by using the nonStandard method (decks with other card repertoires).
protocol Deck {
    // The cards of the deck.  The suits must be in the order clubs (indices 0-12), diamonds (indices 13-25), hearts (indices 26-38),
    //   and spades (indices 39-51).  Within the range assigned to each suit, the denominations must be in the order ace through king.
    var cards : [Card] { get }

    // The aspect ratio (width / height) of each card in this deck.  During play, the card width is the playing field width divided by a constant.
    // The card height is then determined by this ratio to avoid distorting the original image.
    var aspectRatio : CGFloat { get }
}

// Represents a set of instructions for creating a playing deck (as a [Card]) from the cards of a Deck (or "source deck")
class PlayingDeckTemplate : Codable {
    // The number of times each card of the source deck should appear (would be 1 for a standard deck)
    let multiplier : Int

    // Which of the cards of the source deck should appear at all?  For compactness in communicating, the value nil is equivalent to 'all'
    // Otherwise, a 'true' in the mask array selects a card and a 'false' excludes it   A standard deck has nil here.
    let mask : [Bool]?

    // A name for this kind of playing deck for use in dialogs to simplify choosing
    let displayName : String

    init(multiplier: Int, mask: [Bool]?, displayName: String) {
        self.multiplier = multiplier
        self.mask = mask
        self.displayName = displayName
    }

    convenience init(multiplier: Int, omitFrom2To: Int, displayName: String) {
        let range : Range<Int> = 0..<52
        let mask : [Bool] = range.map { index in
            let denom = (index % 13) + 1
            return denom < 2 || denom > omitFrom2To
        }
        self.init(multiplier: multiplier, mask: mask, displayName: displayName)
    }
}

//  Behavior common to all Deck instances
extension Deck {
    // Make the playing deck (as [Card]) from the contents of this source deck
    func makePlayingDeck(_ instructions: PlayingDeckTemplate) -> [Card] {
        // Fast path for standard deck
        if instructions.multiplier == 1 && instructions.mask == nil {
            return self.cards
        }
        // Slower path when the deck is non-standard
        let mask = instructions.mask ?? [Bool](repeating: true, count: 52)
        let oneOfEach = self.cards.filter { mask[$0.index] }
        var cards = [Card]()
        for _ in 0..<instructions.multiplier {
            cards += oneOfEach
        }
        // Use the copy constructor here to renumber the cards without mutating the original source deck
        return zip(cards, cards.indices).map { (card, index) in Card(index, card: card) }
    }
}

// List of potentially useful PlayDeckTemplates, and convenience method to cycle thorugh them
class Decks {
    static let available = [ PlayingDeckTemplate(multiplier: 1, mask: nil, displayName: "Standard"),
                       PlayingDeckTemplate(multiplier: 1, omitFrom2To: 6, displayName: "Piquet"),
                       PlayingDeckTemplate(multiplier: 1, omitFrom2To: 8, displayName: "Euchre"),
                       PlayingDeckTemplate(multiplier: 2, mask: nil, displayName: "Double"),
                       PlayingDeckTemplate(multiplier: 2, omitFrom2To: 6, displayName: "Bezique"),
                       PlayingDeckTemplate(multiplier: 2, omitFrom2To: 8, displayName: "Pinochle") ]

    // Provide convenient way to cycle thorugh the available decks
    static func next(_ name: String) -> PlayingDeckTemplate {
        if let index = available.firstIndex(where: { $0.displayName == name }) {
            return available[(index + 1) % available.count]
        } else {
            Logger.log("Unexpected argument to Decks.next()")
            return available[0] // non-fatal, attempt possibly surprising patch
        }
    }
}

// The default deck is from https://pixabay.com/en/card-deck-deck-cards-playing-cards-161536/
// The single source image consists of five rows of thirteen subareas.   The first four rows are consistent with the canonical card
//    order if you traverse columns within rows.  The last row contains the card back at a known position.
// TODO this image does not have any jokers, so, if we will eventually support jokers, other decks may be better.  The image does
//    include a couple of blank cards which could be designated jokers in a pinch.
class DefaultDeck : Deck {
    static let deck = DefaultDeck()

    let cards : [Card]
    let aspectRatio : CGFloat

    init() {
        if let image = UIImage(named: DefaultDeckName) {
            let horizontalStep = image.size.width / DefaultDeckFrontColumns
            let verticalStep = image.size.height / DefaultDeckAllRows
            aspectRatio = horizontalStep / verticalStep
            let backRect = DefaultDeck.getRectangle(horizontalStep, verticalStep, DefaultDeckBackRow, DefaultDeckBackColumn)
            let back = cropImage(image, backRect)
            var allCards = [Card]()
            var index = 0
            // Traversing columns within rows gives the desired order
            for row in 0..<DefaultDeckFrontRows {
                for column in 0..<DefaultDeckFrontColumns {
                    let frontRect = DefaultDeck.getRectangle(horizontalStep, verticalStep, row, column)
                    let front = cropImage(image, frontRect)
                    allCards.append(Card(index, front: front, back: back))
                    index += 1
                }
            }
            cards = allCards
        } else {
            Logger.logFatalError("Could not load image for default card deck")
        }
    }

    // Determine the cropping rectangle for the deck image to cut out a particular card or the back.
    // The deck image is a grid with some rows and columns and all cells in the grid are the same size.
    private static func getRectangle(_ horizontalStep: CGFloat, _ verticalStep: CGFloat, _ row: Int, _ column: Int) -> CGRect {
        let startX = horizontalStep * column
        let startY = verticalStep * row
        return CGRect(x: startX, y: startY, width: horizontalStep, height: verticalStep)
    }
}
