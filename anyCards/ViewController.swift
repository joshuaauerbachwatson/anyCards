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

// Main ViewController for the AnyCards Game app
class ViewController: UIViewController {

    // Model-related fields

    // The Deck (source deck) in current use.
    var deck : Deck

    // The cards array for the game.  Initially holds the standard deck taken directly from deck.cards, but this may change to a different
    // agreed-upon playing deck.
    var cards : [Card]

    // The list of players (always starts with just 'this' player but expands during discovery until play starts.  The array is ordered by
    // the order fields, ascending)
    var players = [Player]()

    // The index in the players array assigned to 'this' player (the user of the present device)
    var thisPlayer : Int = 0    // Index may change since the order of players is determined by their order fields.

    // The index of the player whose turn it is (moves are allowed iff thisPlayer and activePlayer are the same)
    var activePlayer : Int = 0  // The player listed first always goes first but play rotates thereafter

    // Says whether it's this player's turn to make moves
    var thisPlayersTurn : Bool {
        return thisPlayer == activePlayer
    }

    // The Communicator (nil until player search begins; remains non-nil during actual play)
    var communicator : Communicator? = nil

    // Indicates that play has begun.  If communicator is non-nil and playBegun is false, the player list is still being constructed.
    // Game turns may not occur until play officially begins
    var playBegun = false

    // Indicates that the first yield by a player has occurred.  Until this happens, the first player is allowed to change the
    // deck type and the 'hasHands' setting.  Afterwards, these aspects are fixed.  On each receipt of a new game state, if this
    // flag is false, the incoming deck type and hasHands settings are processed to match the first player's wishes.
    // Otherwise they are ignored.
    var firstYieldOccurred = false

    // Indicates that the player list has changed since the last periodic check.  Each check resets to false.  An actual change in the list
    // resets to true.   The value must be false for PlayerCheckCount intervals of PlayerCheckSpacing duration in order to set playBegun.
    var playerListChanged = false

    // Indicates the number of times (at intervals of PlayerCheckSpacing) that the player list was found to be stable with at least the minimum
    // number of members.  When this reaches PlayerCheckCount, the playBegun bit is set.   Reset to zero if the player list changes.
    var playerListStable = 0

    // The value for the minimum number of players, often (but not always) taken from the OptionSettings (once player list exchanges begin,
    // changes to the OptionSettings have no effect on the current game but information received from other players can raise or lower
    // this value)
    var minPlayers = -1    // To be properly initialized in configurePlayerLabels().

    // The value for the maximum number of players.  See minPlayers
    var maxPlayers = -1    // To be properly initialized in configurePlayerLabels().

    // Convenient terse finder for settings
    var settings : OptionSettings {
        return OptionSettings.instance
    }

    // View-related fields

    // The playing area subview
    let playingArea = UIView()

    // The public area within playingArea.bounds (excludes a possible "hand area" at the bottom)
    var publicArea = CGRect.zero // calculated later

    // The division marker for the hand area
    let handAreaMarker = UIView()

    // Label subviews for the (up to) maxPlayers players in the game
    var playerLabels = [UILabel]()

    // Buttons
    let showButton = UIButton()
    let yieldButton = UIButton()
    let groupsButton = UIButton()
    let findPlayersButton = UIButton()
    let endGameButton = UIButton()
    let optionsButton = UIButton()

    // The subset of the playingArea subviews that are cards.  Normally, the contents of this array is the same as that of the cards
    // array but the order is the subview order rather than index order.
    var cardViews : [Card] {
        return playingArea.subviews.filter({ $0 is Card }).map { $0 as! Card }
    }

    // The subset of the playingArea subviews that are GridBoxes.
    var boxViews : [GridBox] {
        return playingArea.subviews.filter({ $0 is GridBox }).map { $0 as! GridBox }
    }

    // Initializers

    // Get the deck source and cards based on current config.  Note: at present, there is only one set of card "visuals" (known as
    // DefaultDeck).  In the future this might be taken from the settings.
    init() {
        deck = DefaultDeck.deck
        cards = []
        super.init(nibName: nil, bundle: nil)
        cards = makePlayingDeck(deck, settings.deckType)
    }

    // Useless but required
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // External interface

    // Finish basic initialization when the view loads
    override func viewDidLoad() {
        super.viewDidLoad()

        // Make the playing area be a subview of the main view and assign its color
        view.addSubview(playingArea)
        playingArea.backgroundColor = PlayingColor

        // Make the hand area marker be a subview of the playingArea and assign its color.  It is hidden if the hand area is configured
        // as absent
        playingArea.addSubview(handAreaMarker)
        handAreaMarker.backgroundColor = UIColor.black
        handAreaMarker.isHidden = !settings.hasHands

        // Record first player
        players.append(Player(settings.userName))

        // Initialize Labels and buttons
        for i in 0..<4 {
            let player = makeLabel(LabelBackground, parent: self.view)
            playerLabels.append(player)
            if i > 0 {
                player.isHidden = true
            }
        }
        configureButton(showButton, title: ShowTitle, target: self, action: #selector(showTouched), parent: self.view)
        showButton.isHidden = true
        configureButton(groupsButton, title: GroupsTitle, target: self, action: #selector(groupsTouched), parent: self.view)
        configureButton(yieldButton, title: YieldTitle, target: self, action: #selector(yieldTouched), parent: self.view)
        yieldButton.isHidden = true
        configureButton(findPlayersButton, title: FindPlayersTitle, target: self, action: #selector(findPlayersTouched), parent: self.view)
        configureButton(endGameButton, title: EndGameTitle, target: self, action: #selector(endGameTouched), parent: self.view)
        endGameButton.isHidden = true
        configureButton(optionsButton, title: OptionsTitle, target: self, action: #selector(optionsTouched), parent: self.view)

        // Add GridBox-making and destroying recognizer to the playingArea view
        let gridBoxRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressDetected))
        gridBoxRecognizer.minimumPressDuration = 1
        gridBoxRecognizer.allowableMovement = 2
        gridBoxRecognizer.delaysTouchesBegan = true
        playingArea.addGestureRecognizer(gridBoxRecognizer)
    }

    // When the view appears (hence its size is known):
    // 1.  Regardless of the orientation, use the shorter dimension of the view as a "good width" for this device (it would be
    //     the width in portrait).
    // 2.  Use that width and the PlayingAreaAspectRatio to assign a temporary frame to the playingArea
    // 3.  Shuffle and place the cards in a deck.
    // 4.  Do a layout step to get the remaining controls laid out and to correct the playingArea frame.  Some redundant work
    //     may be done but this factoring works in practice.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let areaWidth = view.bounds.width < view.bounds.height ? view.bounds.width : view.bounds.height
        playingArea.frame = CGRect(x: 0, y: 0, width: areaWidth, height: areaWidth / PlayingAreaAspectRatio)
        shuffleAndPlace(areaWidth)
        let gameState = GameState(playingArea)
        removeAllCardsAndBoxes()
        doLayout(gameState)
        configurePlayerLabels(settings.minPlayers, settings.maxPlayers)
        Logger.log("Game initialized")
    }

    // Allow view to be rotated.   We will redo the layout each time while preserving all controller state.
    open override var shouldAutorotate: Bool {
        get {
            return true
        }
    }

    // Support all orientations.   Can layout for portrait or landscape (but tablet aspect ratio is assumed; no phone support)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        get {
            return .all
        }
    }

    // Respond to rotation or other size-changing event by redoing layout.
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let gameState = GameState(playingArea)
        coordinator.animate(alongsideTransition: nil) {_ in
            self.removeAllCardsAndBoxes()
            self.doLayout(gameState)
        }
    }

    // Layout section

    // Perform layout.
    private func doLayout(_ gameState: GameState) {
        // First ensure that the playingArea is properly located in the main view and that buttons and player labels are in place
        let bounds = safeAreaOf(view)
        if bounds.width < bounds.height {
            doPortaitLayout(bounds)
        } else {
            doLandscapeLayout(bounds)
        }
        // The publicArea can now be calculated since the playingArea.bounds have been calculated
        setupPublicArea(settings.hasHands)
        // Now place the cards and GridBoxes, with possible rescaling
        let rescale = playingArea.bounds.width / gameState.areaSize.width
        for cardState in gameState.cards {
            let newView : UIView
            if cardState.index >= 0 {
                newView = findAndFixCard(from: cardState, rescale: rescale)
            } else {
                let box = GridBox(origin: cardState.origin * rescale, size: cards[0].frame.size, host: self)
                newView = box
                box.name = cardState.name
            }
            playingArea.addSubview(newView)
        }
        for card in cardViews {
            card.maybeBeSnapped(boxViews)
        }
        refreshBoxCounts()
        Logger.log("Layout performed")
    }

    // Layout the immediate children of the main view for landscape
    private func doLandscapeLayout(_ bounds: CGRect) {
        // In landscape, the playing area is maximum height and abuts the right edge
        let width = bounds.height * PlayingAreaAspectRatio
        let x = bounds.width - width
        playingArea.frame = CGRect(x: x, y: bounds.minY, width: width, height: bounds.height)
        // The labels and buttons are to the left of the playing area, labels above the midline, buttons below, each having a height computed
        // from the ControlHeightRatio
        let controlHeight = bounds.height * ControlHeightRatio
        var nextY = bounds.midY - controlHeight - border
        for playerLabel in playerLabels.reversed() {
            playerLabel.frame = CGRect(x: bounds.minX, y: nextY, width: x, height: controlHeight)
            nextY = nextY - controlHeight - border
        }
        showButton.frame = CGRect(x: bounds.minX, y: bounds.midY, width: x, height: controlHeight)
        groupsButton.frame = showButton.frame
        yieldButton.frame = showButton.frame.offsetBy(dx: 0, dy: controlHeight + border)
        findPlayersButton.frame = yieldButton.frame.offsetBy(dx: 0, dy: controlHeight + border)
        endGameButton.frame = findPlayersButton.frame
        optionsButton.frame = findPlayersButton.frame.offsetBy(dx: 0, dy: controlHeight + border)
    }

    // Layout the immediate children of the main view for portrait
    private func doPortaitLayout(_ bounds: CGRect) {
        // In portrait, the playingArea abuts the bottom of the view
        let playingHeight = bounds.width / PlayingAreaAspectRatio
        let playingY = bounds.minY + bounds.height - playingHeight
        playingArea.frame = CGRect(x: bounds.minX, y: playingY, width: bounds.width, height: playingHeight)
        // The labels and buttons are above the playing area, each forming a row.  Sizes are computed to fit the available space
        let controlHeight = (playingY - bounds.minY) / 2 - border
        let ctlWidth = (bounds.width - 3 * border) / 4
        var labelX = bounds.minX
        let labelY = bounds.minY + border
        for playerLabel in playerLabels {
            playerLabel.frame = CGRect(x: labelX, y: labelY, width: ctlWidth, height: controlHeight)
            labelX += ctlWidth + border
        }
        let buttonY = labelY + controlHeight + border
        showButton.frame = CGRect(x: bounds.minX, y: buttonY, width: ctlWidth, height: controlHeight)
        groupsButton.frame = showButton.frame
        yieldButton.frame = showButton.frame.offsetBy(dx: ctlWidth + border, dy: 0)
        findPlayersButton.frame = yieldButton.frame.offsetBy(dx: ctlWidth + border, dy: 0)
        endGameButton.frame = findPlayersButton.frame
        optionsButton.frame = findPlayersButton.frame.offsetBy(dx: ctlWidth + border, dy: 0)
    }


    // Actions

    // On touch we ensure the card is frontmost.  If the card was covered before, we suppress tap recognition (return false)
    // on the assumption that bringing the card to the front and/or moving it was the intent rather than turning it over.  But,
    // if the card "looked" frontmost to the user (not covered), we assume the intent is either to tap it or to move it.  It is
    // still brought to the front (since, otherwise, when it is moved, it might end up behind other views).
    private func cardTouched(_ touch: UITouch) -> Bool {
        if !thisPlayersTurn {
            // UI effectively disabled if not your turn
            return false
        }
        if let card = touch.view {
            let wasCovered = isCovered(card)
            playingArea.bringSubviewToFront(card)
            return !wasCovered
        } else {
            Logger.logFatalError("Card gesture recognizer called with non-card")
        }
    }

    // On "tap", which can only happen if onTouch returned true and the card is not dragged
    private func cardTapped(_ touch: UITouch) {
        if let card = touch.view as? Card {
            if card.isFaceUp {
                card.turnFaceDown()
            } else {
                card.turnFaceUp()
            }
        }
    }

    // Respond to dragging of a a card
    @objc func dragging(recognizer: UIPanGestureRecognizer) {
        if recognizer.state == .possible || !thisPlayersTurn {
            return
        }
        if let card = recognizer.view {
            let newFrame = CGRect(origin: card.frame.origin + recognizer.translation(in: playingArea), size: card.frame.size)
            if playingArea.bounds.contains(newFrame) {
                CATransaction.withNoAnimation {
                    card.frame = newFrame
                }
                recognizer.setTranslation(CGPoint.zero, in: view)
            }
        }
        if recognizer.state == .ended {
            if let card = recognizer.view as? Card {
                card.maybeBeSnapped(boxViews)
            }
            refreshBoxCounts()
        }
    }

    // Respond to touch of the end game button.  Shuts down the communicator, effectively removing the player from the game, and resets
    // local game state for a fresh start.
    @objc func endGameTouched() {
        Logger.log("End game touched")
        prepareNewGame()
    }

    // Respond to touch of find players button by making a communicator and sending out the initial player list.
    // Also starts a timer for checking player list stability.
    @objc func findPlayersTouched() {
        Logger.log("Find Players Touched")
        guard let communicator = makeCommunicator(settings.communication, players[0], self, self) else { return }
        self.communicator = communicator
        Timer.scheduledTimer(withTimeInterval: PlayerCheckSpacing, repeats: true, block: timerTick)
        findPlayersButton.isHidden = true
        groupsButton.isHidden = true
        endGameButton.isHidden = false
    }

    // Respond to long press.  A long press within a GridBox is currently interpreted as a request to delete the GridBox.
    // A long press that is not within any GridBox is interpreted as a request to create a new GridBox.
    // This might succeed or fail.
    @objc func longPressDetected(_ recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .ended {
            let location = recognizer.location(in: playingArea)
            let boxes = boxViews.filter { $0.frame.contains(location) }
            if boxes.isEmpty {
                attemptNewGridBox(location)
            } else {
                // Deletion request
                boxes.forEach { $0.removeFromSuperview() }
            }
        }
    }

    // Respond to touch of options button
    @objc func optionsTouched() {
        let dialog = OptionSettingsDialog()
        Logger.logPresent(dialog, host: self, animated: false)
    }

    // Respond to touch of show button.  Sends the GameState but does not advance the turn.
    @objc func showTouched() {
        Logger.log("Show Touched")
        transmit(false)
    }

    // Respond to touch of the groups button.  Opens the dialog for creating, accepting, and deleting
    // game tokens.
    @objc func groupsTouched() {
        let dialog = GroupManagementDialog()
        Logger.logPresent(dialog, host: self, animated: false)
    }

    // Respond to touch of yield button.  Sends the GameState and advances the turn.
    @objc func yieldTouched() {
        Logger.log("Yield Touched")
        transmit(true)
        activePlayer = (thisPlayer + 1) % players.count
        configurePlayerLabels(minPlayers, maxPlayers)
        checkTurnToPlay()
    }

    // Other functions

    // Create a new GridBox or indicate that it can't be done.
    //   -- attempt to create a GridBox with the press at its center; if this does not overlap any other GridBox it succeeds
    //   -- if the attempt overlaps more than one other GridBox it fails
    //   -- if the attempt overlaps exactly one other GridBox, choose a revised origin such that the new GridBox fits next to the old one
    //        above, below, to the left, or to the right, depending on where the press is located.  If none of those revised locations
    //        contain the press or the resulting box would go off the view, the request fails.  Otherwise, it succeeds with the revised
    //        origin
    // A new GridBox is immediately sent to the back and snaps up any cards that fall within it.
    private func attemptNewGridBox(_ location: CGPoint) {
        // Calculate the bounds of the public area
        // Try to create a box with location at its center
        let snapSize = cards[0].frame.size
        let gridBox = GridBox(center: location, size: snapSize, host: self)
        // Reject the GridBox if it would fall outside the public area
        if !publicArea.contains(gridBox.frame) {
            gridBoxFails()
            return
        }
        // Now check for overlap with other GridBoxes
        let overlaps = boxViews.filter { $0.frame.intersects(gridBox.frame) }
        if overlaps.isEmpty {
            // No overlaps
            placeNewGridBox(gridBox)
        } else if overlaps.count > 1 {
            // Too many overlaps to solve automatically, punt to the user
            gridBoxFails()
        } else {
            // Exactly one overlap.  Try to locate the new GridBox next to the existing one but still containing the long press location
            let existing = overlaps[0].frame
            let hstep = existing.width + border
            let vstep = existing.height + border
            let others = [ existing.offsetBy(dx: 0, dy: -vstep), existing.offsetBy(dx: 0, dy: vstep),
                           existing.offsetBy(dx: -hstep, dy: 0), existing.offsetBy(dx: hstep, dy: 0) ]
            for other in others {
                if publicArea.contains(other) && other.contains(location) {
                    placeNewGridBox(GridBox(origin: other.origin, size: snapSize, host: self))
                    return
                }
            }
            gridBoxFails()
        }
    }

    // Check whether this player is the the player whose turn it is and enable the End Turn button if so
    private func checkTurnToPlay() {
        showButton.isHidden = !thisPlayersTurn
        yieldButton.isHidden = !thisPlayersTurn
    }

    // Display a player in its label using the appropriate text color and attributes
    private func configurePlayer(_ label: UILabel, _ playerName: String, _ playerIndex: Int) {
        if playerIndex == thisPlayer {
            let attribs = [NSAttributedString.Key.font: UIFont.italicSystemFont(ofSize: label.font.pointSize)]
            let text = String(format: ThisPlayerTemplate, playerName)
            label.attributedText = NSAttributedString(string: text, attributes: attribs)
        } else {
            label.text = playerName
        }
        label.textColor = (playBegun && playerIndex == activePlayer) ? ActivePlayerColor : NormalTextColor
    }

    // Configure the player labels and min/maxPlayers fields according to the current agreement on the min and max player count.
    // Initially, these values come from OptionSettings; afterwards, they come from GameState received from other players.
    private func configurePlayerLabels(_ min: Int, _ max: Int) {
        minPlayers = min
        maxPlayers = max
        for i in 0..<playerLabels.count {
            let label = playerLabels[i]
            label.isHidden = false
            if i < players.count {
                configurePlayer(label, players[i].name, i)
            } else if i < min {
                label.text = communicator == nil ? MustFind : Searching
            } else if i < max {
                label.text = OptionalPlayer
            } else {
                label.isHidden = true
            }
        }
        // Special case: if communicator has not been started we determine which of findPlayers and endGame are showing based on min/maxPlayers
        // Once the communicator is started the FindPlayers button will show initially and change to endGame once the player list is stable
        if communicator == nil {
            let solitaire = minPlayers == 1 && maxPlayers == 1
            findPlayersButton.isHidden = solitaire
            endGameButton.isHidden = !solitaire
        }
    }

    // Find a specific card from its card-state and adjust it to match the card state, possibly rescaling according to the current playingArea bounds
    private func findAndFixCard(from: CardState, rescale: CGFloat) -> Card {
        let card = cards[from.index]
        if from.faceUp {
            card.turnFaceUp()
        } else {
            card.turnFaceDown()
        }
        card.frame.origin = from.origin * rescale
        return card
    }

    // Indicate that a GridBox cannot be placed
    private func gridBoxFails() {
        bummer(title: BadGridBoxTitle, message: BadGridBoxMessage, host: self)
    }

    // Determine if a card is covered by another card
    private func isCovered(_ card: UIView) -> Bool {
        for cardView in cardViews.reversed() {
            if cardView === card {
                return false
            } else if cardView.frame.intersects(card.frame) {
                return true
            }
        }
        Logger.logFatalError("Card that should be a subview is not found in subviews")
    }

    // Front for Deck.makePlayingDeck, ensures that every card gets a gesture recognizer
    private func makePlayingDeck(_ deck: Deck, _ instructions: PlayingDeckTemplate) -> [Card] {
        let cards = deck.makePlayingDeck(instructions)
        for card in cards {
            let gestureRecognizer = TouchTapAndDragRecognizer(target: self, onDrag: #selector(dragging), onTouch: cardTouched, onTap: cardTapped)
            card.addGestureRecognizer(gestureRecognizer)
        }
        return cards
    }

    // Place a new GridBox into the playingArea after determining that it fits
    private func placeNewGridBox(_ gridBox: GridBox) {
        playingArea.addSubview(gridBox)
        playingArea.sendSubviewToBack(gridBox)
        gridBox.maybeSnapUp(cardViews)
        gridBox.refreshCount()
    }

    // End current game and prepare a new one (responds to EndGame button and also to lost peer condition)
    private func prepareNewGame() {
        // Clean up former game
        communicator?.shutdown()
        communicator = nil
        playBegun = false
        firstYieldOccurred = false
        thisPlayer = 0
        activePlayer = 0
        playerListStable = 0
        playerListChanged = false
        playerLabels.forEach { $0.textColor = NormalTextColor }
        showButton.isHidden = true
        groupsButton.isHidden = false
        yieldButton.isHidden = true
        // Set up new game
        deck = DefaultDeck.deck
        cards = makePlayingDeck(deck, settings.deckType)
        players = [ Player(settings.userName) ]
        configurePlayerLabels(settings.minPlayers, settings.maxPlayers)
        removeAllCardsAndBoxes()
        shuffleAndPlace(playingArea.bounds.width)
    }

    // Refresh the box counts in all GridBoxes
    private func refreshBoxCounts() {
        boxViews.forEach { $0.refreshCount() }
    }

    // Remove all Card and GridBox subviews (including cards in the hand area) from the playing area.
    // We do this when doing a complete layout (not in response to a received GameState, which typically only affects public cards).
    private func removeAllCardsAndBoxes() {
        for subview in playingArea.subviews {
            if subview is Card || subview is GridBox {
                subview.removeFromSuperview()
            }
        }
    }

    // Remove "public" Card and GridBox subviews from the playing area (leaving cards that are in the hand area).
    // We do this when receiving a new GameState, which will include public cards only.
    private func removePublicCardsAndBoxes() {
        for subview in playingArea.subviews {
            if subview is GridBox || (subview is Card && publicArea.contains(subview.center)) {
                subview.removeFromSuperview()
            }
        }
    }

    // Called when settings change.  Reloads all settings that are permitted to change, depending on the phase of the game.  Some setting
    // changes are not effective until the next game.
    func settingsChanged() {
        // If the communicator has not started, all changes are allowed.  The CommunicatorKind change does not need to be processed here since
        // the latest value will be read when the communicator starts.   Changes guarded by firstYieldOccurred can be handled below because
        // a nil communicator implies a false setting for that flag.
        if communicator == nil {
            // Player name
            players[0] = Player(settings.userName)
            // Min and max players
            configurePlayerLabels(settings.minPlayers, settings.maxPlayers)
        }
        // Playing deck and hands area can be changed even after communicator is started if this is the first player and he has not yet
        // ever yielded.
        if !firstYieldOccurred && thisPlayer == 0 {
            // Hand area
            setupPublicArea(settings.hasHands)
            // Deck type
            cards = makePlayingDeck(deck, settings.deckType)
            removeAllCardsAndBoxes()
            shuffleAndPlace(playingArea.bounds.width)
        }
    }

    // Set up the public area and the hand area marker based on the current settings
    private func setupPublicArea(_ present: Bool) {
        if present {
            publicArea = playingArea.bounds.inset(by: UIEdgeInsets(top: 0, left: 0, bottom: cards[0].bounds.height, right: 0))
            handAreaMarker.frame = CGRect(x: publicArea.minX, y: publicArea.maxY, width: publicArea.width, height: border)
            handAreaMarker.isHidden = false
        } else {
            publicArea = playingArea.bounds
            handAreaMarker.isHidden = true
        }
    }

    // Shuffle cards and form deck.  Add a GridBox to hold the deck and place everything on the playingArea
    private func shuffleAndPlace(_ areaWidth: CGFloat) {
        let cardWidth = areaWidth * CardDisplayWidthRatio
        let cardHeight = cardWidth / deck.aspectRatio
        let cardSize = CGSize(width: cardWidth, height: cardHeight)
        let cards = shuffle(self.cards)
        let deckOrigin = CGPoint(x: cardWidth, y: cardHeight)
        cards.forEach { card in
            card.turnFaceDown()
            card.frame = CGRect(origin: deckOrigin, size: cardSize)
            playingArea.addSubview(card)
        }
        let deckBox = GridBox(center: cards[0].center, size: cardSize, host: self)
        deckBox.name = MainDeckName
        placeNewGridBox(deckBox)
    }

    // Respond to timer tick during player search
    private func timerTick(_ timer: Timer) {
        if !playBegun {
            // Until play begins, we are looking for stability in the count and at least minPlayers players.
            if playerListChanged {
                playerListChanged = false
                playerListStable = 0
            } else if players.count >= minPlayers {
                playerListStable += 1
                if playerListStable >= PlayerCheckCount {
                    playBegun = true
                    checkTurnToPlay()
                    communicator?.updatePlayers(players)
                }
            }
        }
        if playBegun {
            // Once play begins, we don't need the timer any more.  Ensure that the player list is trimmed to maxPlayers and that any labels
            // not showing actual players are hidden
            timer.invalidate()
            while players.count > maxPlayers {
                players.removeLast()
            }
            for i in players.count..<playerLabels.count {
                playerLabels[i].isHidden = true
            }
        }
        // In either case, make sure any actual players are showing in the labels
        configurePlayerLabels(minPlayers, maxPlayers)
    }

    // Transmit GameState to the other players, either when just showing or when yielding
    private func transmit(_ yielding: Bool) {
        assert(thisPlayersTurn)
        let gameState : GameState
        if !firstYieldOccurred && thisPlayer == 0 {
            gameState = GameState(deckType: settings.deckType, handArea: settings.hasHands, yielding: yielding,
                                  playingArea: playingArea, publicArea: publicArea)
            firstYieldOccurred = true
        } else {
            gameState = GameState(yielding: yielding, playingArea: playingArea, publicArea: publicArea)
        }
        communicator?.send(gameState)
    }
}

// Conform to protocol for Communicator
extension ViewController : CommunicatorDelegate {
    // Respond to change in membership.   Sometimes we ignore this, but if we are in the starting state we send out a game state with the
    // player list.  Note: we don't use this to detect lost peers; we use the more specific up-call for that purpose.
    func connectedDevicesChanged(_ numConnectedDevices: Int) {
        Logger.log("connectedDevicesChanged, now \(numConnectedDevices)")
        if players.count < minPlayers {
            communicator?.send(GameState(players: players, minPlayers: minPlayers, maxPlayers: maxPlayers))
        }
    }

    // Display communications-related error
    func error(_ error: Error) {
        Logger.log("Communications exception: \(error)")
        DispatchQueue.main.async {
            var host: UIViewController = self
            while host.presentedViewController != nil {
                host = host.presentedViewController!
            }
            bummer(title: CommunicationsErrorTitle, message: error.localizedDescription, host: host)
        }
    }

    // Respond to receipt of a new GameState
    func gameChanged(_ gameState: GameState) {
        DispatchQueue.main.async {
            // Doing everything on the main thread for now; some things could be done in the background but not clear that's necessary
            self.doGameChanged(gameState)
        }
    }
    private func doGameChanged(_ gameState: GameState) {
        if gameState.players.count > 0 {
            // Phase 1 transfer: determining player list.  First, reconcile min and max players.
            //   - The min is initially set to the max of all players' min settings
            //   - The max is set to the min of all players' max settings
            //   - If the resulting min is higher than the max, it is set to match the max.
            var newMin = max(gameState.minPlayers, minPlayers)
            let newMax = min(gameState.maxPlayers, maxPlayers)
            if newMin > newMax {
                newMin = newMax
            }
            var changed = newMin != minPlayers || newMax != maxPlayers
            if changed {
                configurePlayerLabels(newMin, newMax)
            }
            // Then, if the incoming list differs from the local list, merge the lists, and ensure that all players in the list are
            // also in the session.
            if players != gameState.players {
                changed = true
                let merged = (players + gameState.players.filter({ !players.contains($0)})).sorted { $0.order < $1.order }
                players = merged
                // Reset thisPlayer since something may have merged in front of its previous location
                guard let thisPlayer = merged.firstIndex(where: {$0.name == OptionSettings.instance.userName})
                    else { Logger.logFatalError("This player not in player list") }
                self.thisPlayer = thisPlayer
                communicator?.updatePlayers(players)
            }
            // If anything changed at all, then send out the result and indicate that the player list has changed to delay start
            // of play until things settle down.
            if changed {
                communicator?.send(GameState(players: players, minPlayers: minPlayers, maxPlayers: maxPlayers))
                playerListChanged = true
            }
        } else {
            // This is not the initial player exchange but a move by an active player.  There is a special step for the first move
            //  to determine which deck is being used and to set up the hand area if requested.
            if !firstYieldOccurred {
                if let deckType = gameState.deckType {
                    cards = makePlayingDeck(deck, deckType)
                    optionsButton.isHidden = true
                }
                setupPublicArea(gameState.handArea)
                firstYieldOccurred = true
            }
            Logger.log("Received GameState contains \(gameState.cards.count) cards")
            removePublicCardsAndBoxes()
            doLayout(gameState)
            Logger.log("After processing, layout contains \(playingArea.subviews.count) subviews")
            if gameState.yielding {
                activePlayer = (activePlayer + 1) % players.count
                for i in 0..<players.count {
                    configurePlayer(playerLabels[i], players[i].name, i)
                }
                checkTurnToPlay()
            }
        }
    }

    // React to lost peer by ending the game with a short dialog
    func lostPlayer(_ player: String) {
        let action = UIAlertAction(title: OkButtonTitle, style: .cancel, handler: nil)
        let lostPlayerMessage = String(format: LostPlayerTemplate, player)
        let alert = UIAlertController(title: title, message: lostPlayerMessage, preferredStyle: .alert)
        alert.addAction(action)
        Logger.logPresent(alert, host: self, animated: false)
        prepareNewGame()
    }
}
