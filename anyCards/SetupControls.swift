//
//  SetupControls.swift
//  anyCards
//
//  Created by Josh Auerbach on 11/5/24.
//

import SwiftUI
import unigame

// Controls for setting up the game (to be shown in the setup view above the playing surface, which can also be modified during setup)
struct SetupControls: View {
    @Environment(UnigameModel.self) var model
    @Environment(AnyCardsGameHandle.self) var gameHandle
    
    @State private var currentSetup: String? = savedSetups.first?.0
    @State private var showDealDialog: Bool = false
    
    var body: some View {
        @Bindable var gameHandle = gameHandle
        VStack {
            HStack {
                VStack {
                    Text("Deck Type").bold()
                    Picker("Deck Type", selection: $gameHandle.deckType) {
                        ForEach(Decks.available) { deck in
                            Text(deck.displayName).tag(deck)
                        }
                    }
                }
                Spacer()
                Toggle("Hand area", isOn: $gameHandle.hasHands)
                    .fixedSize()
                if currentSetup != nil {
                    Spacer()
                    VStack {
                        Text("Saved Setups").bold()
                        Picker("Saved Setups", selection: $currentSetup) {
                            ForEach(savedSetups.setupNames, id: \.self) { setup in
                                Text(setup).tag(setup)
                            }
                        }
                    }
                }
            }
            HStack {
                Button("Deal", systemImage: "rectangle.portrait.and.arrow.right") {
                    // TODO open the deal dialog here
                }.buttonStyle(.borderedProminent)
                Spacer()
                Button("Save", systemImage: "square.and.arrow.down.fill") {
                    // TODO save the current setup here
                }.buttonStyle(.borderedProminent)
                Spacer()
                Button("Restore", systemImage: "square.and.arrow.up.fill") {
                    // TODO use the saved setup from the picker
                }.buttonStyle(.borderedProminent)
                    .disabled(currentSetup == nil)
                Spacer()
                Button("Reset", systemImage: "clear") {
                    // TODO Perform reset here
                }.buttonStyle(.borderedProminent)
            }
        }.padding().border(.black, width: 2)

    }
}

#Preview {
    let handle = AnyCardsGameHandle()
    SetupControls()
        .environment(UnigameModel(gameHandle: handle))
        .environment(handle)
}
