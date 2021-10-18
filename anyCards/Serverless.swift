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

// To use a serverless model for what is, conceptually, a multi-cast group, requires overcoming an impedence mismatch.
// We use a 2-second repeating timer to poll for what would otherwise be push notifications from the group.
class ServerlessCommunicator : NSObject, Communicator {
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
        guard let encoded = try? encoder.encode([ "gameToken": gameToken ]) else {
            Logger.logFatalError("Unexpected failure to encode gameToken")
        }
        startListening(encoded)
    }

    // Standard initializer (not directly useful for this one)
    required init(_ player: Player, _ delegate: CommunicatorDelegate) {
        self.playerID = String(player.order)
        self.delegate = delegate
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        super.init()
    }

    // Starts the "listening" process (invocations of 'poll' at 2 second intervals)
    func startListening(_ gameToken: Data) {
        let queue = DispatchQueue.global(qos: .background)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        self.timer = timer
        timer.schedule(deadline: .now(), repeating: .seconds(2), leeway: .milliseconds(100))
        timer.setEventHandler {
            postAnAction("getAllState", gameToken, self.newState)
        }
        timer.resume()
    }

    // Interpret a new state
    func newState(_ data: Data?, _ response: URLResponse?, _ err: Error?) {
        guard let validData = validateResponse(data, response, err, delegate.error) else {
            return
        }
        if let playerList = validData["players"] {
            let players = playerList.split(separator: " ").map { String($0) }
            if players != self.lastPlayerList {
                delegate.connectedDevicesChanged(players.count)
                self.lastPlayerList = players
            }
        }
        if let gameState = validData["gameState"] {
            if gameState != self.lastGameState {
                do {
                    let state = try decoder.decode(GameState.self, from: gameState.data(using: .utf8)!)
                    self.lastGameState = gameState
                    delegate.gameChanged(state)
                } catch {
                    delegate.error(error)
                    return
                }
            }
        }

    }

    // Send a new game state
    func send(_ gameState: GameState) {
        var arg: Data
        do {
            let encodedGameState = String(data: try encoder.encode(gameState), encoding: .utf8)
            arg = try encoder.encode([ "gameToken": self.gameToken, "gameState": encodedGameState ])
        } catch {
            delegate.error(error)
            return
        }
        postAnAction("newGameState", arg) { (data, response, err) in
            guard let result = validateResponse(data, response, err, self.delegate.error) else {
                // Error already posted
                return
            }
            if let err = result["problem"] {
                self.delegate.error(ServerlessError("Remote error: \(err)"))
            }
        }
    }

    // Shutdown this communicator.  First withdraw from the game, then stop the polling.
    func shutdown() {
        var arg: Data
        do {
            arg = try encoder.encode([ "gameToken": gameToken, "player": playerID ])
        } catch {
            delegate.error(error)
            return
        }
        postAnAction("withdraw", arg) { (data, response, err) in
            guard let result = validateResponse(data, response, err, self.delegate.error) else {
                // Error already posted
                return
            }
            if let err = result["problem"] {
                self.delegate.error(ServerlessError("Remote error: \(err)"))
            }
            self.timer?.cancel()
        }
    }

    // Update the players list.  Not used for serverless.  The remote player list is maintained by
    // means of the multiple users polling.
    func updatePlayers(_ players: [Player]) {
        // Do nothing
    }
}

// Subroutines for invoking actions and checking results

typealias HttpCompletionHandler = (Data?, URLResponse?, Error?) -> Void

func postAnAction(_ action: String, _ input: Data?, _ handler: @escaping HttpCompletionHandler) {
    guard let url = URL(string: ActionRoot + action + ".json") else {
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
struct ServerlessError: Error, CustomDebugStringConvertible {
    let debugDescription: String
    let localizedDescription: String
    init(_ msg: String) {
        self.localizedDescription = msg
        self.debugDescription = msg
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
        errHandler(ServerlessError("Could not interpret response from backend"))
        return nil
    }
    Logger.log("Got response: \(resp)")
    if resp.statusCode < 200 || resp.statusCode > 299 {
        errHandler(ServerlessError("Got status code \(resp.statusCode) communicating with backend"))
        return nil
    }
    guard let body = data else {
        Logger.log("Response had no body")
        errHandler(ServerlessError("No response data provided"))
        return nil
    }
    do {
        return try JSONDecoder().decode(Dictionary.self, from: body)
    } catch {
        Logger.log("Got decoding error: \(error)")
        errHandler(error)
        return nil
    }
}
