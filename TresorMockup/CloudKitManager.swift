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
        self.keys   = object?.changedValues().map { (key, _) in return key } ?? []
    }
}

class CloudKitManager: NSObject {

    static var shared: CloudKitManager? = CloudKitManager()

    var deleted:  [NSManagedObject] = []
    var updated:  [UpdatedObject]  = []

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
        self.updated  = moc.updatedObjects.map  { UpdatedObject( object: $0 ) }
        self.updated.append(contentsOf: moc.insertedObjects.map { UpdatedObject( object: $0 ) } )
    }

    @objc func contextDidSave(notification: Notification) {
        print("contextDidSave")

        self.deleted.forEach { obj in
            if obj.objectID.isTemporaryID {
                assertionFailure()
            }
            let id        = obj.objectID.uriRepresentation()
            let entryName = obj.entity.managedObjectClassName ?? ""
            print("deleted = \(id): \(entryName)")
        }

        self.updated.forEach { uobj in
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
                let (key, v) = dic

                var typestr = ""
                var valstr  = ""
                if let val = v as? NSString {
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
                else if let val = v as? CKAsset {
                    typestr = "CKAsset"
                    valstr  = val.description
                }
                else if let val = v as? CKReference {
                    typestr = "CKReference"
                    valstr  = val.description
                }
                else {
                    typestr = "UNKNOWN"
                    valstr  = (v as AnyObject).description 
                }

//                let tp = type(of: obj)
//                var tpstr = ""
//                switch tp {
//                case is NSString:
//                    tpstr = "NSString"
//                case is NSNumber:
//                    tpstr = "NSNumber"
//                case is NSData:
//                    tpstr = "NSData"
//                case is NSDate:
//                    tpstr = "NSDate"
//                case is NSArray:
//                    tpstr = "NSArray"
//                case is CLLocation:
//                    tpstr = "CLLocation"
//                case is CKAsset:
//                    tpstr = "CKAsset"
//                case is CKReference:
//                    tpstr = "CKReference"
//                default:
//                    tpstr = String(describing: tp)
//                }
                let str = "\(key): \(typestr) = \(valstr)"
                return result + str + "\n"
            }
            print("updated = \(id): \(entryName)")
            print("updated = \(str)\n")
        }

        //        self.inserted?.forEach  { obj in
        //            print("inserted =  \(obj.entity.managedObjectClassName)")
        //            obj.committedValues(forKeys: nil).forEach { (key: String, val:Any?) in
        //                print("inserted: \(key): \(String(describing: val))")
        //            }
        //        }

        self.deleted  = []
        self.updated  = []
    }
}
