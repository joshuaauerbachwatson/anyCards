//
//  SavedSetupsView.swift
//  anyCards
//
//  Created by Josh Auerbach on 11/12/24.
//

import SwiftUI
import AuerbachLook

struct SavedSetupsView: View {
    @Environment(AnyCardsGameHandle.self) var gameHandle
    @State private var currentSetup: String? = nil
    @State private var showingAlert: Bool = false
    @State private var overwriteError: Bool = false
    @State private var newSetupName = ""

    var body: some View {
        HStack {
            Spacer()
            Text("Saved Setups:").bold()
            Spacer()
            Picker("Saved Setup", selection: $currentSetup) {
                ForEach(gameHandle.savedSetups.setupNames, id: \.self) { setup in
                    Text(setup).tag(setup)
                }
            }
            Spacer()
            Button("Load", systemImage: "square.and.arrow.up.fill") {
                guard let name = currentSetup,
                      let state = gameHandle.savedSetups.setups[name] else {
                    Logger.log("Load button should have been disabled with no currentSetup")
                    return
                }
                gameHandle.playingSurface.restoreGameState(state)
            }
            .disabled(currentSetup == nil)
            Spacer()
            Button("Delete", systemImage: "trash") {
                guard let name = currentSetup else {
                    Logger.log("Delete button should have been disabled with no currentSetup")
                    return
                }
                gameHandle.savedSetups.remove(name)
                currentSetup = gameHandle.savedSetups.first?.0
            }
            .disabled(currentSetup == nil)
            .foregroundStyle(.red)
            Spacer()
            Button("Save New", systemImage: "plus") {
                newSetupName = ""
                showingAlert = true
            }
            .alert("Enter name for saved setup", isPresented: $showingAlert) {
                TextField("Enter name", text: $newSetupName)
                Button("Save") {
                    let state = PlayingState(gameHandle.playingSurface)
                    state.addSetupInfo(deckType: gameHandle.deckType, hasHands: gameHandle.hasHands)
                    if !gameHandle.savedSetups.storeEntry(newSetupName, state, false) {
                        overwriteError = true
                    }
                }
            }
            .alert("Name in use", isPresented: $overwriteError) {  }
            Spacer()
        }
    }
}

#Preview {
    SavedSetupsView()
}
