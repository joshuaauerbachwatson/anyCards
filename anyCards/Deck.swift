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
// Players do not have to use the same Deck implementation but do have to agree on the playing Card array,
// which must be formed from the cards of a "source" Deck, either directly (standard 52 card deck with 0, 1, or 2 jokers)
// or selectively by using the multiplier, mask, and jokers fields of PlayingDeckTemplate or by still other means.
// Currently, there is a single source deck and a fixed set of PlayingDeckTemplate instances with no provision for adding
// either more PlayingDeckTemplates or source decks.  Adding more source decks and templates would be straightforward as
// a code modification to the game but permitting end-users to do so would be more work.
protocol SourceDeck {
    // The cards of a "source deck" from which the actual cards of the playing deck are drawn.
    // The suits must be in the order clubs (indices 0-12), diamonds (indices 13-25), hearts (indices 26-38),
    // and spades (indices 39-51).  Within the range assigned to each suit, the denominations must be in the order ace
    // through king.  Index positions 52 and 53 should be occupied by jokers (which may be the same image or two
    // different images).
    var cards : [Card] { get }

    // The aspect ratio (width / height) of each card in this deck.  During play, the card width is the playing field
    // width divided by a constant.  The card height is then determined by this ratio to avoid distorting the original image.
    var aspectRatio : CGFloat { get }
}

// Represents a set of instructions for creating a playing deck (as a [Card]) from the cards of a SourceDeck
class PlayingDeckTemplate : Codable {
    // The number of times each card of the source deck should appear (would be 1 for a standard deck)
    let multiplier : Int

    // Which of the non-joker cards of the source deck should appear at all?  For compactness in communicating, the value nil
    // is equivalent to 'all'.  Otherwise, a 'true' in the mask array selects a card and a 'false' excludes it.
    // A standard deck has nil here.
    let mask : [Bool]?

    // The number of jokers to include.  The default is 0.
    let jokers: Int

    // A name for this kind of playing deck for use in dialogs to simplify choosing
    let displayName : String

    init(multiplier: Int, mask: [Bool]?, jokers: Int, displayName: String) {
        self.multiplier = multiplier
        self.mask = mask
        self.jokers = jokers
        self.displayName = displayName
    }

    convenience init(multiplier: Int, omitFrom2To: Int, displayName: String) {
        let range : Range<Int> = 0..<52
        let mask : [Bool] = range.map { index in
            let denom = (index % 13) + 1
            return denom < 2 || denom > omitFrom2To
        }
        self.init(multiplier: multiplier, mask: mask, jokers: 0, displayName: displayName)
    }
}

//  Behavior common to all Deck instances
extension SourceDeck {
    // Make the playing deck (as [Card]) from the contents of this source deck
    func makePlayingDeck(_ instructions: PlayingDeckTemplate) -> [Card] {
        // Fast path for complete deck (standard deck plus jokers)
        if instructions.multiplier == 1 && instructions.mask == nil  && instructions.jokers == 2 {
            return self.cards
        }
        // Slower path when the deck is not the complete deck
        var mask = instructions.mask ?? [Bool](repeating: true, count: 52)
        mask.append(instructions.jokers > 0)
        mask.append(instructions.jokers > 1)
        let oneOfEach = self.cards.filter { mask[$0.index] }
        var cards = [Card]()
        for _ in 0..<instructions.multiplier {
            cards += oneOfEach
        }
        // Use the copy constructor here to renumber the cards without mutating the original source deck
        return zip(cards, cards.indices).map { (card, index) in Card(index, card: card) }
    }
}

// List of potentially useful PlayDeckTemplates
class Decks : Codable {
    static let available = [ PlayingDeckTemplate(multiplier: 1, mask: nil, jokers: 0, displayName: "Standard"),
                             PlayingDeckTemplate(multiplier: 1, mask: nil, jokers: 2, displayName: "WithJokers"),
                             PlayingDeckTemplate(multiplier: 1, omitFrom2To: 6, displayName: "Piquet"),
                             PlayingDeckTemplate(multiplier: 1, omitFrom2To: 8, displayName: "Euchre"),
                             PlayingDeckTemplate(multiplier: 2, mask: nil, jokers: 0, displayName: "Double"),
                             PlayingDeckTemplate(multiplier: 2, mask: nil, jokers: 2, displayName: "DoubleWithJokers"),
                             PlayingDeckTemplate(multiplier: 2, omitFrom2To: 6, displayName: "Bezique"),
                             PlayingDeckTemplate(multiplier: 2, omitFrom2To: 8, displayName: "Pinochle") ]
}

// The default deck is from https://pixabay.com/en/card-deck-deck-cards-playing-cards-161536/
// The separate joker image is from https://pixabay.com/vectors/joker-poker-playing-cards-card-28255/
// The primary source image consists of five rows of thirteen subareas.   The first four rows are consistent with the canonical card
//    order if you traverse columns within rows.  The last row contains the card back at a known position.
class DefaultDeck : SourceDeck {
    static let deck = DefaultDeck()

    let cards : [Card]
    let aspectRatio : CGFloat

    init() {
        var back: UIImage
        var index = 0
        var allCards = [Card]()
        if let image = UIImage(named: DefaultDeckName) {
            let horizontalStep = image.size.width / DefaultDeckFrontColumns
            let verticalStep = image.size.height / DefaultDeckAllRows
            aspectRatio = horizontalStep / verticalStep
            let backRect = DefaultDeck.getRectangle(horizontalStep, verticalStep, DefaultDeckBackRow, DefaultDeckBackColumn)
            back = cropImage(image, backRect)
            // Traversing columns within rows gives the desired order
            for row in 0..<DefaultDeckFrontRows {
                for column in 0..<DefaultDeckFrontColumns {
                    let frontRect = DefaultDeck.getRectangle(horizontalStep, verticalStep, row, column)
                    let front = cropImage(image, frontRect)
                    allCards.append(Card(index, front: front, back: back))
                    index += 1
                }
            }
        } else {
            Logger.logFatalError("Could not load image for default card deck")
        }
        if let jokerImage = UIImage(named: JokerImageName) {
            let frontRect = allCards[0].bounds
            let front = cropImage(jokerImage, frontRect)
            allCards.append(Card(index, front: front, back: back))
            index += 1
            allCards.append(Card(index, front: front, back: back))
        } else {
            Logger.logFatalError("Could not load joker image for default card deck")
        }
        cards = allCards
    }

    // Determine the cropping rectangle for the deck image to cut out a particular card or the back.
    // The deck image is a grid with some rows and columns and all cells in the grid are the same size.
    private static func getRectangle(_ horizontalStep: CGFloat, _ verticalStep: CGFloat, _ row: Int, _ column: Int) -> CGRect {
        let startX = horizontalStep * column
        let startY = verticalStep * row
        return CGRect(x: startX, y: startY, width: horizontalStep, height: verticalStep)
    }
}
