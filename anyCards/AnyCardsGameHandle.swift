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
import Observation

fileprivate let HasHandsKey = "HasHands"

// This class is both the `GameHandle` for AnyCards and also its model object.
// It goes into the environment as an @Observable, alongside the UnigameModel.
@Observable
class AnyCardsGameHandle: GameHandle {

    // Settings stored permanently
    var hasHands : Bool = UserDefaults.standard.bool(forKey: HasHandsKey) {
        didSet {
            UserDefaults.standard.set(hasHands, forKey: HasHandsKey)
            playingSurface.setupPublicArea(true)
        }
    }

    var deckType  : PlayingDeckTemplate = PlayingDeckTemplate.load() ?? Decks.available[0].save() {
        didSet {
            deckType.save()
            playingSurface.newDeckType(deckType)
        }
    }
    
    // SavedSetups stored permanently
    var savedSetups: SavedSetups = SavedSetups.load()
    
    // Tolerate a broad range of players (including solitaire).  Conforms to GameHandle
    var numPlayerRange: ClosedRange<Int> = 1...6

    // The name of this app (conforms to GameHandle)
    var appId: String = "anyoldcardgame"
    
    // The TokenProvider (conforms to GameHandle)
    var tokenProvider: any unigame.TokenProvider = Auth0TokenProvider()

    // The playing surface view, which fills the unigame "playing" view and is also part of the unigame "setup" view.
    var playingSurface: PlayingSurface!
    
    // Conforms to GameHandle
    func reset() {
        playingSurface?.reset()
    }
    
    // Conforms to GameHandle
    func stateChanged(_ data: [UInt8], duringSetup: Bool) -> (any Error)? {
        return playingSurface.newPlayingState(data, duringSetup: duringSetup)
    }
    
    // Conforms to GameHandle
    func encodeState(duringSetup: Bool) -> [UInt8] {
        return playingSurface.encodeState(duringSetup: duringSetup)
    }
    
    // Conforms to GameHandle
    var setupView: (any View)? {
        AnyCardsSetup()
    }
    
    // Conforms to GameHandle
    var playingView: any View {
        AnyCardsPlaying()
    }
    
    // Shows that a setup global deal is possible (there is a main deck present and the dealing area is clear)
    var canDeal: Bool = false
    
    // Holds the box on which the various grid box menus should operate
    var box: GridBox? = nil
    
    // Provides the anchor for box-related popup menus as a UnitPoint
    var boxAnchor: UnitPoint {
        guard let boxCenter = box?.center else {
            return .center
        }
        let x = boxCenter.x / playingSurface.bounds.width
        let y = boxCenter.y / playingSurface.bounds.height
        return UnitPoint(x: x, y: y)
    }
    
    // Indicates that the main GridBox menu should be shown
    var showGridBoxMenu: Bool = false
    
    // Use this to set showGridBoxMenu, ensuring that 'box' is set
    func boxMenu(_ box: GridBox) {
        self.box = box
        showGridBoxMenu = true
    }
    // Indicates that the GridBox modification menu should be shown
    var showModifyBoxMenu: Bool = false
    
    // Use this to set showModifyBox, ensuring that 'box' is set
    func modifyBox(_ box: GridBox) {
        self.box = box
        showModifyBoxMenu = true
    }

    // Indicates that the grouping alert should be shown
    var showGroupingToggle: Bool = false
    
    // Calculate the correct anchor for the grouping toggle popover
    var privateAreaAnchor: UnitPoint {
        guard let publicArea = playingSurface.publicArea else {
            return .center
        }
        let point = CGPoint(x: publicArea.midX, y: playingSurface.publicArea.maxY)
        let x = point.x / playingSurface.bounds.width
        let y = point.y / playingSurface.bounds.height
        return UnitPoint(x: x, y: y)
    }
    
    // Indicates that the deal dialog should be shown
    var showDealDialog: Bool = false
    
    // Use this to set showDealDialog, ensuring that 'box' is set
    func dealDialog(_ box: GridBox) {
        self.box = box
        showDealDialog = true
    }
}
