//
//  CloudKitManager.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/07/14.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//

import UIKit
import CoreData

class CloudKitManager: NSObject {

    static var shared: CloudKitManager? = CloudKitManager()

    var deleted:  [NSManagedObject]?
    var updated:  [NSManagedObject]?
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
        self.updated  = Array(moc.updatedObjects)
        self.inserted = Array(moc.insertedObjects)

    }

    @objc func contextDidSave(notification: Notification) {
        print("contextDidSave")

        self.deleted?.forEach  { obj in print("deleted  = \(obj)")}

        self.updated?.forEach  { obj in
            print("updated =  \(obj.entity.managedObjectClassName)")
            obj.committedValues(forKeys: nil).forEach { (key: String, val:Any?) in
                print("updated: \(key): \(String(describing: val))")
            }
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
