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

// TODO this should handle the main playing view for AnyCards
// Perhaps this is not SwiftUI View but rather an evolution of the old VIewController wrapped
// in UIViewRepresentable or something like that.
struct AnyCardsPlaying: UIViewRepresentable {
    typealias UIViewType = PlayingView

    @Environment(UnigameModel.self) var model

    func makeUIView(context: Context) -> PlayingView {
        let gameHandle = model.gameHandle as! AnyCardsGameHandle
        if let playingView = gameHandle.mainPlayingView {
            return playingView
        }
        let playingView = PlayingView(model)
        gameHandle.mainPlayingView = playingView
        return playingView
    }
    func updateUIView(_ uiView: PlayingView, context: Context) {
        uiView.update()
    }
}

#Preview {
    AnyCardsPlaying()
}
