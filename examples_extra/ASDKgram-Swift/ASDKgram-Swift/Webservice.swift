//
//  Webservice.swift
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import UIKit

final class WebService {
    /// Load a new resource. Callback is called on main
	func load<A>(resource: Resource<A>, completion: @escaping (Result<A>) -> ()) {
		URLSession.shared.dataTask(with: resource.url) { data, response, error in
			// Check for errors in responses.
			let result = self.checkForNetworkErrors(data, response, error)
			DispatchQueue.main.async {
                // Parsing should happen off main
				switch result {
				case .success(let data):
					completion(resource.parse(data, response))
				case .failure(let error):
					completion(.failure(error))
				}
			}
		}.resume()
	}
}

extension WebService {
    /// // Check for errors in responses.
	fileprivate func checkForNetworkErrors(_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Result<Data> {
		if let error = error {
            switch error {
            case URLError.notConnectedToInternet, URLError.timedOut:
                return .failure(.noInternetConnection)
            default:
                return .failure(.returnedError(error))
            }
		}
		
		if let response = response as? HTTPURLResponse, response.statusCode <= 200 && response.statusCode >= 299 {
			return .failure((.invalidStatusCode("Request returned status code other than 2xx \(response)")))
		}
		
		guard let data = data else {
            return .failure(.dataReturnedNil)
        }
		
		return .success(data)
	}
}

struct ResponseMetadata {
    let currentPage: Int
    let itemsTotal: Int
    let itemsPerPage: Int
}

extension ResponseMetadata {
    var pagesTotal: Int {
        return itemsTotal / itemsPerPage
    }
}

struct Resource<A> {
	let url: URL
	let parse: (Data, URLResponse?) -> Result<A>
}

extension Resource {
    init(url: URL, page: Int, parseResponse: @escaping (ResponseMetadata, Data) -> Result<A>) {
        // Append extra data to url for paging
        guard let url = URL(string: url.absoluteString.appending("&page=\(page)")) else {
            fatalError("Malformed URL given");
        }
        self.url = url
		self.parse = { data, response in
            // Parse out metadata from header
            guard let httpUrlResponse = response as? HTTPURLResponse,
                let xTotalString = httpUrlResponse.allHeaderFields["x-total"] as? String,
                let xTotal = Int(xTotalString),
                let xPerPageString = httpUrlResponse.allHeaderFields["x-per-page"] as? String,
                let xPerPage = Int(xPerPageString)
                else {
                    return .failure(.errorParsingResponse)
            }
            
            let metadata = ResponseMetadata(currentPage: page, itemsTotal: xTotal, itemsPerPage: xPerPage)
            return parseResponse(metadata, data)
		}
	}
}

enum Result<T> {
	case success(T)
	case failure(NetworkingError)
}

enum NetworkingError: Error {
    case errorParsingResponse
	case errorParsingJSON
	case noInternetConnection
	case dataReturnedNil
	case returnedError(Error)
	case invalidStatusCode(String)
	case customError(String)
}
