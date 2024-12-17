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
import AuerbachLook

// Keeps the game setups being stored persistently
class SavedSetups : Codable {
    struct Setup: Codable {
        let numPlayers: Int
        let contents: PlayingState
    }
    
    // The setups being stored persistently
    var setups = Dictionary<String, Setup>()

    // Get the names of eligible setups (matching numPlayers)
    func setupNames(_ numPlayers: Int) -> [String] {
        let eligible = setups.filter { $0.value.numPlayers == numPlayers }
        return eligible.keys.map { String($0) } // Surprisingly, the type of Disctionary<T,_>.keys is not [T]
    }

    func first(_ numPlayers: Int) -> (String, PlayingState)? {
        if let ans = setups.first(where: {$0.value.numPlayers == numPlayers }) {
            return (ans.key, ans.value.contents)
        }
        return nil
    }

    // Remove item by name
    func remove(_ item: String) {
        Logger.log("remove(\(item))")
        setups[item] = nil
        save()
    }

    // Save the seltups to disk
    private func save() {
        let encoder = JSONEncoder()
        guard let encoded = try? encoder.encode(self) else {
            return Logger.log("Failed to encode serverless group table")
        }
        let dictionaryFile = getDocDirectory().appendingPathComponent(SavedSetupsFile).path
        FileManager.default.createFile(atPath: dictionaryFile, contents: encoded, attributes: nil)
        Logger.log("Setups successfully saved")
        Logger.log("savedSetups file contents at save time: \(String(bytes: encoded, encoding: .utf8) ?? "")")
    }

    // Store a new entry in the dictionary.  This may be protected against overwriting
    // depending on the third argument
    @discardableResult
    func storeEntry(_ name: String, _ state: PlayingState, _ numPlayers: Int, _ overwrite: Bool) -> Bool {
        if !overwrite && setups[name] != nil {
            return false
        }
        setups[name] = Setup(numPlayers: numPlayers, contents: state)
        save()
        return true
    }
    
    class func load() -> SavedSetups {
        let storageFile = getDocDirectory().appendingPathComponent(SavedSetupsFile)
        do {
            let archived = try Data(contentsOf: storageFile)
            Logger.log("savedSetups loaded from disk")
            let decoder = JSONDecoder()
            let ans = try decoder.decode(SavedSetups.self, from: archived)
            Logger.log("\(ans.setups.count) setups found")
            for setup in ans.setups {
                Logger.log(" \(setup.0)")
            }
            return ans
        } catch {
            Logger.log("Saved setups not found, a new instance was created")
            return SavedSetups()
        }
    }
}
