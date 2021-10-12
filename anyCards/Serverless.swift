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

typealias HttpCompletionHandler = (Data?, URLResponse?, Error?) -> Void

class ServerlessError: LocalizedError {
    var localizedDescription: String
    init(_ msg: String) {
        localizedDescription = msg
    }
}

// To use a serverless model for what is, conceptually, a multi-cast group, requires overcoming an impedence mismatch.
// We use a 2-second repeating timer to poll for what would otherwise be push notifications from the group.
class ServerlessCommunicator : NSObject, Communicator {
    let localID: String
    let delegate: CommunicatorDelegate
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    var gameToken: Data? = nil
    var timer: DispatchSourceTimer? = nil
    var lastGameState: GameState? = nil
    var lastPlayerList: [Player] = []
    var opRunning: Bool = false

    convenience init(_ gameToken: String, _ localID: String, _ delegate: CommunicatorDelegate) {
        self.init(localID, delegate)
        guard let encoded = try? encoder.encode([ "gameToken": gameToken ]) else {
            Logger.logFatalError("Unexpected failure to encode gameToken")
        }
        self.gameToken = encoded
        startListening(encoded)
    }

    required init(_ localID: String, _ delegate: CommunicatorDelegate) {
        self.localID = localID
        self.delegate = delegate
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        super.init()
    }

    func startListening(_ gameToken: Data) {
        let queue = DispatchQueue.global(qos: .background)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        self.timer = timer
        timer.schedule(deadline: .now(), repeating: .seconds(2), leeway: .milliseconds(100))
        timer.setEventHandler {
            self.postAnAction("getAllState", gameToken, self.newState)
        }
        timer.resume()
    }

    // Subroutine for invoking actions
    func postAnAction(_ action: String, _ input: Data?, _ handler: @escaping HttpCompletionHandler) {
        if opRunning {
            return
        }
        guard let url = URL(string: ActionRoot + action + ".json") else {
            Logger.logFatalError("Unable to form request URL")
        }
        opRunning = true
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = input
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let task = URLSession.shared.dataTask(with: request, completionHandler: handler)
        task.resume()
    }

    // Subroutine used by all response handlers to validate the response and up-call an error if appropriate
    // Returns data or nil.
    func validateResponse(_ data: Data?, _ response: URLResponse?, _ err: Error?) -> Dictionary<String, String>? {
        opRunning = false
        if let err = err {
            delegate.error(err)
            return nil
        }
        guard let resp = response as? HTTPURLResponse else {
            delegate.error(ServerlessError("Could not interpret response from backend"))
            return nil
        }
        if resp.statusCode < 200 || resp.statusCode > 299 {
            delegate.error(ServerlessError("Got status code \(resp.statusCode) communicating with backend"))
            return nil
        }
        guard let body = data else {
            delegate.error(ServerlessError("No response data provided"))
            return nil
        }
        do {
            return try decoder.decode(Dictionary.self, from: body)
        } catch {
            delegate.error(error)
            return nil
        }
    }

    // Interpret a new state
    func newState(_ data: Data?, _ response: URLResponse?, _ err: Error?) {
        guard let validData = validateResponse(data, response, err) else {
            return
        }
        if let playerList = validData["players"] {
            do {
                let players = try decoder.decode([String].self, from: playerList.data(using: .utf8)!)
                let report = players == self.lastPlayerList
                // TODO process players
            } catch {
                delegate.error(error)
                return
            }
        }
        if let gameState = validData["gameState"] {
            do {
                let state = try decoder.decode(GameState.self, from: gameState.data(using: .utf8)!)
                // TODO process state
            } catch {
                delegate.error(error)
                return
            }
        }

    }

    func send(_ gameState: GameState) {
        Logger.logFatalError("Serverless communicator is under construction")
    }

    func shutdown() {
        Logger.logFatalError("Serverless communicator is under construction")
    }

    func updatePlayers(_ players: [Player]) {
        Logger.logFatalError("Serverless communicator is under construction")
    }
}
