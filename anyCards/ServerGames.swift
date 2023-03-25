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

// Stores pairs consisting of player group tokens (required) and player group nicknames (optional).  Used only when playing games
// using the server (with MPC, the player group consists of those in proximity, by definition).

struct ServerGamePair: Codable {
    let token: String
    let nickName: String?
}

class ServerGames : Codable {
    // The ServerGamePairs being stored persistently
    var pairs = [ServerGamePair]()

    var tokens: [String] {
        get {
            return pairs.map { $0.token }
        }
    }

    var first: ServerGamePair? {
        get {
            return pairs.first
        }
    }

    // Get the "next" pair, given a token
    func next(_ current: String) -> ServerGamePair? {
        guard let index = tokens.firstIndex(of: current), index < tokens.count - 1 else {
            Logger.log("\(current) has no 'next'")
            return nil
        }
        let ans = pairs[index + 1]
        Logger.log("next(\(current))=\(ans)")
        return ans
    }

    // Remove items by token value (there should be only one such item but this will remove all in case of duplicates)
    func remove(_ item: String) {
        Logger.log("remove(\(item))")
        pairs.removeAll(where: { $0.token == item })
        save()
    }

    // Save the pairs to disk
    private func save() {
        let encoder = JSONEncoder()
        guard let encoded = try? encoder.encode(self) else {
            return Logger.log("Failed to encode serverless group table")
        }
        let dictionaryFile = getDocDirectory().appendingPathComponent(ServerGameFile).path
        FileManager.default.createFile(atPath: dictionaryFile, contents: encoded, attributes: nil)
        Logger.log("Server group table successfully saved")
    }

    // Store a new entry (name, token) in the dictionary
    func storeEntry(_ token: String, _ nickName: String?) {
        let newPair = ServerGamePair(token: token, nickName: nickName)
        Logger.log("save game tokens updated with \(token)(\(nickName ?? "nil"))")
        pairs.append(newPair)
        save()
    }
}

var serverGames: ServerGames = {
    let storageFile = getDocDirectory().appendingPathComponent(ServerGameFile)
    do {
        let archived = try Data(contentsOf: storageFile)
        let decoder = JSONDecoder()
        let ans = try decoder.decode(ServerGames.self, from: archived)
        Logger.log("ServerGames instance loaded from disk with \(ans.pairs.count) entries")
        return ans
    } catch {
        Logger.log("Saved ServerGames not found, a new one was created")
        return ServerGames()
    }
}()
