//
//  DealDialog.swift
//  anyCards
//
//  Created by Josh Auerbach on 11/8/24.
//

import SwiftUI
import unigame

// Enumeration of possible dealing targets
enum TargetKind : Int, CaseIterable {
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
    @Environment(AnyCardsGameHandle.self) var model
    
    let box: GridBox
    
    @State private var hands: Int = 2
    @State private var cards: Int = 5
    @State private var targetKind: Int = 0
    var targets: String {
        TargetKind(rawValue: targetKind)?.display ?? "Unknown"
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
                    in: 0...TargetKind.allCases.count-1) {
                HStack {
                    Text("Type of groupings:").bold()
                    Spacer()
                    Text("\(targets)")
                }
            }
            // TODO DealButton should be mutually exclusive with Error label
            Button("Deal", systemImage: "rectangle.portrait.and.arrow.right") {
                let kind = TargetKind(rawValue: targetKind) ?? TargetKind.Hands
                model.playingSurface.deal(hands: hands, cards: cards, kind: kind, from: box)
            }.buttonStyle(.borderedProminent)
        }.padding().border(.black, width: 2)
    }
}

#Preview {
    let playingSurface = PlayingSurface()
    DealDialog(box: playingSurface.deck!)
        .environment(playingSurface.gameHandle)
}
