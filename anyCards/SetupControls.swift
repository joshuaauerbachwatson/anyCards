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
    @Environment(AnyCardsGameHandle.self) var gameHandle
    
    var surface: PlayingSurface {
        gameHandle.playingSurface
    }
    
    var deck: GridBox {
        if let ans = surface.deck {
            return ans
        }
        Logger.logFatalError("Logic should have ruled out access to PlayingSurface.deck if absent")
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
                    gameHandle.dealDialog(deck)
                }.buttonStyle(.borderedProminent)
                    .disabled(!gameHandle.canDeal)
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
