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
    let items : [ItemHolder] // The positions of all the cards and boxes
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
        self.items = controller.playingArea.subviews.filter({isEligibleCard($0) || $0 is GridBox}).map{ ItemHolder.make($0) }
        self.areaSize = controller.playingArea.bounds.size
    }
    // decoding initializer is auto-generated

    // Conform to Equatable protocol
    static func == (lhs: GameState, rhs: GameState) -> Bool {
        return lhs.setup?.deckType.displayName == rhs.setup?.deckType.displayName
        && lhs.setup?.handArea == rhs.setup?.handArea
        && lhs.items == rhs.items
        && lhs.sendingPlayer == rhs.sendingPlayer
        && lhs.activePlayer == rhs.activePlayer
        && lhs.areaSize == rhs.areaSize
    }
}

// Determine if a view is a card and is not private.
fileprivate func isEligibleCard(_ maybe: UIView) -> Bool {
    guard let card = maybe as? Card else { return false }
    return !card.isPrivate
}

enum ItemHolder: Codable, Equatable {
    case Box(GridBoxState)
    case Card(CardState)

    static func make(_ item: UIView) -> ItemHolder {
        if let card = item as? Card {
            return .Card(CardState(card))
        }
        if let box = item as? GridBox {
            return .Box(GridBoxState(box))
        }
        Logger.logFatalError("Attempted creation of ItemHolder from a view that is not a Card or GridBox")
    }

    // Conform to Equatable protocol
    static func == (lhs: ItemHolder, rhs: ItemHolder) -> Bool {
        switch lhs {
        case .Box(let boxState1):
            switch rhs {
            case .Box(let boxState2):
                return boxState1 == boxState2
            default:
                return false
            }
        case .Card(let cardState1):
            switch rhs {
            case .Card(let cardState2):
                return cardState1 == cardState2
            default:
                return false
            }
        }
    }
}

// Represents the transmissable state unique to a Card
final class CardState : Codable, Equatable {
    let origin : CGPoint
    var index : Int   // permit overwrite when reordering a restored game state used as a restored setup
    let faceUp : Bool

    // Initializer from a Card
    init( _ card: Card) {
        faceUp = card.isFaceUp
        index = card.index
        origin = card.frame.origin
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
