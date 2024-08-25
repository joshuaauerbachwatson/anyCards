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

// A table dialog for choosing a deck kind

class PlayingDeckDialog : TableDialogController {
    let host : GameSetupDialog

    // Main init
    init(_ host: GameSetupDialog, size: CGSize, anchor: CGPoint) {
        self.host = host
        super.init(host.view, size: size, anchor: anchor)
    }

    // Necessary but useless
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Override getCurrentRow to reflect the index position of the "current" playing deck template
    override func getCurrentRow() -> Int {
        let deckName = host.vc.deckType.displayName
        return Decks.available.firstIndex(where: {$0.displayName == deckName}) ?? 0
    }

    // Override the number of rows to use the number of playing deck definitions
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Decks.available.count
    }

    // Override initializeRow to use the appropriate labels for the box kinds
    override func initializeRow(_ label: UILabel, _ row: Int) {
        label.text = Decks.available[row].displayName
    }

    // Override rowSelected to handle the appropriate action changing the deckType
    override func rowSelected(_ row: Int) -> Bool {
        let deckType = Decks.available[row]
        if deckType.displayName != host.vc.deckType.displayName {
            host.vc.deckType = deckType
            host.deckType.text = deckType.displayName
            host.vc.newShuffle()
            host.vc.transmit()
        }
        return true
    }
}
