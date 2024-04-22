//
//  ChatController.swift
//  anyCards
//
//  Created by Josh Auerbach on 4/19/24.
//

import UIKit

class ChatController : UIViewController, UITextFieldDelegate {
    let input = UITextField()
    let send = UIButton()
    let done = UIButton()
    let messages = UITextView()
    var channel: ChatChannel!
    
    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = UIModalPresentationStyle.fullScreen
        channel = ChatChannel(messages)
        channel.connect()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        configureTextField(input, .white, parent: view)
        input.delegate = self
        input.textAlignment = .left
        configureButton(send, title: SendTitle, target: self, action: #selector(sendTouched), parent: view)
        configureButton(done, title: DoneTitle, target: self, action: #selector(doneTouched), parent: view)
        messages.font = getTextFont()
        messages.text = ""
        messages.isEditable = false
        messages.backgroundColor = .white
        view.addSubview(messages)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let safeArea = safeAreaOf(view)
        let startX = safeArea.minX + border
        let startY = safeArea.minY + border
        let fullWidth = safeArea.width - 2 * border
        let halfWidth = (fullWidth - border) / 2
        let controlHeight = ControlHeightRatio * safeArea.height
        place(input, startX, startY, fullWidth, controlHeight)
        place(send, startX, below(input), halfWidth, controlHeight)
        place(done, after(send), below(input), halfWidth, controlHeight)
        let messagesHeight = safeArea.maxY - done.frame.maxY - border
        place(messages, startX, below(done), fullWidth, messagesHeight)
    }
    
    @objc func sendTouched() {
        guard let message = input.text else {
            return
        }
        channel.send(message)
        input.text = nil
    }
    
    @objc func doneTouched() {
        Logger.logDismiss(self, host: (presentingViewController ?? self), animated: true)
        channel.disconnect()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        sendTouched()
    }
}

// Manage the websocket connection for the chat
class ChatChannel {
    private var webSocketTask: URLSessionWebSocketTask?
    let messages: UITextView
    
    init(_ messages: UITextView) {
        self.messages = messages
    }
    
    func connect() {
        guard webSocketTask == nil else {
            return
        }

        let url = URL(string: "wss://unigame-befsi.ondigitalocean.app/websocket/ws")!
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.receive(completionHandler: onReceive)
        webSocketTask?.resume()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
    }
    
    // MARK: - Sending / recieving
    private func onReceive(incoming: Result<URLSessionWebSocketTask.Message, Error>) {
        webSocketTask?.receive(completionHandler: onReceive)

        if case .success(let message) = incoming {
            onMessage(message: message)
        }
        else if case .failure(let error) = incoming {
            let nserror = error as NSError
            if nserror.domain == NSPOSIXErrorDomain && nserror.code == POSIXError.ENOTCONN.rawValue {
                return
            }
            Logger.logFatalError("Error receiving message: \(error)")
        }
    }
    
    private func onMessage(message: URLSessionWebSocketTask.Message) {
        let toAppend: String
        switch message {
        case .data(let data):
            toAppend = String(decoding: data, as: UTF8.self)
        case .string(let text):
            toAppend = text
        @unknown default:
            Logger.logFatalError("Unanticipated incoming message type")
        }
        DispatchQueue.main.async {
            var transcript = self.messages.text ?? ""
            if transcript.count > 0 {
                transcript += "\n"
            }
            transcript += toAppend
            self.messages.text = transcript
            let range = NSRange(location: transcript.count-1, length: 1)
            self.messages.scrollRangeToVisible(range)
        }
    }
    
    func send(_ text: String) {
        let toSend = "[\(OptionSettings.instance.userName)] \(text)"
        let message = URLSessionWebSocketTask.Message.string(toSend)
        webSocketTask?.send(message) { error in
            if let error = error {
                Logger.logFatalError("Error sending message: \(error)")
            }
        }
    }
    
    deinit {
        disconnect()
    }

}
