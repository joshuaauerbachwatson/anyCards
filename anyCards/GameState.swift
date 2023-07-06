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
    // In initial setup, only the player list is transmitted, along with the intended number of players
    let players : [Player]   // The list of players, ordered by 'order' fields (ascending).  Eventually, all players must agree on the list
    let numPlayers : Int     // The number of players needed to play (must be agreed upon)
    // As part of first player's first show or yield the PlayingDeckTemplate and handArea values are transmitted (ignored at other times)
    let deckType : PlayingDeckTemplate?
    let handArea : Bool
    // Fields used during play (starting with the first player's first turn)
    let items : [ItemHolder]  // The state of each card in the active deck plus all GridBoxes (use empty array before play begins)
    let yielding : Bool      // If true, the transmitting player is yielding control to the next player in turn
    let areaSize : CGSize    // The size of the playing area of the transmitting player (used for rescaling with unlike-sized devices)

    // Initializer from current playing area view used when simply performing layout (initially or in response to a size change).  Only the
    // playingArea is important and everything in the playing area is processed (even if there is a hand area).  This is indicated by passing
    // a nil publicArea
    convenience init(_ playingArea: UIView) {
        self.init([], -1, nil, false, false, playingArea, nil)
    }

    // Initializer used for initial exchanges while establishing the player list.  Just players and the desired number of players are important
    convenience init(players: [Player], numPlayers: Int) {
        self.init(players, numPlayers, nil, false, false, nil, nil)
    }

    // Initializer used by the first player on or prior to his first yield; includes the deckType and handArea arguments
    convenience init(deckType: PlayingDeckTemplate, handArea: Bool, yielding: Bool, playingArea: UIView, publicArea: CGRect) {
        self.init([], -1, deckType, handArea, yielding, playingArea, publicArea)
    }

    // Initializer used for all moves once the first player has yielded
    convenience init(yielding: Bool, playingArea: UIView, publicArea: CGRect) {
        self.init([], -1, nil, OptionSettings.instance.hasHands, yielding, playingArea, publicArea)
    }
    
    // Initializer from Dictionary (accept new game state sent from the server)
    convenience init(_ newState: Dictionary<String,Any>) {
        let players = newState["players"] as? [Player] ?? []
        let numPlayers = newState["numPlayers"] as? Int ?? -1
        let deckType = newState["deckType"] as? PlayingDeckTemplate
        let handArea = newState["handArea"] as? Bool ?? false
        let yielding = newState["yielding"] as? Bool ?? false
        let playingArea = newState["playingArea"] as? UIView
        let publicArea = newState["publicArea"] as? CGRect
        self.init(players, numPlayers, deckType, handArea, yielding, playingArea, publicArea)
    }

    // General initializer, not publicly visible.
    private init(_ players: [Player], _ numPlayers: Int, _ deckType: PlayingDeckTemplate?, _ handArea: Bool,
                 _ yielding: Bool, _ playingArea: UIView?, _ publicArea:  CGRect?) {
        let cards = playingArea?.subviews.filter({isEligibleCard($0, publicArea) || $0 is GridBox}).map{ ItemHolder.make($0) } ?? []
        self.players = players
        self.numPlayers = numPlayers
        self.deckType = deckType
        self.handArea = handArea
        self.items = cards
        self.yielding = yielding
        self.areaSize = playingArea?.bounds.size ?? CGSize.zero
    }
    // decoding initializer is auto-generated

    // Conform to Equatable protocol
    static func == (lhs: GameState, rhs: GameState) -> Bool {
        return lhs.players == rhs.players
        && lhs.numPlayers == rhs.numPlayers
        && lhs.deckType?.displayName == rhs.deckType?.displayName
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
