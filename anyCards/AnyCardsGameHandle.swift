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

class AnyCardsGameHandle: GameHandle {
    var numPlayerRange: ClosedRange<Int> = 1...6
    
    var appId: String = "anyoldcardgame"
    
    var tokenProvider: any unigame.TokenProvider = Auth0TokenProvider()
    
    func stateChanged(_ data: Data, duringSetup: Bool) -> (any LocalizedError)? {
       return nil // TODO
    }
    
    func encodeState(duringSetup: Bool) -> Data {
        return Data() // TODO
    }
    
    var setupView: (any View)? = AnyCardsSetup()
    
    var playingView: any View = AnyCardsPlaying()
}
