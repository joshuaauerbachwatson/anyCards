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

// Stores associations between serverless game group names and game tokens
class ServerlessGames : Codable {
    // The dictionary keyed by the user-chosen game name string
    private var dictionary = [String: String]()

    // Get the token for a given name
    func getToken(_ name: String) -> String? {
        return dictionary[name]
    }

    // Get the name for a given token (slower in theory but we don't expect the dictionary to be large)
    func getName(_ token: String) -> String? {
        return dictionary.first { $0.1 == token }?.0
    }

    var names: [String] { dictionary.keys.sorted() }

    // Get the "next" name, given a name from the names list.  Slow in theory but we don't expect the dictionary
    // to be large
    func next(_ current: String) -> String? {
        guard let index = names.firstIndex(of: current), index < names.count - 1 else {
            return nil
        }
        return names[index + 1]
    }

    // Remove an item by its name
    func remove(_ item: String) {
        dictionary[item] = nil
        save()
    }

    // Save the dictionary to disk
    private func save() {
        let encoder = JSONEncoder()
        guard let encoded = try? encoder.encode(self) else { return Logger.log("Failed to serverless game table") }
        let dictionaryFile = getDocDirectory().appendingPathComponent(ServerlessGameFile).path
        FileManager.default.createFile(atPath: dictionaryFile, contents: encoded, attributes: nil)
    }

    // Store a new pair (name, token) in the dictionary
    func storePair(_ name: String, _ token: String) {
        dictionary[name] = token
        save()
    }
}

var serverlessGames: ServerlessGames = {
    let dictionaryFile = getDocDirectory().appendingPathComponent(ServerlessGameFile)
    do {
        let archived = try Data(contentsOf: dictionaryFile)
        let decoder = JSONDecoder()
        return try decoder.decode(ServerlessGames.self, from: archived)
    } catch {
        return ServerlessGames()
    }
}()
