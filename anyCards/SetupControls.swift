//
//  SetupControls.swift
//  anyCards
//
//  Created by Josh Auerbach on 11/5/24.
//

import SwiftUI
import unigame

// Controls for setting up the game (to be shown in the setup view above the playing view)
struct SetupControls: View {
    @Environment(UnigameModel.self) var model
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    SetupControls()
        .environment((UnigameModel(gameHandle: AnyCardsGameHandle())))
}
