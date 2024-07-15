//
//  CredentialStore.swift
//  anyCards
//
//  Created by Josh Auerbach on 4/24/24.
//

import Foundation
import Auth0

// Manage Auth0-provided credentials

class CredentialStore {
    private init() {}
    static let instance = CredentialStore()
    
    // Cache the credentials read from disk or obtained via login
    private var _credentials: Auth0.Credentials?

    // Access variable for credentials.  Reads from storage if not cached or if cached value is expired.
    // If there are no credentials in storage (of if stored credentials have expired) returns nil.
    var credentials: Auth0.Credentials? {
        if let result = _credentials, result.expiresIn > Date.now {
            return result
        }
        let storageFile = getDocDirectory().appendingPathComponent(CredentialsFile)
        do {
            let archived = try Data(contentsOf: storageFile)
            Logger.log("credentials loaded from disk")
            let decoder = JSONDecoder()
            let ans = try decoder.decode(Auth0.Credentials.self, from: archived)
            guard ans.expiresIn < Date.now else {
                Logger.log("credentials found but they have expired")
                return nil
            }
            _credentials = ans
            return ans
        } catch {
            Logger.log("Credentials not found on disk")
            return nil
        }
    }
    
    // Perform login iff there are not already valid credentials present.
    // Since the actual log handshake is asynchronous, the processing that requires the credentials
    // should take place in the handler up to the next point where user interaction is required.
    // Errors here do not terminate the app but report the error and leave credentials at nil.
    // The app should still be usable but only in solitaire or "Nearby Only" mode.
    func loginIfNeeded(handler: @escaping (Auth0.Credentials?, Auth0.WebAuthError?)->()) {
        // Test for already present
        if let already = credentials, already.expiresIn > Date.now {
            // Login not needed
            Logger.log("Using credentials already stored")
            handler(already, nil)
            return
        }
        // Do actual login`
        Auth0.webAuth().useHTTPS().audience("https://unigame.com").start { result in
            switch result {
            case .success(let credentials):
                let encoder = JSONEncoder()
                guard let encoded = try? encoder.encode(credentials) else {
                    Logger.logFatalError("Failed to encode Auth0 credentials")
                }
                let credsFile = getDocDirectory().appendingPathComponent(CredentialsFile).path
                FileManager.default.createFile(atPath: credsFile, contents: encoded, attributes: nil)
                self._credentials = credentials
                Logger.log("Credentials successfully saved")
                handler(credentials, nil)
            case .failure(let error):
                Logger.log("Login failed with \(error)")
                handler(nil, error)
            }
        }
    }
}
