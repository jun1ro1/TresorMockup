//
//  CloudKitManager.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/07/14.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//

import UIKit
import CoreData

class UpdatedObject {
    var object: NSManagedObject?
    var keys: [String]

    init() {
        self.object = nil
        self.keys   = []
    }
}

class CloudKitManager: NSObject {

    static var shared: CloudKitManager? = CloudKitManager()

    var deleted:  [NSManagedObject]?
    var updated:  [UpdatedObject]?
    var inserted: [NSManagedObject]?

    func addObserver( managedObjectContext moc: NSManagedObjectContext?) {
        NotificationCenter.default.addObserver(self, selector: #selector(contextWillSave(notification:)), name: NSNotification.Name.NSManagedObjectContextWillSave, object: moc)

        NotificationCenter.default.addObserver(self, selector: #selector(contextDidSave(notification:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: moc)
    }

    @objc func contextWillSave(notification: Notification) {
        guard let moc = notification.object as? NSManagedObjectContext else {
            assertionFailure()
            return
        }
        print("contextWillSave")
        self.deleted  = Array(moc.deletedObjects)
        self.updated  = moc.updatedObjects.map { obj in
            let uobj = UpdatedObject()
            uobj.object = obj
            uobj.keys   = obj.changedValues().map { (key, _) in return key }
            return uobj
        }
        self.inserted = Array(moc.insertedObjects)
    }

    @objc func contextDidSave(notification: Notification) {
        print("contextDidSave")

        self.deleted?.forEach { obj in
            if obj.objectID.isTemporaryID {
                assertionFailure()
            }
            let id        = obj.objectID.uriRepresentation()
            let entryName = obj.entity.managedObjectClassName ?? ""
            print("deleted = \(id): \(entryName)")
        }

        self.updated?.forEach { uobj in
            let obj = uobj.object
            guard obj != nil else {
                assertionFailure()
                return
            }
            if obj!.objectID.isTemporaryID {
                assertionFailure()
            }
            let id         = obj!.objectID.uriRepresentation()
            let entryName  = obj!.entity.managedObjectClassName ?? ""
            let attributes = obj!.committedValues(forKeys: uobj.keys)

            let str = attributes.reduce("") { (result, dic) in
                let (key, val) = dic
                return result + key + ": " + (val as AnyObject).description + "\n"
            }
            print("updated = \(id): \(entryName)")
            print("updated = \(str)")
        }

        self.inserted?.forEach  { obj in
            print("inserted =  \(obj.entity.managedObjectClassName)")
            obj.committedValues(forKeys: nil).forEach { (key: String, val:Any?) in
                print("inserted: \(key): \(String(describing: val))")
            }
        }

        self.deleted  = nil
        self.updated  = nil
        self.inserted = nil
    }
}
