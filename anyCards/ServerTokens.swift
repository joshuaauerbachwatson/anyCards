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

// Stores tokens, with optional nicknames.  Tokens are used only when using the server (with MPC,
// the player group consists of those in proximity, by definition).

struct StoredToken: Codable {
    let token: String
    let nickName: String?
    var display: String {
        if let nickName = nickName {
            return "\(nickName): \(token)"
        }
        return token
    }
}

class ServerTokens : Codable {
    // The stored tokens themselves
    var pairs = [StoredToken]()

    var displays: [String] {
        get {
            return pairs.map { $0.display }
        }
    }

    var first: StoredToken? {
        get {
            return pairs.first
        }
    }

    // Remove items by token value (there should be only one such item but this will remove all in case of duplicates)
    func remove(_ item: String) {
        pairs.removeAll(where: { $0.token == item })
        save()
    }

    // Remove item by index position.  Returns the display value for the item.
    func remove(at: Int) -> String {
        let removed = pairs.remove(at: at)
        save()
        return removed.display
    }

    // Save the pairs to disk
    private func save() {
        let encoder = JSONEncoder()
        guard let encoded = try? encoder.encode(self) else {
            return Logger.log("Failed to encode server tokens")
        }
        let dictionaryFile = getDocDirectory().appendingPathComponent(ServerGameFile).path
        FileManager.default.createFile(atPath: dictionaryFile, contents: encoded, attributes: nil)
        Logger.log("Server tokens successfully saved")
    }

    // Store a new entry (name, token) in the dictionary.  Returns the display value for the new item.
    func storeEntry(_ token: String, _ nickName: String?) -> String {
        let newPair = StoredToken(token: token, nickName: nickName)
        Logger.log("save game tokens updated with \(newPair.display)")
        pairs.append(newPair)
        save()
        return newPair.display
    }

    // Decorates a token to become a displayable value with a nickname iff the token is in the saved server tokens.
    // Otherwise returns the token itself
    func getDisplayFromToken(_ token: String) -> String {
        if let pair = pairs.first(where: { $0.token == token }) {
            return pair.display
        }
        return token
    }
}

var serverTokens: ServerTokens = {
    let storageFile = getDocDirectory().appendingPathComponent(ServerGameFile)
    do {
        let archived = try Data(contentsOf: storageFile)
        let decoder = JSONDecoder()
        let ans = try decoder.decode(ServerTokens.self, from: archived)
        Logger.log("Server tokens loaded from disk with \(ans.pairs.count) entries")
        return ans
    } catch {
        Logger.log("Saved ServerTokens not found, a new one was created")
        return ServerTokens()
    }
}()
