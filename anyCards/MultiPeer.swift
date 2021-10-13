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
import MultipeerConnectivity

// Communicator implementation for multi-peer
class MultiPeerCommunicator : NSObject, Communicator {
    // The local "peer id"
    private let peerId : MCPeerID

    // The advertiser object
    private let serviceAdvertiser : MCNearbyServiceAdvertiser

    // The browser object
    private let serviceBrowser : MCNearbyServiceBrowser

    // The delegate, with which we communicate critical events
    private let delegate : CommunicatorDelegate?

    // The session as a lazily initialized private property
    private lazy var session : MCSession = {
        let session = MCSession(peer: self.peerId, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        return session
    }()

    // Initializer conformed to Communicator protocol (accepts delegate argument)
    required init(_ player: Player, _ delegate: CommunicatorDelegate) {
        self.delegate = delegate
        self.peerId = MCPeerID(displayName: String(player.order))
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: peerId, discoveryInfo: nil, serviceType: MultiPeerServiceName)
        self.serviceBrowser = MCNearbyServiceBrowser(peer: peerId, serviceType: MultiPeerServiceName)
        super.init()
        serviceBrowser.delegate = self
        serviceAdvertiser.delegate = self
        Logger.log("Multipeer: starting advertiser and browser")
        serviceAdvertiser.startAdvertisingPeer()
        serviceBrowser.startBrowsingForPeers()
    }

    // Send the game state to all peers.  A harmless no-op if there are no peers.  Handles errors (when there is at least one peer) by
    // calling delegate.error().   Implements Communicator protocol
    func send(_ gameState : GameState) {
        if session.connectedPeers.count > 0 {
            Logger.log("Sending new game state")
            let encoder = JSONEncoder()
            do {
                let encoded = try encoder.encode(gameState)
                try session.send(encoded, toPeers: session.connectedPeers, with: .reliable)
            } catch let error {
                delegate?.error(error)
            }
        }
    }

    // Shutdown communications
    func shutdown() {
        serviceAdvertiser.stopAdvertisingPeer()
        serviceBrowser.stopBrowsingForPeers()
        session.disconnect()
    }

    // Update the player list based on caller's view
    func updatePlayers(_ players: [Player]) {
        let registered = session.connectedPeers.map { $0.displayName }
        let newlyArrived = players.map({ String($0.order) }).filter { !registered.contains($0) }
        for arrived in newlyArrived {
            let peer = (arrived == peerId.displayName) ? peerId : MCPeerID(displayName: arrived)
            session.nearbyConnectionData(forPeer: peer) { (data, error) in
                if let data = data {
                    Logger.log("Adding \(arrived) to session")
                    self.session.connectPeer(peer, withNearbyConnectionData: data)
                }
            }
        }


    }
}

// Conformance to protocol MCNearbyServiceAdvertiserDelegate
extension MultiPeerCommunicator : MCNearbyServiceAdvertiserDelegate {
    // React to error in advertising
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        delegate?.error(error)
    }

    // React to invitation from peer
    // Note: This code accepts all incoming connections automatically.
    // To keep sessions private the user should be notified and asked to confirm incoming connections.
    // This can be implemented using the MCAdvertiserAssistant classes.
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Logger.log("didReceiveInvitationFromPeer \(peerID)")
        invitationHandler(true, self.session)
    }
}

// Conformance to protocol MCNearbyServiceBrowserDelegate
extension MultiPeerCommunicator : MCNearbyServiceBrowserDelegate {
    // React to error in browsing
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        delegate?.error(error)
    }

    // React to found peer
    // Note: This code invites any peer automatically. The MCBrowserViewController class
    // could be used to scan for peers and invite them manually (TODO).
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        Logger.log("Peer found: \(peerID)")
        browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
    }

    // React to losing contact with peer
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Logger.log("Peer lost: \(peerID)")
        delegate?.lostPlayer(peerID.displayName)
    }
}

// Conformance to protocol MCSessionDelegate
extension MultiPeerCommunicator : MCSessionDelegate {
    // React to state change
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Logger.log("peer \(peerID) didChangeState: \(state.rawValue)")
        self.delegate?.connectedDevicesChanged(session.connectedPeers.count)
    }

    // React to incoming data
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Logger.log("didReceiveData: \(data)")
        if let delegate = self.delegate {
            let decoder = JSONDecoder()
            do {
                let gameState = try decoder.decode(GameState.self, from: data)
                delegate.gameChanged(gameState)
            } catch let error {
                Logger.log("Error decoding game state: " + error.localizedDescription)
            }
        }
    }

    // React to received stream (not used here but required by protocol)
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        Logger.log("didReceiveStream")
    }

    // React to received resource (not used here but required by protocol)
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        Logger.log("didStartReceivingResourceWithName")
    }

    // React to received resource, alternate form (not used here but required by protocol)
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?,
                 withError error: Error?) {
        Logger.log("didFinishReceivingResourceWithName")
    }
}
