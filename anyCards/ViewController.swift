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

// Main ViewController for the AnyCards Game app
class ViewController: UIViewController {

    // Shadow values for all of the settings
    var userName : String {
        get {
            return OptionSettings.instance.userName
        }
        set {
            OptionSettings.instance.userName = newValue
        }
    }
    var communication : CommunicatorKind {
        get {
            return OptionSettings.instance.communication
        }
        set {
            OptionSettings.instance.communication = newValue
            setChatButtonVisibility()
        }
    }
    var gameToken : String? {
        switch(communication) {
        case .MultiPeer:
            return nil
        case .ServerBased(let gameToken):
            return gameToken
        }
    }
    var deckType : PlayingDeckTemplate {
        get {
            return OptionSettings.instance.deckType
        }
        set {
            OptionSettings.instance.deckType = newValue
            cards = makePlayingDeck(Deck, deckType)
        }
    }
    var hasHands : Bool {
        get {
            return OptionSettings.instance.hasHands
        }
        set {
            OptionSettings.instance.hasHands = newValue
        }
    }
    private var storedNumPlayers : Int { // only use this if leader
        get {
            return OptionSettings.instance.numPlayers
        }
        set {
            OptionSettings.instance.numPlayers = newValue
            // Changes to numPlayers should propagate eagerly
            transmit()
        }
    }
    private var _numPlayers : Int = 0 // cache for received value
    var numPlayers : Int { // zero if not leader until value received
        get {
            if leadPlayer {
                return storedNumPlayers
            }
            return _numPlayers
        }
        set {
            _numPlayers = newValue
            if leadPlayer {
                storedNumPlayers = newValue
            }
        }
    }
    var leadPlayer : Bool {
        get {
            return OptionSettings.instance.leadPlayer
        }
        set {
            OptionSettings.instance.leadPlayer = newValue
            if newValue {
                // On becoming leader, transmit state
                transmit()
            }
        }
    }
    
    // Model-related fields

    // The source deck in current use.
    // TODO this is not yet settable.   When it does become settable, then changes to it should be handled dynamically
    // just like changes to the deck type.
    let Deck = DefaultDeck.deck

    // The cards array for the game.  This depends on the values of Deck and deckType but is kept up to date with them.
    var cards : [Card] = []

    // The list of players (always starts with just 'this' player but expands during discovery until play starts.
    // The array is ordered by
    // the order fields, ascending)
    var players = [Player]()

    // The index in the players array assigned to 'this' player (the user of the present device).  Initially zero.
    var thisPlayer : Int = 0    // Index may change since the order of players is determined by their order fields.

    // The index of the player whose turn it is (moves are allowed iff thisPlayer and activePlayer are the same)
    var activePlayer : Int = 0  // The player listed first always goes first but play rotates thereafter

    // Says whether it's this player's turn to make moves
    var thisPlayersTurn : Bool {
        return thisPlayer == activePlayer
    }

    // The Communicator (nil until player search begins; remains non-nil during actual play)
    var communicator : Communicator? = nil

    // Indicates that play has begun.  If communicator is non-nil and playBegun is false, the player list is still being
    // constructed.  Game turns may not occur until play officially begins
    var playBegun = false

    // Indicates that the first yield by the leader has occurred.  Until this happens, the leader is allowed to change the
    // setup.  Afterwards, the setup is fixed.  This field is only meaningful in the leader's app instance.
    var setupIsComplete = false
    
    // The transcript of the ongoing chat (if in use)
    var chatTranscript = ""
    
    //  Controls whether card grouping is active in the private area.  Starts out false
    var groupingInPrivateArea = false

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

    // Buttons
    let yieldButton = UIButton()
    let playersButton = UIButton()
    let endGameButton = UIButton()
    let gameSetupButton = UIButton()
    let helpButton = UIButton()
    let chatButton = UIButton()

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
        let cardHeight = cardWidth / Deck.aspectRatio
        return CGSize(width: cardWidth, height: cardHeight)
    }
    
    // The amount by which a card being dragged in the private area may extend into the public area without danger of
    // ending up there.
    var privateAreaCardOverlap: CGFloat {
        return cardSize.height / 5
    }

    // Initializers

    // Main initializer, bypass builder stuff
    init() {
        super.init(nibName: nil, bundle: nil)
        cards = makePlayingDeck(Deck, deckType)
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

        // Make the hand area marker be a subview of the playingArea and assign its color. 
        // It is hidden if the hand area is configured as absent.
        playingArea.addSubview(handAreaMarker)
        handAreaMarker.backgroundColor = UIColor.black
        handAreaMarker.isHidden = !hasHands

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
        configureButton(chatButton, title: ChatTitle, target: self, action: #selector(chatTouched), parent: self.view)
        chatButton.isHidden = true

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
            configurePlayerLabels()
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
        let gameState = GameState(self, includeHandArea: true)
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
        place(helpButton, after(yieldButton), buttonY, ctlWidth/2, controlHeight)
        place(chatButton, after(helpButton), buttonY, ctlWidth/2, controlHeight)

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
        setupPublicArea()
        // Now place the cards and GridBoxes, with possible rescaling
        if let gameState = gs {
            let rescale = playingArea.bounds.minDimension / gameState.areaSize.minDimension
            Logger.log("rescale is \(rescale)")
            for boxState in gameState.boxes {
                let box = GridBox(origin: boxState.origin * rescale, size: cardSize, host: self)
                box.name = boxState.name
                box.owner = boxState.owner
                box.kind = boxState.kind
                playingArea.addSubview(box)
            }
            for cardState in gameState.cards {
                let card = findAndFixCard(from: cardState, rescale: rescale)
                // Ensure that the card has sufficient pixels overlapping the playing area so as to be easily seen
                let insets = UIEdgeInsets(top: MinCardPixels, left: MinCardPixels, bottom: MinCardPixels, right: MinCardPixels)
                let legal = playingArea.bounds.inset(by: insets)
                let actual = card.frame
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
                    card.frame = CGRect(origin: CGPoint(x: newX, y: newY), size: card.frame.size)
                }
                playingArea.addSubview(card)
            }
            refreshBoxCounts()
        } else {
            // First ever layout, no gameState exists yet.  Just create and place the deck, without rescaling.
            shuffleAndPlace()
        }
        Logger.log("Layout performed")
    }

    // Actions

    // On "tap", which can only happen if card is not dragged.  Tapping a covered card brings it to the front.
    // Tapping a non-covered card flips it over.
    private func cardTapped(_ touch: UITouch) {
        if let card = touch.view as? Card {
            if maybeTakeHand(card) {
                return
            }
            if !thisPlayersTurn {
                Logger.log("Card tap when not this player's turn (ignored)")
                return
            }
            if isCovered(card) {
                playingArea.bringSubviewToFront(card)
            } else if card.isFaceUp {
                card.turnFaceDown(true)
            } else {
                card.turnFaceUp(true)
            }
            transmit()
        } else {
            Logger.logFatalError("Card gesture recognizer called with non-card")
        }
    }

    // Respond to dragging of a card
    @objc func dragging(recognizer: UIPanGestureRecognizer) {
        if recognizer.state == .possible {
            return
        }
        guard let card = recognizer.view as? Card else {
            Logger.log("View not dragged, not a Card")
            return
        }
        if maybeTakeHand(card) {
            return
        }
        if !card.isPrivate && !thisPlayersTurn {
            Logger.log("Public card cannot be dragged when not the player's turn")
        }
        if let box = card.box, !box.mayBeModified {
            box.mayNotModify()
            return
        }
        if recognizer.state == .began {
            let dragSet = findDragSet(card)
            playingArea.bringSubviewToFront(card)
            dragSet.forEach() {
                playingArea.bringSubviewToFront($0)
            }
            card.dragSet = dragSet
        }
        // In any active drag state we move all the cards in the drag set
        let translation = recognizer.translation(in: playingArea)
        // We allow the drag as long as the actual card is in the playing area and, if the player is not the active player,
        // as long as no part of it is in the public area.  We don't check the other cards, which may leave them off the screen,
        // although when the drag ends they will be adjusted individually.
        let primaryNewFrame = CGRect(origin: card.frame.origin + translation, size: card.frame.size)
        if playingArea.bounds.contains(primaryNewFrame) &&
                (thisPlayersTurn || primaryNewFrame.minY > publicArea.maxY - privateAreaCardOverlap) {
            for draggedCard in card.dragSet {
                let newFrame = CGRect(origin: draggedCard.frame.origin + translation, size: card.frame.size)
                draggedCard.frame = newFrame
            }
            recognizer.setTranslation(CGPoint.zero, in: view)
        }
        // At the end, we adjust the cards individually
        if recognizer.state == .ended {
            for draggedCard in card.dragSet {
                // Let a box snap up card if appropriate.  We assume all boxes are public so we skip if private
                if !draggedCard.isPrivate {
                    let rejectedDecks = draggedCard.maybeBeSnapped(boxViews)
                    // Make sure an unsnapped card isn't covering too much of a rejected deck
                    if rejectedDecks.count > 0 {
                        unhideDeck(draggedCard, rejectedDecks)
                    }
                }
                // Make sure the card isn't left straddling the hand area line
                if !publicArea.contains(draggedCard.frame) && publicArea.intersects(draggedCard.frame) {
                    // Card is partly in the public area and partly in the hand area
                    var newOrigin: CGPoint
                    if draggedCard.frame.midY < publicArea.maxY {
                        // More than half the card is in the public area
                        newOrigin = CGPoint(x: draggedCard.frame.minX, y: publicArea.maxY - draggedCard.frame.height - border)
                    } else {
                        // At least half the card is in the hand area
                        newOrigin = CGPoint(x: draggedCard.frame.minX, y: publicArea.maxY + border)
                    }
                    // Place the card into the most appropriate area (public or hand)
                    draggedCard.frame.origin = newOrigin
                }
                // Mark card public or private
                draggedCard.isPrivate = !publicArea.contains(draggedCard.frame.center)
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
            players.append(makePlayer())
        }
        Logger.log("Making communicator of kind \(communication.displayName)")
        makeCommunicator(communication, player: players[0], delegate: self, host: self) { (communicator, error) in
            if let communicator = communicator {
                Logger.log("Got back valid communicator")
                self.communicator = communicator
                self.setChatButtonVisibility()
                hide(self.playersButton)
                unhide(self.endGameButton)
            } else if let error = error {
                bummer(title: "Could not establish communication", message: error.localizedDescription, host: self)
            } else {
                Logger.logFatalError("makeCommunicator got unexpected response")
            }
        }
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
                guard let menu = GridBoxMenu(box) else {
                    box.mayNotModify()
                    return
                }
                Logger.logPresent(menu, host: self, animated: true)
            } else if publicArea.contains(location ){
                attemptNewGridBox(location)
            } else {
                // Long press in the private area brings up the card grouping dislog
                chooseGroupingInPrivateArea()
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
        let newActivePlayer = (thisPlayer + 1) % players.count
        transmit(activePlayer: newActivePlayer)
        self.activePlayer = newActivePlayer
        if leadPlayer {
            Logger.log("Leader is yielding, marking setup complete")
            setupIsComplete = true
            hide(gameSetupButton)
        }
        configurePlayerLabels()
        checkTurnToPlay()
    }

    // Respond to touch of help button.   Display help html file.
    @objc func helpTouched() {
        let helpControl = HelpController(helpPage: HelpFile, email: FeedbackEmail, returnText: ReturnText, appName: "AnyCards")
        Logger.logPresent(helpControl, host: self, animated: true)
    }
    
    // Respond to touch of the chat button.  Open the chat view
    @objc func chatTouched() {
        guard let communicator = self.communicator else {
            Logger.logFatalError("chat button should not have been visible with no communicator")
        }
        let chatWindow = ChatController(chatTranscript, communicator: communicator)
        Logger.logPresent(chatWindow, host: self, animated: true)
    }

    // Other functions
    
    // When a card is tapped or dragged, determine if it is in a properly owned Hand Box and, if so, take the hand
    func maybeTakeHand(_ card: Card) -> Bool {
        if let box = card.box, box.kind == .Hand, box.mayBeModified {
            takeHand(box)
            return true
        }
        return false
    }
    
    // Display alert allowing user to toggle card grouping in the private area
    func chooseGroupingInPrivateArea() {
        let groupAction = UIAlertAction(title: "Grouped", style: .default) { _ in
            self.groupingInPrivateArea = true
        }
        let ungroupAction = UIAlertAction(title: "Individual", style: .default) { _ in
            self.groupingInPrivateArea = false
        }
        let alert = UIAlertController(title: "Card Grouping", message: "How to drag cards in hand", preferredStyle: .alert)
        alert.addAction(groupAction)
        alert.addAction(ungroupAction)
        Logger.logPresent(alert, host: self, animated: false)
    }
    
    // Decide whether chat button should be hidden or not
    func setChatButtonVisibility() {
        if let communicator = self.communicator, communicator.isChatAvailable {
            unhide(chatButton)
        } else {
            hide(chatButton)
        }
    }


    // Given a card, find all the other cards that cover it or that cover cards that cover it (transitive closure).
    // The original card plus the found others constitutes the "drag set" which is going to be dragged as a whole
    // We can find the set with a single pass over cardViews because that list is ordered back to front.  If we start where
    // the source card is placed, all subsequent cards that intersect that card or any cards previously added to the set
    // are in the set.
    private func findDragSet(_ card: Card) -> [Card] {
        var answer = [card]
        if card.isPrivate && !groupingInPrivateArea {
            Logger.log("Not grouping cards in private area")
            return answer
        }
        var cardSeen = false
        //Logger.log("finding drag set for card \(card.index)")
        for candidate in cardViews {
            if !cardSeen && candidate.index == card.index {
                //Logger.log("found card in card views")
                cardSeen = true
            } else if cardSeen && candidate.isPrivate == card.isPrivate && intersectsAny(candidate, answer) {
                //Logger.log("adding card \(candidate.index) to drag set")
                answer.append(candidate)
            }
        }
        if !cardSeen {
            Logger.logFatalError("Dragged card not found in card views")
        }
        //Logger.log("have a drag set with \(answer.count) cards")
        return answer
    }

    // Determine if a view overlaps any of a set of views
    private func intersectsAny(_ candidate: UIView, _ others: [UIView]) -> Bool {
        return others.contains(where: { $0.frame.intersects(candidate.frame) })
    }

    // Determine if any .Deck GridBox is largely covered by a card that it couldn't snap up.  If so, move the card enough
    // to make clear it is not part of the deck.  The 'decks' argument contains only .Deck GridBoxes which overlap the card.
    // Here we determine if the overlap is large enough to be of concern and move the card if necessary.
    private func unhideDeck(_ card: Card, _ decks: [GridBox]) {
        let cardX = card.frame.minX
        let cardY = card.frame.minY
        for deck in decks {
            let xDiff = cardX - deck.snapFrame.minX
            let yDiff = cardY - deck.snapFrame.minY
            if xDiff.magnitude < SnapThreshhold && yDiff.magnitude < SnapThreshhold {
                // The card covers the deck or nearly so.  That is, its origin lies within a square
                // centered at the deck's origin, with width and height of 2 * SnapThreshhold.  We can
                // determine the quadrant of the square containing the card's origin by using the signs
                // of xDiff and yDiff.  Then we move the card's origin to the outer corner of that quadrant.
                var cornerShift: CGPoint
                switch xDiff.sign {
                case .minus:
                    switch yDiff.sign {
                    case .minus:
                        cornerShift = CGPoint(x: -SnapThreshhold, y: -SnapThreshhold)
                    case .plus:
                        cornerShift = CGPoint(x: -SnapThreshhold, y: SnapThreshhold)
                    }
                case .plus:
                    switch yDiff.sign {
                    case .minus:
                        cornerShift = CGPoint(x: SnapThreshhold, y: -SnapThreshhold)
                    case .plus:
                        cornerShift = CGPoint(x: SnapThreshhold, y: SnapThreshhold)
                    }
                }
                card.frame.origin = deck.frame.origin + cornerShift
                // Since GridBoxes cannot overlap, if the card overlapped one to such a great extent it cannot overlap others
                return
            }
        }
    }

    // Create a new GridBox or indicate that it can't be done.
    //   -- attempt to create a GridBox with the press at its center; if this does not overlap any other GridBox it succeeds
    //   -- if the attempt overlaps more than one other GridBox it fails
    //   -- if the attempt overlaps exactly one other GridBox, choose a revised origin such that the new GridBox fits
    //      next to the old one, above, below, to the left, or to the right, depending on where the press is located.
    //      If none of those revised locations contain the press or the resulting box would go off the view, the request fails.
    //      Otherwise, the request succeeds with the revised origin
    // A new GridBox is immediately sent to the back and snaps up any cards that fall within it.
    private func attemptNewGridBox(_ location: CGPoint) {
        // Calculate the bounds of the public area
        // Try to create a box with location at its center
        let snapSize = cards[0].frame.size
        let gridBox = GridBox(center: location, size: snapSize, host: self)
        // Reject the GridBox if any part of it would fall outside the public area
        // Note that this function should not be called unless the long press location is in the public area
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
            label.attributedText = nil
            label.text = playerName
        }
        Logger.log("Setting text color for player \(playerIndex). " +
                   " This player is \(thisPlayer), playBegun is \(playBegun) and activePlayer is \(activePlayer)")
        label.textColor = (playBegun && playerIndex == activePlayer) ? ActivePlayerColor : NormalTextColor
    }

    // Configure the player labels according to latest information.
    func configurePlayerLabels() {
        for i in 0..<playerLabels.count {
            let label = playerLabels[i]
            unhide(label)
            if i < players.count {
                configurePlayer(label, players[i].name, i)
            } else if i == 0 {
                // Implies player.count == 0, meaning the game has not started.  Just fill in current player
                configurePlayer(label, userName, i)
            } else if i < numPlayers {
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
        card.frame = CGRect(origin: from.origin * rescale, size: cardSize)
        // Cards don't change size, which was set once "suitable for this device."
        card.isPrivate = from.isPrivate // Almost always false but can be true when using GameState for purely local purposes
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
    private func makePlayingDeck(_ deck: SourceDeck, _ instructions: PlayingDeckTemplate) -> [Card] {
        Logger.log("making playing deck")
        let cards = deck.makePlayingDeck(instructions)
        Logger.log("there are \(cards.count) cards")
        for card in cards {
            if let recognizers = card.gestureRecognizers, recognizers.count > 0 {
                continue
            }
            // TODO consider changing the interpretation of a nil touch recognizer when there is a tap recognizer.
            // The effect should be 'true' rather than 'false', in which case the following vacuous function would not
            // be necessary.
            func beTrue(_ touch: UITouch)-> Bool { return true }
            let gestureRecognizer = TouchTapAndDragRecognizer(target: self, onDrag: #selector(dragging), onTouch: beTrue, onTap: cardTapped)
            card.addGestureRecognizer(gestureRecognizer)
        }
        return cards
    }

    // Place a new GridBox into the playingArea after determining that it fits
    // Note: the GridBox should still be modifiable at this point since it is newly created.
    private func placeNewGridBox(_ gridBox: GridBox) {
        playingArea.addSubview(gridBox)
        playingArea.sendSubviewToBack(gridBox)
        gridBox.maybeSnapUp(cardViews)
        gridBox.refreshCount()
        if gridBox.name == nil {
            guard let menu = ModifyGridBox(gridBox) else {
                // Should not happen
                Logger.log("ModifyGridBox constructor failed in a context where it shouldn't have")
                return
            }
            Logger.logPresent(menu, host: self, animated: true)
        }
    }

    // Set the orientation lock fields
    private func setOrientationLocks(_ landscape: Bool) {
        Logger.log("Leader has sent setup information.  Orientation locked to \(landscape ? "landscape" : "portrait")")
        self.lockedToLandscape = landscape
        self.lockedToPortrait = !landscape
        self.setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    // End current game and prepare a new one (responds to EndGame button and also to lost peer condition)
    private func prepareNewGame() {
        // Clean up former game
        communicator?.shutdown(false)
        communicator = nil
        playBegun = false
        lockedToLandscape = false
        lockedToPortrait = false
        setupIsComplete = false
        thisPlayer = 0
        activePlayer = 0
        playerLabels.forEach { $0.textColor = NormalTextColor }
        unhide(playersButton)
        hide(endGameButton, yieldButton)
        players = []
        configurePlayerLabels()
        chatButton.isHidden = true
        // Set up new game
        newShuffle()
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

    // Called when the deck type or hand area setting changes.  
    // Does the initial setup for that combination of decktype and hand area.
    func newShuffle() {
        Logger.log("Request for newShuffle (deck change?)")
        setupPublicArea()
        removeAllCardsAndBoxes()
        shuffleAndPlace()
    }

    // Set up the public area and the hand area marker based on the current settings
    func setupPublicArea() {
        if hasHands {
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
        Logger.log("Shuffling and placing \(self.cards.count) cards")
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
    func transmit(activePlayer: Int? = nil) {
        guard let communicator = self.communicator, thisPlayersTurn else {
            return // Make it possible to call this without worrying.
        }
        let gameState = GameState(self, activePlayer: activePlayer)
        communicator.send(gameState)
    }
}

// Conform to protocol for Communicator
extension ViewController : CommunicatorDelegate {
    // Respond to a new player list during game initiation.  We do not use this call later for lost players;
    // we use `lostPlayer` for that.  The received players array is already properly sorted.
    func newPlayerList(_ newNumPlayers: Int, _ newPlayers: [Player]) {
        DispatchQueue.main.async {
            self.doNewPlayerList(newNumPlayers, newPlayers)
        }
    }
    
    func doNewPlayerList(_ newNumPlayers: Int, _ newPlayers: [Player]) {
        Logger.log("newPlayerList received, newNumPlayers=\(newNumPlayers), \(newPlayers.count) players present")
        self.players = newPlayers
        if players.count > 0 { // Should always be true, probably, but give communicators some slack
            // Recalculate thisPlayer based on new list
            guard let thisPlayer = players.firstIndex(where: {$0.name == OptionSettings.instance.userName})
            else { 
                Logger.log("The player for this app is not in the received player list")
                return
            }
            self.thisPlayer = thisPlayer
            
            // Manage incoming numPlayers.  Ignore it if leader.  For others, store it but 0 means unknown.
            if !leadPlayer {
                numPlayers = newNumPlayers
            }
            if numPlayers > 0 {
                // Check whether we now have the right number of players.  It is an error to have too many.
                // If we have exactly the right number, check that there is exactly one lead player and indicate an error
                // if there is none or more than one.  If that test is passed, indicate that play can begin.
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
                    Logger.log("Player list complete, play begun")
                    checkTurnToPlay()
                } // else player list not complete
            } // else we don't know the number of players yet
            // Always configure the player labels after all information is processed.
            configurePlayerLabels()
        } // else this call does not provide any players
    }

    // Handle a new chat message
    func newChatMsg(_ msg: String) {
        chatTranscript = chatTranscript == "" ? msg : chatTranscript + "\n" + msg
        DispatchQueue.main.async {
            if let chatController = self.presentedViewController as? ChatController {
                chatController.updateTranscript(self.chatTranscript)
            }
        }
    }
    
    // Display communications-related error and do some cleanup
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
                self.communicator?.shutdown(true)
                self.prepareNewGame()
            }
            alert.addAction(stopPlaying)
            Logger.logPresent(alert, host: self, animated: false)
        }
    }

    // Respond to receipt of a new GameState
    func gameChanged(_ gameState: GameState) {
        if gameState.sendingPlayer == thisPlayer {
            // Don't accept remote game state updates that you originated yourself.
            // TODO Consider whether this should be more properly handled inside the communicator since it is not
            // something that can happen with all communicators.
            Logger.log("Rejected incoming game state during own turn")
            return
        }
        if !playBegun {
            Logger.log("Play has not begun so not processing game state")
            return
        }
        DispatchQueue.main.async {
            // Doing everything on the main thread for now; some things could be done in the background but not clear that's necessary
            self.doGameChanged(gameState)
        }
    }
    private func doGameChanged(_ gameState: GameState) {
        Logger.log("doGameChanged invoked")
        if let setup = gameState.setup, !leadPlayer {
            Logger.log("Still in initial setup, processing deck type and public area")
            cards = makePlayingDeck(Deck, setup.deckType)
            hasHands = setup.handArea
            setupPublicArea()
            setOrientationLocks(gameState.areaSize.landscape)
        }
        Logger.log("Received GameState contains \(gameState.boxes.count) boxes and \(gameState.cards.count) cards")
        if gameState.activePlayer != self.activePlayer {
            Logger.log("The active player has changed")
            self.activePlayer = gameState.activePlayer
            for i in 0..<players.count {
                configurePlayer(playerLabels[i], players[i].name, i)
            }
            checkTurnToPlay()
        }
        removePublicCardsAndBoxes()
        doLayout(gameState)
    }

    // Restore a saved game state
    func restoreGameState(_ gameState: GameState) {
        if let setup = gameState.setup {
            self.deckType = setup.deckType
            cards = makePlayingDeck(Deck, setup.deckType)
            hasHands = setup.handArea
        }
        setupPublicArea()
        removePublicCardsAndBoxes()
        // Randomize the cards in the restored state (leaving grid boxes alone)
        var newIndices = shuffle(Array<Int>(0..<gameState.cards.count))
        for card in gameState.cards {
            card.index = newIndices.removeFirst()
        }
        doLayout(gameState)
        transmit()
    }

    // React to lost peer by ending the game with a short dialog
    func lostPlayer(_ player: Player) {
        Logger.log("Lost player \(player.display)")
        let lostPlayerMessage = String(format: LostPlayerTemplate, player.display)
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
    
    // Perform the "take hand" function
    func takeHand(_ box: GridBox) {
        // Calculate the placement points in the private area
        let lastX = playingArea.bounds.width - cardSize.width - border
        var currentX = playingArea.bounds.minX + border
        let step = (lastX - currentX) / (box.cards.count - 1)
        //Logger.log("currentX=\(currentX), lastX=\(lastX), step=\(step)")
        let fixedY = playingArea.bounds.maxY - cardSize.height - border
        // Prepare animation functions to move the cards
        var animations = [()->Void]()
        for card in box.cards.sorted(by: { $0.index < $1.index }) {
            let xValue = currentX // use immutable to ensure value is captured, not reference
            animations.append({
                UIView.animate(withDuration: DealCardDuration, animations: {
                    //Logger.log("card.frame.origin was \(card.frame.origin)")
                    card.frame.origin = CGPoint(x: xValue, y: fixedY)
                    //Logger.log("card.frame.origin is now \(card.frame.origin)")
                    card.turnFaceUp()
                    card.isPrivate = true
                    self.playingArea.bringSubviewToFront(card)
                })
            })
            currentX += step
        }
        // Move the cards with animation
        runAnimationSequence(animations) {
            // Delete the box
            box.removeFromSuperview()
            self.transmit()
        }
    }


    // Get the player name associated with an index position or else use a helpful placeholder phrase
    func getPlayer(index: Int) -> String {
        if index < players.count {
            return players[index].name
        }
        return "Player #\(index+1)"
    }

    // Make a Player object for the current player
    func makePlayer() -> Player {
        return Player(userName, leadPlayer)
    }
}
