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
import AuerbachLook

// A dialog view for actions centered on a GridBox (shows as popover)
struct GridBoxMenu: View {
    @Environment(AnyCardsGameHandle.self) var gameHandle
    @Environment(UnigameModel<AnyCardsGameHandle>.self) var model
    @Environment(\.dismiss) var dismiss

    var surface: PlayingSurface {
        gameHandle.playingSurface
    }
    
    var box: GridBox {
        if let ans = gameHandle.box {
            return ans
        }
        Logger.logFatalError("GridBoxMenu presented with no subject GridBox")
    }

    // Use this function to dismiss the popup when state has been modified
    private func done() {
        dismiss()
        model.transmit()
    }

    var body: some View {
        VStack {
            Button {
                surface.takeHand(box)
                done()
            } label: {
                Label("Take Hand", systemImage: "hand.wave")
                    .frame(maxWidth: .infinity)
            }
            .disabled(box.kind != .Hand || !gameHandle.hasHands)
            Button {
                switch box.kind {
                case .Discard, .DiscardYield:
                    box.kind = .Deck
                case .Deck:
                    box.kind = .Discard
                case .General, .Hand:
                    break // should be ruled out by hiding the control
                }
                done()
            } label: {
                Label("Turn Over", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!box.kind.canTurnOver)
            Button {
                var cards = box.cards
                cards.forEach() { $0.removeFromSuperview() }
                cards = shuffle(cards)
                cards.forEach() { surface.addSubview($0) }
                done()
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
            }
            Button {
                gameHandle.dealDialog(box)
                dismiss()
            } label: {
                Label("Deal", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!box.canDeal)
            Button {
                gameHandle.showModifyBoxMenu = true
                dismiss()
            } label: {
                Label("Modify", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            Button {
                box.removeFromSuperview()
                surface.setCanDeal()
                done()
            } label: {
                Label("Delete", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
        }
        .fixedSize()
        .buttonStyle(.borderedProminent)
    }
}

fileprivate func testSurface() -> PlayingSurface {
    let ans = PlayingSurface().initializeView().newShuffle()
    ans.gameHandle.box = ans.deck
    return ans
}

#Preview {
    let surface = testSurface()
    GridBoxMenu()
        .environment(surface.gameHandle)
        .environment(surface.model)
}
