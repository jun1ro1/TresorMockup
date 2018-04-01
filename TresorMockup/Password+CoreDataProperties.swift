//
//  Password+CoreDataProperties.swift
//  
//
//  Created by OKU Junichirou on 2018/04/01.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension Password {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Password> {
        return NSFetchRequest<Password>(entityName: "Password")
    }

    @NSManaged public var active: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var password: String?
    @NSManaged public var selectedAt: Date?
    @NSManaged public var uuid: UUID?
    @NSManaged public var site: Site?

}
