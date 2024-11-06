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

// Represents the state of the playing view to be transmitted between devices.
// Also used to facilitate layout within a single device.
class PlayingState : Codable {
    let boxes:  [GridBoxState] // The positions and properties of the boxes
    let cards: [CardState]   // The positions and properties of the cards
    let areaSize : CGSize    // The size of the playing area of the transmitting player (for rescaling with unlike-sized devices)

    // Initializer from local PlayingView state.
    //  - The 'includeHandArea' flag is presented when the items should include cards in the hand area.  This is _never_
    // done when transmitting but is done when using the GameState locally to facilitate layout.
    init(_ playingView: PlayingSurface, includeHandArea: Bool = false) {
        self.boxes = playingView.subviews.filter({$0 is GridBox}).map{ GridBoxState($0 as! GridBox) }
        self.cards = playingView.subviews.filter({isEligibleCard($0, includeHandArea)}).map{ CardState($0 as! Card) }
        self.areaSize = playingView.bounds.size
    }
}

class PlayingStateWithSetup: PlayingState {
    let deckType: PlayingDeckTemplate
    let hasHands: Bool
    override init(_ playingView: PlayingSurface, includeHandArea: Bool = false) {
        deckType = playingView.gameHandle.deckType
        hasHands = playingView.gameHandle.hasHands
        super.init(playingView, includeHandArea: includeHandArea)
    }
    required init(from decoder: any Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
}

// Determine if a view is a card and is not private, except in the special case where we accept private cards
fileprivate func isEligibleCard(_ maybe: UIView, _ privateOk: Bool) -> Bool {
    guard let card = maybe as? Card else { return false }
    return privateOk || !card.isPrivate
}

// Represents the transmissable state unique to a Card
final class CardState : Codable {
    let origin : CGPoint
    var index : Int   // permit overwrite when reordering a restored game state used as a restored setup
    let faceUp : Bool
    // TODO: Consider that the following will always be false in any card state that is serialized since the intent is
    // never to store or transmit private cards.  However, it can be true in some CardStates when, for example,
    // using a GameState to help facilitate the rotation of the playing view.  It is a possible optimization to
    // omit the isPrivate flag when serializing and set it to false when deserializing but the benefit will likely
    // be small.
    let isPrivate : Bool

    // Initializer from a Card
    init( _ card: Card) {
        faceUp = card.isFaceUp
        index = card.index
        origin = card.frame.origin
        isPrivate = card.isPrivate
    }
}

// Represents the transmissable state unique to a GridBox
final class GridBoxState : Codable {
    let origin : CGPoint
    let name : String?
    let kind : GridBox.Kind
    let owner : Int

    // Initializer from a GridBox
    init( _ box: GridBox) {
        name = box.name
        kind = box.kind
        owner = box.owner
        origin = box.frame.origin
    }
}
