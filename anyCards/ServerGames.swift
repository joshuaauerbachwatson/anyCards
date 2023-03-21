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

// Stores associations between player group nicknames and player group tokens.  Used only when playing games
// using the server (with MPC, the player group

class ServerGames : Codable {
    // The dictionary keyed by the user-chosen game name string
    private var dictionary = [String: String]()

    // Get the token for a given name
    func getToken(_ name: String) -> String? {
        let ans = dictionary[name]
        Logger.log("getToken(\(name))=\(ans ?? "")")
        return ans
    }

    // Get the name for a given token (slower in theory but we don't expect the dictionary to be large)
    func getName(_ token: String) -> String? {
        let ans = dictionary.first { $0.1 == token }?.0
        Logger.log("getName(\(token))=\(ans ?? "")")
        return ans
    }

    var names: [String] {
        let ans = dictionary.keys.sorted()
        Logger.log("names=\(ans)")
        return ans
    }

    // Get the "next" name, given a name from the names list.  Slow in theory but we don't expect the dictionary
    // to be large
    func next(_ current: String) -> String? {
        guard let index = names.firstIndex(of: current), index < names.count - 1 else {
            Logger.log("\(current) has no 'next'")
            return nil
        }
        let ans = names[index + 1]
        Logger.log("next(\(current))=\(ans)")
        return ans
    }

    // Remove an item by its name
    func remove(_ item: String) {
        Logger.log("remove(\(item))")
        dictionary[item] = nil
        save()
    }

    // Save the dictionary to disk
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
    func storeEntry(_ name: String, _ token: String) {
        dictionary[name] = token
        Logger.log("dictionary updated with \(name)=\(token)")
        save()
    }
}

var serverGames: ServerGames = {
    let dictionaryFile = getDocDirectory().appendingPathComponent(ServerGameFile)
    do {
        let archived = try Data(contentsOf: dictionaryFile)
        let decoder = JSONDecoder()
        let ans = try decoder.decode(ServerGames.self, from: archived)
        Logger.log("ServerGames instance loaded from disk with \(ans.names.count) entries")
        return ans
    } catch {
        Logger.log("Saved ServerGames not found, a new one was created")
        return ServerGames()
    }
}()
