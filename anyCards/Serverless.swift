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

// To use a serverless model for what is, conceptually, a multi-cast group, requires overcoming an impedence mismatch.
// We use a 2-second repeating timer to poll for what would otherwise be push notifications from the group.
class ServerlessCommunicator : NSObject, Communicator {
    let localID: String
    let delegate: CommunicatorDelegate
    let timer: DispatchSourceTimer
    var lastGameState: GameState? = nil
    var opRunning: Bool = false

    required init(_ localID: String, _ delegate: CommunicatorDelegate) {
        self.localID = localID
        self.delegate = delegate
        let queue = DispatchQueue.global(qos: .background)
        self.timer = DispatchSource.makeTimerSource(queue: queue)
        self.timer.schedule(deadline: .now(), repeating: .seconds(2), leeway: .milliseconds(100))
        super.init()
        self.timer.setEventHandler {
            self.postAnAction("getGameState", nil, self.newGameState)
        }
        self.timer.resume()
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

    func newGameState(_ data: Data?, _ response: URLResponse?, _ err: Error?) {
        opRunning = false
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
