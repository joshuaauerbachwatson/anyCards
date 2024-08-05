//
//  ChatController.swift
//  anyCards
//
//  Created by Josh Auerbach on 4/19/24.
//

import UIKit

// UIViewController for showing the chat transcript and sending chat messages.
// TODO on tablets this perhaps should not use .fullScreen presentation style.  But, full screen is probably
// needed for phones and is ok to get started with in general.
class ChatController : UIViewController, UITextFieldDelegate {
    let input = UITextField()
    let send = UIButton()
    let done = UIButton()
    let messages = UITextView()
    let communicator: Communicator
    
    init(_ messages: String, communicator: Communicator) {
        self.communicator = communicator
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = UIModalPresentationStyle.fullScreen
        self.messages.font = getTextFont()
        self.messages.text = messages
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        configureTextField(input, UIColor.systemBackground, parent: view)
        input.delegate = self
        input.textAlignment = .left
        configureButton(send, title: SendTitle, target: self, action: #selector(sendTouched), parent: view)
        configureButton(done, title: DoneTitle, target: self, action: #selector(doneTouched), parent: view)
        messages.isEditable = false
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
        input.becomeFirstResponder()
    }
    
    @objc func sendTouched() {
        guard let message = input.text else {
            return
        }
        communicator.sendChatMsg(message)
        input.text = nil
    }
    
    @objc func doneTouched() {
        Logger.logDismiss(self, host: (presentingViewController ?? self), animated: true)
    }
    
    func updateTranscript(_ messages: String) {
        self.messages.text = messages
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        sendTouched()
    }
}
