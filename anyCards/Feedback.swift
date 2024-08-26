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
import MessageUI
import AuerbachLook

// Utility to send feedback, possibly including logs
class Feedback {
    // Send feedback.  Return true if mail is enabled on this platform (not a guarantee that mail was sent, since that is actually up to the user)
    // The arguments are the mail destination and a hosting view controller, which much also implement the delegate function.  It is up to the
    // host to dismiss the view.
    static func send(_ dest: String, _ host: UIViewController & MFMailComposeViewControllerDelegate) -> Bool {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = host
            mail.setToRecipients([dest])
            mail.setMessageBody(FeedbackMessageBody, isHTML: true)
            mail.setSubject(FeedbackMessageSubject)
            let logs = Logger.getAllLogIndices()
            if logs.count > 0 {
                addLog(mail, logs[0])
            }
            if logs.count > 1 {
                addLog(mail, logs[1])
            }
            Logger.logPresent(mail, host: host, animated: true)
            return true
        } else {
            return false
        }
    }

    // Add a log to the outgoing email
    private static func addLog(_ mail: MFMailComposeViewController, _ index: Int) {
        let logPath = Logger.makeLogPath(index)
        let url = URL(fileURLWithPath: logPath)
        if let attachmentData = try? Data(contentsOf: url) {
            mail.addAttachmentData(attachmentData, mimeType: "text/plain", fileName: Logger.LogPrefix + String(index))
        } else {
            Logger.log(String(format: "Unable to read data from log with path %@", logPath))
        }
    }
}
