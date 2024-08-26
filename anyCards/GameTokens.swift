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

// Stores game tokens (now generally called "game IDs").  Game tokens are used only when using the server (with MPC,
// the player group consists of those in proximity, by definition).

class GameTokens : Codable {
    // The stored tokens themselves
    var values = [String]()

    var first: String? {
        get {
            return values.first
        }
    }

    // Remove items by token value (there should be only one such item but this will remove all in case of duplicates)
    func remove(_ item: String) {
        values.removeAll(where: { $0 == item })
        save()
        switch OptionSettings.instance.communication {
        case .ServerBased(let gameToken):
            if gameToken == item {
                OptionSettings.instance.communication = .ServerBased(CommunicatorKind.DeletedGameToken)
            }
        default:
            break
        }
    }

    // Remove item by index position.  Returns the value of the item.
    func remove(at: Int) -> String {
        let removed = values.remove(at: at)
        save()
        return removed
    }

    // Save the values to disk
    private func save() {
        let encoder = JSONEncoder()
        guard let encoded = try? encoder.encode(self) else {
            return Logger.log("Failed to encode server tokens")
        }
        let gamesFile = getDocDirectory().appendingPathComponent(ServerGameFile).path
        FileManager.default.createFile(atPath: gamesFile, contents: encoded, attributes: nil)
        Logger.log("Server tokens successfully saved")
    }

    // Store a new token in the list.
    func storeToken(_ token: String) {
        Logger.log("save game tokens updated with \(token)")
        if values.contains(token) {
            return
        }
        values.append(token)
        save()
    }
}

var gameTokens: GameTokens = {
    let storageFile = getDocDirectory().appendingPathComponent(ServerGameFile)
    do {
        let archived = try Data(contentsOf: storageFile)
        let decoder = JSONDecoder()
        let ans = try decoder.decode(GameTokens.self, from: archived)
        Logger.log("Game tokens loaded from disk with \(ans.values.count) entries")
        return ans
    } catch {
        Logger.log("Saved GameTokens not found, a new one was created")
        return GameTokens()
    }
}()
