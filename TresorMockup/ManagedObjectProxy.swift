//
//  ManagedObjectProxy.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/03/17.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//

import Foundation
import CoreData

class ManagedObjectProxy {

    // MARK: - properties
    var managedObject: NSManagedObject
    var hasChanges: Bool {
        get {
            return self.changed
        }
    }

    // MARK: - private instance variables
    private var attributes: [ String: AnyObject ]
    private var changed: Bool

    // MARK: - life cycle
    init(managedObject: NSManagedObject) {
        self.managedObject = managedObject
        self.attributes   = [:]
        self.changed      = false
        self.load()
    }

    // MARK: - public methods
    func load() {
        self.changed = false
        let entity: NSEntityDescription = self.managedObject.entity;
        _ = Array( entity.attributesByName.keys ).map {
            self.attributes[$0 as String] = self.managedObject.primitiveValue(forKey: $0 as String) as AnyObject
        }
    }

    func writeBack(closure: (NSObject, AnyObject)->Void = {_,_ in }) {
        self.changed = false
        for (key, val) in self.attributes {
            if (val as? NSNull) == nil {
                self.managedObject.setValue(val, forKey: key)
                closure(key as NSObject, val)
            }
        }
    }

    func setValue(_ value: AnyObject?, forKey key: String) {
        self.attributes[key] = value
        self.changed = true
    }

    func value(forKey key: String) -> AnyObject? {
        return self.attributes[ key ]
    }
}
