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

import SwiftUI
import unigame

// Enumeration of possible dealing targets
enum TargetKind : CaseIterable, Identifiable {
    case Hands, Piles, OwnedDecks, SharedDecks, OwnedDiscards, SharedDiscards
    
    var display: String {
        switch self {
        case .Hands:
            return "Hands"
        case .Piles:
            return "Piles"
        case .OwnedDecks:
            return "Owned Decks"
        case .SharedDecks:
            return "Shared Decks"
        case .OwnedDiscards:
            return "Owned Discards"
        case .SharedDiscards:
            return "Shared Discards"
        }
    }
   
    // Conform to Identifiable to enable Picker use
    var id: String {
        display
    }
    
    var boxKind : GridBox.Kind {
        switch self {
        case .Hands:
            return .Hand
        case .OwnedDecks, .SharedDecks:
            return .Deck
        case .OwnedDiscards, .SharedDiscards:
            return .Discard
        case .Piles:
            return .General
        }
    }
    
    var isOwned: Bool {
        switch self {
        case .OwnedDecks, .OwnedDiscards, .Hands:
            return true
        default:
            return false
        }
    }
}

// A dialog view for performing the deal (shows as popover)
struct DealDialog: View {
    @Environment(AnyCardsGameHandle.self) var gameHandle
    @Environment(UnigameModel.self) var model
    @Environment(\.dismiss) private var dismiss
    
    let box: GridBox
    
    @State private var cards: Int = 5
    @State var targetKind: TargetKind
    let availableKinds: [TargetKind]
    
    init(box: GridBox, hasHands: Bool) {
        self.box = box
        if hasHands {
            availableKinds = TargetKind.allCases
            targetKind = .Hands
        } else {
            availableKinds = [TargetKind](TargetKind.allCases.dropFirst())
            targetKind = .Piles
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("Number of players:")
                    .font(.headline)
                Spacer()
                Text("\(model.numPlayers)")
            }
            Stepper(value: $cards,
                    in: 2...200) {
                HStack {
                    Text("Cards per target:").bold()
                    Spacer()
                    Text("\(cards)")
                }
            }
            HStack {
                Text("Type of target:").bold()
                Spacer()
                Picker("", selection: $targetKind) {
                    ForEach(availableKinds) { kind in
                        Text(kind.display).tag(kind)
                    }
                }
            }
            if model.numPlayers * cards > box.cards.count {
                Text("Not enough cards available for this deal")
                    .foregroundStyle(.red)
            } else {
                Button("Deal", systemImage: "rectangle.portrait.and.arrow.right") {
                    gameHandle.playingSurface.deal(hands: model.numPlayers, cards: cards,
                                                   kind: targetKind, from: box)
                    dismiss()
                }.buttonStyle(.borderedProminent)
            }
        }.padding().border(.black, width: 2)
    }
}

#Preview {
    let playingSurface = PlayingSurface().initializeView().newShuffle()
    DealDialog(box: playingSurface.deck!, hasHands: true)
        .environment(playingSurface.gameHandle)
        .environment(playingSurface.model)
}
