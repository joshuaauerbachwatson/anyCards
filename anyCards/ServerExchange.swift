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
fileprivate let pathNewState = "/newstate"
fileprivate let pathWithdraw = "/withdraw"
fileprivate let argGameToken = "gameToken"
fileprivate let argPlayer    = "player"
fileprivate let argPlayers   = "players"
fileprivate let argGameState = "gameState"
fileprivate let argError     = "argError"
fileprivate let playerHeader = "PlayerOrder"
fileprivate let gameHeader   = "GameToken"
fileprivate let websocketURL = "wss://unigame-befsi.ondigitalocean.app/websocket"
fileprivate let typeChat = UInt8(("C" as UnicodeScalar).value)
fileprivate let typeGame = UInt8(("G" as UnicodeScalar).value)
fileprivate let typePlayers = UInt8(("P" as UnicodeScalar).value)
fileprivate let typeLostPlayer = UInt8(("L" as UnicodeScalar).value)

// This communicator currently uses two means of communication, a websocket and https request/response.
// The https mechanism may be gradually phased out.
// Currently:  websocket is used for chat and received state.  https is used for sending gamestate and for
// withdrawing from the game.
class ServerBasedCommunicator : NSObject, Communicator {
    // Chat is available with this communicator.  True, it is only available when the communicator is connected.
    // But, a Communicator connects on construction and should be rendered inaccessible on failure or termination of
    // a game.
    let isChatAvailable = true
    
    // Internal state
    private let gameToken: String
    private let accessToken: String
    private let player: Player
    private let delegate: CommunicatorDelegate
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var webSocketTask: URLSessionWebSocketTask! // Initialized after super call

    private var lastGameState: GameState? = nil

    // The initializer to use for this Communicator.  Accepts a gameToken and player and starts listening
    init(_ accessToken: String, gameToken: String, player: Player, delegate: CommunicatorDelegate) {
        self.accessToken = accessToken
        self.gameToken = gameToken
        self.player = player
        self.delegate = delegate
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        super.init()
        self.webSocketTask = connectWebsocket(game: gameToken, player: player, accessToken: accessToken)
    }

    // Process a new Received state
    private func processReceivedState(_ newState: ReceivedState) {
        // Note: eventually ReceivedState goes away and we get GameState and Player list separately
        if let playerList = newState.players, let (numPlayers, players) = decodePlayers(playerList) {
            delegate.newPlayerList(numPlayers, players)
        }
        if let gameState = newState.gameState {
            if gameState != self.lastGameState {
                 self.lastGameState = gameState
                 delegate.gameChanged(gameState)
            } // do nothing if no change
        } else if self.lastGameState != nil {
            // Once some GameState has been established, all polls should be returning one
            delegate.error(ServerError("No game state included in received state"), false)
        } // but if a GameState was never sent, we can assume that none exists on the server yet either
    }

    // Send a new game state (part of Communicator protocol)
    func send(_ gameState: GameState) {
        var arg: Data
        do {
            let msg = SentState(gameToken: self.gameToken, player: self.player.token,
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
    
    // Shutdown this communicator.  First disconnect the websocket, then try to withdraw from the game (silently)
    // Part of communicator protocol
    func shutdown() {
        disconnectWebsocket()
        guard let arg = try? encoder.encode([ argGameToken: gameToken, argPlayer: player.token ]) else {
        // ignore error and stop trying to withdraw
            return
        }
        postAnAction(pathWithdraw, accessToken, arg) { (data, response, err) in return } // ignore errors
    }

    // Subroutine to initialize the websocket connection
    private func connectWebsocket(game: String, player: Player, accessToken: String) -> URLSessionWebSocketTask {
        Logger.log("New websocket connection with game=\(game), player=\(player.token)")
        var numPlayers = ""
        if player.order == 1 {
            // Leader
            numPlayers = "&numPlayers=\(OptionSettings.instance.numPlayers)"
        }
        let url = URL(string: "\(websocketURL)?\(gameHeader)=\(game)&\(playerHeader)=\(player)\(numPlayers)")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask.receive(completionHandler: onWebsocketReceive)
        webSocketTask.resume()
        return webSocketTask
    }
    
    // Subroutine to disconnect the websocket
    private func disconnectWebsocket() {
        webSocketTask.cancel(with: .normalClosure, reason: nil)
    }
    
    // Completion handler for websocket receive.  Posts a new receive, then processes the present one.
    private func onWebsocketReceive(incoming: Result<URLSessionWebSocketTask.Message, Error>) {
        webSocketTask.receive(completionHandler: onWebsocketReceive)

        if case .success(let message) = incoming {
            onWebsocketMessage(message: message)
        }
        else if case .failure(let error) = incoming {
            let nserror = error as NSError
            if nserror.domain == NSPOSIXErrorDomain && nserror.code == POSIXError.ENOTCONN.rawValue {
                return
            }
            Logger.logFatalError("Error receiving message: \(error)")
        }
    }
    
    // Handles a message received on the websocket
    private func onWebsocketMessage(message: URLSessionWebSocketTask.Message) {
        // The message type may be either string or data.  At the protocol level these are both just bytes
        // but the Task code will have encoded to String if it thinks it's getting text.  We undo this here and
        // treat everything like a byte array.
        switch message {
        case .data(let data):
            processIncomingFromWebsocket(data)
        case .string(let text):
            if let data = text.data(using: .utf8) {
                processIncomingFromWebsocket(data)
            }
        default:
            Logger.logFatalError("Unanticipated incoming message type")
        }
    }
  
    // Process incoming information from websocket
    private func processIncomingFromWebsocket(_ rawData: Data) {
        let type = rawData[0]
        let data = rawData.dropFirst()
        switch type {
        case typeChat:
            delegate.newChatMsg(String(decoding: data, as: UTF8.self))
        case typeGame:
            deliverReceivedState(data)
        case typePlayers:
            deliverPlayerList(data)
        case typeLostPlayer:
            deliverLostPlayer(data)
        default:
            Logger.logFatalError("Protocol error.  Unknown message type \(type)")
        }
    }
    
    // Decodes and then processes received game state
    private func deliverReceivedState(_ data: Data) {
        do {
            let received = try JSONDecoder().decode(ReceivedState.self, from: data)
            processReceivedState(received)
        } catch {
            Logger.log("Got decoding error: \(error)")
            delegate.error(error, false)
        }
    }
    
    // Decodes and then processes received player list
    private func deliverPlayerList(_ data: Data) {
        if let coded = String(data: data, encoding: .utf8), let answer = decodePlayers(coded) {
            let (numPlayers, players) = answer
            delegate.newPlayerList(numPlayers, players)
        }
    }
    
    // Decodes and then processes received lost player message
    private func deliverLostPlayer(_ data: Data) {
        if let lost = String(data: data, encoding: .utf8), let player = Player(lost) {
            delegate.lostPlayer(player)
        }
    }
    
    // Send a chat message.  Part of the Communicator protocol
    func sendChatMsg(_ text: String) {
        let toSend = "[\(OptionSettings.instance.userName)] \(text)"
        let message = URLSessionWebSocketTask.Message.string(toSend)
        webSocketTask.send(message) { error in
            if let error = error {
                Logger.logFatalError("Error sending message: \(error)")
            }
        }
    }
}


// Subroutines for invoking actions and checking results

typealias HttpCompletionHandler = (Data?, URLResponse?, Error?) -> Void

fileprivate func postAnAction(_ action: String, _ token: String, _ input: Data?, _ handler: @escaping HttpCompletionHandler) {
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

// The value received on the websocket as a push notification when the state of the server changes.
struct ReceivedState: Decodable {
    let players: String?
    let gameState: GameState?
}

// Subroutine used by response handlers to validate the response and up-call an error if appropriate
// Returns the result dictionary if valid or nil if error.
fileprivate func validateResponse<T: Decodable>(_ data: Data?, _ response: URLResponse?, _ err: Error?, _ type: T.Type, _ errHandler: (Error, Bool)->Void) -> T? {
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
