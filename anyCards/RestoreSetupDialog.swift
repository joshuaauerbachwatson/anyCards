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

// A table dialog for choosing a saved setup to restore or delete

class RestoreSetupDialog : TableDialogController {
    let host : ViewController

    // Pass-thru init
    init(_ host: ViewController, size: CGSize, anchor: CGPoint) {
        self.host = host
        super.init(host.view, size: size, anchor: anchor)
    }

    // Necessary but useless
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Override getCurrentRow to reflect the index position of the "current" saved setup
    // TODO: at present we do not remember the current saved setup so we will always return 0
    override func getCurrentRow() -> Int {
        return 0
    }

    // Override the number of rows to use the size of savedSetups
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return savedSetups.setups.count
    }

    // Override initializeRow to use the setupNames values
    override func initializeRow(_ label: UILabel, _ row: Int) {
        label.text = savedSetups.setupNames[row]
    }

    // Override rowSelected to handle the appropriate action for restoring a saved setup
    override func rowSelected(_ row: Int) -> Bool {
        let name = savedSetups.setupNames[row]
        guard let state = savedSetups.setups[name] else {
            Logger.logFatalError("saved setups are in an inconsistent state")
        }
        host.restoreGameState(state)
        return true
    }

    // Override deleteRow to handle the appropriate action for deleting a saved setup
    override func deleteRow(_ row: Int) {
        let key = savedSetups.setupNames[row]
        savedSetups.remove(key)
    }
}
