//
//  CredentialStore.swift
//  anyCards
//
//  Created by Josh Auerbach on 4/24/24.
//

import Foundation
import Auth0
import AuerbachLook
import unigame

// An Auth0 implementation of unigame TokenProvider
class Auth0TokenProvider: TokenProvider {
    func login(_ handler: @escaping (unigame.Credentials?, LocalizedError?)->()) {
        Auth0.webAuth().useHTTPS().audience("https://unigame.com").start { result in
            switch result {
            case .success(let auth0creds):
                let credentials = unigame.Credentials(accessToken: auth0creds.accessToken, expiresIn: auth0creds.expiresIn)
                handler(credentials, nil)
            case .failure(let error):
                Logger.log("Login failed with \(error)")
                handler(nil, error)
            }
        }
    }
}
