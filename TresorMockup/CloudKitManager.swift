//
//  CloudKitManager.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/07/14.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//

import UIKit
import CoreData

fileprivate class deletedObject {
    var entryName: String?
    var id: URL?

    func description() -> String {
        return (self.id?.absoluteString ?? "") + ":" + (self.entryName ?? "")
    }
}

fileprivate class updatedObject {
    var entryName: String?
    var id: URL?
    var attributes: [String: Any?]

    init() {
        self.entryName  = nil
        self.id         = nil
        self.attributes = [:]
    }

    func description() -> String {
        var str: String = ""
        str += self.id?.absoluteString ?? ""
        str += ":"
        str += self.entryName ?? ""
        str += "\n"
        str += self.attributes.reduce("") { (result, dic) in
            let (key, val) = dic
            return result + key + ": " + val.debugDescription + "\n"
        }
        return str
    }

}

class CloudKitManager: NSObject {

    static var shared: CloudKitManager? = CloudKitManager()

    fileprivate var deleted:  [deletedObject]?
    fileprivate var updated:  [updatedObject]?
    fileprivate var inserted: [NSManagedObject]?

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
        self.deleted  = moc.deletedObjects.map { obj in
            if obj.objectID.isTemporaryID {
                assertionFailure()
            }
            let delobj       = deletedObject()
            delobj.id        = obj.objectID.uriRepresentation()
            delobj.entryName = obj.entity.managedObjectClassName
            return delobj
        }
        self.updated  = moc.updatedObjects.map { obj in
            if obj.objectID.isTemporaryID {
                assertionFailure()
            }
            let updobj       = updatedObject()
            updobj.id        = obj.objectID.uriRepresentation()
            updobj.entryName = obj.entity.managedObjectClassName
            updobj.attributes = obj.changedValues()
            return updobj

        }
        self.inserted = Array(moc.insertedObjects)

    }

    @objc func contextDidSave(notification: Notification) {
        print("contextDidSave")

        self.deleted?.forEach  { obj in print("deleted  = \(obj)")}

        self.updated?.forEach  { obj in print("updated  = \(obj.description())")}

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
