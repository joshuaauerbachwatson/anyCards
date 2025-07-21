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
import AuerbachLook

// The description for the game
fileprivate let description = """
<p>
    <em>AnyCards</em> provides a virtual cardtable surface that is shared across
    devices, and a virtual deck of cards.  It allows you to move and turn over cards,
    make boxes to hold stacks of cards, and do routine moves like dealing or
    taking up a hand.
</p>

<p>The players use their separate devices to play a card game with
    the cards. Each player may optionally have a private hand. The game
    provides for an orderly succession of turns but does not otherwise
    build in the rules of any particular card game. It will support the
    playing of a wide variety of games that are played entirely with
    cards.</p>

<p>Achieving agreement about what game to play, enforcing its
    rules, or incorporating interactions such as bidding, may require
    voice or message contact between players.  There is a built-in chat channel
    that may go part or all of the way to solving this problem.
"""

// Fulfill the HelpHandle contract.
struct AnyCardsHelpHandle: HelpHandle {
    let baseURL: URL?
    let appSpecificTOC = [
        HelpTOCEntry("Basics", "Card Manipulation Basics"),
        HelpTOCEntry("Boxes", "Boxes", indented: true),
        HelpTOCEntry("Hands", "The Private Hand Area", indented: true),
        HelpTOCEntry("Setup", "Setting up a Game"),
        HelpTOCEntry("Playing", "Playing and Ending a Game")
    ]
    let generalDescription = description
    let appSpecificHelp: String
    let email: String? = "anycardsreports@gmail.com"
    let appName = "AnyCards"
    let tipResetter: TipResetter? = nil

    init() {
        let path = Bundle.module.url(forResource: "AnyCardsHelp", withExtension: "html")!
        baseURL = path
        guard let html = try? String(contentsOf: path, encoding: .utf8) else {
            Logger.logFatalError("Help for AnyCards could not be found or could not be read")
        }
        appSpecificHelp = html
    }
}
