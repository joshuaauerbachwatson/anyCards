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

// Constants mimic those in the backend
let pathCreate   = "/create"
let pathDelete   = "/delete"
let pathNewState = "/newstate"
let pathPoll     = "/poll"
let pathWithdraw = "/withdraw"
let argAppToken  = "appToken"
let argGameToken = "gameToken"
let argForce     = "force"
let argGameState = "gameState"
let argPlayer    = "player"
let argPlayers   = "players"

// This communicator is temporarily using a strategy designed for a serverless implementation.   In that case there was an
// impedence mismatch for what is, conceptually, a multi-cast group.  We use a 2-second repeating timer to poll for what
// The plan is to stop using http and start using a connection based protocol in which we can do true push notifications
// from the group.
class ServerBasedCommunicator : NSObject, Communicator {
    let playerID: String
    let delegate: CommunicatorDelegate
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    var gameToken: String?
    var timer: DispatchSourceTimer? = nil
    var lastGameState: String? = nil
    var lastPlayerList: [String] = []

    // The initializer to use for this Communicator.  Accepts a gameToken and starts listening
    convenience init(_ gameToken: String, _ player: Player, _ delegate: CommunicatorDelegate) {
        self.init(player, delegate)
        self.gameToken = gameToken
        guard let encoded = try? encoder.encode([ argGameToken: gameToken, argPlayer: playerID ]) else {
            Logger.logFatalError("Unexpected failure to encode gameToken and player")
        }
        startListening(encoded)
    }

    // Standard initializer specified by protocol (not directly useful for this class)
    required init(_ player: Player, _ delegate: CommunicatorDelegate) {
        self.playerID = String(player.order)
        self.delegate = delegate
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        super.init()
    }

    // Starts the "listening" process (invocations of 'poll' at 2 second intervals)
    func startListening(_ args: Data) {
        let queue = DispatchQueue.global(qos: .background)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        self.timer = timer
        timer.schedule(deadline: .now(), repeating: .seconds(2), leeway: .milliseconds(100))
        timer.setEventHandler {
            postAnAction(pathPoll, args, self.newState)
        }
        timer.resume()
    }

    // Interpret a new state
    func newState(_ data: Data?, _ response: URLResponse?, _ err: Error?) {
        guard let validData = validateResponse(data, response, err, delegate.error) else {
            shutdown()
            return
        }
        if let playerList = validData[argPlayers] {
            let players = playerList.split(separator: " ").map { String($0) }
            if players != self.lastPlayerList {
                delegate.connectedDevicesChanged(players.count)
                self.lastPlayerList = players
            }
        }
        guard let gameState = validData[argGameState] else {
            delegate.error(ServerError("Invalid answer to poll"))
            shutdown()
            return
        }
        if gameState != self.lastGameState {
            do {
                let state = try decoder.decode(GameState.self, from: gameState.data(using: .utf8)!)
                self.lastGameState = gameState
                delegate.gameChanged(state)
            } catch {
                delegate.error(error)
                shutdown()
                return
            }
        } // do nothing if no change
    }

    // Send a new game state
    func send(_ gameState: GameState) {
        var arg: Data
        do {
            let encodedGameState = String(data: try encoder.encode(gameState), encoding: .utf8)
            arg = try encoder.encode([ argGameToken: self.gameToken, argPlayer: self.playerID, argGameState: encodedGameState ])
        } catch {
            delegate.error(error)
            return
        }
        postAnAction(pathNewState, arg) { (data, response, err) in
            _ = validateResponse(data, response, err, self.delegate.error)
        }
    }

    // Shutdown this communicator.  First stop the polling, then try to withdraw from the game (silently)
		func shutdown() {
    		 self.timer?.cancel()
    		 guard let arg = try? encoder.encode([ argGameToken: gameToken, argPlayer: playerID ]) else {
                 // ignore error and stop trying to withdraw
         		 return
    		 }
        postAnAction(pathWithdraw, arg) { (data, response, err) in return } // ignore errors
    }

    // Update the players list.  Not used for server based.  The remote player list is maintained by
    // means of the multiple users polling.
    func updatePlayers(_ players: [Player]) {
        // Do nothing
    }
}

// Subroutines for invoking actions and checking results

typealias HttpCompletionHandler = (Data?, URLResponse?, Error?) -> Void

func postAnAction(_ action: String, _ input: Data?, _ handler: @escaping HttpCompletionHandler) {
    guard let url = URL(string: ActionRoot + action) else {
        Logger.logFatalError("Unable to form request URL")
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = input
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    let task = URLSession.shared.dataTask(with: request, completionHandler: handler)
    Logger.log("Posting request: \(request)")
    task.resume()
}

// A generic error for communications problems
struct ServerError: Error, CustomDebugStringConvertible {
    let debugDescription: String
    let localizedDescription: String
    init(_ msg: String) {
        self.localizedDescription = msg
        self.debugDescription = msg
    }
    init(_ statusCode: Int) {
        self.init(HTTPURLResponse.localizedString(forStatusCode: statusCode))
    }
}

// Subroutine used by response handlers to validate the response and up-call an error if appropriate
// Returns the result dictionary or nil.
func validateResponse(_ data: Data?, _ response: URLResponse?, _ err: Error?, _ errHandler: (Error)->Void) -> Dictionary<String, String>? {
    if let err = err {
        Logger.log("Got error return: \(err)")
        errHandler(err)
        return nil
    }
    guard let resp = response as? HTTPURLResponse else {
        errHandler(ServerError("Could not interpret response from backend"))
        return nil
    }
    Logger.log("Got response: \(resp)")
    if resp.statusCode < 200 || resp.statusCode > 299 {
        errHandler(ServerError(resp.statusCode))
        return nil
    }
    if let body = data {
        do {
            return try JSONDecoder().decode(Dictionary.self, from: body)
        } catch {
            Logger.log("Got decoding error: \(error)")
            errHandler(error)
            return nil
        }
    } else {
        // empty body is ok in some contexts
        return Dictionary<String, String>()
    }
}
