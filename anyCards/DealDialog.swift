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
enum TargetKind : Int, CaseIterable {
    // Hands and Piles cases must be the first two cases respectively
    // since we rely on stepping through the cases and they are the default
    // starting points (depending on whether there is a hand area).
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
    @Environment(\.dismiss) private var dismiss
    
    let box: GridBox
    
    @State private var hands: Int = 2
    @State private var cards: Int = 5
    @State var targetKind: Int
    var targetKindText: String {
        TargetKind(rawValue: targetKind)?.display ?? "Unknown"
    }
    var targetRange: ClosedRange<Int>
    
    init(box: GridBox, hasHands: Bool) {
        self.box = box
        if hasHands {
            targetRange = 0...TargetKind.allCases.count - 1
            targetKind = 0
        } else {
            targetRange = 1...TargetKind.allCases.count - 1
            targetKind = 1
        }
    }
    
    var body: some View {
        VStack {
            Stepper(value: $hands,
                    in: 2...6) {
                HStack {
                    Text("Number of groupings:").bold()
                    Spacer()
                    Text("\(hands)")
                }
            }
            Stepper(value: $cards,
                    in: 2...200) {
                HStack {
                    Text("Cards per grouping:").bold()
                    Spacer()
                    Text("\(cards)")
                }
            }
            Stepper(value: $targetKind,
                    in: targetRange) {
                HStack {
                    Text("Type of groupings:").bold()
                    Spacer()
                    Text("\(targetKindText)")
                }
            }
            if hands * cards > box.cards.count {
                Text("Not enough cards available for this deal")
                    .foregroundStyle(.red)
            } else {
                Button("Deal", systemImage: "rectangle.portrait.and.arrow.right") {
                    let kind = TargetKind(rawValue: targetKind) ?? TargetKind.Hands
                    gameHandle.playingSurface.deal(hands: hands, cards: cards, kind: kind, from: box)
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
}
