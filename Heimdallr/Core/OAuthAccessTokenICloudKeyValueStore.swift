//
//  OAuthAccessTokenICloudKeyValueStore.swift
//  Heimdallr
//
//  Created by Fabio Milano on 05/06/16.
//  Copyright © 2016 B264 GmbH. All rights reserved.
//

import Foundation

/// A persistent iCloud Key Value based access token store.
@objc public class OAuthAccessTokenICloudKeyValueStore: NSObject, OAuthAccessTokenStore {
    private let store = NSUbiquitousKeyValueStore.defaultStore()
    private let service: String
    
    public init(service: String = "de.rheinfabrik.heimdallr.oauth") {
        self.service = service
    }
    
    public func storeAccessToken(accessToken: OAuthAccessToken?) {
        if let accessToken = accessToken {
            var accessTokenDictionaryRepresentation = [String: String]()
    
            accessTokenDictionaryRepresentation.updateValue(accessToken.accessToken, forKey: "access_token")
            accessTokenDictionaryRepresentation.updateValue(accessToken.tokenType, forKey: "token_type")
            
            if let refreshToken = accessToken.refreshToken {
                accessTokenDictionaryRepresentation.updateValue(refreshToken, forKey: "refresh_token")
            }
            
            accessTokenDictionaryRepresentation.updateValue(accessToken.accessToken, forKey: "access_token")
        
            if let expiresAt = accessToken.expiresAt {
                accessTokenDictionaryRepresentation.updateValue(expiresAt.timeIntervalSince1970.description, forKey: "expires_at")
            }
            
            store.setDictionary(accessTokenDictionaryRepresentation, forKey: service)
        }
        
        store.synchronize()
    }
    
    public func retrieveAccessToken() -> OAuthAccessToken? {
        if let accessTokenDictionaryRepresentation = store.dictionaryForKey(service) {
            let accessToken = accessTokenDictionaryRepresentation["access_token"] as? String
            let tokenType = accessTokenDictionaryRepresentation["token_type"] as? String
            let refreshToken = accessTokenDictionaryRepresentation["refresh_token"] as? String
            let expiresAtString = accessTokenDictionaryRepresentation["expires_at"] as? String
                
            let expiresAt = expiresAtString.flatMap { description in
                return Double(description).flatMap { expiresAtInSeconds in
                    return NSDate(timeIntervalSince1970: expiresAtInSeconds)
                }
            }
            
            if let accessToken = accessToken, tokenType = tokenType {
                return OAuthAccessToken(accessToken: accessToken, tokenType: tokenType, expiresAt: expiresAt, refreshToken: refreshToken)
            }
        }
        
        return nil
    }
}