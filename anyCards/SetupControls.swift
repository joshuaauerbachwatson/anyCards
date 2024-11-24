//
//  SetupControls.swift
//  anyCards
//
//  Created by Josh Auerbach on 11/5/24.
//

import SwiftUI
import unigame
import AuerbachLook

// Controls for setting up the game (to be shown in the setup view above the playing surface, which can also be modified during setup)
struct SetupControls: View {
    @Environment(UnigameModel.self) var model
    @Environment(AnyCardsGameHandle.self) var gameHandle
    
    var surface: PlayingSurface {
        gameHandle.playingSurface
    }
    
    var deck: GridBox? {
        return surface.deck
    }
    
    var body: some View {
        @Bindable var gameHandle = gameHandle
        VStack {
            HStack {
                Text("Deck Type").bold()
                Picker("Deck Type", selection: $gameHandle.deckType) {
                    ForEach(Decks.available) { deck in
                        Text(deck.displayName).tag(deck)
                    }
                }
            }
            HStack {
                Toggle("Hand area", isOn: $gameHandle.hasHands)
                    .fixedSize()
                Spacer()
                Button("Deal", systemImage: "rectangle.portrait.and.arrow.right") {
                    gameHandle.showDealDialog = true
                }.buttonStyle(.borderedProminent)
                    .popover(isPresented: $gameHandle.showDealDialog) {
                    DealDialog(box: deck!, hasHands: gameHandle.hasHands)
                }.disabled(!surface.canDeal)
                Button("Reset", systemImage: "clear") {
                    surface.newShuffle()
                }.buttonStyle(.borderedProminent)
            }
            SavedSetupsView()
        }

    }
}

#Preview {
    let surface = PlayingSurface().initializeView().newShuffle()    
    SetupControls()
        .environment(surface.model)
        .environment(surface.gameHandle)
}
