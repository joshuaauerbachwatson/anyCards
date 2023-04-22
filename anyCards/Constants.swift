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
let ControlHeightRatio = CGFloat(1) / CGFloat(20) // Ratio of label or button height to safe area height
let DealCardDuration = 0.2
let DealingCardsDefault = 7
let DealingCardsMax = 52
let DealingCardsMin = 1
let DealingHandsDefault = 2
let DealingHandsMax = 4
let DealingHandsMin = 1
let DefaultDeckAllRows = 5
let DefaultDeckBackColumn = 2
let DefaultDeckBackRow = 4
let DefaultDeckFrontColumns = 13
let DefaultDeckFrontRows = 4
let DialogEdgeMargin = CGFloat(10)
let DialogSpacer = CGFloat(4)
let FixedLabelHeight = CGFloat(25)
let FlipTime = 0.5
let GameSetupSize = CGSize(width: 480, height: 300)
let GameTokenLength = 12
let GridBoxExpansion = CGFloat(1.2)
let GridBoxNamePortion = CGFloat(0.75) // Portion of the GridBox excess area occupied by the name (the rest holds the count)
let HandAreaExpansion = CGFloat(1.2) // Allow some headroom for moving cards inside the hand area
let LayoutAreaRatioLandscape = CGFloat(1366) / CGFloat(980) // H/W to use for layout in landscape (== iPad 12.9" safe area shapes)
let LayoutAreaRatioPortrait = CGFloat(1322) / CGFloat(1024) // H/W to use for layout in portrait (== iPad 12.9" safe area shape)
let MinCardPixels = CGFloat(5) // Minimum number of pixels of a card's width or height that must be within the playing area
let NumPlayersDefault = 2
let PlayerManagementSize = CGSize(width:480, height: 600)
let PlayersMax = 4
let PlayersMin = 1
let PlayingAreaRatioLandscape = CGFloat(48) / CGFloat(59)  // H/W of the playing area in landscape
let PlayingAreaRatioPortrait = CGFloat(59) / CGFloat(48)  // H/W of the playing area in portrait
let ReturnLabelWidth = CGFloat(150)
let SnapThreshhold = CGFloat(10)  // Number of points of overlap to initiate a "snap to grid"

// Document names
let DefaultDeckName = "DefaultCardDeck.png"
let HelpFile = "AnyCardsHelp" /* Excludes extension */
let SavedSetupsFile = "savedSetups"
let ServerGameFile = "serverGames"

// Colors
let ActivePlayerColor = UIColor(60, 180, 75)
let CountLabelColor = UIColor.red
let FillerColor = UIColor.darkGray
let GridBackgroundColor = UIColor.black
let HelpTextBackground = UIColor.white
let HelpViewBackground = UIColor(170, 110, 40)
let LabelBackground = UIColor.white
let PlayingColor = UIColor(white: 0.875, alpha: 1.0)
let SettingsDialogBackground = UIColor.lightGray

// Texts
let BadGridBoxMessage = "Too close to other card boxes"
let BadGridBoxTitle = "Bad Placement"
let CancelButtonTitle = "Cancel"
let CardsLabelText = "cards each"
let ChooseNameMessage = "choose name for setup"
let CommunicationsErrorTitle = "Communications problem"
let ConfirmButtonTitle = "Confirm"
let ContinueTitle = "Attempt to Continue"
let DealTitle = "Deal"
let DealingHeaderTemplate = "Dealing from box named '%@'"
let DealingHeaderUnnamed = "Dealing from unnamed box"
let DeckBoxName = "Deck"
let DeckTypeText = "Deck Type: "
let DoneTitle = "Done"
let DeleteTitle = "Delete"
let EndGame = "; game ending"
let EndGameTitle = "End Game"
let FindPlayersTitle = "Find Players"
let ForgetTitle = "Forget this token"
let FromLabelText = "from"
let GameSetupTitle = "Setup Game"
let GridBoxKindTitle = "Kind of box"
let GridBoxMenuHeaderTemplate = "Modifying box named '%@'"
let GridBoxMenuHeaderUnnamed = "Modifying unnamed box"
let GridBoxNameTitle = "Name for box"
let GridBoxNamePlaceholder = "Enter name"
let GridBoxSpecifyTitle = "Specify box details"
let HandAreaNo = "Absent"
let HandAreaText = "Private Hand Area: "
let HandAreaYes = "Present"
let HandsLabelText = "hands of"
let HelpTitle = "Help"
let InternalDealingError = "Internal error in dealing function"
let InvalidTokenMessage = "Token must be 12 chars, letters and numbers only"
let InvalidTokenTitle = "Invalid token"
let LeaderStatusLabelText = "Are you leader?: "
let LocalRemoteLabelText = "Players source: "
let LocalText = "Nearby only"
let LostPlayerTemplate = "Lost contact with '%@'"
let LostPlayerTitle = "Lost Player"
let MainDeckName = "Deck"
let MayNotAccess = "May not access"
let MayNotTurnOver = "May not turn over"
let MissingToken = "Missing token"
let MissingVersionMessage = "Version information not available"
let ModifyTitle = "Modify"
let MultiPeerServiceName = "anyoldcardgame"
let MustFind = "[Must Find]"
let MustRemainFaceUp = "Card must remain face up until moved"
let MustRemainFaceDown = "Card must remain face down until moved"
let NextTitle = "Show next token"
let NickNameLabelText = "Nickname: "
let NickNamePlaceholder = "[optional]"
let NoDealPossible = "There are no decks to deal from"
let NoDealTitle = "No Deal"
let NoLeadPlayersMessage = "No leader"
let NoText = "No"
let NotEnoughCards = "Not enough cards"
let NumPlayersText = "Number of players: "
let OkButtonTitle = "Ok"
let OverwriteSetupTitle = "Saved Setup Exists"
let OverwriteSetupTemplate = "Overwrite the saved setup named '%@'?"
let OwnedGridBoxTemplate = "Box is owned by '%@'"
let OwnedTitle = "Owned: "
let PlayerErrorTitle = "Error finding players"
let PlayersHeaderText = "Assemble Players"
let PlayersTitle = "Players"
let RemoteText = "Entire internet"
let ResetTitle = "Reset"
let ReturnText = "Return to Game"
let SaveSetupTitle = "Save as ..."
let SaveTokenTitle = "Remember this token"
let Searching = "[Searching]"
let SendFeedback = "sendFeedback" /* Internal script name */
let SettingsHeaderText = "Settings for Current Game"
let ShuffleTitle = "Shuffle"
let TakeHandTitle = "Take Hand"
let ThisPlayerTemplate = "* %@ *"
let TokenLabelText = "Token: "
let TokenPlaceholder = "Type or paste token"
let TooManyHands = "Too many hands (won't fit)"
let TooManyLeadsMessage = "Too many leaders"
let TooManyPlayersMessage = "Too many players"
let TurnOverTitle = "Turn Over"
let UserNameText = "Your User Name: "
let UseButtonTitle = "Use saved setup"
let VersionPrefix = "Version: "
let YesText = "Yes"
let YieldTitle = "Yield"

// Bug reporting
let FeedbackEmail = "anycardsreports@gmail.com"
let FeedbackText = "Report a Problem"
let NoEmailTitle = "No Email"
let NoEmailMessage = "Cannot send problem report because email is not configured on this device or is not available to this app"
let FeedbackMessageSubject = "AnyCards Game Feedback"
let FeedbackMessageBody = """
Replace this text with your specific feedback.   If you are reporting a problem, it is best to leave any log attachments
in place; they are transcripts of events that occurred in AnyCards games and will help in diagnosing the problem.  If you
prefer to delete the logs it is your call.
"""
