//
//  Password+CoreDataProperties.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/03/03.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//
//

import Foundation
import CoreData


extension Password {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Password> {
        return NSFetchRequest<Password>(entityName: "Password")
    }

    override public func awakeFromInsert() {
        self.setPrimitiveValue(Date(), forKey: "createdAt")
        self.setPrimitiveValue(UUID(), forKey: "uuid")
        self.setPrimitiveValue(true, forKey: "active")
    }
}
