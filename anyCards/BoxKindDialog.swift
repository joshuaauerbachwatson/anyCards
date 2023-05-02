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

// A table dialog for choosing a box kind

class BoxKindDialog : TableDialogController {
    let host : ModifyGridBox
    let box : GridBox

    // Main init
    init(_ host: ModifyGridBox, _ box: GridBox, size: CGSize, anchor: CGPoint) {
        self.host = host
        self.box = box
        super.init(host.view, size: size, anchor: anchor)
    }

    // Necessary but useless
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Override getCurrentRow to reflect the index position of the "current" box kind
    override func getCurrentRow() -> Int {
        return GridBox.Kind.allKinds.firstIndex(of: box.kind) ?? 0
    }

    // Override the number of rows to use the number of GridBox kind values
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return GridBox.Kind.allKinds.count
    }

    // Override initializeRow to use the appropriate labels for the box kinds
    override func initializeRow(_ label: UILabel, _ row: Int) {
        label.text = GridBox.Kind.allKinds[row].label
    }

    // Override rowSelected to handle the appropriate action changing the GridBox kind
    override func rowSelected(_ row: Int) -> Bool {
        let kind = GridBox.Kind.allKinds[row]
        if kind != box.kind {
            box.kind = kind
            host.kind.text = box.kind.label
            host.vc.transmit()
        }
        return true
    }
}
