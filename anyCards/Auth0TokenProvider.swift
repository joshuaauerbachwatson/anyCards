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
final class Auth0TokenProvider: TokenProvider {
    func login() async -> (unigame.Credentials?, LocalizedError?) {
        do {
            let auth0creds = try await Auth0.webAuth().useHTTPS().audience("https://unigame.com").start()
            let credentials = unigame.Credentials(accessToken: auth0creds.accessToken, expiresIn: auth0creds.expiresIn)
            return (credentials, nil)
        } catch {
            let error = error as? WebAuthError ?? WebAuthError.unknown
            return (nil, error)
        }
    }
}
