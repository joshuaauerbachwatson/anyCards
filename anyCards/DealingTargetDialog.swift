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

// A table dialog for choosing a category of "target" when dealing.  Choices include "Hands", "Piles", "Owned Decks",
// "Shared Decks", "Owned Discards", "Shared Discards"

enum TargetKind : Int, CaseIterable {
    case Hands, Piles, OwnedDecks, SharedDecks, OwnedDiscards, SharedDiscards
    
    var display: String {
        switch self {
        case .Hands:
            return "Hands"
        case .Piles:
            return "Piles"
        case .OwnedDecks:
            return "Owned Decks"
        case .SharedDecks:
            return "Shared Decks"
        case .OwnedDiscards:
            return "Owned Discards"
        case .SharedDiscards:
            return "Shared Discards"
        }
    }
    
    var boxKind : GridBox.Kind {
        switch self {
        case .Hands:
            return .Hand
        case .OwnedDecks, .SharedDecks:
            return .Deck
        case .OwnedDiscards, .SharedDiscards:
            return .Discard
        case .Piles:
            return .General
        }
    }
    
    var isOwned: Bool {
        switch self {
        case .OwnedDecks, .OwnedDiscards, .Hands:
            return true
        default:
            return false
        }
    }
}

class DealingTargetDialog : TableDialogController {
    let host : DealingDialog

    // Main init
    init(_ host: DealingDialog, size: CGSize, anchor: CGPoint) {
        self.host = host
        super.init(host.view, size: size, anchor: anchor)
        setEditing(false, animated: false)
    }

    // Necessary but unused
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Override getCurrentRow to reflect the default choice
    override func getCurrentRow() -> Int {
        return host.targetKind.rawValue
    }

    // Override the number of rows to reflect the number of choices
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return TargetKind.allCases.count
    }

    // Override initializeRow to use the appropriate labels for the choices
    override func initializeRow(_ label: UILabel, _ row: Int) {
        label.text = TargetKind.allCases[row].display
    }

    // Override rowSelected to record the choice
    override func rowSelected(_ row: Int) -> Bool {
        host.setTargetKind(row)
        return true
    }
}
