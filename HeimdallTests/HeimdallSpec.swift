import AeroGearHttpStub
import Heimdall
import LlamaKit
import Nimble
import Quick

class OAuthAccessTokenMockStore: OAuthAccessTokenStore {
    var storeAccessTokenCalled: Bool = false

    var mockedAccessToken: OAuthAccessToken? = nil
    var storedAccessToken: OAuthAccessToken? = nil
    
    func storeAccessToken(accessToken: OAuthAccessToken?) {
        storeAccessTokenCalled = true

        storedAccessToken = accessToken
    }
    
    func retrieveAccessToken() -> OAuthAccessToken? {
        return mockedAccessToken ?? storedAccessToken
    }
}

class HeimdallResourceRequestMockAuthenticator: HeimdallResourceRequestAuthenticator {
    func authenticateResourceRequest(request: NSURLRequest, accessToken: OAuthAccessToken) -> NSURLRequest {
        var mutableRequest = request.mutableCopy() as NSMutableURLRequest
        mutableRequest.addValue("totally", forHTTPHeaderField: "MockAuthorized")
        return mutableRequest
    }
}

class HeimdallSpec: QuickSpec {
    let bundle = NSBundle(forClass: HeimdallSpec.self)

    override func spec() {
        var accessTokenStore: OAuthAccessTokenMockStore!
        var heimdall: Heimdall!

        beforeEach {
            // due to the internals of aerogear-ios-httpstub we need to access the stubs manager once
            StubsManager.removeAllStubs()
            
            accessTokenStore = OAuthAccessTokenMockStore()
            heimdall = Heimdall(tokenURL: NSURL(string: "http://rheinfabrik.de")!, accessTokenStore: accessTokenStore)
            heimdall.requestAuthenticator = HeimdallResourceRequestMockAuthenticator()
        }
        
        describe("-init") {
            context("when a token is saved in the store") {
                it("loads the token from the token store") {
                    accessTokenStore.mockedAccessToken = OAuthAccessToken(accessToken: "foo", tokenType: "bar")
                    expect(heimdall.hasAccessToken).to(beTrue())
                }
            }
        }

        describe("-invalidateAccessToken") {
            beforeEach {
                accessTokenStore.storeAccessToken(OAuthAccessToken(accessToken: "foo", tokenType: "bar", expiresAt: NSDate(timeIntervalSinceNow: 3600)))
            }

            it("invalidates the currently stored access token") {
                heimdall.invalidateAccessToken()

                expect(accessTokenStore.retrieveAccessToken()?.expiresAt).to(equal(NSDate(timeIntervalSince1970: 0)))
            }
        }
        
        describe("-clearAccessToken") {
            
            beforeEach {
                accessTokenStore.storeAccessToken(OAuthAccessToken(accessToken: "foo", tokenType: "bar", expiresAt: NSDate(timeIntervalSinceNow: 3600)))
            }
            
            it("clears the currently stored access token") {
                heimdall.clearAccessToken()
                
                expect(heimdall.hasAccessToken).to(beFalse())
            }
        }

        describe("-requestAccessToken") {
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
                        heimdall.requestAccessToken(username: "username", password: "password") { result = $0; done() }
                    }
                }

                afterEach {
                    StubsManager.removeAllStubs()
                }

                it("succeeds") {
                    expect(result?.isSuccess).to(beTrue())
                }

                it("sets the access token") {
                    expect(accessTokenStore.storeAccessTokenCalled).to(beTrue())
                }
                
                it("stores the access token in the token store") {
                    expect(accessTokenStore.storeAccessTokenCalled).to(beTrue())
                }
            }

            context("with an error response") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "authorize-error.json", bundle: self.bundle, statusCode: 400)
                    }

                    waitUntil { done in
                        heimdall.requestAccessToken(username: "username", password: "password") { result = $0; done() }
                    }
                }

                afterEach {
                    StubsManager.removeAllStubs()
                }

                it("fails") {
                    expect(result?.isSuccess).to(beFalse())
                }

                it("fails with the correct error domain") {
                    expect(result?.error?.domain).to(equal(OAuthErrorDomain))
                }

                it("fails with the correct error code") {
                    expect(result?.error?.code).to(equal(OAuthErrorInvalidClient))
                }

                it("does not set the access token") {
                    expect(heimdall.hasAccessToken).to(beFalse())
                }
            }

            context("with an invalid response") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "authorize-invalid.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        heimdall.requestAccessToken(username: "username", password: "password") { result = $0; done() }
                    }
                }

                afterEach {
                    StubsManager.removeAllStubs()
                }

                it("fails") {
                    expect(result?.isSuccess).to(beFalse())
                }

                it("fails with the correct error domain") {
                    expect(result?.error?.domain).to(equal(HeimdallErrorDomain))
                }

                it("fails with the correct error code") {
                    expect(result?.error?.code).to(equal(HeimdallErrorInvalidData))
                }

                it("does not set the access token") {
                    expect(heimdall.hasAccessToken).to(beFalse())
                }
            }

            context("with an invalid response missing a token") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "authorize-invalid-token.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        heimdall.requestAccessToken(username: "username", password: "password") { result = $0; done() }
                    }
                }

                afterEach {
                    StubsManager.removeAllStubs()
                }

                it("fails") {
                    expect(result?.isSuccess).to(beFalse())
                }

                it("fails with the correct error domain") {
                    expect(result?.error?.domain).to(equal(HeimdallErrorDomain))
                }

                it("fails with the correct error code") {
                    expect(result?.error?.code).to(equal(HeimdallErrorInvalidData))
                }

                it("does not set the access token") {
                    expect(heimdall.hasAccessToken).to(beFalse())
                }
            }

            context("with an invalid response missing a type") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "authorize-invalid-type.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        heimdall.requestAccessToken(username: "username", password: "password") { result = $0; done() }
                    }
                }

                afterEach {
                    StubsManager.removeAllStubs()
                }

                it("fails") {
                    expect(result?.isSuccess).to(beFalse())
                }

                it("fails with the correct error domain") {
                    expect(result?.error?.domain).to(equal(HeimdallErrorDomain))
                }

                it("fails with the correct error code") {
                    expect(result?.error?.code).to(equal(HeimdallErrorInvalidData))
                }

                it("does not set the access token") {
                    expect(heimdall.hasAccessToken).to(beFalse())
                }
            }
        }

        describe("-authenticateRequest") {
            var request = NSURLRequest(URL: NSURL(string: "http://rheinfabrik.de")!)
            var result: Result<NSURLRequest, NSError>?

            afterEach {
                result = nil
            }

            context("when not authorized") {
                beforeEach {
                    waitUntil { done in
                        heimdall.authenticateRequest(request) { result = $0; done() }
                    }
                }

                it("fails") {
                    expect(result?.isSuccess).to(beFalse())
                }

                it("fails with the correct error domain") {
                    expect(result?.error?.domain).to(equal(HeimdallErrorDomain))
                }

                it("fails with the correct error code") {
                    expect(result?.error?.code).to(equal(HeimdallErrorNotAuthorized))
                }
            }

            context("when authorized with a still valid access token") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "request-valid.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        heimdall.requestAccessToken(username: "username", password: "password") { _ in done() }
                    }

                    waitUntil { done in
                        heimdall.authenticateRequest(request) { result = $0; done() }
                    }
                }

                it("succeeds") {
                    expect(result?.isSuccess).to(beTrue())
                }

                it("authenticates the request using the current requestAuthenticator") {
                    expect(result?.value?.valueForHTTPHeaderField("MockAuthorized")).to(equal("totally"))
                }
            }

            context("when authorized with an expired access token and no refresh token") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "request-invalid-norefresh.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        heimdall.requestAccessToken(username: "username", password: "password") { _ in done() }
                    }

                    waitUntil { done in
                        heimdall.authenticateRequest(request) { result = $0; done() }
                    }
                }

                it("fails") {
                    expect(result?.isSuccess).to(beFalse())
                }

                it("fails with the correct error domain") {
                    expect(result?.error?.domain).to(equal(HeimdallErrorDomain))
                }

                it("fails with the correct error code") {
                    expect(result?.error?.code).to(equal(HeimdallErrorNotAuthorized))
                }
            }

            context("when authorized with an expired access token and a valid refresh token") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in !heimdall.hasAccessToken }) { request in
                        return StubResponse(filename: "request-invalid.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        heimdall.requestAccessToken(username: "username", password: "password") { _ in done() }
                    }

                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "request-valid.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        heimdall.authenticateRequest(request) { result = $0; done() }
                    }
                }

                it("succeeds") {
                    expect(result?.isSuccess).to(beTrue())
                }

                it("authenticates the request using the current requestAuthenticator") {
                    expect(result?.value?.valueForHTTPHeaderField("MockAuthorized")).to(equal("totally"))
                }
            }
        }
    }
}
