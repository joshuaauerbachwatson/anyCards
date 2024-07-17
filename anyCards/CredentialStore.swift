//
//  CredentialStore.swift
//  anyCards
//
//  Created by Josh Auerbach on 4/24/24.
//

import Foundation
import Auth0

// Manage Auth0-provided credentials

// Provide access to the stored expires_in value without alteration during decoding.
// When deserializing Credentials, this expiresIn value is adjusted on the assumption it represents an interval from 'now'
// (as specified by OAuth2) rather than an interval from the Date/Time reference point.  So, we need to re-do that
// with the correct assumption.
struct StoredExpiresIn: Decodable {
    let expires_in: Date
}

class CredentialStore {
    private init() {}
    static let instance = CredentialStore()
    
    // Cache the credentials read from disk or obtained via login
    private var _credentials: Auth0.Credentials?

    // Access variable for credentials.  Reads from storage if not cached or if cached value is expired.
    // If there are no credentials in storage (of if stored credentials have expired) returns nil.
    var credentials: Auth0.Credentials? {
        if let result = _credentials, result.expiresIn > Date.now {
            Logger.log("Using cached credentials")
            return result
        }
        let storageFile = getDocDirectory().appendingPathComponent(CredentialsFile)
        do {
            let archived = try Data(contentsOf: storageFile)
            Logger.log("Credentials loaded from disk")
            let decoder = JSONDecoder()
            let ans = try decoder.decode(Auth0.Credentials.self, from: archived)
            let storedExpiration = try decoder.decode(StoredExpiresIn.self, from: archived)
            Logger.log("Credentials found and decoded.  They expire at \(storedExpiration.expires_in)")
            Logger.log("Date/time now is \(Date.now)")
            guard storedExpiration.expires_in > Date.now else {
                Logger.log("credentials expired")
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
                self._credentials = credentials
                let credsFile = getDocDirectory().appendingPathComponent(CredentialsFile).path
                FileManager.default.createFile(atPath: credsFile, contents: encoded, attributes: nil)
                Logger.log("Credentials successfully saved")
                // Note that the saved expires_in value is reset to be the interval since hte Date reference point,
                // not the interval since "now".  This must be compensated for when re-read.
                handler(credentials, nil)
            case .failure(let error):
                Logger.log("Login failed with \(error)")
                handler(nil, error)
            }
        }
    }
}
