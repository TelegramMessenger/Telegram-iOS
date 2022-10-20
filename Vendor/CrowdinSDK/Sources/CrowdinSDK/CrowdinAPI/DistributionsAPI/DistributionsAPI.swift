//
//  DistributionsAPI.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 5/19/19.
//

import Foundation

class DistributionsAPI: CrowdinAPI {
    let hashString: String
    
    init(hashString: String, organizationName: String? = nil, auth: CrowdinAuth? = nil, session: URLSession = .shared) {
        self.hashString = hashString
        super.init(organizationName: organizationName, auth: auth, session: session)
    }
	
	override var apiPath: String {
		return "distributions/metadata?hash=\(hashString)"
	}
	
    func getDistribution(completion: @escaping (DistributionsResponse?, Error?) -> Void) {
        self.cw_get(url: fullPath, completion: completion)
    }
}
