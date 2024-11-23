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

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all {
        didSet {
            // Based on probably flawed recommendation in https://stackoverflow.com/questions/66037782/swiftui-how-do-i-lock-a-particular-view-in-portrait-mode-whilst-allowing-others
            UIApplication.shared.connectedScenes.forEach { scene in
                if let windowScene = scene as? UIWindowScene {
                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientationLock))
                }
            }
            // The following is deprecated as of iOS 16.  The recommended replacement is an instance method
            // but I don't have a UIViewController instance here.  Since my UIKit code is using UIViewRepresentatble
            // there is no UIViewController instance there, either.
            // UIViewController.attemptRotationToDeviceOrientation()
        }
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?)
            -> UIInterfaceOrientationMask {
        return Self.orientationLock
    }
}
