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

// Represents the state of a game.  Transmitted between devices.   Also used to facilitate layout within a single device.
class GameState : Codable, Equatable {
    // Setup is only sent by the leader and only until the leader's first yield
    struct Setup : Codable {
        let deckType : PlayingDeckTemplate
        let handArea : Bool
    }
    let setup : Setup?       // Setup information if present.
    let boxes:  [GridBoxState] // The positions and properties of the boxes
    let cards: [CardState]   // The positions and properties of the cards
    let sendingPlayer : Int  // The index of the player constructing the GameState
    let activePlayer: Int    // The index of the player whose turn it is (== previous except when yielding)
    let areaSize : CGSize    // The size of the playing area of the transmitting player (for rescaling with unlike-sized devices)

    // Initializer from local ViewController state.
    //  - The 'includeHandArea' flag is presented when the items should include cards in the hand area.  This is _never_
    // done when transmitting but is done when using the GameState locally to facilitate layout.
    //  - The activePlayer argument is presented when yielding, since, in that case, the active player after yielding
    // will differ from the active player before yielding.  The local activePlayer value cannot change until after
    // transmission, since transmit is gated by thisPlayersTurn.
    init(_ controller: ViewController, includeHandArea: Bool = false, activePlayer: Int? = nil) {
        if controller.leadPlayer && !controller.setupIsComplete {
            self.setup = Setup(deckType: controller.deckType, handArea: controller.hasHands)
        } else {
            self.setup = nil
        }
        self.sendingPlayer = controller.thisPlayer
        self.activePlayer = activePlayer ?? controller.activePlayer
        self.boxes = controller.playingArea.subviews.filter({$0 is GridBox}).map{ GridBoxState($0 as! GridBox) }
        self.cards = controller.playingArea.subviews.filter({isEligibleCard($0, includeHandArea)}).map{ CardState($0 as! Card) }
        self.areaSize = controller.playingArea.bounds.size
    }
    // decoding initializer is auto-generated

    // Conform to Equatable protocol
    static func == (lhs: GameState, rhs: GameState) -> Bool {
        return lhs.setup?.deckType.displayName == rhs.setup?.deckType.displayName
        && lhs.setup?.handArea == rhs.setup?.handArea
        && lhs.boxes == rhs.boxes
        && lhs.cards == rhs.cards
        && lhs.sendingPlayer == rhs.sendingPlayer
        && lhs.activePlayer == rhs.activePlayer
        && lhs.areaSize == rhs.areaSize
    }
}

// Determine if a view is a card and is not private, except in the special case where we accept private cards
fileprivate func isEligibleCard(_ maybe: UIView, _ privateOk: Bool) -> Bool {
    guard let card = maybe as? Card else { return false }
    return privateOk || !card.isPrivate
}

// Represents the transmissable state unique to a Card
final class CardState : Codable, Equatable {
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

    // Conform to Equatable protocol
    static func == (lhs: CardState, rhs: CardState) -> Bool {
        lhs.origin == rhs.origin
        && lhs.index == rhs.index
        && lhs.faceUp == rhs.faceUp
    }
}

// Represents the transmissable state unique to a GridBox
final class GridBoxState : Codable, Equatable {
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

    // Conform to Equatable protocol
    static func == (lhs: GridBoxState, rhs: GridBoxState) -> Bool {
        lhs.origin == rhs.origin
        && lhs.name == rhs.name
        && lhs.kind == rhs.kind
        && lhs.owner == rhs.owner
    }
}
