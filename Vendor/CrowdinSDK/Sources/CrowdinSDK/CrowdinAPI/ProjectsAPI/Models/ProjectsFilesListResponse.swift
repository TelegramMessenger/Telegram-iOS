//
//  ProjectsFilesListResponse.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 09.02.2020.
//

import Foundation

// MARK: - ProjectsFilesListResponse
public struct ProjectsFilesListResponse: Codable {
    public let data: [ProjectsFilesListResponseDatum]
    public let pagination: ProjectsFilesListResponsePagination

    enum CodingKeys: String, CodingKey {
        case data
        case pagination
    }
}

// MARK: - ProjectsFilesListResponseDatum
public struct ProjectsFilesListResponseDatum: Codable {
    public let data: ProjectsFilesListResponseData

    enum CodingKeys: String, CodingKey {
        case data
    }

    public init(data: ProjectsFilesListResponseData) {
        self.data = data
    }
}

// MARK: - ProjectsFilesListResponseData
public struct ProjectsFilesListResponseData: Codable {
    public let id: Int
    public let projectID: Int
    public let branchID: Int?
    public let directoryID: Int?
    public let name: String
    public let title: String?
    public let type: String
    public let revisionID: Int
    public let status: String
    public let priority: String

    enum CodingKeys: String, CodingKey {
        case id
        case projectID = "projectId"
        case branchID = "branchId"
        case directoryID = "directoryId"
        case name
        case title
        case type
        case revisionID = "revisionId"
        case status
        case priority
    }
}

// MARK: - ProjectsFilesListResponseExportOptions
public struct ProjectsFilesListResponseExportOptions: Codable {
    public let exportPattern: String

    enum CodingKeys: String, CodingKey {
        case exportPattern
    }

    public init(exportPattern: String) {
        self.exportPattern = exportPattern
    }
}

// MARK: - ProjectsFilesListResponseImportOptions
public struct ProjectsFilesListResponseImportOptions: Codable {
    public let firstLineContainsHeader: Bool
    public let importTranslations: Bool
    public let scheme: ProjectsFilesListResponseScheme

    enum CodingKeys: String, CodingKey {
        case firstLineContainsHeader
        case importTranslations
        case scheme
    }
}

// MARK: - ProjectsFilesListResponseScheme
public struct ProjectsFilesListResponseScheme: Codable {
    public let identifier: Int
    public let sourcePhrase: Int
    public let en: Int
    public let de: Int

    enum CodingKeys: String, CodingKey {
        case identifier
        case sourcePhrase
        case en
        case de
    }
}

// MARK: - ProjectsFilesListResponsePagination
public struct ProjectsFilesListResponsePagination: Codable {
    public let offset: Int
    public let limit: Int

    enum CodingKeys: String, CodingKey {
        case offset
        case limit
    }
}
