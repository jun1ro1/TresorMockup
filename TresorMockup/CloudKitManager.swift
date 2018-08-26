//
//  CloudKitManager.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/07/14.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//

import UIKit
import CoreData
import CoreLocation
import CloudKit
import SwiftyBeaver

class UpdatedObject {
    var object: NSManagedObject?
    var keys: [String]

    init() {
        self.object = nil
        self.keys   = []
    }

    convenience init(object: NSManagedObject?) {
        self.init()
        self.object = object
        self.keys   = object?.changedValues().map {
            let (k, v) = $0
            SwiftyBeaver.self.debug("\(k):\(v)")
            return $0.key
            } ?? []
    }
}

class CloudKitManager: NSObject {
    static var shared: CloudKitManager? = CloudKitManager()
    private var log = SwiftyBeaver.self

    var inserted: [NSManagedObject] = []
    var deleted:  [NSManagedObject] = []
    var updated:  [UpdatedObject]   = []

    func addObserver( managedObjectContext moc: NSManagedObjectContext?) {
        NotificationCenter.default.addObserver(self, selector: #selector(contextWillSave(notification:)), name: NSNotification.Name.NSManagedObjectContextWillSave, object: moc)

        NotificationCenter.default.addObserver(self, selector: #selector(contextDidSave(notification:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: moc)
    }

    func propertiesString(_ properties:[String: Any? ]) -> [String] {
        return properties.map {
            let (key, v) = $0

            var typestr = ""
            var valstr  = ""

            if v is NSNull {
                typestr = "NULL"
                valstr  = "NIL"
            }
            else if let val = v as? NSString {
                typestr = "NSString"
                valstr  = val as String
            }
            else if let val = v as? NSNumber {
                typestr = "NSNumber"
                valstr  = val.stringValue
            }
            else if let val = v as? NSData {
                typestr = "NSData"
                valstr  = val.description
            }
            else if let val = v as? NSDate {
                typestr = "NSDate"
                valstr  = val.description
            }
            else if let val = v as? NSArray {
                typestr = "NSArray"
                valstr  = val.description
            }
            else if let val = v as? CLLocation {
                typestr = "CLLocation"
                valstr  = val.description
            }
            else if let val = v as? NSManagedObject {
                typestr = "CKReference"
                valstr  = "\(val.entity.name!) \(String(describing: val.idstr))"
            }
            else if let val = v as? NSSet {
                typestr = "CKReference NSSet"
                valstr  = val.reduce("") {
                    let obj = $1 as! NSManagedObject
                    return $0 + obj.entity.name! + String(describing: obj.idstr) + "\n" }
            }
            else if let val = v as? CKAsset {
                typestr = "CKAsset"
                valstr  = val.description
            }
            else {
                typestr = "UNKNOWN"
                valstr  = (v as AnyObject).description
                assertionFailure()
            }

            return "\(key): \(typestr) = \(valstr)"
        }
    }

    @objc func contextWillSave(notification: Notification) {
        guard let moc = notification.object as? NSManagedObjectContext else {
            assertionFailure()
            return
        }
        self.log.debug("contextWillSave")
        
        self.deleted  = Array(moc.deletedObjects)
        self.inserted = Array(moc.insertedObjects)
        self.updated  = moc.updatedObjects.map  { UpdatedObject( object: $0 ) }
    }

    @objc func contextDidSave(notification: Notification) {
        self.log.debug("contextDidSave")

        self.deleted.forEach { obj in
            let id        = obj.idstr ?? "NO UUID"
            let entryName = obj.entity.managedObjectClassName ?? ""
            self.log.debug("[deleted] id = \(id) type = \(entryName)")
            self.propertiesString( obj.committedValues(forKeys: nil) ).forEach { self.log.debug("  " + $0) }

        }

        self.inserted.forEach  { obj in
            if obj.objectID.isTemporaryID {
                assertionFailure()
            }
            let id        = obj.idstr ?? "NO UUID"
            let entryName = obj.entity.managedObjectClassName ?? ""
            self.log.debug("[inserted] id = \(id): type = \(entryName)")
            self.propertiesString( obj.committedValues(forKeys: nil) ).forEach { self.log.debug("  " + $0) }
        }

        self.updated.forEach { uobj in
            let obj = uobj.object
            guard obj != nil else {
                assertionFailure()
                return
            }
            let id         = obj!.idstr ?? "NO UUID"
            let entryName  = obj!.entity.managedObjectClassName ?? ""
            self.log.debug("[updated] id = \(id): type = \(entryName)")
            self.propertiesString( obj!.committedValues(forKeys: uobj.keys) ).forEach { self.log.debug("  " + $0) }
        }

        self.inserted = []
        self.deleted  = []
        self.updated  = []
    }
}

extension NSManagedObject {
    var idstr: String? {
        return self.value(forKey: "uuid") as? String
    }
}
