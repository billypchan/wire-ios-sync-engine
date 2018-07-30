//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation

extension URL {
    enum Host {
        static let connect = "connect"
        static let login = "login"
    }
    enum Path {
        static let success = "success"
        static let failure = "failure"
    }
}

extension URLQueryItem {
    enum Key {
        static let successRedirect = "success_redirect"
        static let errorRedirect = "error_redirect"
        static let cookie = "cookie"
        static let userIdentifier = "userid"
        static let errorLabel = "label"
        static let validationToken = "validation_token"
    }
    
    enum Template {
        static let cookie = "$cookie"
        static let userIdentifier = "$userid"
        static let errorLabel = "$label"
    }
}

@objc public protocol URLSessionProtocol: class {
    @objc(dataTaskWithURL:completionHandler:)
    func dataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask
}

extension URLSession: URLSessionProtocol {}

public typealias StatusCode = Int

public enum ValidationError: Equatable {
    case invalidCode
    case invalidStatus(StatusCode)
    case unknown
    
    init?(response: HTTPURLResponse?, error: Error?) {
        switch (response?.statusCode, error) {
        case (404?, _): self = .invalidCode
        case ((400...599)?, _): self = .invalidStatus(response!.statusCode)
        case (_, .some), (.none, _): self = .unknown
        default: return nil
        }
    }
}

public protocol CompanyLoginRequesterDelegate: class {

    /**
     * The login requester asks the user to verify their identity on the given website.
     *
     * - parameter requester: The requester asking for validation.
     * - parameter url: The URL where the user should be taken to perform validation.
     */

    func companyLoginRequester(_ requester: CompanyLoginRequester, didRequestIdentityValidationAtURL url: URL)

}

/**
 * An object that validates the identity of the user and creates a session using company login.
 */

public class CompanyLoginRequester {
    
    /// The URL scheme that where the callback will be provided.
    public let callbackScheme: String

    /// The object that observes events and performs the required actions.
    public weak var delegate: CompanyLoginRequesterDelegate?

    let backendHost: String
    private let defaults: UserDefaults
    private let session: URLSessionProtocol

    /// Creates a session requester that uses the specified parameters.
    public init(
        backendHost: String,
        callbackScheme: String,
        defaults: UserDefaults = .shared(),
        session: URLSessionProtocol = URLSession.shared
        ) {
        self.backendHost = backendHost
        self.callbackScheme = callbackScheme
        self.defaults = defaults
        self.session = session
    }
    
    // MARK: - Token Validation
    
    /**
     * Validated a company login token.
     *
     * This method will verify a compy login token with the backend.
     * The requester provided by the `enqueueProvider` passed to `init` will
     * be used to perform the request.
     *
     * - parameter token: The user login token.
     * - parameter completion: The completion closure called with the validation result.
     */
    
    public func validate(token: UUID, completion: @escaping (ValidationError?) -> Void) {
        guard let url = urlComponents(for: token).url else { fatalError("Invalid company login url.") }
    
        let request = session.dataTask(with: url) { _, response, error in
            DispatchQueue.main.async {
                completion(ValidationError(response: response as? HTTPURLResponse, error: error))
            }
        }
        
        request.resume()
    }

    // MARK: - Identity Request

    /**
     * Starts the company login flow for the user with the given login token.
     *
     * This method constructs the login URL, and calls the `delegate`, that will
     * handle opening the URL. Typically, this initiates the login flow, which will
     * open Safari. The `SessionManager` will handle the callback URL.
     *
     * - parameter token: The user login token, constructed from the request code.
     */

    public func requestIdentity(for token: UUID) {
        let validationToken = CompanyLoginVerificationToken()
        var components = urlComponents(for: token)
        
        components.queryItems = [
            URLQueryItem(name: URLQueryItem.Key.successRedirect, value: makeSuccessCallbackString(using: validationToken)),
            URLQueryItem(name: URLQueryItem.Key.errorRedirect, value: makeFailureCallbackString(using: validationToken))
        ]

        guard let url = components.url else {
            fatalError("Invalid company login URL. This is a developer error.")
        }

        validationToken.store(in: defaults)
        delegate?.companyLoginRequester(self, didRequestIdentityValidationAtURL: url)
    }

    // MARK: - Utilities
    
    private func urlComponents(for token: UUID) -> URLComponents {
        var components = URLComponents()
        components.scheme = "https"
        components.host = backendHost
        components.path = "/sso/initiate-login/\(token.uuidString)"
        return components
    }

    private func makeSuccessCallbackString(using token: CompanyLoginVerificationToken) -> String {
        var components = URLComponents()
        components.scheme = callbackScheme
        components.host = URL.Host.login
        components.path = "/" + URL.Path.success

        components.queryItems = [
            URLQueryItem(name: URLQueryItem.Key.cookie, value: URLQueryItem.Template.cookie),
            URLQueryItem(name: URLQueryItem.Key.userIdentifier, value: URLQueryItem.Template.userIdentifier),
            URLQueryItem(name: URLQueryItem.Key.validationToken, value: token.uuid.transportString())
        ]

        return components.url!.absoluteString
    }

    private func makeFailureCallbackString(using token: CompanyLoginVerificationToken) -> String {
        var components = URLComponents()
        components.scheme = callbackScheme
        components.host = URL.Host.login
        components.path = "/" + URL.Path.failure

        components.queryItems = [
            URLQueryItem(name: URLQueryItem.Key.errorLabel, value: URLQueryItem.Template.errorLabel),
            URLQueryItem(name: URLQueryItem.Key.validationToken, value: token.uuid.transportString())
        ]

        return components.url!.absoluteString
    }

}