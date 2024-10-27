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

// TODO this should handle the main playing view for AnyCards
// Perhaps this is not SwiftUI View but rather an evolution of the old VIewController wrapped
// in UIViewRepresentable or something like that.
struct AnyCardsPlaying: UIViewRepresentable {
    typealias UIViewType = PlayingView
    func makeUIView(context: Context) -> PlayingView {
        return PlayingView(context)
    }
    func updateUIView(_ uiView: PlayingView, context: Context) {
        // TODO
    }
}

// TODO populate this class with relevant material from the old ViewController.view
class PlayingView: UIView {
    let context: UIViewRepresentableContext<AnyCardsPlaying>
    init(_ context: UIViewRepresentableContext<AnyCardsPlaying>) {
        self.context = context
        super.init(frame: CGRect    .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#Preview {
    AnyCardsPlaying()
}
