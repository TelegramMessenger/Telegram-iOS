//
//  Networking.swift
//  AppleReminders
//
//  Created by Josh R on 3/22/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import Foundation


struct IconAPI {
    func fetchIcon(urlString: String, completion: @escaping (Result<Data?, Error>) -> Void) {
        let imgURLString = "https://logo.clearbit.com/\(urlString)"
        guard let url = URL(string: imgURLString) else { return }
        
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 404 {
                    completion(.success(nil))
                }
            }
            completion(.success(data))
        }.resume()
    }
}
