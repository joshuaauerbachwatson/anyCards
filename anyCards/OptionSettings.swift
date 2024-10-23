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

import UIKit
import AuerbachLook

// Model the UserDefaults keys and types that we use in the game.  By convention we read directly from UserDefaults
// and write through to UserDefaults on any change.  This yields the simplest maintenance.  Make this single-instance
// to make it easy to access and to ensure there is only one instance of UserSettings in the app.  Apple says changes
// are asynchronous, so, with more than one instance of UserSettings, there could be race conditions.  With a single
// instance, there is a consistent view within the app, even if the disk's view is lagging.
class OptionSettings {
    // Preference keys
    private static let DeckTypeKey = "DeckType"
    private static let HasHandsKey = "HasHands"

    // Single instance
    static let instance = OptionSettings()

    // Constructor is private to guarantee single instance
    private init() {}

    // Values

    var hasHands : Bool {
        get {
            return UserDefaults.standard.bool(forKey: OptionSettings.HasHandsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: OptionSettings.HasHandsKey)
        }
    }

    var deckType  : PlayingDeckTemplate {
        get {
            if let data = UserDefaults.standard.data(forKey: OptionSettings.DeckTypeKey) {
                let decoder = JSONDecoder()
                do {
                    return try decoder.decode(PlayingDeckTemplate.self, from: data)
                } catch let error {
                    Logger.log("Error decoding deck type information from UserDefaults: " + error.localizedDescription)
                }
            }
            // Never set or the current value didn't decode correctly (treat the same as 'never set')
            let ans = Decks.available[0]  // The first available deck is the implicit default (by convention, this is a standard deck)
            self.deckType = ans // invokes setter
            return ans
        }
        set {
            let encoder = JSONEncoder()
            do {
                let encoded = try encoder.encode(newValue)
                UserDefaults.standard.set(encoded, forKey: OptionSettings.DeckTypeKey)
            } catch let error {
                Logger.log("Error encoding NonStandardDeck information from UserDefaults: " + error.localizedDescription)
            }
        }
    }
}
