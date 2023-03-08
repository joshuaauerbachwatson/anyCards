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
import WebKit
import MessageUI

// Controller for a full screen modal view with a web view and a button to dismiss it.  Used to display help texts.

class HelpController: UIViewController {
    /* The extension of the help resources */
    let HelpExt = "html"

    let resource : String
    let returnText : String
    let returnButton = UIButton()
    var webView : WKWebView!  // Delayed init (viewDidLoad)

    // Arguments are 1.  The resource name of the help page to display, 2. Text to use in the return button,
    // 3. (optional) a WKUserContentController for the WkWebView used to display the help, allowing hotlinks
    // in the help to communicate to the app.
    init(_ resource: String, _ returnText: String) {
        self.resource = resource
        self.returnText = returnText
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = UIModalPresentationStyle.fullScreen
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Set up view
    override func viewDidLoad() {
        // Background
        view.backgroundColor = HelpViewBackground

        // Return button
        returnButton.setTitle(returnText, for: .normal)
        returnButton.titleLabel?.adjustsFontSizeToFitWidth = true
        returnButton.backgroundColor = ButtonBackground
        returnButton.addTarget(self, action: #selector(returnTouched), for: .touchUpInside)
        returnButton.layer.cornerRadius = 8
        self.view.addSubview(returnButton)

        // Web view
        let config = WKWebViewConfiguration()
        let contentCtl = WKUserContentController()
        contentCtl.add(self, name: SendFeedback)
        // TODO probably want "Tips" as well
        config.userContentController = contentCtl
        webView = WKWebView(frame: CGRect.zero, configuration: config) // Satisfies delayed init
        webView.backgroundColor = HelpTextBackground
        view.addSubview(webView)
        let path = Bundle.main.url(forResource: resource, withExtension: HelpExt)!
        webView.load(URLRequest(url: path))
    }

    // Allow view to be rotated.   We will redo the layout each time while preserving all controller state.
    open override var shouldAutorotate: Bool {
        get {
            return true
        }
    }

    // Respond to request to do new layout
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        doLayout()
    }

    // Support all orientations.   Can layout for portrait or landscape, with tablet or phone type dimensions
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        get {
            return .all
        }
    }

    // Calculate frames for all the subviews based on orientation
    func doLayout() {
        let returnY = safeAreaOf(view).minY + border
        let returnX = view.bounds.width / CGFloat(2) - ReturnLabelWidth / 2
        returnButton.frame = CGRect(x: returnX, y: returnY, width: ReturnLabelWidth, height: FixedLabelHeight)
        let webY = returnButton.frame.maxY + border
        let webX = border
        let webWidth = view.bounds.width - 2 * border
        let webHeight = view.bounds.maxY - border - webY
        webView.frame = CGRect(x: webX, y: webY, width: webWidth, height: webHeight)
    }

    // Dismiss view when return button touched
    @objc func returnTouched() {
        Logger.logDismiss(self, host: (presentingViewController ?? self), animated: true)
    }
}

// Conform to WKScriptMessageHandler and MFMailComposeViewControllerDelegate
extension HelpController : WKScriptMessageHandler, MFMailComposeViewControllerDelegate {
    // Dispatch "scripts" to internal functions
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Handle scripts
        switch message.name {
            // TODO probably want to support "Tips" here also
        case SendFeedback:
            if !Feedback.send(FeedbackEmail, self) {
                bummer(title: NoEmailTitle, message: NoEmailMessage, host: self)
            }
        default:
            Logger.log("userContentController called with unexpected handler name: " + message.name)
        }
    }

    // Implement the delegate function to dismiss the mail client
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        Logger.logDismiss(controller, host: self, animated: false)
    }
}
