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
import unigame
import SwiftUI
import AuerbachLook

fileprivate let DeckTypeKey = "DeckType"
fileprivate let HasHandsKey = "HasHands"

class AnyCardsGameHandle: GameHandle {
    // Settings stored permanently

    var hasHands : Bool {
        get {
            return UserDefaults.standard.bool(forKey: HasHandsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: HasHandsKey)
        }
    }

    var deckType  : PlayingDeckTemplate {
        get {
            if let data = UserDefaults.standard.data(forKey: DeckTypeKey) {
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
                UserDefaults.standard.set(encoded, forKey: DeckTypeKey)
            } catch let error {
                Logger.log("Error encoding NonStandardDeck information from UserDefaults: " + error.localizedDescription)
            }
        }
    }
    
    // Tolerate a broad range of players (including solitaire).  Conforms toe GameHandle
    var numPlayerRange: ClosedRange<Int> = 1...6

    // The name of this app (conforms to GameHandle)
    var appId: String = "anyoldcardgame"
    
    // The TokenProvider (conforms to GameHandle)
    var tokenProvider: any unigame.TokenProvider = Auth0TokenProvider()
    
    var mainPlayingView: PlayingView? = nil
    
    // Conforms to GameHandle
    func reset() {
        // TODO more may be needed here
        mainPlayingView?.reset()
    }
    
    // Conforms to GameHandle
    func stateChanged(_ data: [UInt8], duringSetup: Bool) -> (any Error)? {
        if let playing = mainPlayingView {
            return playing.newPlayingState(data, duringSetup: duringSetup)
        }
        Logger.logFatalError("The main playing view was never initialized")
    }
    
    // Conforms to GameHandle
    func encodeState(duringSetup: Bool) -> [UInt8] {
        if let playing = mainPlayingView {
            return playing.encodeState(duringSetup: duringSetup)
        }
        Logger.logFatalError("The main playing view was never initialized")
    }
    
    // TODO can we get away with single instances of the views (as below)?
    
    // Conforms to GameHandle
    var setupView: (any View)? = AnyCardsSetup()
    
    // Conforms to GameHandle
    var playingView: any View = AnyCardsPlaying()
}
