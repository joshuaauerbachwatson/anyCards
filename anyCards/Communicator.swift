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

// Basic support for game communication.  Two implementations are
// contemplated.
// 1.  Multi-peer (proximity).  Implemented.
// 2.  Backend with volatile state (using DigitalOcean App Platform).  In progress.
// The long range plan is to drop (1) and retire the communicator abstraction,
// then shift logic to the backend so we can better implement pluggable game rules.

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

// Enumerate the kinds of communicators that exist.  We treat server-based communicators
// with different game groups as different "kinds".
enum CommunicatorKind {
    case MultiPeer, ServerBased(String)

    // Construct CommunicatorKind from a tag value (e.g. one stored in UserDefaults).
    static func from(_ tag: String?) -> CommunicatorKind {
        guard let name = tag else {
            return .MultiPeer
        }
        switch name {
            // ServerBased group names must not begin with blank
        case " MultiPeer":
            return .MultiPeer
        default: return .ServerBased(name)
        }
    }

    // Get the appropriate tag value for this CommunicatorKind
    var tag : String {
        switch self {
        case .MultiPeer:
            return " MultiPeer"
        case .ServerBased (let gameName):
            return gameName
        }
    }

    // Get the appropriate display name (e.g for option dialogs)
    var displayName : String {
        switch self {
        case .MultiPeer:
            return LocalOnly
        case .ServerBased (let gameName):
            return gameName
        }
    }

    // Get the "next" kind.  This sequences through the fixed kind (MultiPeer) and uses the server based game
    // table to sequence through perhaps multiple server based game groups.
    var next: CommunicatorKind {
        switch self {
        case .MultiPeer:
            if let name = serverGames.names.first {
                return .ServerBased(name)
            } else {
                return .MultiPeer
            }
        case .ServerBased (let name):
            if let nextName = serverGames.next(name) {
                return .ServerBased(nextName)
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
    case .ServerBased(let groupName):
        guard let gameToken = serverGames.getToken(groupName) else {
            // This actually represents a loss of internal consistency since the group name was chosen from
            // a dialog and should have an associated token.  Not clear what else we can do about it though.
            bummer(title: "Not found", message: "Game group \(groupName) was not found", host: host)
            return nil
        }
        return ServerBasedCommunicator(gameToken, player, delegate)
    }
}
