//
//  Site+CoreDataProperties.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/03/03.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//
//

import Foundation
import CoreData


extension Site {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Site> {
        return NSFetchRequest<Site>(entityName: "Site")
    }
}

// MARK: Generated accessors for passwords
extension Site {

    override public func awakeFromInsert() {
        self.setPrimitiveValue(Date(), forKey: "createdAt")
        self.setPrimitiveValue(UUID(), forKey: "uuid")
        self.setPrimitiveValue(true, forKey: "active")
    }

    @objc(addPasswordsObject:)
    @NSManaged public func addToPasswords(_ value: Password)

    @objc(removePasswordsObject:)
    @NSManaged public func removeFromPasswords(_ value: Password)

    @objc(addPasswords:)
    @NSManaged public func addToPasswords(_ values: NSSet)

    @objc(removePasswords:)
    @NSManaged public func removeFromPasswords(_ values: NSSet)

}
