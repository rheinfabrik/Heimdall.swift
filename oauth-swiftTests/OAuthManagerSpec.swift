//
//  OAuthManagerSpec.swift
//  oauth-swift
//
//  Created by Felix Jendrusch on 2/10/15.
//  Copyright (c) 2015 B264 GmbH. All rights reserved.
//

import Quick
import Nimble
import AeroGearHttpStub

import LlamaKit
import oauth_swift

public class MockStorage: OAuthAccessTokenStorage {
    
    public var storeAccessTokenCalled: Bool = false
    public var mockedAccessToken: OAuthAccessToken? = nil
    
    private var storedAccessToken: OAuthAccessToken? = nil
    
    public func storeAccessToken(accessToken: OAuthAccessToken){
        storeAccessTokenCalled = true
        storedAccessToken = accessToken
    }
    
    public func retrieveAccessToken() -> OAuthAccessToken? {
        return mockedAccessToken ?? storedAccessToken
    }
    
}

class OAuthManagerSpec: QuickSpec {
    let bundle = NSBundle(forClass: OAuthManagerSpec.self)

    override func spec() {
        var manager: OAuthManager!
        var storage: MockStorage!

        beforeEach {
            storage = MockStorage()
            manager = OAuthManager(tokenURL: NSURL(string: "http://rheinfabrik.de")!, clientID: "spec", tokenStorage: storage)
        }
        
        describe("-init") {
            
            context("when a token is saved in the storage") {
                
                it("loads the token from the token storage") {
                    storage.mockedAccessToken = OAuthAccessToken(token: "foo", type: "bar", expiresAt: nil, refreshToken: nil)
                    expect(manager.hasAccessToken).to(beTrue())
                }
                
            }
            
        }
        
        describe("-authorize") {
            var result: Result<Void, NSError>?

            afterEach {
                result = nil
            }

            context("with a valid response") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "authorize-valid.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        manager.authorize("username", password: "password") { result = $0; done() }
                    }
                }

                afterEach {
                    StubsManager.removeAllStubs()
                }

                it("succeeds") {
                    expect(result?.isSuccess).to(beTrue())
                }

                it("sets the access token") {
                    expect(storage.storeAccessTokenCalled).to(beTrue())
                }
                
                it("stores the access token in the token storage") {
                    expect(storage.storeAccessTokenCalled).to(beTrue())
                }
                
            }

            context("with an invalid response") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "authorize-invalid.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        manager.authorize("username", password: "password") { result = $0; done() }
                    }
                }

                afterEach {
                    StubsManager.removeAllStubs()
                }

                it("fails") {
                    expect(result?.isSuccess).to(beFalse())
                }

                it("fails with the correct error code") {
                    expect(result?.error?.code).to(equal(OAuthManagerErrorInvalidData))
                }

                it("does not set the access token") {
                    expect(manager.hasAccessToken).to(beFalse())
                }
            }

            context("with an invalid response missing a token") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "authorize-invalid-token.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        manager.authorize("username", password: "password") { result = $0; done() }
                    }
                }

                afterEach {
                    StubsManager.removeAllStubs()
                }

                it("fails") {
                    expect(result?.isSuccess).to(beFalse())
                }

                it("fails with the correct error code") {
                    expect(result?.error?.code).to(equal(OAuthManagerErrorInvalidData))
                }

                it("does not set the access token") {
                    expect(manager.hasAccessToken).to(beFalse())
                }
            }

            context("with an invalid response missing a type") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "authorize-invalid-type.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        manager.authorize("username", password: "password") { result = $0; done() }
                    }
                }

                afterEach {
                    StubsManager.removeAllStubs()
                }

                it("fails") {
                    expect(result?.isSuccess).to(beFalse())
                }

                it("fails with the correct error code") {
                    expect(result?.error?.code).to(equal(OAuthManagerErrorInvalidData))
                }

                it("does not set the access token") {
                    expect(manager.hasAccessToken).to(beFalse())
                }
            }
        }

        describe("-requestByAddingAuthorizationToRequest") {
            var request = NSURLRequest(URL: NSURL(string: "http://rheinfabrik.de")!)
            var result: Result<NSURLRequest, NSError>?

            afterEach {
                result = nil
            }

            context("when not authorized") {
                beforeEach {
                    waitUntil { done in
                        manager.requestByAddingAuthorizationToRequest(request) { result = $0; done() }
                    }
                }

                it("fails") {
                    expect(result?.isSuccess).to(beFalse())
                }

                it("fails with the correct error code") {
                    expect(result?.error?.code).to(equal(OAuthManagerErrorNotAuthorized))
                }
            }

            context("when authorized with a still valid access token") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "request-valid.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        manager.authorize("username", password: "password") { _ in done() }
                    }

                    waitUntil { done in
                        manager.requestByAddingAuthorizationToRequest(request) { result = $0; done() }
                    }
                }

                it("succeeds") {
                    expect(result?.isSuccess).to(beTrue())
                }

                it("adds the correct authorization header to the request") {
                    expect(result?.value?.valueForHTTPHeaderField("Authorization")).to(equal("bearer MTQzM2U3YTI3YmQyOWQ5YzQ0NjY4YTZkYjM0MjczYmZhNWI1M2YxM2Y1MjgwYTg3NDk3ZDc4ZGUzM2YxZmJjZQ"))
                }
            }

            context("when authorized with an expired access token and no refresh token") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "request-invalid-norefresh.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        manager.authorize("username", password: "password") { _ in done() }
                    }

                    waitUntil { done in
                        manager.requestByAddingAuthorizationToRequest(request) { result = $0; done() }
                    }
                }

                it("fails") {
                    expect(result?.isSuccess).to(beFalse())
                }

                it("fails with the correct error code") {
                    expect(result?.error?.code).to(equal(OAuthManagerErrorNotAuthorized))
                }
            }

            context("when authorized with an expired access token and a valid refresh token") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in !manager.hasAccessToken }) { request in
                        return StubResponse(filename: "request-invalid.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        manager.authorize("username", password: "password") { _ in done() }
                    }

                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "request-valid.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        manager.requestByAddingAuthorizationToRequest(request) { result = $0; done() }
                    }
                }

                it("succeeds") {
                    expect(result?.isSuccess).to(beTrue())
                }

                it("adds the correct authorization header to the request") {
                    expect(result?.value?.valueForHTTPHeaderField("Authorization")).to(equal("bearer MTQzM2U3YTI3YmQyOWQ5YzQ0NjY4YTZkYjM0MjczYmZhNWI1M2YxM2Y1MjgwYTg3NDk3ZDc4ZGUzM2YxZmJjZQ"))
                }
            }
        }
    }
}