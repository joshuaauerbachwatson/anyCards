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

import Foundation

// Represents a Player.  The player is known by a name and has an "order" field.
// The leader will have order 1.  All other players have randomly generated orders in the range 2...UInt32.max
// The order determines the order in which players appear in the player list and governs the succession of
// play.  The player with the lowest order number is always the leader and always "plays first".  But, since
// the leader configures the game, he may yield after configuring and before making an actual move, causing the
// player just after him to play first.   A Player structure is not Codable per se but has a simple serialization
// deserialization for transmission purposes.
struct Player : Equatable {
    let name : String
    let order : UInt32

    // Memberwise initializer not generated by compiler since I declare another initializer
    init(name: String, order: UInt32) {
        self.name = name
        self.order = order
    }
    
    // Initializer to deserialize a token in a transmitted player list
    // A colon separates the base64 encoded name from the order string, which must represent non-zero
    // UInt32.  Note that if the coded string was properly formed, the initializer should succeed.
    init?(_ coded: String) {
        guard let sep = coded.lastIndex(of: ":") else { return nil }
        let encodedName = String(coded.prefix(upTo: sep))
        guard let encodedNameData = Data(base64Encoded: encodedName) else { return nil }
        guard let name = String(data: encodedNameData, encoding: .utf8) else { return nil }
        let orderStr = coded.suffix(from: coded.index(after: sep))
        guard let order = UInt32(orderStr), order > 0 else { return nil }
        self.init(name: name, order: order)
    }
    
    // Initializer used to generate your own Player struct (once)
    init(_ name: String, _ mustPlayFirst: Bool) {
        Logger.log("Player \(name) created with mustPlayFirst=\(mustPlayFirst)")
        let order = mustPlayFirst ? 1 : arc4random_uniform(UInt32.max - 2) + 2
        self.init(name: name, order: order)
    }

    // Turn the player into a transmittable token
    var token : String {
        let name = Data(self.name.utf8).base64EncodedString()
        return "\(name):\(String(order))"
    }
}

// Encode an array of players, along with a "max players" number.  Note: by design numPlayers is
// specified separately and need not be equal to the count of the players array.
func encodePlayers(_ numPlayers: Int, _ players: [Player]) -> String {
    let tokens = players.map { $0.token }
    return "\(numPlayers) \(tokens.joined(separator: " "))"
}

// Decode an array of players (prefixed by a number of players which may differ from the count of the array)
func decodePlayers(_ coded: String) -> (Int, [Player])? {
    let tokens = coded.split(separator: " ")
    guard let numPlayers = Int(tokens[0]) else { return nil }
    var players: [Player] = []
    for token in tokens.dropFirst() {
        guard let player = Player(String(token)) else { return nil }
        players.append(player)
    }
    return (numPlayers, players)
}
