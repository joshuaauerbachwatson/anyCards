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
let argGameToken = "gameToken"
let argPlayer    = "player"
let argPlayers   = "players"
let argGameState = "gameState"
let argError     = "argError"

// This communicator is temporarily using a strategy designed for a serverless implementation.   In that case there was an
// impedence mismatch for what is, conceptually, a multi-cast group.  We use a 2-second repeating timer to poll for any
// changes that would otherwise be pushed out upon occurance.
// TODO The plan is to augment http with websockets, the latter being used for push notifications as well as a chat channel.
class ServerBasedCommunicator : NSObject, Communicator {
    let playerID: String
    let delegate: CommunicatorDelegate
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    var gameToken: String
    var accessToken: String
    var timer: DispatchSourceTimer? = nil
    var lastGameState: GameState? = nil
    var lastPlayerList: Set<String> = Set<String>()

    // The initializer to use for this Communicator.  Accepts a gameToken and player and starts listening
    init(_ accessToken: String, gameToken: String, player: Player, delegate: CommunicatorDelegate) {
        self.accessToken = accessToken
        self.gameToken = gameToken
        self.playerID = String(player.order)
        self.delegate = delegate
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        super.init()
        // TODO poll is slated for removal once we can use websocket as an alternative
        let poll = Poll(gameToken: gameToken, player: playerID)
        guard let encoded = try? encoder.encode(poll) else {
            Logger.logFatalError("Unexpected failure to encode gameToken and player")
        }
        startListening(encoded)
    }

    // Starts the "listening" process (invocations of 'poll' at 2 second intervals)
    func startListening(_ args: Data) {
        let queue = DispatchQueue.global(qos: .background)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        self.timer = timer
        timer.schedule(deadline: .now(), repeating: .seconds(2), leeway: .milliseconds(100))
        timer.setEventHandler {
            postAnAction(pathPoll, self.accessToken, args, self.newState)
        }
        timer.resume()
    }

    // Interpret a new state
    func newState(_ data: Data?, _ response: URLResponse?, _ err: Error?) {
        guard let newState = validateResponse(data, response, err, ReceivedState.self, delegate.error) else {
            timer?.cancel()
            return
        }
        if let playerList = newState.players {
            let players = Set<String>(playerList.split(separator: " ").map { String($0) })
            if players != self.lastPlayerList {
                delegate.connectedDevicesChanged(players.count)
                findMissingPlayers(players)
                self.lastPlayerList = players
            }
        }
        if let gameState = newState.gameState {
            if gameState != self.lastGameState {
                 self.lastGameState = gameState
                 delegate.gameChanged(gameState)
            } // do nothing if no change
        } else if self.lastGameState != nil {
            // Once some GameState has been established, all polls should be returning one
            timer?.cancel()
            delegate.error(ServerError("No game state included in answer to poll"), false)
        } // but if a GameState was never sent, we can assume that none exists on the server yet either
    }

    // Find a player that was missing on a poll and notify so game can be terminated.  Only one lost player is reported because
    // that report will end the game anyway.   The argument is the new player set; the old one is in self.lastPlayerList
    func findMissingPlayers(_ players: Set<String>) {
        let missing = self.lastPlayerList.subtracting(players)
        if let toReport = missing.first {
            self.delegate.lostPlayer(toReport)
        }
    }

    // Send a new game state
    func send(_ gameState: GameState) {
        var arg: Data
        do {
            let msg = SentState(gameToken: self.gameToken, player: self.playerID,
                                gameState: gameState)
            arg = try encoder.encode(msg)
        } catch {
            delegate.error(error, false)
            return
        }
        postAnAction(pathNewState, accessToken, arg) { (data, response, err) in
            _ = validateResponse(data, response, err, Dictionary<String,String>.self, self.delegate.error)
        }
    }

    // Shutdown this communicator.  First stop the polling, then try to withdraw from the game (silently)
    func shutdown() {
        self.timer?.cancel()
        guard let arg = try? encoder.encode([ argGameToken: gameToken, argPlayer: playerID ]) else {
        // ignore error and stop trying to withdraw
            return
        }
        postAnAction(pathWithdraw, accessToken, arg) { (data, response, err) in return } // ignore errors
    }

    // Update the players list.  Not used for server based.  The remote player list is maintained by
    // means of the multiple users polling.
    func updatePlayers(_ players: [Player]) {
        // Do nothing
    }
}

// Subroutines for invoking actions and checking results

typealias HttpCompletionHandler = (Data?, URLResponse?, Error?) -> Void

func postAnAction(_ action: String, _ token: String, _ input: Data?, _ handler: @escaping HttpCompletionHandler) {
    guard let url = URL(string: ActionRoot + action) else {
        Logger.logFatalError("Unable to form request URL")
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = input
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
    init(_ statusCode: Int, withMessage: String? = nil) {
        var msg = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        if let detail = withMessage {
            msg = "\(msg) (\(detail))"
        }
        self.init(msg)
    }
}

// The value sent in a newstate exchange
struct SentState: Encodable {
    let gameToken: String
    let player: String
    let gameState: GameState
}

// The value sent when polling
struct Poll: Encodable {
    let gameToken: String
    let player: String
}

// The value received in response to a poll
struct ReceivedState: Decodable {
    let players: String?
    let gameState: GameState?
}

// Subroutine used by response handlers to validate the response and up-call an error if appropriate
// Returns the result dictionary if valid or nil if error.
func validateResponse<T: Decodable>(_ data: Data?, _ response: URLResponse?, _ err: Error?, _ type: T.Type, _ errHandler: (Error, Bool)->Void) -> T? {
    if let err = err {
        Logger.log("Got error return: \(err)")
        errHandler(err, false)
        return nil
    }
    guard let resp = response as? HTTPURLResponse else {
        errHandler(ServerError("Could not interpret response from backend"), false)
        return nil
    }
    Logger.log("Got response status code: \(resp.statusCode)")
    if resp.statusCode < 200 || resp.statusCode > 299 {
        // By convention, in any error case, the body will not conform to T but rather will be a one-element string->string Dictionary
        // whose element is "error" (or else there is no body).
        var errMsg: String? = nil
        if let data = data, data.count > 0  {
            if let errBody = try? JSONDecoder().decode(Dictionary<String,String>.self, from: data) {
                errMsg = errBody[argError]
            }
        }
        errHandler(ServerError(resp.statusCode, withMessage: errMsg), resp.statusCode == 404)
        return nil
    }
    var body: T? = nil
    if let data = data, data.count > 0 {
//        let showData = String(decoding: data, as: UTF8.self)
//        Logger.log("Got data: \(showData)")
        Logger.log("Decoding message with type \(type)")
        do {
            body = try JSONDecoder().decode(T.self, from: data)
        } catch {
            Logger.log("Got decoding error: \(error)")
            errHandler(error, false)
            return nil
        }
    }
    return body
}
