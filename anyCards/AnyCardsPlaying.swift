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

// The playing view for AnyCards uses UIViewRepresentable to incorporate code from
// the older (UIKit) version of AnyCards.
struct PlayingSurfaceWrapper: UIViewRepresentable {
    typealias UIViewType = PlayingSurface

    @Environment(AnyCardsGameHandle.self) var gameHandle

    func makeUIView(context: Context) -> PlayingSurface {
        gameHandle.playingSurface.initializeView()
        return gameHandle.playingSurface
    }
    func updateUIView(_ uiView: PlayingSurface, context: Context) {
        uiView.update(context)
    }
}

struct AnyCardsPlaying: View {
    @Environment(AnyCardsGameHandle.self) var gameHandle
    
    var box: GridBox {
        if let ans = gameHandle.box {
            return ans
        }
        Logger.logFatalError("GameHandle.box requested in context where it is nil")
    }
    
    var body: some View {
        @Bindable var handle = gameHandle
        GeometryReader { metrics in
            VStack {
                let portraitRatio = CGSize(width: 1024, height: 1322)
                let landscapeRatio = CGSize(width: 1366, height: 980)
                let aspectRatio = metrics.size.landscape ? landscapeRatio : portraitRatio
                PlayingSurfaceWrapper()
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .popover(isPresented: $handle.showGridBoxMenu,
                             attachmentAnchor: .point(handle.boxAnchor)) {
                        GridBoxMenu()
                    }
                    .popover(isPresented: $handle.showDealDialog,
                             attachmentAnchor: .point(gameHandle.boxAnchor)) {
                        DealDialog(box: box, hasHands: gameHandle.hasHands)
                    }
                   .popover(isPresented: $handle.showModifyBoxMenu,
                             attachmentAnchor: .point(gameHandle.boxAnchor)) {
                        ModifyBoxMenu()
                    }
            }
        }
    }
}

#Preview {
    let surface = PlayingSurface()
    AnyCardsPlaying()
        .environment(surface.gameHandle)
        .environment(surface.model)
}
