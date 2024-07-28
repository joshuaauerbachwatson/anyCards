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

// Basic support for game communication.  Two implementations exist.
// 1.  Multi-peer (proximity).
// 2.  Backend with volatile state (using DigitalOcean App Platform).

// The protocol implemented by all Communicator implementations
protocol Communicator {
    var isChatAvailable: Bool { get }
    func sendChatMsg(_ mag: String)
    func send(_ gameState: GameState)
    func shutdown()
}

// The protocol for the delegate (callbacks)
protocol CommunicatorDelegate {
    func newPlayerList(_ numPlayers: Int, _ players: [Player])
    func gameChanged(_ gameState: GameState)
    func error(_ error: Error, _ deleteGame: Bool)
    func lostPlayer(_ peer: String)
    func newChatMsg(_ msg: String)
}

// Enumerate the kinds of communicators that exist.  We treat server-based communicators
// with different game tokens different "kinds".
enum CommunicatorKind: Equatable {
    case MultiPeer, ServerBased(String)
    
    // Value for a .ServerBased CommunicatorKind whose game token has been deleted
    static let DeletedGameToken = " Deleted"

    // Value for a tag, stored in OptionSettings, that denotes .MultiPeer rather than a game token
    private static let MultiPeerTag = " MultiPeer"

    // Construct CommunicatorKind from a tag value (e.g. one stored in UserDefaults).
    static func from(_ tag: String?) -> CommunicatorKind {
        guard let name = tag else {
            return .MultiPeer
        }
        switch name {
        case MultiPeerTag:
            return .MultiPeer
        default:
            return .ServerBased(name)
        }
    }

    // Get the appropriate tag value for this CommunicatorKind
    var tag : String {
        switch self {
        case .MultiPeer:
            return Self.MultiPeerTag
        case .ServerBased (let gameToken):
            return gameToken
        }
    }

    // Get the appropriate display name (e.g for option dialogs)
    var displayName : String {
        switch self {
        case .MultiPeer:
            return LocalText
        case .ServerBased (let gameToken):
            return gameToken
        }
    }
}

// Global function to create a communicator of given kind
func makeCommunicator(_ kind: CommunicatorKind, player: Player, delegate: CommunicatorDelegate,
                      host: UIViewController, handler: @escaping (Communicator?, LocalizedError?)->Void) {
    switch kind {
    case .MultiPeer:
        handler(MultiPeerCommunicator(player, delegate), nil)
    case .ServerBased(let gameToken):
        CredentialStore.instance.loginIfNeeded() { (credentials, error) in
            if let accessToken = credentials?.accessToken {
                handler(ServerBasedCommunicator(accessToken, gameToken: gameToken, player: player, delegate: delegate), nil)
            } else if let error = error {
                handler(nil, error)
            } else {
                Logger.logFatalError("Login result was neither credentials nor error")
            }
        }
    }
}
