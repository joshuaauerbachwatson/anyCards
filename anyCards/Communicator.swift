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

// Basic support for game communication (either multi-peer or game center)

// The protocol implemented by both Communicator implementations
protocol Communicator {
    init(_ localID: String, _ delegate: CommunicatorDelegate)
    func send(_ gameState: GameState)
    func shutdown()
    func updatePlayers(_ players: [Player])
}

// The protocol for the delegate (callbacks)
protocol CommunicatorDelegate {
    func connectedDevicesChanged(_ connectedDevices: [String])
    func gameChanged(_ gameState: GameState)
    func error(_ error: Error)
    func lostPlayer(_ peer: String)
}

// Enumerate the kinds of communicators that exist
enum CommunicatorKind : Int {
    case MultiPeer, GameCenter

    var displayName : String {
        switch self {
        case .MultiPeer:
            return LocalOnly
        case .GameCenter:
            return PlayViaGameCenter
        }
    }
}

// Global function to create a communicator of given kind
func makeCommunicator(_ kind: CommunicatorKind, _ localID: String, _ delegate: CommunicatorDelegate) -> Communicator {
    switch kind {
    case .MultiPeer:
        return MultiPeerCommunicator(localID, delegate)
    case .GameCenter:
        Logger.logFatalError("Game Center communication not implemented yet")
    }
}
