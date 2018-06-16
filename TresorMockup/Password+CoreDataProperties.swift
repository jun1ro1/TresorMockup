//
//  Password+CoreDataProperties.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/06/16.
//  Copyright © 2018年 OKU Junichirou. All rights reserved.
//
//

import Foundation
import CoreData


extension Password {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Password> {
        return NSFetchRequest<Password>(entityName: "Password")
    }

    @NSManaged public var active: Bool
    @NSManaged public var createdAt: NSDate?
    @NSManaged public var password: String?
    @NSManaged public var selectedAt: NSDate?
    @NSManaged public var uuid: UUID?
    @NSManaged public var current: Bool
    @NSManaged public var site: Site?

}
