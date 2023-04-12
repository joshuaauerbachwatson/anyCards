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

    // The value for the number of players, often (but not always) taken from the OptionSettings (once player list exchanges begin,
    // changes to the OptionSettings have no effect on the current game but information received from other players can raise or lower
    // this value)
    var numPlayers = -1    // To be properly initialized in configurePlayerLabels().

    // Convenient terse finder for settings
    var settings : OptionSettings {
        return OptionSettings.instance
    }

    // View-related fields

    // Flag for ensuring that the "initial" layout only happens once and isn't repeated when an overlaying view is dismissed.
    // Layout should only be redone when the device orientation or shape is changed or when a new game state is received.
    var notYetInitialized = true

    // Indicates that any new layout must be landscape
    var lockedToLandscape = false

    // Indicates that any new layout must be portrait
    var lockedToPortrait = false

    // Indicates that the current layout is or should be landscape (negated means portrait)
    var isLandscape: Bool {
        get {
            return lockedToLandscape || (!lockedToPortrait && view.bounds.size.landscape)
        }
    }

    // The playing area subview
    let playingArea = UIView()

    // The public area within playingArea.bounds (excludes a possible "hand area" at the bottom)
    var publicArea = CGRect.zero // calculated later

    // The "dealing area" within the publicArea (defined once the publicArea is defined).
    // This is where cards are dealt by the dealing dialog
    var dealingArea: CGRect {
        if publicArea == CGRect.zero {
            return publicArea
        }
        let y = publicArea.maxY - border - (cardSize.height * GridBoxExpansion)
        return CGRect(x: publicArea.minX, y: y, width: publicArea.width, height: cardSize.height)
    }

    // Indicates whether dealing is possible.  Dealing is possible if there are no subviews that intersect the dealingArea
    var canDeal: Bool {
        return !playingArea.subviews.contains(where: { $0.frame.intersects(dealingArea)})
    }

    // The division marker for the hand area
    let handAreaMarker = UIView()

    // Label subviews for the (up to) maxPlayers players in the game
    var playerLabels = [UILabel]()

    // Buttons and button-sized labels
    let yieldButton = UIButton()
    let playersButton = UIButton()
    let endGameButton = UIButton()
    let gameSetupButton = UIButton()
    let helpButton = UIButton()

    // The subset of the playingArea subviews that are cards.  Normally, the contents of this array is the same as that of the cards
    // array but the order is the subview order rather than index order.
    var cardViews : [Card] {
        return playingArea.subviews.filter({ $0 is Card }).map { $0 as! Card }
    }

    // The subset of the playingArea subviews that are GridBoxes.
    var boxViews : [GridBox] {
        return playingArea.subviews.filter({ $0 is GridBox }).map { $0 as! GridBox }
    }

    // The expected size of a card in the current layout
    var cardSize: CGSize {
        let cardWidth = playingArea.frame.minDimension * CardDisplayWidthRatio
        let cardHeight = cardWidth / deck.aspectRatio
        return CGSize(width: cardWidth, height: cardHeight)
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
        view.backgroundColor = FillerColor
        view.addSubview(playingArea)
        playingArea.backgroundColor = PlayingColor

        // Make the hand area marker be a subview of the playingArea and assign its color.  It is hidden if the hand area is configured
        // as absent
        playingArea.addSubview(handAreaMarker)
        handAreaMarker.backgroundColor = UIColor.black
        handAreaMarker.isHidden = !settings.hasHands

        // Initialize Labels and buttons
        for i in 0..<4 {
            let player = makeLabel(LabelBackground, parent: self.view)
            playerLabels.append(player)
            if i > 0 {
                hide(player)
            }
        }
        configureButton(playersButton, title: PlayersTitle, target: self, action: #selector(playersTouched), parent: self.view)
        configureButton(yieldButton, title: YieldTitle, target: self, action: #selector(yieldTouched), parent: self.view)
        configureButton(endGameButton, title: EndGameTitle, target: self, action: #selector(endGameTouched), parent: self.view)
        hide(endGameButton, yieldButton)
        configureButton(gameSetupButton, title: GameSetupTitle, target: self, action: #selector(gameSetupTouched), parent: self.view)
        configureButton(helpButton, title: HelpTitle, target: self, action: #selector(helpTouched), parent: self.view)

        // Add GridBox-making and destroying recognizer to the playingArea view
        let gridBoxRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressDetected))
        gridBoxRecognizer.minimumPressDuration = 1
        gridBoxRecognizer.allowableMovement = 2
        gridBoxRecognizer.delaysTouchesBegan = true
        playingArea.addGestureRecognizer(gridBoxRecognizer)
    }

    // When the view appears (hence its size is known), check whether an initial layout has been done.  If
    // not, do one.  Also configure the labels.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if notYetInitialized {
            notYetInitialized = false // don't repeat this sequence
            doLayout(nil)
            configurePlayerLabels(settings.numPlayers)
            Logger.log("Game initialized")
        }
    }

    // Allow view to be rotated.   We will redo the layout each time while preserving all controller state.
    open override var shouldAutorotate: Bool {
        get {
            return true
        }
    }

    // Support orientations according the "lock" flags.  If not locks, all orientations are accepted.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        get {
            if lockedToLandscape {
                return .landscape
            }
            if lockedToPortrait {
                return .portrait
            }
            return .all
        }
    }

    // Respond to rotation or other size-changing event by redoing layout.
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Hopefully temporary:
        if size.landscape && lockedToPortrait || !size.landscape && lockedToLandscape {
            bummer(title: "Rotation error", message: "Rotation should have been forbidden", host: self)
            return
        }
        let gameState = GameState(playingArea)
        coordinator.animate(alongsideTransition: nil) {_ in
            self.removeAllCardsAndBoxes()
            self.doLayout(gameState)
        }
    }

    // Layout section

    // Perform layout.
    private func doLayout(_ gs: GameState?) {
        // First establish a layout area within the safe area.  This area has a fixed "tablet like" aspect ratio regardless of
        // whether the device is a tablet or a phone.  Even on some tablets (that are not 12.9 iPad pros) this may not exactly
        // match the safe area.
        let safeArea = safeAreaOf(view)
        var layoutWidth: CGFloat, layoutHeight: CGFloat
        if safeArea.size.landscape {
            layoutHeight = safeArea.height
            layoutWidth = safeArea.height * LayoutAreaRatioLandscape
        } else {
            layoutWidth = safeArea.width
            layoutHeight = safeArea.width * LayoutAreaRatioPortrait
        }
        let layoutX = safeArea.midX - layoutWidth / 2
        let layoutY = safeArea.midY - layoutHeight / 2

        // Calculate some values needed to layout buttons and labels
        let controlHeight = ControlHeightRatio * layoutHeight
        let ctlWidth = (layoutWidth - 3 * border) / 4
        var labelX = layoutX
        let buttonX = layoutX
        let labelY = layoutY + border
        let buttonY = labelY + controlHeight + border

        // Layout the player labels
        for playerLabel in playerLabels {
            place(playerLabel, labelX, labelY, ctlWidth, controlHeight)
            labelX += ctlWidth + border
        }

        // Layout the buttons
        place(playersButton, buttonX, buttonY, ctlWidth, controlHeight)
        endGameButton.frame = playersButton.frame
        gameSetupButton.frame = playersButton.frame.offsetBy(dx: ctlWidth + border, dy: 0)
        yieldButton.frame = gameSetupButton.frame.offsetBy(dx: ctlWidth + border, dy: 0)
        helpButton.frame = yieldButton.frame.offsetBy(dx: ctlWidth + border, dy: 0)

        // The playingArea frame is positioned below the buttons and labels with the fixed aspect ratio determined by the
        // orientation but limited by the available space (in landscape the natural height might not quite fit).
        let aspectRatio = safeArea.size.landscape ? PlayingAreaRatioLandscape : PlayingAreaRatioPortrait
        let height = layoutWidth * aspectRatio
        Logger.log("natural height is \(height)")
        let areaY = helpButton.frame.maxY + border
        let maxHeight = layoutY + layoutHeight - areaY
        playingArea.frame = CGRect(x: layoutX, y: areaY, width: layoutWidth, height: min(height, maxHeight))
        Logger.log("Safe area is \(safeArea)")
        Logger.log("Playing area frame is \(playingArea.frame)")
        // We can now define the extent of the public area based on the playing area and whether or not there's a private area
        setupPublicArea(settings.hasHands)
        // Now place the cards and GridBoxes, with possible rescaling
        if let gameState = gs {
            let rescale = playingArea.bounds.minDimension / gameState.areaSize.minDimension
            Logger.log("rescale is \(rescale)")
            for cardState in gameState.cards {
                let newView : UIView
                if cardState.index >= 0 {
                    newView = findAndFixCard(from: cardState, rescale: rescale)
                } else {
                    Logger.log("cards[0].frame.size was \(cards[0].frame.size), now resized to \(cards[0].frame.size * rescale)")
                    let box = GridBox(origin: cardState.origin * rescale, size: cards[0].frame.size, host: self)
                    newView = box
                    box.name = cardState.name
                }
                // Ensure that newView has sufficient pixels overlapping the playing area so as to be easily seen
                let insets = UIEdgeInsets(top: MinCardPixels, left: MinCardPixels, bottom: MinCardPixels, right: MinCardPixels)
                let legal = playingArea.bounds.inset(by: insets)
                let actual = newView.frame
                if !actual.intersects(legal) {
                    var (newX, newY) = (actual.minX, actual.minY)
                    if actual.maxX <= legal.minX {
                        newX = legal.minX - (actual.width / 2)
                    } else if actual.minX >= legal.maxX {
                        newX = legal.maxX - (actual.width / 2)
                    }
                    if actual.maxY <= legal.minY {
                        newY = legal.minY - (actual.height / 2)
                    } else if actual.minY >= legal.maxY {
                        newY = legal.maxY - (actual.height / 2)
                    }
                    newView.frame = CGRect(origin: CGPoint(x: newX, y: newY), size: newView.frame.size)
                }
                playingArea.addSubview(newView)
            }
            for card in cardViews {
                card.maybeBeSnapped(boxViews)
            }
            refreshBoxCounts()
        } else {
            // First ever layout, no gameState exists yet.  Just create and place the deck, without rescaling.
            shuffleAndPlace()
        }
        Logger.log("Layout performed")
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
            transmit()
            return !wasCovered
        } else {
            Logger.logFatalError("Card gesture recognizer called with non-card")
        }
    }

    // On "tap", which can only happen if onTouch returned true and the card is not dragged
    private func cardTapped(_ touch: UITouch) {
        if let card = touch.view as? Card {
            if card.isFaceUp {
                card.turnFaceDown(true)
            } else {
                card.turnFaceUp(true)
            }
            transmit()
        }
    }

    // Respond to dragging of a card
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
                // Let a box snap up card if appropriate
                card.maybeBeSnapped(boxViews)
                // Make sure the card isn't left straddling the hand area line
                if !publicArea.contains(card.frame) && publicArea.intersects(card.frame) {
                    // Card is partly in the public area and partly in the hand area
                    var newOrigin: CGPoint
                    if card.frame.midY < publicArea.maxY {
                        // More than half the card is in the public area
                        newOrigin = CGPoint(x: card.frame.minX, y: publicArea.maxY - card.frame.height - border)
                    } else {
                        // At least half the card is in the hand area
                        newOrigin = CGPoint(x: card.frame.minX, y: publicArea.maxY + border)
                    }
                    // Snap the card into the most appropriate area
                    card.frame.origin = newOrigin
                }
            }
            refreshBoxCounts()
            transmit()
        }
    }

    // Respond to touch of the end game button.  Shuts down the communicator, effectively removing the player from the game, and resets
    // local game state for a fresh start.
    @objc func endGameTouched() {
        Logger.log("End game touched")
        prepareNewGame()
    }

    // Start the search for players
    func startPlayerSearch() {
        if players.count == 0 {
            players.append(makePlayer(settings))
        }
        guard let communicator = makeCommunicator(settings.communication, players[0], self, self) else { return }
        self.communicator = communicator
        hide(playersButton)
        unhide(endGameButton)
    }

    // Respond to long press.  A long press within a GridBox brings up the GridBoxMenu dialog to perform various actions
    // on the gridbox.  A long press that is not within any GridBox is interpreted as a request to create a new GridBox.
    // This might succeed or fail.  Once it's determined that it will succeed, the NewGridBoxMenu is brought up to prepare
    // the attributes of the GridBox.  We assume that GridBoxes do not overlap, so the long press cannot be within more than
    // one GridBox.
    @objc func longPressDetected(_ recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .ended {
            let location = recognizer.location(in: playingArea)
            if let box = boxViews.first(where:  { $0.frame.contains(location) }) {
                let menu = GridBoxMenu(box)
                Logger.logPresent(menu, host: self, animated: true)
            } else {
                attemptNewGridBox(location)
            }
        }
    }

    // Respond to touch of gameSetup button
    @objc func gameSetupTouched() {
        let dialog = GameSetupDialog()
        Logger.logPresent(dialog, host: self, animated: false)
    }

    // Respond to touch of the players button.  Opens the dialog for choosing nearby versus remote, entering a group token for remote,
    // nominating yourself as lead player, setting the number of players, etc.
    @objc func playersTouched() {
        let dialog = PlayerManagementDialog()
        Logger.logPresent(dialog, host: self, animated: false)
    }

    // Respond to touch of yield button.  Sends the GameState and advances the turn.
    @objc func yieldTouched() {
        Logger.log("Yield Touched")
        transmit(true)
        activePlayer = (thisPlayer + 1) % players.count
        configurePlayerLabels(numPlayers)
        checkTurnToPlay()
    }

    // Respond to touch of help button.   Display help html file.
    @objc func helpTouched() {
        let helpControl = HelpController(HelpFile, ReturnText)
        Logger.logPresent(helpControl, host: self, animated: true)
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
        gridBox.kind = .General
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

    // Configure the player labels according to latest information.
    func configurePlayerLabels(_ num: Int) {
        numPlayers = num
        for i in 0..<playerLabels.count {
            let label = playerLabels[i]
            unhide(label)
            if i < players.count {
                configurePlayer(label, players[i].name, i)
            } else if i == 0 {
                // Implies player.count == 0, meaning the game has not started.  Just fill in current player
                configurePlayer(label, settings.userName, i)
            } else if i < num {
                label.text = communicator == nil ? MustFind : Searching
            } else {
                hide(label)
            }
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
        // Cards don't change size, which was set once "suitable for this device."
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

    // Front for Deck.makePlayingDeck, ensures that every card gets a gesture recognizer, but only once.
    private func makePlayingDeck(_ deck: Deck, _ instructions: PlayingDeckTemplate) -> [Card] {
        Logger.log("making playing deck")
        let cards = deck.makePlayingDeck(instructions)
        for card in cards {
            if let recognizers = card.gestureRecognizers, recognizers.count > 0 {
                continue
            }
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
        if gridBox.name == nil {
            let menu = ModifyGridBox(gridBox)
            Logger.logPresent(menu, host: self, animated: true)
        }
    }

    // Set the firstYieldOccurred field and the associated orientation lock fields.  Hide the game setup button once first yield occurs.
    private func setFirstYieldOccurred(_ value: Bool, _ landscape: Bool) {
        self.firstYieldOccurred = value
        self.gameSetupButton.isHidden = value
        if value {
            Logger.log("firstYieldOccurred has been set to true, orientation locked to \(landscape ? "landscape" : "portrait")")
            self.lockedToLandscape = landscape
            self.lockedToPortrait = !landscape
        } else {
            Logger.log("firstYieldOccurred has been set to false")
            self.lockedToLandscape = false
            self.lockedToPortrait = false
        }
        self.setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    // End current game and prepare a new one (responds to EndGame button and also to lost peer condition)
    private func prepareNewGame() {
        // Clean up former game
        communicator?.shutdown()
        communicator = nil
        playBegun = false
        setFirstYieldOccurred(false, false)
        thisPlayer = 0
        activePlayer = 0
        playerLabels.forEach { $0.textColor = NormalTextColor }
        unhide(playersButton)
        hide(endGameButton, yieldButton)
        players = []
        // Set up new game
        deck = DefaultDeck.deck
        cards = makePlayingDeck(deck, settings.deckType)
        configurePlayerLabels(settings.numPlayers)
        removeAllCardsAndBoxes()
        shuffleAndPlace()
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

    // Called when the deck type or hand area setting changes.  Does the initial setup for that combination of decktype and hand area.
    func newShuffle() {
        setupPublicArea(settings.hasHands)
        cards = makePlayingDeck(deck, settings.deckType)
        removeAllCardsAndBoxes()
        shuffleAndPlace()
    }

    // Set up the public area and the hand area marker based on the current settings
    private func setupPublicArea(_ present: Bool) {
        if present {
            publicArea = playingArea.bounds.inset(by: UIEdgeInsets(top: 0, left: 0, bottom: cardSize.height * HandAreaExpansion, right: 0))
            place(handAreaMarker, publicArea.minX, publicArea.maxY, publicArea.width, border)
            unhide(handAreaMarker)
        } else {
            publicArea = playingArea.bounds
            hide(handAreaMarker)
        }
    }

    // Shuffle cards and form deck.  Add a GridBox to hold the deck and place everything on the playingArea
    private func shuffleAndPlace() {
        let cards = shuffle(self.cards)
        let deckOrigin = CGPoint(x: cardSize.width, y: cardSize.height)
        cards.forEach { card in
            card.turnFaceDown()
            card.frame = CGRect(origin: deckOrigin, size: cardSize)
            playingArea.addSubview(card)
        }
        let deckBox = GridBox(center: cards[0].center, size: cardSize, host: self)
        deckBox.name = MainDeckName
        deckBox.kind = .Deck
        placeNewGridBox(deckBox)
    }

    // Transmit GameState to the other players, either when just showing or when yielding
    func transmit(_ yielding: Bool = false) {
        guard thisPlayersTurn && communicator != nil else {
            return // Make it possible to call this without worrying.
        }
        let gameState : GameState
        if !firstYieldOccurred && thisPlayer == 0 {
            gameState = GameState(deckType: settings.deckType, handArea: settings.hasHands, yielding: yielding,
                                  playingArea: playingArea, publicArea: publicArea)
            setFirstYieldOccurred(yielding, gameState.areaSize.landscape)
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
        if players.count < numPlayers {
            let playerCount = settings.leadPlayer ? numPlayers : -1
            communicator?.send(GameState(players: players, numPlayers: playerCount))
        }
    }

    // Display communications-related error
    func error(_ error: Error, _ mustDeleteGame: Bool) {
        Logger.log("Communications error \(error)")
        var host: UIViewController = self
        DispatchQueue.main.async {
            while host.presentedViewController != nil {
                host = host.presentedViewController!
            }
            let alert = UIAlertController(title: CommunicationsErrorTitle, message: "\(error)", preferredStyle: .alert)
            var stopTitle = EndGameTitle
            if mustDeleteGame {
                stopTitle = OkButtonTitle
            } else {
                let keepPlaying = UIAlertAction(title: ContinueTitle, style: .default, handler: nil)
                alert.addAction(keepPlaying)
            }
            let stopPlaying = UIAlertAction(title: stopTitle, style: .cancel) { _ in
                self.communicator?.shutdown()
                let communication = self.settings.communication
                switch communication {
                case .ServerBased(let token):
                    serverGames.remove(token)
                    self.settings.communication = communication.next
                default:
                    break
                }
                self.prepareNewGame()
            }
            alert.addAction(stopPlaying)
            Logger.logPresent(alert, host: self, animated: false)
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
            // Phase 1 transfer: determining player list.  First, determine whether the sending player has provided
            //   a new numPlayers value (only the "lead" player "should" do this but because of the echoing logic when
            //   the player list changes, the value can appear in other contexts.  It is harmless to do a label configuration).
            var changed = false
            if gameState.numPlayers > 0 {
                configurePlayerLabels(gameState.numPlayers)
            }
            // Then, if the incoming list differs from the local list, merge the lists and notify the communicator.
            // Only the multipeer communicator actually needs or uses this notification.
            if players != gameState.players {
                Logger.log("Former players list was \(players)")
                Logger.log("New players list is \(gameState.players)")
                changed = true
                let merged = (players + gameState.players.filter({ !players.contains($0)})).sorted { $0.order < $1.order }
                Logger.log("Merged players list is \(merged)")
                players = merged
                // Reset thisPlayer since something may have merged in front of its previous location
                guard let thisPlayer = merged.firstIndex(where: {$0.name == OptionSettings.instance.userName})
                    else { Logger.logFatalError("This player not in player list") }
                self.thisPlayer = thisPlayer
                communicator?.updatePlayers(players)
            }

            // Check whether we now have the right number of players.  It is an error to have too many.  If we have exactly the
            // right number, check that there is exactly one lead player and indicate an error if there is none or more than one.
            // If that test is passed, indicate that play can begin.
            if numPlayers < players.count {
                presentTerminalError(PlayerErrorTitle, TooManyPlayersMessage)
                return
            } else if numPlayers == players.count {
                for player in 0..<numPlayers {
                    if players[player].order == 1 {
                        if player > 0 {
                            presentTerminalError(PlayerErrorTitle, TooManyLeadsMessage)
                            return
                        }
                    } else if player == 0 {
                        presentTerminalError(PlayerErrorTitle, NoLeadPlayersMessage)
                        return
                    }
                }
                // Player list is complete with exactly one lead player
                playBegun = true
                checkTurnToPlay()
            }

            // If anything changed at all, then share the result with other players so that consensus can eventually occur.
            // Note: in the absence of communication failures this is overkill because all players actually should get the same
            // information.  It seems that when we use MPC this extra sharing step is needed sometimes.  Things should quiesce because
            // if nothing changed, nothing is transmitted.
            if changed {
                Logger.log("Sending because 'changed' in players logic")
                communicator?.send(GameState(players: players, numPlayers: numPlayers))
            }
        } else {
            // This is not the initial player exchange but a move by an active player.  There is a special step for the first move
            //  to determine which deck is being used and to set up the hand area if requested.
            Logger.log("Received GameState contains \(gameState.cards.count) cards")
            if !firstYieldOccurred {
                if let deckType = gameState.deckType {
                    cards = makePlayingDeck(deck, deckType)
                }
                setupPublicArea(gameState.handArea)
                setFirstYieldOccurred(true, gameState.areaSize.landscape)
            }
            removePublicCardsAndBoxes()
            doLayout(gameState)
            if gameState.yielding {
                activePlayer = (activePlayer + 1) % players.count
                for i in 0..<players.count {
                    configurePlayer(playerLabels[i], players[i].name, i)
                }
                checkTurnToPlay()
            }
        }
    }

    // Restore a saved game state
    func restoreGameState(_ gameState: GameState) {
        if let deckType = gameState.deckType {
            settings.deckType = deckType
            cards = makePlayingDeck(deck, deckType)
        }
        settings.hasHands = gameState.handArea
        setupPublicArea(gameState.handArea)
        removePublicCardsAndBoxes()
        doLayout(gameState)
    }

    // Save the current game state
    func saveGameState() -> GameState {
        return GameState(deckType: settings.deckType, handArea: settings.hasHands, yielding: false, playingArea: playingArea, publicArea: publicArea)
    }

    // React to lost peer by ending the game with a short dialog
    func lostPlayer(_ playerID: String) {
        var player = getPlayer(playerID)
        if player == nil {
            Logger.log("Lost player \(playerID)")
            player = playerID
        } else {
            Logger.log("Lost player \(player!)(\(playerID))")
        }
        let lostPlayerMessage = String(format: LostPlayerTemplate, player!)
        presentTerminalError(LostPlayerTitle, lostPlayerMessage)
    }

    // Present an error message box for a condition that should terminate the game
    // Designed to be used in callbacks (uses DispatchQueue.main.async)
    func presentTerminalError(_ title: String, _ message: String) {
        var host: UIViewController = self
        DispatchQueue.main.async {
            while host.presentedViewController != nil {
                host = host.presentedViewController!
            }
            let action = UIAlertAction(title: OkButtonTitle, style: .cancel, handler: nil)
            let fullMessage = message + EndGame
            let alert = UIAlertController(title: title, message: fullMessage, preferredStyle: .alert)
            alert.addAction(action)
            Logger.logPresent(alert, host: self, animated: false)
            self.prepareNewGame()
        }
    }

    // Get the player name for a playerID, assuming the playerID is found in the 'players' list
    func getPlayer(_ playerID: String) -> String? {
        let possibles = players.filter { String($0.order) == playerID}
        if possibles.count == 1 {
            return possibles[0].name
        }
        return nil
    }

    // Make a Player object for the current player
    func makePlayer(_ settings: OptionSettings) -> Player {
        return Player(settings.userName, settings.leadPlayer)
    }
}
