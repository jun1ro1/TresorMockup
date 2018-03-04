//
//  SiteExtension.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/03/04.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//

import Foundation
import CoreData

public class Site: NSManagedObject {
    override public func awakeFromInsert() {
        self.setPrimitiveValue(Date(), forKey: "createdAt")
        self.setPrimitiveValue(UUID(), forKey: "uuid")
        self.setPrimitiveValue(true, forKey: "active")
    }
}
