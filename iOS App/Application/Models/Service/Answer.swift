//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: Answer.swift
// *********************************************************************************************
// 

import Foundation
import PDFKit
import XMLParsing
import os

/**
 Struct to represent the AnswerResponse JSON object returned from Engagement Cloud knowledge via ICS
 */
struct AnswerResponse: Decodable {
    var isForEdit: Bool?
    var recordId: String?
    var versionId: String?
    var documentId: String?
    var title: String?
    var version: String?
    var answerId: Int?
    var dateModified: String?
    var priority: String?
    var createDate: String?
    var lastModifiedDate: String?
    var dateAdded: String?
    var displayStartDate: String?
    var displayEndDate: String?
    var published: Bool?
    var pending: Bool?
    var publishDate: String?
    var checkedOut: Bool?
    var publishedVersion: String?
    var xml: String?
    var resourcePath: String?
    
    enum CodingKeys: String, CodingKey {
        case isForEdit,
        recordId,
        versionId,
        documentId,
        title,
        version,
        answerId,
        dateModified,
        priority,
        createDate,
        lastModifiedDate,
        dateAdded,
        displayStartDate,
        displayEndDate,
        published,
        pending,
        publishDate,
        checkedOut,
        publishedVersion,
        xml,
        resourcePath
    }
    
    // ICS doesn't properly convert bools; it leaves them as strings.  We need to perform the convertion here.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        isForEdit = try? container.decode(String.self, forKey: CodingKeys.isForEdit).boolValue
        recordId = try? container.decode(String.self, forKey: CodingKeys.recordId)
        versionId = try? container.decode(String.self, forKey: CodingKeys.versionId)
        documentId = try? container.decode(String.self, forKey: CodingKeys.documentId)
        title = try? container.decode(String.self, forKey: CodingKeys.title)
        version = try? container.decode(String.self, forKey: CodingKeys.version)
        answerId = try? container.decode(Int.self, forKey: CodingKeys.answerId)
        dateModified = try? container.decode(String.self, forKey: CodingKeys.dateModified)
        priority = try? container.decode(String.self, forKey: CodingKeys.priority)
        createDate = try? container.decode(String.self, forKey: CodingKeys.createDate)
        lastModifiedDate = try? container.decode(String.self, forKey: CodingKeys.lastModifiedDate)
        dateAdded = try? container.decode(String.self, forKey: CodingKeys.dateAdded)
        displayStartDate = try? container.decode(String.self, forKey: CodingKeys.displayStartDate)
        displayEndDate = try? container.decode(String.self, forKey: CodingKeys.displayEndDate)
        published = try? container.decode(String.self, forKey: CodingKeys.published).boolValue
        pending = try? container.decode(String.self, forKey: CodingKeys.pending).boolValue
        publishDate = try? container.decode(String.self, forKey: CodingKeys.publishDate)
        checkedOut = try? container.decode(String.self, forKey: CodingKeys.checkedOut).boolValue
        publishedVersion = try? container.decode(String.self, forKey: CodingKeys.publishedVersion)
        xml = try? container.decode(String.self, forKey: CodingKeys.xml)
        resourcePath = try? container.decode(String.self, forKey: CodingKeys.resourcePath)
    }
    
    /**
     Method that allows conversion of the XML string to a decodable type, such as manuals or bulletins.
     
     - parameters:
        - object: The object type to attempt conversion to.
    */
    func xmlToType<T: Decodable>(object: T.Type) -> T? {
        guard let xml = self.xml, let xmlData = xml.data(using: .utf8) else {
            #if DEBUG
            os_log("No XML data attached to answer")
            #endif
            
            return nil
        }
        
        var convertedItem: T?
        
        let decoder = XMLDecoder()
        
        do {
            convertedItem = try decoder.decode(T.self, from: xmlData)
        } catch {
            error.log()
        }
        
        return convertedItem
    }
}

/**
 Struct to represent the AnswerArrayResponse JSON object returned from Engagement Cloud knowledge via ICS
 */
struct AnswerArrayResponse: Decodable {
    var items: [AnswerResponse]?
    var hasMore: Bool?
    var limit: Int?
    var offset: Int?
    var count: Int?
    
    enum CodingKeys: String, CodingKey {
        case items,
        hasMore,
        limit,
        offset,
        count
    }
    
    // ICS doesn't properly convert bools; it leaves them as strings.  We need to perform the convertion here.
    init(from decorder: Decoder) throws {
        let container = try decorder.container(keyedBy: CodingKeys.self)
        
        items = try? container.decode([AnswerResponse].self, forKey: CodingKeys.items)
        hasMore = try? container.decode(String.self, forKey: CodingKeys.hasMore).boolValue
        limit = try? container.decode(Int.self, forKey: CodingKeys.limit)
        offset = try? container.decode(Int.self, forKey: CodingKeys.offset)
        count = try? container.decode(Int.self, forKey: CodingKeys.count)
    }
}

/**
 Represents a KB answer with a url field that will point to a PDF hosted on the public internet
 */
struct PdfAnswer: Decodable {
    var title: String?
    var attachment: String?
    var summary: String?
    var url: URL?
    var details: String?
    
    enum CodingKeys: String, CodingKey {
        case title = "TITLE",
        attachment = "ATTACHEMENT", //yes, this key has an e in it for some reason.
        summary = "SUMMARY",
        url = "URL",
        details = "DETAILS"
    }
    
    enum PDFDocumentError: Error {
        case url,
        file,
        pdf
    }
    
    // Update the decoder so that we can turn the URL into a URL object here without having to implement the logic in multiple places.
    init(from decorder: Decoder) throws {
        let container = try decorder.container(keyedBy: CodingKeys.self)
        
        title = try? container.decode(String.self, forKey: CodingKeys.title)
        attachment = try? container.decode(String.self, forKey: CodingKeys.attachment)
        summary = try? container.decode(String.self, forKey: CodingKeys.summary)
        details = try? container.decode(String.self, forKey: CodingKeys.details)
        
        guard let urlStr = try? container.decode(String.self, forKey: CodingKeys.url) else { return }
        
        // If the URL has HTTP, then check for the file remotely.
        if urlStr.contains("http") {
            url = URL(string: urlStr)
        }
        // Otherwise, see if it is included in the app bundle.
        else {
            let fileNameParts = urlStr.split(separator: ".")
            
            guard fileNameParts.count == 2 else { return }
            
            url = Bundle.main.url(forResource: String(fileNameParts[0]), withExtension: String(fileNameParts[1]))
        }
    }
    
    /**
     Constructs a URL from a resource path and the attachment or file name parsed from the knowledge XML.
     This method is used primarily with OSvC since the URL node is not returned by knowledge advanced, but is a concatination of the XML attribute(s) and the resource path from the answer.
     
     - Parameter path: The URL path provided in the resourcePath attribute of the answer.
    */
    mutating func setUrlFromResourcePath(_ path: String) {
        let attachmentName = self.attachment ?? self.title
        
        guard attachmentName != nil else { return }
        let fullPath = String(format: "%@%@", path, attachmentName!)
        guard let url = URL(string: fullPath) else { return }
        
        self.url = url
    }
    
    /**
     Returns a PDFDocument from either a remote or local URL.
     
     - Parameter completion: Callback called after the remote file is retrieved.
     - Parameter pdf: The returned PDF file.
    */
    func getPDFFile(completion: @escaping (_ pdf: PDFDocument?) -> ()) {
        guard let url = self.url else { completion(nil); return }
        
        let getPDFFromData: (Data) -> () = { data in
            guard let pfd = PDFDocument(data: data) else { completion(nil); return }
            
            completion(pfd)
        }
        
        // Load from URL
        if url.absoluteString.contains("http") {
            let request = URLRequest.init(url: url, cachePolicy: URLRequest.CachePolicy.returnCacheDataElseLoad, timeoutInterval: 20)
            GenericIntegrationBroker.shared.performRequest(request: request) { results in
                switch results {
                case .success(let data):
                    getPDFFromData(data)
                    break
                default:
                    completion(nil)
                    break
                }
                
                
            }
        }
            // Load from file
        else {
            guard let data = try? Data(contentsOf: url) else { completion(nil); return }
            
            getPDFFromData(data)
        }
    }
}
