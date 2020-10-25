//
//  Site+CoreDataProperties.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/06/16.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//
//

import Foundation
import CoreData

extension Site {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Site> {
        return NSFetchRequest<Site>(entityName: "Site")
    }
    
    @NSManaged public var active: Bool
    @NSManaged public var charSet: Int32
    @NSManaged public var createdAt: NSDate?
    @NSManaged public var loginAt: NSDate?
    @NSManaged public var maxLength: Int16
    @NSManaged public var memo: String?
    @NSManaged public var selectAt: NSDate?
    @NSManaged public var title: String?
    @NSManaged public var url: String?
    @NSManaged public var userid: String?
    @NSManaged public var uuid: String?
    @NSManaged public var passwordCurrent: NSString?
    @NSManaged public var passwords: NSSet?
    
}

extension Site {
    func readString(from properties: [String: String]) {
        let dateFormatter = ISO8601DateFormatter()
        let names = Site.entity().properties.map { $0.name }
        names.forEach { name in
            if let val = properties[name] {
                switch Site.entity().attributesByName[name]?.attributeType {
                case .booleanAttributeType:
                    self.setValue(Bool(val), forKey: name)
                case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
                    self.setValue(Int(val), forKey: name)
                case .dateAttributeType:
                    self.setValue(dateFormatter.date(from: val), forKey: name)
                case .stringAttributeType:
                    self.setValue(String(val), forKey: name)
                default:
                    self.setValue(nil, forKey: name)
                }
            }
        }
    }
}


// MARK: Generated accessors for passwords
extension Site {
    
    @objc(addPasswordsObject:)
    @NSManaged public func addToPasswords(_ value: Password)
    
    @objc(removePasswordsObject:)
    @NSManaged public func removeFromPasswords(_ value: Password)
    
    @objc(addPasswords:)
    @NSManaged public func addToPasswords(_ values: NSSet)
    
    @objc(removePasswords:)
    @NSManaged public func removeFromPasswords(_ values: NSSet)
    
}
