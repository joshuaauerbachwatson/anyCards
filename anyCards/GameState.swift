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
class GameState : Codable {
    // In initial setup, only the player list is transmitted, along with max and min players
    let players : [Player]   // The list of players, ordered by 'order' fields (ascending).  Eventually, all players must agree on the list
    let maxPlayers : Int     // Maximum number of players that can play (must be agreed upon)
    let minPlayers : Int     // Minimum number of players needed to begin play (must be agreed upon)
    // As part of first player's first show or yield the PlayingDeckTemplate and handArea values are transmitted (ignored at other times)
    let deckType : PlayingDeckTemplate?
    let handArea : Bool
    // Fields used during play (starting with the first player's first turn)
    let cards : [CardState]  // The state of each card in the active deck plus all GridBoxes (use empty array before play begins
    let yielding : Bool      // If true, the transmitting player is yielding control to the next player in turn
    let areaSize : CGSize    // The size of the playing area of the transmitting player (used for rescaling with unlike-sized devices)

    // Initializer from current playing area view used when simply performing layout (initially or in response to a size change).  Only the
    // playingArea is important and everything in the playing area is processed (even if there is a hand area).  This is indicated by passing
    // nil as the maxPublicY.
    convenience init(_ playingArea: UIView) {
        self.init([], -1, -1, nil, false, false, playingArea, nil)
    }

    // Initializer used for initial exchanges while establishing the player list.  Just players and their min and max are important
    convenience init(players: [Player], minPlayers: Int, maxPlayers: Int) {
        self.init(players, minPlayers, maxPlayers, nil, false, false, nil, nil)
    }

    // Initializer used by the first player on or prior to his first yield; includes the deckType and handArea arguments
    convenience init(deckType: PlayingDeckTemplate, handArea: Bool, yielding: Bool, playingArea: UIView, publicArea: CGRect) {
        self.init([], -1, -1, deckType, handArea, yielding, playingArea, publicArea)
    }

    // Initializer used for all moves once the first player has yielded
    convenience init(yielding: Bool, playingArea: UIView, publicArea: CGRect) {
        self.init([], -1, -1, nil, OptionSettings.instance.hasHands, yielding, playingArea, publicArea)
    }

    // General initializer, not publically visible.  Note that the handArea argument is not just initialized, it also governs
    // how the playingArea is processed to find relevant subviews.
    private init(_ players: [Player], _ minPlayers: Int, _ maxPlayers: Int, _ deckType: PlayingDeckTemplate?, _ handArea: Bool,
                 _ yielding: Bool, _ playingArea: UIView?, _ publicArea:  CGRect?) {
        let cards = playingArea?.subviews.filter({isEligibleCard($0, publicArea) || $0 is GridBox}).map{ CardState($0) } ?? []
        self.players = players
        self.minPlayers = minPlayers
        self.maxPlayers = maxPlayers
        self.deckType = deckType
        self.handArea = handArea
        self.cards = cards
        self.yielding = yielding
        self.areaSize = playingArea?.bounds.size ?? CGSize.zero
    }

    // decoding initializer is auto-generated
}

// Determine if a view is a card and its center Y is in the public area
fileprivate func isEligibleCard(_ maybe: UIView, _ publicArea: CGRect?) -> Bool {
    if maybe is Card {
        return publicArea?.contains(maybe.center) ?? true
    } else {
        return false
    }
}

// Represents the state of an individual Card or GridBox
class CardState : Codable {
    let origin : CGPoint  // The origin of the SnapFrame for a GridBox
    let index : Int       // Or -1 for a GridBox
    let faceUp : Bool     // Ignored for a GridBox
    let name : String?    // nil except for GridBox that has had a name assigned

    // Initializer from a Card or GridBox.  The argument MUST be one of these (ensured by the GameState consructors)
    init( _ view: UIView) {
        if let card = view as? Card {
            origin = card.frame.origin
            faceUp = card.isFaceUp
            index = card.index
            name = nil
        } else if let box = view as? GridBox {
            origin = box.snapFrame.origin
            faceUp = false
            index = -1
            name = box.name
        } else {
            Logger.logFatalError("Argument to the CardState constructor must be a Card or GridBox; got \(type(of :view)) instead")
        }
    }

    // Decoding initializer is auto-generated
}
