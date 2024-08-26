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

// A table dialog for choosing a saved token to restore or delete

class RestoreTokenDialog : TableDialogController {
    let host : PlayerManagementDialog

    // Pass-thru init
    init(_ host: PlayerManagementDialog, size: CGSize, anchor: CGPoint) {
        self.host = host
        super.init(host.view, size: size, anchor: anchor)
    }

    // Necessary but useless
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Override getCurrentRow.  If the PlayerManagementDialog.token.text matches a stored row, use that index.
    // Otherwise, use zero.
    override func getCurrentRow() -> Int {
        if let row = gameTokens.values.firstIndex(where: { $0 == host.token.text }) {
            return row
        }
        return 0
    }

    // Override the number of rows to use the size of serverTokens.pairs
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return gameTokens.values.count
    }

    // Override initializeRow to use the serverTokens values
    override func initializeRow(_ label: UILabel, _ row: Int) {
        label.text = gameTokens.values[row]
    }

    // Override rowSelected to handle the appropriate action for restoring a tokens
    override func rowSelected(_ row: Int) -> Bool {
        let token = gameTokens.values[row]
        host.showToken(token)
        return true
    }

    // Override deleteRow to handle the appropriate action for deleting a stored token
    override func deleteRow(_ row: Int) {
        let removed = gameTokens.remove(at: row)
        if host.token.text == removed {
            host.showInitialToken()
        }
    }
}
