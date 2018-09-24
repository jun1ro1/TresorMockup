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
    var recordID: CKRecord.ID?
    var record: CKRecord?

    init() {
        self.object   = nil
        self.keys     = []
        self.recordID = nil
        self.record   = nil
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
    fileprivate var changeToken: CKServerChangeToken?
    fileprivate var fetchChangeToken: CKServerChangeToken?
    fileprivate var zoneIDs: [CKRecordZone.ID]
    fileprivate var context: NSManagedObjectContext?

    var inserted: [NSManagedObject] = []
    var deleted:  [NSManagedObject] = []
    var updated:  [UpdatedObject]   = []

    override init() {
        //        super.init()
        self.bundleID  = Bundle.main.bundleIdentifier!
        self.container = CKContainer.default()
        self.database  = self.container.privateCloudDatabase
        self.zone      = CKRecordZone(zoneName: self.bundleID + "_Zone")
        self.changeToken = nil
        self.fetchChangeToken = nil
        self.zoneIDs   = []
        self.context   = nil
    }

    func start() {
        self.context = CoreDataManager.shared.managedObjectContext
        // Create a custom zone
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()

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
            dispatchGroup.leave()

            guard error == nil else {
                assertionFailure()
                return
            }
        }
        self.database.add(subscriptionOperation)
        dispatchGroup.notify(queue: DispatchQueue.global()) {
            self.log.debug("checkUpdates")
            self.checkUpdates()
        }
    }

    func checkUpdates() {
        let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: self.changeToken)
        operation.recordZoneWithIDChangedBlock = { (zone) in
            self.zoneIDs.append(zone)
        }

        operation.changeTokenUpdatedBlock = { (token) in
            self.changeToken = token
            self.log.debug("changeTokenUpdatedBlock token = \(token)")

        }

        operation.fetchDatabaseChangesCompletionBlock = { (token, more, error) in
            self.log.debug("fetchDatabaseChangesCompletionBlock error = \(String(describing: error))")
            self.log.debug("fetchDatabaseChangesCompletionBlock token = \(String(describing: token)) more = \(more)")
            guard error == nil && !self.zoneIDs.isEmpty else {
                assertionFailure()
                return
            }

            self.changeToken = token
            let options = CKFetchRecordZoneChangesOperation.ZoneOptions()
            options.previousServerChangeToken = self.fetchChangeToken
            let fetchOperaion = CKFetchRecordZoneChangesOperation(recordZoneIDs: self.zoneIDs, optionsByRecordZoneID: [self.zoneIDs[0]: options])
            fetchOperaion.recordChangedBlock = { (record) in
                self.log.debug("CKFetchRecordZoneChangesOperation record = \(record)")
                let recordID = record.recordID.recordName
                let request  = NSFetchRequest<NSFetchRequestResult>(entityName: record.recordType)
                request.predicate = NSPredicate(format: "uuid = %@", recordID)
                do {
                    self.log.debug("context fetch request = \(request)")
                    let result = try self.context?.fetch(request)
                    self.log.debug("context fetch result = \(String(describing: result))")
                    var obj: NSManagedObject?
                    if result == nil || result!.isEmpty {
                        let entityDesc = NSEntityDescription.entity(forEntityName: record.recordType, in: self.context!)
                        obj = NSManagedObject(entity: entityDesc!, insertInto: self.context)
                        self.context!.insert(obj!)
                    }
                    else {
                        obj = result![0] as? NSManagedObject
                    }
                    record.allKeys().forEach { (key) in
                        let val = record[key]
                        self.log.debug("recordChangedBlock setValue val = \(String(describing: val)) key = \(key)")
                        obj?.setValue(val, forKey: key)
                    }

                    self.log.debug("CKFetchRecordZoneChangesOperation obj = \(String(describing: obj))")
                }
                catch {
                    self.log.debug("context fetch = error")
                }

            }
            fetchOperaion.recordZoneChangeTokensUpdatedBlock = { (zoneID, token, data) in
                self.fetchChangeToken = token
            }
            fetchOperaion.recordZoneFetchCompletionBlock = { (zonID, token, data, more, error) in
                self.log.debug("recordZoneFetchCompletionBlock error = \(String(describing: error))")
            }
            fetchOperaion.fetchRecordZoneChangesCompletionBlock = { (error) in
                self.log.debug("fetchRecordZoneChangesCompletionBlock error = \(String(describing: error))")
            }
            self.database.add(fetchOperaion)
        }
        self.database.add(operation)
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
                let targetid   = CKRecord.ID(recordName: val.idstr ?? "NO UUID",
                                             zoneID: self.zone.zoneID)
                let reference  = CKRecord.Reference(recordID: targetid, action: .deleteSelf)
                self.log.debug("  \(key): CKReference = \(targetid) reference = \(reference)")

            }
            else if let val = value as? NSArray {
                let val2 = val.map { (elem: Any) -> (Any) in
                    if let val = elem as? NSManagedObject {
                        let targetid   = CKRecord.ID(recordName: val.idstr ?? "NO UUID",
                                                     zoneID: self.zone.zoneID)
                        let reference  = CKRecord.Reference(recordID: targetid, action: .deleteSelf)
                        self.log.debug("  \(key): CKReference = \(targetid)")
                        return reference
                    }
                    else {
                        return elem
                    }
                }
                record.setObject(val2.isEmpty ? nil : val2 as CKRecordValue, forKey: key)
            }
            else if let val = value as? NSSet {
                let val2 = val.allObjects.map { (elem: Any) -> (Any) in
                    if let val = elem as? NSManagedObject {
                        let targetid   = CKRecord.ID(recordName: val.idstr ?? "NO UUID",
                                                     zoneID: self.zone.zoneID)
                        let reference  = CKRecord.Reference(recordID: targetid, action: .deleteSelf)
                        self.log.debug("  \(key): CKReference = \(targetid)")
                        return reference
                    }
                    else {
                        return elem
                    }
                }
                record.setObject(val2.isEmpty ? nil : val2 as CKRecordValue, forKey: key)
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

        //        self.inserted = Array(moc.insertedObjects)
        self.deleted  = Array(moc.deletedObjects)
        self.updated  = moc.updatedObjects.map  { UpdatedObject( object: $0 ) }
            + moc.insertedObjects.map { UpdatedObject( object: $0 ) }
    }

    @objc func contextDidSave(notification: Notification) {
        self.log.debug("contextDidSave")

        var toSave:   [CKRecord]    = []
        var toDelete: [CKRecord.ID] = []

        //        self.inserted.forEach  { obj in
        //            let recid   = CKRecord.ID(recordName: obj.idstr ?? "NO UUID",
        //                                      zoneID: self.zone.zoneID)
        //            let rectype = obj.entity.name ?? "UNKOWN NAME"
        //            self.log.debug("[inserted] id = \(recid): type = \(rectype)")
        //            let record  = CKRecord(recordType: rectype, recordID: recid)
        //            self.setProperties(record: record, properties: obj.committedValues(forKeys: nil) )
        //            toSave.append(record)
        //        }

        // records to be deleted
        self.deleted.forEach { obj in
            let recid   = CKRecord.ID(recordName: obj.idstr ?? "NO UUID",
                                      zoneID: self.zone.zoneID)
            let rectype = obj.entity.name ?? "UNKOWN NAME"
            self.log.debug("[deleted] id = \(recid): type = \(rectype)")
            toDelete.append(recid)
        }

        // set recordID
        self.updated.forEach { uobj in
            guard let obj: NSManagedObject = uobj.object else {
                assertionFailure()
                return
            }
            uobj.recordID = CKRecord.ID(recordName: obj.idstr ?? "NO UUID",
                                        zoneID: self.zone.zoneID)
        }

        let fetchOperation = CKFetchRecordsOperation(recordIDs: self.updated.map { $0.recordID! })
        fetchOperation.fetchRecordsCompletionBlock = { (records, error) in
            self.log.debug("CKFetchRecordsOperation error = \(String(describing: error))")
            records?.forEach { (id, record) in
                let uobj = self.updated.first(where: { $0.recordID == id })
                if uobj != nil {
                    uobj?.record = record
                }
            }
            self.updated.forEach {
                if $0.record == nil {
                    $0.record = CKRecord(recordType: $0.object!.entity.name ?? "UNKOWN NAME",
                                         recordID: $0.recordID!)
                }
            }

            self.updated.forEach { uobj in
                guard let obj: NSManagedObject = uobj.object else {
                    assertionFailure()
                    return
                }
                let record  = uobj.record!
                self.setProperties(record: record, properties: obj.committedValues(forKeys: uobj.keys) )
                toSave.append(record)
            }

            self.log.debug( "CKModifyRecordsOperation save = \(String(describing: toSave))" )
            self.log.debug( "CKModifyRecordsOperation delete = \(String(describing: toDelete))" )

            let operation = CKModifyRecordsOperation(recordsToSave: toSave,
                                                     recordIDsToDelete: toDelete)
            operation.modifyRecordsCompletionBlock = { (save, delete, error) in
                self.log.debug("CKModifyRecordsOperation error = \(String(describing: error))")
                if error != nil {
                    self.log.error( "CKModifyRecordsOperation error save = \(String(describing: save))" )
                    self.log.error( "CKModifyRecordsOperation error delete = \(String(describing: delete))" )
                }
            }
            self.inserted = []
            self.deleted  = []
            self.updated  = []

            self.database.add(operation)
        }
        self.database.add(fetchOperation)

    }
}

extension NSManagedObject {
    var idstr: String? {
        return self.value(forKey: "uuid") as? String
    }
}
