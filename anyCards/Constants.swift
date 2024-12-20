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

// Global constants for Any Old Card Game

// Numbers
let CardDisplayWidthRatio = CGFloat(1) / CGFloat(8)     // Ratio of card width to standard view width
let DealCardDuration = 0.2
let DefaultDeckAllRows = 5
let DefaultDeckBackColumn = 2
let DefaultDeckBackRow = 4
let DefaultDeckFrontColumns = 13
let DefaultDeckFrontRows = 4
let FlipTime = 0.5
let GridBoxExpansion = CGFloat(1.2)
let GridBoxKindPortion = CGFloat(0.15)
let GridBoxNamePortion = CGFloat(0.60) // Portion of the GridBox excess area occupied by the name (the rest holds the kind and count)
let HandAreaExpansion = CGFloat(1.6) // Allow some headroom for moving cards inside the hand area
let MinCardPixels = CGFloat(5) // Minimum number of pixels of a card's width or height that must be within the playing area
let SnapThreshhold = CGFloat(10)  // Number of points of overlap to initiate a "snap to grid"

// Document names
let DefaultDeckName = "DefaultCardDeck.png"
let JokerImageName = "JokerImage.png"
let SavedSetupsFile = "savedSetups"

// Colors
let CountLabelColor = UIColor.red
let GridBackgroundColor = UIColor.black
let LabelBackground = UIColor.white
let PlayingColor = UIColor(white: 0.875, alpha: 1.0)

// Texts
let BadGridBoxMessage = "Too close to other card boxes or to an edge"
let MainDeckName = "Deck"
let OwnedGridBoxTemplate = "Box is owned by '%@'"
O
