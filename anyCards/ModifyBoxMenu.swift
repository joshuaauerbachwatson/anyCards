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

// A menu that shows when a new GridBox is created or on request from the GridBoxMenu.
// Allows certain GridBox attributes to be changed.
struct ModifyBoxMenu: View {
    @Environment(AnyCardsGameHandle.self) var gameHandle
    @Environment(UnigameModel.self) var model
    @Environment(\.dismiss) var dismiss
    
    @State private var boxName: String = ""
    @State private var boxKind: GridBox.Kind = .General
    @State private var owned: Bool = false
    
    var box: GridBox {
        if let ans = gameHandle.box {
            return ans
        }
        Logger.logFatalError("ModifyBoxMenu presented with no subject GridBox")
    }

    var body: some View {
        VStack {
            HStack {
                Text("Box name:")
                    .font(.headline)
                    .fixedSize()
                TextField("Box name", text: $boxName)
                    .autocorrectionDisabled()
            }
            HStack {
                Text("Box type:").bold()
                Spacer()
                Picker("", selection: $boxKind) {
                    ForEach(GridBox.Kind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
            }
            Toggle("Owned:", isOn: $owned)
            Button {
                Logger.log("Applying changes from ModifyBoxMenu")
                box.name = boxName
                Logger.log("Set name to \(box.name ?? "nil")")
                box.kind = boxKind
                Logger.log("Set kind to \(box.kind)")
                box.owner = owned ? model.thisPlayer : GridBox.Unowned
                Logger.log("Set owner to \(box.owner)")
                dismiss()
                model.transmit()
            } label: {
                Text("Apply Changes")
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .onAppear {
            UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
            boxName = box.name ?? ""
            Logger.log("Box name read as \(boxName)")
            boxKind = box.kind
            Logger.log("Box kind read as \(boxKind)")
            owned = box.owner != GridBox.Unowned
            Logger.log("owned read as \(owned)")
        }.padding()
    }
}

fileprivate func testSurface() -> PlayingSurface {
    let ans = PlayingSurface().initializeView().newShuffle()
    ans.gameHandle.box = ans.deck
    return ans
}

#Preview {
    let surface = testSurface()
    return ModifyBoxMenu()
        .environment(surface.gameHandle)
        .environment(surface.model)
}
