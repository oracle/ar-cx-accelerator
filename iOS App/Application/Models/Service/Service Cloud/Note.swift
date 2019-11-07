//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 3/6/19 8:46 AM
// *********************************************************************************************
// File: Note.swift
// *********************************************************************************************
// 

import Foundation

struct Note: Codable {
    
    //MARK: - Properties
    
    /**
     The row id of the node note.
    */
    var id: Int?
    
    /**
     The text of the node note.
     */
    private(set) var text: String
    
    /**
     The created time of the node note.
     */
    var createdTime: Date?
    
    /**
     The account that created the node note.
     */
    var createdByAccount: String?
    
    /**
     The last updated time of the node note.
     */
    var updatedTime: Date?
    
    /**
     The account that last updated the node note.
     */
    var updatedByAccount: String?
    
    /**
     The channel in which the note was entereed of the node note.
     */
    var channel: String?
    
    //MARK: - Enums
    
    /**
     The coding keys that map JSON keys to this struct.
     */
    enum CodingKeys: String, CodingKey {
        case id,
        text,
        createdTime,
        createdByAccount,
        updatedTime,
        updatedByAccount,
        channel
    }
    
    /**
     Errors that this struct may supply during throw statements.
    */
    enum NoteError: Error {
        case base64DecodeError,
        base64EncodeError
    }
    
    //MARK: - Implementation Methods
    
    /**
     An init method that takes the required text property and sets it.
     
     - Parameter text: The text string of the note.
     */
    init(_ text: String) {
        self.text = text
    }
    
    //MARK: - Codable Methods
    
    /**
     An init method that is run when this struct is created from a decoder.
     
     - Parameter decoder: The decoder that is constructing this object.
     */
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try? container.decode(Int.self, forKey: CodingKeys.id)
        createdByAccount = try? container.decode(String.self, forKey: CodingKeys.createdByAccount)
        updatedByAccount = try? container.decode(String.self, forKey: CodingKeys.updatedByAccount)
        channel = try? container.decode(String.self, forKey: CodingKeys.channel)
        
        // Ecapsulate the text decoding in a try/catch block so that we gracefully fail to no text.
        do {
            let base64EncodedNoteStr = try container.decode(String.self, forKey: CodingKeys.text)
            guard let decodedStr = base64EncodedNoteStr.base64Decoded else { throw NoteError.base64DecodeError }
            
            text = decodedStr
        } catch {
            error.log()
            text = ""
        }
        
        //TODO: May need to update this formatter when Engagement Cloud notes are added to account for the differences in the way Engagement Cloud and Service Cloud handle datetime stamps.
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        
        if let createdDateStr = try? container.decode(String.self, forKey: CodingKeys.createdTime), let createdDate = df.date(from: createdDateStr) {
            self.createdTime = createdDate
        }
        
        if let updatedDateStr = try? container.decode(String.self, forKey: CodingKeys.updatedTime), let updatedDate = df.date(from: updatedDateStr) {
            self.updatedTime = updatedDate
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Only the text string should be passed when a note is created.  Only encode it.
        guard let base64EncodedStr = text.base64Encoded else { throw NoteError.base64EncodeError }
        
        try container.encode(base64EncodedStr, forKey: CodingKeys.text)
    }
}

struct NoteRequest: Encodable {
    /**
     A single note object that will be supplied for the note creation process.
    */
    var Notes: Note
    
    /**
     An init method that takes the required text property and sets it.
     
     - Parameter text: The text string of the note.
     */
    init (_ text: String) {
        let note = Note(text)
        
        self.Notes = note
    }
}


struct NoteArrayResponse: Decodable {
    /**
     An array of Notes.
     */
    var items: [Note]?
}
