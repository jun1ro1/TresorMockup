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
        self.keys   = object?.changedValues().map { $0.key } ?? []
    }
}

// https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitQuickStart/MaintainingaLocalCacheofCloudKitRecords/MaintainingaLocalCacheofCloudKitRecords.html#//apple_ref/doc/uid/TP40014987-CH12-SW1

class CloudKitManager: NSObject {
    static      var shared: CloudKitManager = CloudKitManager()

    fileprivate var container: CKContainer
    fileprivate var database:  CKDatabase
    fileprivate var zone:      CKRecordZone
    fileprivate var bundleID:  String
    fileprivate var log = SwiftyBeaver.self

    var inserted: [NSManagedObject] = []
    var deleted:  [NSManagedObject] = []
    var updated:  [UpdatedObject]   = []

    override init() {
        //        super.init()
        self.bundleID  = Bundle.main.bundleIdentifier!
        self.container = CKContainer.default()
        self.database  = self.container.privateCloudDatabase
        self.zone      = CKRecordZone(zoneName: self.bundleID + "_Zone")
    }

    func start() {
        // Create a custom zone
        let createZoneOperation =
            CKModifyRecordZonesOperation(recordZonesToSave: [self.zone], recordZoneIDsToDelete: [])
        createZoneOperation.modifyRecordZonesCompletionBlock = { (saved, deleted, error) in
            self.log.debug("CKModifyRecordZonesOperation error = \(String(describing: error))")
            guard error == nil else {
                assertionFailure()
                return
            }
        }
        self.database.add(createZoneOperation)

        // Subscribing to Change Notifications
        let subscription = CKDatabaseSubscription(subscriptionID: self.bundleID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        let subscriptionOperation =
            CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
        subscriptionOperation.modifySubscriptionsCompletionBlock = {
            (subscriptions, deletedIDs, error) in
            self.log.debug("CKModifySubscriptionsOperation error = \(String(describing: error))")
            guard error == nil else {
                assertionFailure()
                return
            }
        }
        self.database.add(subscriptionOperation)
    }

    func save(record: CKRecord) {
        self.database.save(record,
                           completionHandler: { (recordSaved, error) in
                            self.log.debug("error = \(String(describing: error))")
                            if error != nil {
                                print("CKRecord save error")
                            }
        })
    }

    func addObserver( managedObjectContext moc: NSManagedObjectContext?) {
        NotificationCenter.default.addObserver(self, selector: #selector(contextWillSave(notification:)), name: NSNotification.Name.NSManagedObjectContextWillSave, object: moc)

        NotificationCenter.default.addObserver(self, selector: #selector(contextDidSave(notification:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: moc)
    }

    func setProperties(record: CKRecord, properties:[String: Any?]) {
        properties.forEach {
            let (key, value) = $0

            if (value as? NSNull) != nil {
                record.setObject(nil, forKey: key)
                self.log.debug("  \(key): NSNull = \(String(describing: value))")
            }
            else if let val = value as? NSString {
                record.setObject(val, forKey: key)
                self.log.debug("  \(key): NSString = \(val)")
            }
            else if let val = value as? NSNumber {
                record.setObject(val, forKey: key)
                self.log.debug("  \(key): NSNumber = \(val)")
            }
            else if let val = value as? NSData {
                record.setObject(val, forKey: key)
                self.log.debug("  \(key): NSData = \(val)")
            }
            else if let val = value as? NSDate {
                record.setObject(val, forKey: key)
                self.log.debug("  \(key): NSDate = \(val)")
            }
            else if let val = value as? NSArray {
                record.setObject(val, forKey: key)
                self.log.debug("  \(key): NSArray = \(val)")
            }
            else if let val = value as? CLLocation {
                record.setObject(val, forKey: key)
                self.log.debug("  \(key): CLLocation = \(val)")
            }
            else if let val = value as? CKAsset {
                record.setObject(val, forKey: key)
                self.log.debug("  \(key): CKAsset = \(val)")
            }
            else if let val = value as? NSManagedObject {
                let targetid   = CKRecord.ID(recordName: val.idstr ?? "NO UUID")
                let reference  = CKRecord.Reference(recordID: targetid, action: .deleteSelf)
                self.log.debug("  \(key): CKReference = \(targetid)")

            }
            else if let val = value as? NSArray {
                let val2 = val.map { (elem: Any) -> (Any) in
                    if let val = elem as? NSManagedObject {
                        let targetid   = CKRecord.ID(recordName: val.idstr ?? "NO UUID")
                        let reference  = CKRecord.Reference(recordID: targetid, action: .deleteSelf)
                        self.log.debug("  \(key): CKReference = \(targetid)")
                        return reference
                    }
                    else {
                        return elem
                    }
                }
                record.setObject(val2 as CKRecordValue, forKey: key)
            }
            else if let val = value as? NSSet {
                let val2 = val.allObjects.map { (elem: Any) -> (Any) in
                    if let val = elem as? NSManagedObject {
                        let targetid   = CKRecord.ID(recordName: val.idstr ?? "NO UUID")
                        let reference  = CKRecord.Reference(recordID: targetid, action: .deleteSelf)
                        self.log.debug("  \(key): CKReference = \(targetid)")
                        return reference
                    }
                    else {
                        return elem
                    }
                }
                record.setObject(val2 as CKRecordValue, forKey: key)
            }
            else {
                self.log.debug("  \(key): UNKNOWN = \(String(describing: value))")
                assertionFailure("UNKOWN")
            }
        }
    }


    @objc func contextWillSave(notification: Notification) {
        self.log.debug("contextWillSave")
        guard let moc = notification.object as? NSManagedObjectContext else {
            assertionFailure()
            return
        }

        self.inserted = Array(moc.insertedObjects)
        self.deleted  = Array(moc.deletedObjects)
        self.updated  = moc.updatedObjects.map  { UpdatedObject( object: $0 ) }
    }

    @objc func contextDidSave(notification: Notification) {
        self.log.debug("contextDidSave")

        self.inserted.forEach  { obj in
            let recid   = CKRecord.ID(recordName: obj.idstr ?? "NO UUID")
            let rectype = obj.entity.name ?? "UNKOWN NAME"
            self.log.debug("[inserted] id = \(recid): type = \(rectype)")
            let record  = CKRecord(recordType: rectype, recordID: recid)
            self.setProperties(record: record, properties: obj.committedValues(forKeys: nil) )
        }

        self.updated.forEach { uobj in
            guard let obj: NSManagedObject = uobj.object else {
                assertionFailure()
                return
            }
            let recid   = CKRecord.ID(recordName: obj.idstr ?? "NO UUID")
            let rectype = obj.entity.name ?? "UNKOWN NAME"
            self.log.debug("[updated] id = \(recid): type = \(rectype)")
            let record  = CKRecord(recordType: rectype, recordID: recid)
            self.setProperties(record: record, properties: obj.committedValues(forKeys: uobj.keys) )
        }

        self.deleted.forEach { obj in
            let recid   = CKRecord.ID(recordName: obj.idstr ?? "NO UUID")
            let rectype = obj.entity.name ?? "UNKOWN NAME"
            self.log.debug("[deleted] id = \(recid): type = \(rectype)")
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
