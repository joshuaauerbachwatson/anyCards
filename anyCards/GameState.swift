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
    // Examined only on first yield: part of setup performed by leader
    let deckType : PlayingDeckTemplate?
    let handArea : Bool
    // Fields always present
    let items : [ItemHolder] // The positions of all the cards and boxes
    let yielding : Bool      // If true, the transmitting player is yielding control to the next player in turn
    let areaSize : CGSize    // The size of the playing area of the transmitting player (for rescaling with unlike-sized devices)

    // Initializer from local ViewController state.
    // The 'includeHandArea' flag is presented when the items should include cards in the hand area.  This is _never_
    // done when transmitting but is done when simply using the GameState to facilitate layout.
    convenience init(_ controller: ViewController, yielding: Bool = false, includeHandArea: Bool = false) {
        self.init(controller.deckType, controller.hasHands, yielding, controller.playingArea,
                  includeHandArea ? controller.publicArea : nil)
    }

    // General initializer, not publicly visible.  TODO there used to be many convenience initializers but not any more,
    // so perhaps we can collapse this into the one remaining one.
    private init(_ deckType: PlayingDeckTemplate?, _ handArea: Bool,
                 _ yielding: Bool, _ playingArea: UIView?, _ publicArea:  CGRect?) {
        let cards = playingArea?.subviews.filter({isEligibleCard($0, publicArea) || $0 is GridBox}).map{ ItemHolder.make($0) } ?? []
        self.deckType = deckType
        self.handArea = handArea
        self.items = cards
        self.yielding = yielding
        self.areaSize = playingArea?.bounds.size ?? CGSize.zero
    }
    // decoding initializer is auto-generated

    // Conform to Equatable protocol
    static func == (lhs: GameState, rhs: GameState) -> Bool {
        return lhs.deckType?.displayName == rhs.deckType?.displayName
        && lhs.handArea == rhs.handArea
        && lhs.items == rhs.items
        && lhs.yielding == rhs.yielding
        && lhs.areaSize == rhs.areaSize
    }
}

// Determine if a view is a card and its center is in the public area.
// If there is no public area (may be true during early phases of game setup), then all cards are eligible.
fileprivate func isEligibleCard(_ maybe: UIView, _ publicArea: CGRect?) -> Bool {
    if maybe is Card {
        return publicArea?.contains(maybe.center) ?? true
    } else {
        return false
    }
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
