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
import unigame
import CBORCoding
import SwiftUI

// The playing surface view for the AnyCards Game app.
// Although AnyCards uses the unigame framework, which is SwiftUI-based, this view had much existing code from before
// the dependency on unigame was introduced.  So, it is retained as a UIKit view.
// Because it holds references to both the UnigameModel and the AnyCardsGameHandle, we treat it as the root object
// when instantiating the app.
class PlayingSurface: UIView {
    let model: UnigameModel<AnyCardsGameHandle>
    let gameHandle: AnyCardsGameHandle

    init() {
        Logger.log("A new playing surface is being constructed")
        self.model = AnyCardsGameHandle.makeModel()
        self.gameHandle = self.model.gameHandle
        Logger.log("Unigame model has been created")
        super.init(frame: CGRect.zero)
        Logger.log("Playing surface init has been run")
        self.gameHandle.playingSurface = self
        Logger.log("Constructed circular reference between PlayingSurface and AnyCardsGemeHandle")
        self.cards = sourceDeck.makePlayingDeck(gameHandle.deckType)
        Logger.log("Initial cards array constructed (without gesture recognizers)")
        Logger.log("Initialization of playing view is complete")
   }
       
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Respond to update request from SwiftUI world.
    // Note: still not sure what should happen here.
    func update(_ context: UIViewRepresentableContext<PlayingSurfaceWrapper>) {
        Logger.log("Update of PlayingSurface requested by SwiftUI ... ignored for now")
    }

    // Model-related fields

    // The source deck in current use (not currently settable)
    let sourceDeck = DefaultDeck.deck

    // The cards array for the game.  This depends on the values of Deck and deckType but is kept up to date with them.
    var cards : [Card] = []
    
    //  Controls whether card grouping is active in the private area.  Starts out false
    var groupingInPrivateArea = false

    // View-related fields

    // Set the orientation lock fields
    private func setOrientationLocks(_ landscape: Bool) {
        Logger.log("Leader has sent setup information.  Orientation locked to \(landscape ? "landscape" : "portrait")")
        setSceneGeometry(landscape ? .landscape : .portrait)
    }
    
    // Sets the geometry of the current window scene
    private func setSceneGeometry(_ mask: UIInterfaceOrientationMask) {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                Logger.log("Orientation setting was denied \(error)")
            }
        }
    }

    // The public area within this view (excludes a possible "hand area" at the bottom)
    var publicArea: CGRect!  // Initialized in setupPublicArea which must be called before possible access

    // The "dealing area" within the publicArea (defined once the publicArea is defined).
    // This is where cards are dealt by the dealing dialog
    var dealingArea: CGRect {
        if publicArea == CGRect.zero {
            return publicArea
        }
        let boxHeight = cardSize.height * GridBoxExpansion
        let y = publicArea.maxY - border - boxHeight
        return CGRect(x: publicArea.minX, y: y, width: publicArea.width, height: boxHeight)
    }
    
    // One time flag for doing final initialization of the view.  We cannot do this in the constructor because the
    // view is constructed too early in the lifecycle of the app and the gesture recognition is not yet setup then.
    var viewIsInitialized = false
    

    // Indicates whether the dealing area is free to receive dealt hands or boxes.
    var dealingAreaClear: Bool {
        if dealingArea == .zero {
            return false
        }
        return !subviews.contains(where: { $0.frame.intersects(dealingArea)})
    }
    
    // The division marker for the hand area
    let handAreaMarker = UIView()

    // The subset of the playingArea subviews that are cards.  Normally, the contents of this array is the same as that of the cards
    // array but the order is the subview order rather than index order.
    var cardViews : [Card] {
        return subviews.filter({ $0 is Card }).map { $0 as! Card }
    }

    // The subset of the subviews that are GridBoxes.
    var boxViews : [GridBox] {
        return subviews.filter({ $0 is GridBox }).map { $0 as! GridBox }
    }

    // The expected size of a card in the current layout
    var cardSize: CGSize {
        let cardWidth = frame.minDimension * CardDisplayWidthRatio
        let cardHeight = cardWidth / sourceDeck.aspectRatio
        return CGSize(width: cardWidth, height: cardHeight)
    }
    
    // The amount by which a card being dragged in the private area may extend into the public area without danger of
    // ending up there.
    var privateAreaCardOverlap: CGFloat {
        return cardSize.height / 5
    }
    
    // "The" deck for this playing surface
    var deck: GridBox? {
        boxViews.first(where: {$0.name == MainDeckName})
    }

    // Finish basic initialization when the view is constructed
    // Returns self for convenient chaining when setting up previews
    @discardableResult
    func initializeView() -> PlayingSurface {
        
        if viewIsInitialized {
            return self
        }
        viewIsInitialized = true

        backgroundColor = PlayingColor

        // Make the hand area marker be a subview of the playingArea and assign its color. 
        // It is hidden if the hand area is configured as absent.
        addSubview(handAreaMarker)
        handAreaMarker.backgroundColor = UIColor.black
        handAreaMarker.isHidden = !gameHandle.hasHands

        // Add GridBox-making and destroying recognizer
        let gridBoxRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressDetected))
        gridBoxRecognizer.minimumPressDuration = 1
        gridBoxRecognizer.allowableMovement = 2
        gridBoxRecognizer.delaysTouchesBegan = true
        addGestureRecognizer(gridBoxRecognizer)
        
        // Ensure card gesture recognizers are in place
        addCardGestureRecognizers()
        return self
    }

    // When the view first appears (hence its size is known) do the initial layout.
    // This method is called repeatedly for various reasons; after the first time we ignore it.
    override func layoutSubviews() {
        super.layoutSubviews()
        if boxViews.count == 0 && cardViews.count == 0 {
            // First ever layout, no gameState exists yet.  Just create and place the deck, without rescaling.
            setupPublicArea()
            shuffleAndPlace()
            Logger.log("Playing area initialized")
        }
    }

    // Layout section

    // Perform layout after changes.  The PlayingState argument contains the new desired state.
    private func doLayoutFromState(_ gs: PlayingState) {
        removeAllCardsAndBoxes()
        if let setup = gs.setup, !model.leadPlayer {
            Logger.log("Still in initial setup, processing deck type and public area, locking orientation")
            cards = sourceDeck.makePlayingDeck(setup.deckType)
            addCardGestureRecognizers()
            gameHandle.hasHands = setup.hasHands
            setupPublicArea()
            setOrientationLocks(gs.areaSize.landscape)
        }
        let currentScale = bounds.minDimension
        let newScale = gs.areaSize.minDimension
        let rescale = currentScale > 0 && newScale > 0 ? currentScale/newScale : 1.0
        Logger.log("rescale is \(rescale)")
        for boxState in gs.boxes {
            let box = GridBox(origin: boxState.origin * rescale, size: cardSize, host: self)
            box.name = boxState.name
            box.owner = boxState.owner
            box.kind = boxState.kind
            addSubview(box)
        }
        for cardState in gs.cards {
            let card = findAndFixCard(from: cardState, rescale: rescale)
            // Ensure that the card has sufficient pixels overlapping the playing area so as to be easily seen
            let insets = UIEdgeInsets(top: MinCardPixels, left: MinCardPixels, bottom: MinCardPixels, right: MinCardPixels)
            let legal = bounds.inset(by: insets)
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
            addSubview(card)
        }
        refreshBoxCounts()
        Logger.log("New layout was performed for a new PlayingState")
    }

    // Actions

    // On "tap", which can only happen if card is not dragged.  Tapping a covered card brings it to the front.
    // Tapping a non-covered card flips it over.
    private func cardTapped(_ touch: UITouch) {
        if let card = touch.view as? Card {
            if maybeTakeHand(card) {
                return
            }
            if !model.thisPlayersTurn {
                Logger.log("Card tap when not this player's turn (ignored)")
                return
            }
            if isCovered(card) {
                bringSubviewToFront(card)
            } else if card.isFaceUp {
                card.turnFaceDown(true)
            } else {
                card.turnFaceUp(true)
            }
            model.transmit()
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
        if !card.isPrivate && !model.thisPlayersTurn {
            Logger.log("Public card cannot be dragged when not the player's turn")
        }
        if let box = card.box, !box.mayBeModified {
            box.mayNotModify()
            return
        }
        if recognizer.state == .began {
            let dragSet = findDragSet(card)
            bringSubviewToFront(card)
            dragSet.forEach() {
                bringSubviewToFront($0)
            }
            card.dragSet = dragSet
        }
        // In any active drag state we move all the cards in the drag set
        let translation = recognizer.translation(in: self)
        // We allow the drag as long as the actual card is in the playing area and, if the player is not the active player,
        // as long as no part of it is in the public area.  We don't check the other cards, which may leave them off the screen,
        // although when the drag ends they will be adjusted individually.
        let primaryNewFrame = CGRect(origin: card.frame.origin + translation, size: card.frame.size)
        if bounds.contains(primaryNewFrame) &&
                (model.thisPlayersTurn || primaryNewFrame.minY > publicArea.maxY - privateAreaCardOverlap) {
            for draggedCard in card.dragSet {
                let newFrame = CGRect(origin: draggedCard.frame.origin + translation, size: card.frame.size)
                draggedCard.frame = newFrame
                // Mark card public or private
                draggedCard.isPrivate = !publicArea.contains(draggedCard.frame.center)
           }
           recognizer.setTranslation(CGPoint.zero, in: self)
        }
        // At the end, we adjust the cards individually
        if recognizer.state == .ended {
            for draggedCard in card.dragSet {
                // Let a box snap up card if appropriate.  If the card is snapped and the box that snapped it
                // has the autoYield property, then the turn is yielded.
                let rejectedDecks = draggedCard.maybeBeSnapped(boxViews)
                if rejectedDecks.count > 0 {
                    // Make sure an unsnapped card isn't covering too much of a rejected deck
                    unhideDeck(draggedCard, rejectedDecks)
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
            }
            refreshBoxCounts()
            model.transmit()
            setCanDeal()
        }
    }
    
    // Function to set the observable canDeal flag
    func setCanDeal() {
        let cards = deck?.cards.count ?? 0
        gameHandle.canDeal = cards > 1 && dealingAreaClear
    }
 
    // Function to perform a deal
    func deal(hands: Int, cards: Int, kind: TargetKind, from box: GridBox) {
        let step = dealingArea.width / hands
        let start = (step - cardSize.width) / 2
        var origin = CGPoint(x: dealingArea.minX + start, y: dealingArea.minY)
        var dealt = [GridBox]()
        for i in 0..<hands {
            let hand = GridBox(origin: origin, size: box.snapFrame.size, host: self)
            hand.kind = kind.boxKind
            hand.owner = kind.isOwned ? i : GridBox.Unowned
            dealt.append(hand)
            origin.x += step
            addSubview(hand)
            hand.name = kind.isOwned ? model.getPlayer(index: i) : "\(i)"
        }
        var animations = [()->Void]()
        for _ in 0..<cards {
            for hand in dealt {
                animations.append(makeOneCardDealFunction(hand, from: box))
            }
        }
        runAnimationSequence(animations) {
            if kind == .Piles {
                for hand in dealt {
                    hand.removeFromSuperview()
                }
            }
            self.model.transmit()
        }
    }

    // Make an animation function for dealing single card to a specific hand
    private func makeOneCardDealFunction(_ hand: GridBox, from: GridBox) -> ()->Void {
        func once() {
            UIView.animate(withDuration: DealCardDuration) {
                hand.snapUp(from.cards[0])
                hand.refreshCount()
                from.refreshCount()
            }
        }
        return once
    }


    // Supply encoded form of the state of the view on request from the game handle
    func encodeState(duringSetup: Bool) -> [UInt8] {
        let encoder = CBOREncoder()
        let playingState = PlayingState(self)
        if duringSetup {
            playingState.addSetupInfo(deckType: gameHandle.deckType, hasHands: gameHandle.hasHands)
                 }
        do {
            return try [UInt8](encoder.encode(playingState))
        } catch {
            Logger.logFatalError("Error while encoding state: \(error)")
        }
    }
    
    // Accept new game state
    func newPlayingState(_ data: [UInt8]) -> Error? {
        let decoder = CBORDecoder()
        let newState: PlayingState
        do {
            newState = try decoder.decode(PlayingState.self, from: Data(data))
        } catch {
            return error
        }
        doLayoutFromState(newState)
        return nil
    }

    // Respond to long press.  A long press within a GridBox brings up the GridBoxMenu dialog to perform various actions
    // on the gridbox.  A long press that is not within any GridBox is interpreted as a request to create a new GridBox.
    // This might succeed or fail.  Once it's determined that it will succeed, the NewGridBoxMenu is brought up to prepare
    // the attributes of the GridBox.  We assume that GridBoxes do not overlap, so the long press cannot be within more than
    // one GridBox.
    @objc func longPressDetected(_ recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .ended {
            let location = recognizer.location(in: self)
            if let box = boxViews.first(where:  { $0.frame.contains(location) }) {
                if box.mayBeModified {
                    gameHandle.boxMenu(box)
                } else {
                    box.mayNotModify()
                }
            } else if publicArea.contains(location ){
                attemptNewGridBox(location)
            } else {
                // Long press in the private area brings up the card grouping dislog
                gameHandle.showGroupingToggle = true
            }
        }
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
    
    // Perform the "take hand" function
    func takeHand(_ box: GridBox) {
        // Calculate the placement points in the private area
        let lastX = bounds.width - cardSize.width - border
        var currentX = bounds.minX + border
        let step = (lastX - currentX) / (box.cards.count - 1)
        //Logger.log("currentX=\(currentX), lastX=\(lastX), step=\(step)")
        let fixedY = bounds.maxY - cardSize.height - border
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
                    self.bringSubviewToFront(card)
                })
            })
            currentX += step
        }
        // Move the cards with animation
        runAnimationSequence(animations) {
            // Delete the box
            box.removeFromSuperview()
            self.model.transmit()
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
        model.displayError(BadGridBoxMessage)
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

    // Ensure that every card gets a gesture recognizer, but only once.
    private func addCardGestureRecognizers() {
        Logger.log("adding gesture recognizers to cards")
        Logger.log("there are \(cards.count) cards")
        for card in cards {
            if let recognizers = card.gestureRecognizers, recognizers.count > 0 {
                continue
            }
            let gestureRecognizer = TouchTapAndDragRecognizer(target: self, onDrag: #selector(dragging), onTouch: nil, onTap: cardTapped)
            card.addGestureRecognizer(gestureRecognizer)
        }
    }
    
    // Set a new deck type
    func newDeckType(_ deckType: PlayingDeckTemplate) {
        cards = sourceDeck.makePlayingDeck(deckType)
        addCardGestureRecognizers()
        newShuffle()
        model.transmit()
    }

    // Place a new GridBox into the playingArea after determining that it fits
    // Note: the GridBox should still be modifiable at this point since it is newly created.
    private func placeNewGridBox(_ gridBox: GridBox) {
        addSubview(gridBox)
        sendSubviewToBack(gridBox)
        gridBox.maybeSnapUp(cardViews)
        gridBox.refreshCount()
        if gridBox.name == nil {
            if gridBox.mayBeModified {
                gameHandle.modifyBox(gridBox)
            } else {
                gridBox.mayNotModify()
            }
        }
        setCanDeal()
    }

    // Reset the playing state (called from gameHandle.reset() as appropriate)
    func reset() {
        // Clean up former game
        setSceneGeometry(.all)
        // Shuffle cards
        newShuffle()
    }

    // Refresh the box counts in all GridBoxes
    private func refreshBoxCounts() {
        boxViews.forEach { $0.refreshCount() }
    }

    // Remove all Card and GridBox subviews (including cards in the hand area) from the playing area.
    // We do this when doing a complete layout (not in response to a received GameState, which typically only affects public cards).
    private func removeAllCardsAndBoxes() {
        for subview in subviews {
            if subview is Card || subview is GridBox {
                subview.removeFromSuperview()
            }
        }
    }

    // Remove "public" Card and GridBox subviews from the playing area (leaving cards that are in the hand area).
    // We do this when receiving a new GameState, which will include public cards only.
    private func removePublicCardsAndBoxes() {
        for subview in subviews {
            if subview is GridBox || (subview is Card && publicArea.contains(subview.center)) {
                subview.removeFromSuperview()
            }
        }
    }

    // Called when the deck type or hand area setting changes.  
    // Does the initial setup for that combination of decktype and hand area.
    // Returns self for convenient chaining in previews
    @discardableResult
    func newShuffle() -> PlayingSurface {
        Logger.log("Request for newShuffle (deck change?)")
        setupPublicArea()
        removeAllCardsAndBoxes()
        shuffleAndPlace()
        return self
    }

    // Set up the public area and the hand area marker based on the current settings
    func setupPublicArea(_ transmit: Bool = false) {
        if gameHandle.hasHands {
            Logger.log("Setting up public area and private hands area")
            Logger.log("PlayingSurface bounds are \(bounds)")
            publicArea = bounds.inset(by: UIEdgeInsets(top: 0, left: 0, bottom: cardSize.height * HandAreaExpansion, right: 0))
            Logger.log("Public area is \(publicArea ?? CGRect.zero)")
            place(handAreaMarker, publicArea.minX, publicArea.maxY, publicArea.width, border)
            Logger.log("Hand area marker frame is \(handAreaMarker.frame)")
            unhide(handAreaMarker)
        } else {
            Logger.log("Setting up public area with no private hands area")
            publicArea = bounds
            hide(handAreaMarker)
        }
        if transmit {
            model.transmit()
        }
    }

    // Restore a saved game state.  Note that saved game states must include setup info.
    func restoreGameState(_ gameState: PlayingState) {
        guard let setup = gameState.setup else { Logger.logFatalError("game state saved without setup") }
        gameHandle.deckType = setup.deckType
        gameHandle.hasHands = setup.hasHands
        cards = sourceDeck.makePlayingDeck(gameHandle.deckType)
        addCardGestureRecognizers()
        setupPublicArea()
        removePublicCardsAndBoxes()
        // Randomize the cards in the restored state (leaving grid boxes alone)
        var newIndices = shuffle(Array<Int>(0..<gameState.cards.count))
        for card in gameState.cards {
            card.index = newIndices.removeFirst()
        }
        doLayoutFromState(gameState)
        model.transmit()
    }


    // Shuffle cards and form deck.  Add a GridBox to hold the deck and place everything on the playingArea
    private func shuffleAndPlace() {
        Logger.log("Shuffling and placing \(self.cards.count) cards")
        let cards = shuffle(self.cards)
        let deckOrigin = CGPoint(x: cardSize.width, y: cardSize.height)
        cards.forEach { card in
            card.turnFaceDown()
            card.frame = CGRect(origin: deckOrigin, size: cardSize)
            addSubview(card)
        }
        let deckBox = GridBox(center: cards[0].center, size: cardSize, host: self)
        deckBox.name = MainDeckName
        deckBox.kind = .Deck
        placeNewGridBox(deckBox)
    }
}
