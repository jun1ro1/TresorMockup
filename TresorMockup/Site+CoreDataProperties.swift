//
//  Site+CoreDataProperties.swift
//  
//
//  Created by OKU Junichirou on 2018/04/01.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension Site {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Site> {
        return NSFetchRequest<Site>(entityName: "Site")
    }

    @NSManaged public var active: Bool
    @NSManaged public var charSet: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var loginAt: Date?
    @NSManaged public var maxLength: Int16
    @NSManaged public var memo: String?
    @NSManaged public var password: String?
    @NSManaged public var selectAt: Date?
    @NSManaged public var title: String?
    @NSManaged public var url: String?
    @NSManaged public var userid: String?
    @NSManaged public var uuid: UUID?
    @NSManaged public var passwords: NSSet?

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
