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

// Basic support for game communication.  Three implementations are
// contemplated.
// 1.  Multi-peer (proximity).  Implemented.
// 2.  Apple Game center.  Maybe.  If it can be tested conveniently.
// 3.  Serverless backend (using the Nimbella stack).
// If (3) can be implemented and implementing (2) will be any kind of a
//   problem, I will drop (2).

// The protocol implemented by all Communicator implementations
protocol Communicator {
    init(_ player: Player, _ delegate: CommunicatorDelegate)
    func send(_ gameState: GameState)
    func shutdown()
    func updatePlayers(_ players: [Player])
}

// The protocol for the delegate (callbacks)
protocol CommunicatorDelegate {
    func connectedDevicesChanged(_ numDevices: Int)
    func gameChanged(_ gameState: GameState)
    func error(_ error: Error)
    func lostPlayer(_ peer: String)
}

// Enumerate the kinds of communicators that exist.  We treat serverless communicators
// with different game groups as different "kinds".
enum CommunicatorKind {
    case MultiPeer, GameCenter, Serverless(String)

    // Construct CommunicatorKind from a tag value (e.g. one stored in UserDefaults).
    static func from(_ tag: String?) -> CommunicatorKind {
        guard let name = tag else {
            return .MultiPeer
        }
        switch name {
            // Serverless group names must not begin with blank
        case " MultiPeer":
            return .MultiPeer
        case " GameCenter":
            return .GameCenter
        default: return .Serverless(name)
        }
    }

    // Get the appropriate tag value for this CommunicatorKind
    var tag : String {
        switch self {
        case .MultiPeer:
            return " MultiPeer"
        case .GameCenter:
            return " GameCenter"
        case .Serverless (let gameName):
            return gameName
        }
    }

    // Get the appropriate display name (e.g for option dialogs)
    var displayName : String {
        switch self {
        case .MultiPeer:
            return LocalOnly
        case .GameCenter:
            return PlayViaGameCenter
        case .Serverless (let gameName):
            return gameName
        }
    }

    // Get the "next" kind.  This sequences through the fixed kinds and uses the serverless game
    // table to sequence through perhaps multiple serverless game groups.
    var next: CommunicatorKind {
        switch self {
        case .MultiPeer:
            return .GameCenter
        case .GameCenter:
            if let name = serverlessGames.names.first {
                return .Serverless(name)
            } else {
                return .MultiPeer
            }
        case .Serverless (let name):
            if let nextName = serverlessGames.next(name) {
                return .Serverless(nextName)
            } else {
                return .MultiPeer
            }
        }
    }
}

// Global function to create a communicator of given kind
func makeCommunicator(_ kind: CommunicatorKind, _ player: Player, _ delegate: CommunicatorDelegate,
                      _ host: UIViewController) -> Communicator? {
    switch kind {
    case .MultiPeer:
        return MultiPeerCommunicator(player, delegate)
    case .GameCenter:
        bummer(title: "Not implemented", message: "Game Center communications are not yet implemented", host: host)
        return nil
    case .Serverless(let groupName):
        guard let gameToken = serverlessGames.getToken(groupName) else {
            // This actually represents a loss of internal consistency since the group name was chosen from
            // a dialog and should have an associated token.  Not clear what else we can do about it though.
            bummer(title: "Not found", message: "Game group \(groupName) was not found", host: host)
            return nil
        }
        return ServerlessCommunicator(gameToken, player, delegate)
    }
}
