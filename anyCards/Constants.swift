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
let MinPlayersDefault = 2
let MaxPlayersDefault = 4
let PlayersMin = 1
let PlayersMax = 4
let PlayerCheckCount = 3 // Number of times the player list must be stable before declaring "game time"
let PlayerCheckSpacing = 1.0 // Number of seconds between checks of the player list
let FlipTime = 0.5
let DefaultDeckBackRow = 4
let DefaultDeckBackColumn = 2
let DefaultDeckFrontRows = 4
let DefaultDeckAllRows = 5
let DefaultDeckFrontColumns = 13
let CardDisplayWidthRatio = CGFloat(1) / CGFloat(8)     // Ratio of card width to standard view width
let PlayingAreaRatioPortrait = CGFloat(59) / CGFloat(48)  // Aspect ratio of the playing area in portrait
let PlayingAreaRatioLandscape = CGFloat(48) / CGFloat(59)  // Aspect ratio of the playing area in landscape
let LayoutAreaRatioPortrait = CGFloat(1322) / CGFloat(1024) // Aspect ratio to use for layout area (== iPad 12.9" safe area shape)
let LayoutAreaRatioLandscape = CGFloat(1366) / CGFloat(980) // Aspect ratio to use for layout area (== iPad 12.9" safe area shape, inverted)
let ControlHeightRatio = CGFloat(1) / CGFloat(20) // Ratio of label or button height to safe area height
let OptionSettingsSize = CGSize(width: 480, height: 300)
let GroupManagementSize = CGSize(width:480, height: 600)
let OptionSettingsEdgeMargin = CGFloat(10)
let OptionSettingsSpacer = CGFloat(4)
let GridBoxExpansion = CGFloat(1.2)
let SnapThreshhold = CGFloat(10)  // Number of points of overlap to initiate a "snap to grid"
let GridBoxNamePortion = CGFloat(0.75) // Portion of the GridBox excess area occupied by the name (the rest holds the count)
let DealingHandsDefault = 2
let DealingHandsMin = 1
let DealingHandsMax = 5
let DealingCardsDefault = 7
let DealingCardsMin = 1
let DealingCardsMax = 52

// Document names
let ServerGameFile = "serverGames"

// Colors
let FillerColor = UIColor.darkGray
let PlayingColor = UIColor(white: 0.875, alpha: 1.0)
let LabelBackground = UIColor.white
let ActivePlayerColor = UIColor(60, 180, 75)
let SettingsDialogBackground = UIColor.lightGray
let GridBackgroundColor = UIColor.black
let CountLabelColor = UIColor.red

// Texts
let DefaultDeckName = "DefaultCardDeck.png"
let MultiPeerServiceName = "anyoldcardgame"
let LostPlayerTitle = "Lost Player"
let LostPlayerTemplate = "Lost contact with '%@'; game ending."
let OptionsTitle = "Game"
let FindPlayersTitle = "Players"
let ShowTitle = "Show"
let GroupsTitle = "Groups"
let YieldTitle = "Yield"
let EndGameTitle = "End Game"
let CommunicationsErrorTitle = "Communications problem"
let CommunicationLabelText = "Player Group: "
let DeckTypeText = "Deck Type: "
let HandAreaText = "Private Hand Area: "
let HandAreaYes = "Present"
let HandAreaNo = "Absent"
let PlayViaGameCenter = "Use Game Center"
let LocalOnly = "Nearby Only"
let UserNameText = "Your User Name: "
let MinPlayersText = "Min. # of players: "
let MaxPlayersText = "Max. # of players: "
let MustFind = "[Must Find]"
let Searching = "[Searching]"
let OptionalPlayer = "[Optional]"
let SettingsHeaderText = "Settings for Current Game"
let DoneButtonTitle = "Done"
let OkButtonTitle = "Ok"
let ThisPlayerTemplate = "* %@ *"
let BadGridBoxTitle = "Bad Placement"
let BadGridBoxMessage = "Too close to other card boxes"
let MainDeckName = "Deck"
let GroupManagementHeaderText = "Manage Groups"
let GroupNameLabelText = "Name: "
let TokenLabelText = "Token: "
let CopyTokenTitle = "Copy Token to Pasteboard"
let JoinGroupTitle = "Join Existing Group"
let CreateGroupTitle = "Create New Group"
let RenameGroupTitle = "Rename Group"
let DeleteGroupTitle = "Delete Group"
let DeleteGroupMessage = "Choose a scope for the deletion"
let SelfOnlyTitle = "For Self Only"
let ForAllTitle = "For Everyone"
let WithForceTitle = "Even if Playing"
let NextButtonTitle = "Show Next Group"
let CurrentGroupPrefix = "Now playing: "
let ConfirmButtonTitle = "Confirm"
let CancelButtonTitle = "Cancel"
let NoGroupPlaceholder = "Choose action below"
let GroupNamePlaceholder = "Enter your name for the group"
let TokenPlaceholder = "Type or paste a token here"
let GenerateTokenPlaceholder = "Token will be generated"
let ContinueTitle = "Attempt to Continue"
let MissingVersionMessage = "Version information not available"
let VersionPrefix = "Version: "
let DealTitle = "Deal"
let HelpTitle = "Help"
let DealingHeaderText = "Dealing"
let HandsLabelText = "hands of"
let CardsLabelText = "cards each"
let FromLabelText = "from"
let DeckBoxName = "Deck"
let NoDealTitle = "No Deal"
let NoDealPossible = "There are no decks to deal from"
let InternalDealingError = "Internal error in dealing function"
let NotEnoughCards = "Not enough cards"
let TooManyHands = "Too many hands (won't fit)"
