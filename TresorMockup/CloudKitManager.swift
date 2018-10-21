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

    fileprivate var deleted:  [NSManagedObject] = []
    fileprivate var updated:  [UpdatedObject]   = []

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
        let databaseOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: self.changeToken)
        databaseOperation.recordZoneWithIDChangedBlock = { (zone) in
            self.zoneIDs.append(zone)
            self.log.debug("recordZoneWithIDChangedBlock zone = \(zone)")
        }

        databaseOperation.changeTokenUpdatedBlock = { (token) in
            self.changeToken = token
            self.log.debug("changeTokenUpdatedBlock token = \(token)")
        }

        databaseOperation.fetchDatabaseChangesCompletionBlock = { (token, more, error) in
            self.log.debug("fetchDatabaseChangesCompletionBlock error = \(String(describing: error))")
            self.log.debug("fetchDatabaseChangesCompletionBlock token = \(String(describing: token)) more = \(more)")
            guard error == nil && !self.zoneIDs.isEmpty else {
                self.log.debug("fetchDatabaseChangesCompletionBlock self.zonIDs is empty")
                return
            }
            self.changeToken = token

            var changes: [String: ManagedObjectCloudRecord] = [:]
            let options = CKFetchRecordZoneChangesOperation.ZoneOptions()
            options.previousServerChangeToken = self.fetchChangeToken
            let recordOperation = CKFetchRecordZoneChangesOperation(recordZoneIDs: self.zoneIDs, optionsByRecordZoneID: [self.zoneIDs[0]: options])
            recordOperation.recordChangedBlock = { (record) in
                self.log.debug("CKFetchRecordZoneChangesOperation record = \(record)")
                let mocr = ManagedObjectCloudRecord(cloudRecord: record)
                changes[(mocr.recordID?.recordName)!] = mocr
            }
            recordOperation.fetchRecordZoneChangesCompletionBlock = { (error) in
                self.log.debug("fetchRecordZoneChangesCompletionBlock error = \(String(describing: error))")

                var refered: [String] = []
                for mocr in changes.values {
                    guard let record = mocr.cloudRecord else {
                        continue
                    }
                    for key in record.allKeys() {
                        if let ref = record[key] as? CKRecord.Reference {
                            refered.append(ref.recordID.recordName)
                        }
                        else if let refs = record[key] as? [CKRecord.Reference] {
                            refered.append(contentsOf: refs.map { $0.recordID.recordName })
                        }
                    }
                }
                refered.forEach {
                    if changes[$0] == nil {
                        let recordID =  CKRecord.ID(recordName: $0, zoneID: self.zone.zoneID)
                        changes[$0] = ManagedObjectCloudRecord(recordID: recordID)
                    }
                }

                let recordTypes = Set( changes.values.compactMap { $0.cloudRecord?.recordType } )
                self.log.debug("recordTypes = \(recordTypes)")

                for recordType in recordTypes {
                    let recordIDs =
                        changes.values.filter { $0.cloudRecord?.recordType == recordType }
                            .compactMap { return $0.recordID }
                    self.log.debug("recordType = \(recordType) recordIDs = \(recordIDs)")

                    let request  = NSFetchRequest<NSFetchRequestResult>(entityName: recordType)
                    request.predicate = NSPredicate(format: "uuid IN %@", recordIDs)

                    do {
                        self.log.debug("context fetch request = \(request)")
                        let result: [NSManagedObject]? = try (self.context?.fetch(request) as? [NSManagedObject])
                        self.log.debug("context fetch result = \(String(describing: result))")

                        result?.forEach {
                            guard let idstr = $0.idstr else {
                                return
                            }
                            changes[idstr]?.managedObject = $0
                        }
                        recordIDs.forEach {
                            if changes[$0.recordName]?.managedObject == nil {
                                let entityDesc = NSEntityDescription.entity(forEntityName: recordType, in: self.context!)
                                changes[$0.recordName]?.managedObject =
                                    NSManagedObject(entity: entityDesc!, insertInto: self.context)
                            }
                        }
                     }
                    catch {
                        self.log.debug("fetch error")
                    }
                }
                for id in changes.keys {
                    guard let mocr = changes[id] else {
                        assertionFailure()
                        continue
                    }
                    guard let record = mocr.cloudRecord else {
                        assertionFailure()
                        continue
                    }
                    guard let object = mocr.managedObject else {
                        assertionFailure()
                        continue
                    }

                    record.allKeys().forEach { (key) in
                        if record[key] is [CKRecord.Reference] {
//                            object.value(forKey: key) is NSSet {
//                            let refs = (record[key] as! [CKRecord.Reference]).map {
//                                let recordID = $0.recordID.recordName
//
//                            }
//                            (object.value(forKey: key) as NSSet).addingObjects(from:
//                            )
                            let vals = record[key]! as [CKRecord.Reference]
                            vals.forEach { (ref) in
                                self.log.debug("reference = \(ref.recordID)")
                            }
                        }
                        else if let val = record[key] {
                            self.log.debug("recordChangedBlock setPrimitiveValue val = \(String(describing: val)) key = \(key)")
                            object.setPrimitiveValue(val, forKey: key)
                        }
                        else {
                            object.setPrimitiveValue(nil, forKey: key)
                        }
                    }
                    self.log.debug("CKFetchRecordZoneChangesOperation obj = \(String(describing: object ))")
                }

                do {
                    try self.context!.save()
                }
                catch {
                    self.log.debug("context.save error")
                }
            }
            recordOperation.recordZoneChangeTokensUpdatedBlock = { (zoneID, token, data) in
                self.fetchChangeToken = token
            }
            recordOperation.recordZoneFetchCompletionBlock = { (zonID, token, data, more, error) in
                self.log.debug("recordZoneFetchCompletionBlock error = \(String(describing: error))")
            }
            self.database.add(recordOperation)
        }
        self.database.add(databaseOperation)
    }


    func addObserver( managedObjectContext moc: NSManagedObjectContext?) {
        NotificationCenter.default.addObserver(self, selector: #selector(contextWillSave(notification:)), name: NSNotification.Name.NSManagedObjectContextWillSave, object: moc)

        NotificationCenter.default.addObserver(self, selector: #selector(contextDidSave(notification:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: moc)
    }


    @objc func contextWillSave(notification: Notification) {
        self.log.debug("contextWillSave")
        guard let moc = notification.object as? NSManagedObjectContext else {
            assertionFailure()
            return
        }

        self.deleted  = Array(moc.deletedObjects)
        self.updated  =
            moc.updatedObjects.map  { UpdatedObject( object: $0 ) }
            + moc.insertedObjects.map { UpdatedObject( object: $0 ) }
    }

    @objc func contextDidSave(notification: Notification) {
        self.log.debug("contextDidSave notification = \(notification)")

        var toDelete: [CKRecord.ID] = []
        var toSave:   [CKRecord]    = []

        var managedObjectCloudRecordRelations: [String: ManagedObjectCloudRecord] = [:]

        // records to be deleted
        toDelete = self.deleted.map {
            let recid   = CKRecord.ID(recordName: $0.idstr ?? "NO UUID",
                                      zoneID: self.zone.zoneID)
            let rectype = $0.entity.name ?? "UNKOWN NAME"
            self.log.debug("[deleted] id = \(recid): type = \(rectype)")
            return recid
        }
        self.deleted = []

        // set managedObjectCloudRecordRelations
        self.updated.forEach { uobj in
            guard let obj: NSManagedObject = uobj.object else {
                assertionFailure()
                return
            }
            guard let id = obj.idstr else {
                assertionFailure()
                return
            }
            var mocr = ManagedObjectCloudRecord(managedObject: obj)
            mocr.recordID = CKRecord.ID(recordName: id, zoneID: self.zone.zoneID)
            mocr.keys     = uobj.keys
            managedObjectCloudRecordRelations[id] = mocr
        }
        self.updated  = []

        var referenced: [String] = []
        managedObjectCloudRecordRelations.keys.forEach {
            let mocr = managedObjectCloudRecordRelations[$0]
            guard let obj  = mocr?.managedObject else {
                return
            }
            mocr?.keys.forEach { (key) in
                if let val = obj.value(forKey: key) as? NSManagedObject {
                    let targetid   = val.idstr ?? "NO UUID"
                    referenced.append(targetid)
                    self.log.debug("\(val.entity.name ?? "").\(key): referenced = \(targetid)")
                }
                else if let vals = obj.value(forKey: key) as? NSArray {
                    vals.forEach {
                        if let val = $0 as? NSManagedObject {
                            let targetid   = val.idstr ?? "NO UUID"
                            referenced.append(targetid)
                            self.log.debug("\(val.entity.name ?? "").\(key): referenced = \(targetid)")
                        }
                    }
                }
                else if let vals = obj.value(forKey: key) as? NSSet {
                    vals.allObjects.forEach {
                        if let val = $0 as? NSManagedObject {
                            let targetid   = val.idstr ?? "NO UUID"
                            referenced.append(targetid)
                            self.log.debug("\(val.entity.name ?? "").\(key): referenced = \(targetid)")
                        }
                    }
                }
            }
        }
        referenced.forEach { (ref) in
            if managedObjectCloudRecordRelations[ref] == nil {
                let recid   = CKRecord.ID(recordName: ref,
                                          zoneID: self.zone.zoneID)
                let mocr = ManagedObjectCloudRecord(recordID: recid)
                managedObjectCloudRecordRelations[ref] = mocr
                self.log.debug("reference inserted = \(ref)")
            }
        }

        managedObjectCloudRecordRelations.keys.forEach {
            let mocr = managedObjectCloudRecordRelations[$0]
            self.log.debug("key = \($0)\nmocr = \(String(describing: mocr))\n")
        }

        let recordIDs = managedObjectCloudRecordRelations.values.map { $0.recordID! }
        self.log.debug("recordIDs = \(recordIDs)")
        let fetchRecordsOperation = CKFetchRecordsOperation(
            recordIDs: recordIDs
        )
        fetchRecordsOperation.fetchRecordsCompletionBlock = { (records, error) in
            self.log.debug("CKFetchRecordsOperation error = \(String(describing: error))")
            guard records != nil else {
                assertionFailure()
                return
            }
            guard !records!.isEmpty else {
                self.log.info("records = empty")
                return
            }
            for key in managedObjectCloudRecordRelations.keys {
                guard let mocr = managedObjectCloudRecordRelations[key] else {
                    assertionFailure()
                    continue
                }
                guard let recordID = mocr.recordID else {
                    assertionFailure()
                    continue
                }
                if let record = records![recordID] {
                    // the cloud record whose recordID is is found
                    managedObjectCloudRecordRelations[key]!.cloudRecord = record
                }
                else {
                    // a cloud record is not found then create it
                    managedObjectCloudRecordRelations[key]!.cloudRecord =
                        CKRecord(recordType: mocr.managedObject!.entity.name ?? "UNKNOWN NAME",
                                 recordID: mocr.recordID!)
                }
            }

            for key in managedObjectCloudRecordRelations.keys {
                guard let mocr = managedObjectCloudRecordRelations[key] else {
                    assertionFailure()
                    continue
                }
                guard let record = mocr.cloudRecord else {
                    assertionFailure()
                    continue
                }
                guard let obj = mocr.managedObject else {
                    assertionFailure()
                    continue
                }
                self.setProperties(record: record,
                                   properties: obj.committedValues(forKeys: mocr.keys) )
            }

            toSave = managedObjectCloudRecordRelations.values.compactMap { $0.cloudRecord }

            self.log.debug( "CKModifyRecordsOperation save = \(String(describing: toSave))" )
            self.log.debug( "CKModifyRecordsOperation delete = \(String(describing: toDelete))" )
        }

        let modifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: toSave,
                                                              recordIDsToDelete: toDelete)
        modifyRecordsOperation.modifyRecordsCompletionBlock = { (save, delete, error) in
            self.log.debug("CKModifyRecordsOperation error = \(String(describing: error))")
            if error != nil {
                self.log.error( "CKModifyRecordsOperation error save = \(String(describing: save))" )
                self.log.error( "CKModifyRecordsOperation error delete = \(String(describing: delete))" )
            }
        }

        modifyRecordsOperation.addDependency(fetchRecordsOperation)
        self.database.add(fetchRecordsOperation)
        self.database.add(modifyRecordsOperation)
    }

    func setProperties(record: CKRecord, properties:[String: Any?]) {
        properties.forEach {
            let (key, value) = $0
            let oldval = record.object(forKey: key)

            if (value as? NSNull) != nil {
                record.setObject(nil, forKey: key)
                self.log.debug("  \(key): NSNull = \(String(describing: value))")
            }
            else if let val = value as? NSString {
                if oldval == nil || val != oldval as? NSString {
                    record.setObject(val, forKey: key)
                    self.log.debug("  \(key): NSString = \(val)")
                }
            }
            else if let val = value as? NSNumber {
                if oldval == nil || val != oldval as? NSNumber {
                    record.setObject(val, forKey: key)
                    self.log.debug("  \(key): NSNumber = \(val)")
                }
            }
            else if let val = value as? NSData {
                if oldval == nil || val != oldval as? NSData {
                    record.setObject(val, forKey: key)
                    self.log.debug("  \(key): NSData = \(val)")
                }
            }
            else if let val = value as? NSDate {
                if oldval == nil || val != oldval as? NSDate {
                    record.setObject(val, forKey: key)
                    self.log.debug("  \(key): NSDate = \(val)")
                }
            }
            else if let val = value as? NSArray {
                if oldval == nil || val != oldval as? NSArray {
                    record.setObject(val, forKey: key)
                    self.log.debug("  \(key): NSArray = \(val)")
                }
            }
            else if let val = value as? CLLocation {
                if oldval == nil || val != oldval as? CLLocation {
                    record.setObject(val, forKey: key)
                    self.log.debug("  \(key): CLLocation = \(val)")
                }
            }
            else if let val = value as? CKAsset {
                if oldval == nil || val != oldval as? CKAsset {
                    record.setObject(val, forKey: key)
                    self.log.debug("  \(key): CKAsset = \(val)")
                }
            }
            else if let val = value as? NSManagedObject {
                let targetid   = CKRecord.ID(recordName: val.idstr ?? "NO UUID",
                                             zoneID: self.zone.zoneID)
                let reference  = CKRecord.Reference(recordID: targetid, action: .deleteSelf)
                record.setObject(reference, forKey: key)
                self.log.debug("  \(key): CKReference = \(targetid) reference = \(reference)")
            }
            else if let vals = value as? NSArray {
                let valsary = vals.map { (elem: Any) -> (Any) in
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
                record.setObject(valsary.isEmpty ? nil : valsary as CKRecordValue, forKey: key)
            }
            else if let vals = value as? NSSet {
                let valsary = vals.allObjects.map { (elem: Any) -> (Any) in
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
                record.setObject(valsary.isEmpty ? nil : valsary as CKRecordValue, forKey: key)
            }
            else {
                self.log.debug("  \(key): UNKNOWN = \(String(describing: value))")
                assertionFailure("UNKOWN")
            }
        }
    }

}

// MARK: - Structures
fileprivate struct ManagedObjectCloudRecord {
    var recordID:      CKRecord.ID?
    var managedObject: NSManagedObject?
    var keys:          [String]
    var cloudRecord:   CKRecord?

    init() {
        self.recordID      = nil
        self.managedObject = nil
        self.keys          = []
        self.cloudRecord   = nil
    }

    init(managedObject: NSManagedObject) {
        self.init()
        self.managedObject = managedObject
    }

    init(cloudRecord: CKRecord) {
        self.init()
        self.recordID    = cloudRecord.recordID
        self.cloudRecord = cloudRecord
    }

    init(recordID: CKRecord.ID) {
        self.init()
        self.recordID = recordID
    }

}

fileprivate struct UpdatedObject {
    var object: NSManagedObject?
    var keys: [String]

    init() {
        self.object   = nil
        self.keys     = []
    }

    init(object: NSManagedObject?) {
        self.init()
        self.object = object
        self.keys   = object?.changedValues().map { $0.key } ?? []
    }
}


// MARK: - Extensions
fileprivate extension NSManagedObject {
    var idstr: String? {
        return self.value(forKey: "uuid") as? String
    }
}


