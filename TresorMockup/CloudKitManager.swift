//
//  CloudKitManager.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/07/14.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//
//  J.D Gauchat "iCloud and CloudKit in iOS"
//  http://www.formasterminds.com/quick_guides_for_masterminds/guide.php?id=57

import UIKit
import CoreData
import CoreLocation
import CloudKit
import SwiftyBeaver

// https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitQuickStart/MaintainingaLocalCacheofCloudKitRecords/MaintainingaLocalCacheofCloudKitRecords.html#//apple_ref/doc/uid/TP40014987-CH12-SW1

// http://app-craft.com/cloudkit-同期（２）/

class CloudKitManager: NSObject {
    static      var shared: CloudKitManager = CloudKitManager()

    static      let CLOUDKIT_MANAGER_UPDATE_INTERFACE = "CLOUDKIT_CHANGED_UPDATE_INTERFACE"
    static      let CLOUDKIT_MANAGER_UPDATED          = "UPDATED"
    static      let CLOUDKIT_MANAGER_DELETED          = "DELETED"

    fileprivate var container: CKContainer
    fileprivate var database:  CKDatabase
    fileprivate var zone:      CKRecordZone
    fileprivate var bundleID:  String
    fileprivate var log = SwiftyBeaver.self
    fileprivate var changeToken: CKServerChangeToken?
    fileprivate var fetchChangeToken: CKServerChangeToken?
    fileprivate var zoneIDs: [CKRecordZone.ID]
    fileprivate var subscriptionID: CKSubscription.ID
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
        self.subscriptionID = self.bundleID
        self.context   = nil
    }

    func start() {
        self.context = CoreDataManager.shared.managedObjectContext
        // Create a custom zone
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()

        // Create a fetch zones operation
        let fetchZonesOperation = CKFetchRecordZonesOperation(recordZoneIDs: [self.zone.zoneID])
        let fetchSubscriptionOperation = CKFetchSubscriptionsOperation(subscriptionIDs: [self.subscriptionID])
        fetchSubscriptionOperation.addDependency(fetchZonesOperation)

        fetchZonesOperation.fetchRecordZonesCompletionBlock = { (zoneIDs, error) in
            self.log.debug("CKFetchRecordZonesOperation error = \(String(describing: error))")
            self.log.debug("CKFetchRecordZonesOperation zonIDs = \(String(describing: zoneIDs))")

            if zoneIDs == nil || zoneIDs!.values.isEmpty {
                let createZoneOperation =
                    CKModifyRecordZonesOperation(
                        recordZonesToSave: [self.zone], recordZoneIDsToDelete: [])
                createZoneOperation.modifyRecordZonesCompletionBlock = {
                    (saved, deleted, error) in
                    self.log.debug("CKModifyRecordZonesOperation error = \(String(describing: error))")
                    guard error == nil else {
                        assertionFailure()
                        return
                    }
                }
                fetchSubscriptionOperation.addDependency(createZoneOperation)
                self.database.add(createZoneOperation)
            }
        }
        self.database.add(fetchZonesOperation)

        // Subscribing to Change Notifications
        fetchSubscriptionOperation.fetchSubscriptionCompletionBlock = {
            (subscriptions, error) in
            self.log.debug("CKFetchSubscriptionsOperation error = \(String(describing: error))")
            self.log.debug("CKFetchSubscriptionsOperation subscriptions = \(String(describing: subscriptions))")

            if error != nil || subscriptions?[self.subscriptionID] == nil {
                let subscription = CKDatabaseSubscription(subscriptionID: self.bundleID)
                subscription.notificationInfo = CKSubscription.NotificationInfo()
                subscription.notificationInfo?.shouldSendContentAvailable = true
                let modifySubscriptionOperation =
                    CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
                modifySubscriptionOperation.modifySubscriptionsCompletionBlock = {
                    (subscriptions, deletedIDs, error) in
                    self.log.debug("CKModifySubscriptionsOperation error = \(String(describing: error))")
                    dispatchGroup.leave()
                }

            }
            else {
                dispatchGroup.leave()
            }

        }
        self.database.add(fetchSubscriptionOperation)

        dispatchGroup.notify(queue: DispatchQueue.global()) {
            self.log.debug("checkUpdates")
            self.checkUpdates()
        }
    }

    func checkUpdates() {
        // MARK:  CKFetchDatabaseChangesOperation
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

            // MARK: CKFetchRecordZoneChangesOperation
            let recordOperation = CKFetchRecordZoneChangesOperation(recordZoneIDs: self.zoneIDs, optionsByRecordZoneID: [self.zoneIDs[0]: options])

            recordOperation.recordChangedBlock = { (record) in
                self.log.debug("CKFetchRecordZoneChangesOperation recordID = \(record.recordID.recordName)")
                var mocr = ManagedObjectCloudRecord(cloudRecord: record)
                mocr.mode.insert(.save)
                changes[(mocr.recordID?.recordName)!] = mocr
            }

            recordOperation.recordWithIDWasDeletedBlock = { (recordID, recordType) in
                self.log.debug("recordWithIDWasDeletedBlock recordID = \(recordID.recordName) recordType = \(recordType)")
                let id = recordID.recordName
                if changes[id] == nil {
                    changes[id] = ManagedObjectCloudRecord(recordID: recordID, recordType: recordType)
                }
                changes[id]!.mode.insert(.delete)
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

                let recordTypes = Set( changes.values.compactMap { $0.recordType } )
                self.log.debug("recordTypes = \(recordTypes)")

                for recordType in recordTypes {
                    let recordIDs: [String] =
                        changes.values.filter { $0.recordType == recordType }
                            .compactMap { return $0.recordID?.recordName }
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
                            if changes[$0]?.managedObject == nil {
                                guard changes[$0]?.mode != [.delete] else {
                                    return
                                }
                                let entityDesc = NSEntityDescription.entity(forEntityName: recordType, in: self.context!)
                                changes[$0]?.managedObject =
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
                        continue
                    }
                    guard let object = mocr.managedObject else {
                        continue
                    }

                    record.allKeys().forEach { (key) in
                        if record[key] is [CKRecord.Reference] {
                            guard object.value(forKey: key) is NSSet else {
                                self.log.error("Is not Set object = \(object) key = \(key)")
                                return
                            }
                            let method: String = "add"
                                + String(key.first!).uppercased()
                                + String(key.dropFirst())
                                + ":"
                            let selector: Selector = Selector(method)
                            guard object.responds(to: selector) else {
                                self.log.error("Dose not respond object = \(object) selector = \(method)")
                                return
                            }
                            let refs = record[key] as! [CKRecord.Reference]
                            let objs: [NSManagedObject]  = refs.compactMap {
                                let id = $0.recordID.recordName
                                let obj = changes[id]?.managedObject
                                if obj == nil {
                                    self.log.error("referenced ID is not found id = \(id)")
                                }
                                return obj
                            }
                            let sets: NSSet = NSSet(array: objs)
                            object.perform(selector, with: sets)
                         }
                        else if record[key] is CKRecord.Reference {
                            let ref = record[key] as! CKRecord.Reference
                            let id  = ref.recordID.recordName
                            if let obj: NSManagedObject = changes[id]?.managedObject {
                                self.log.debug("recordChangedBlock setPrimitiveValue refrenced = \(String(describing: obj)) key = \(key)")
                                object.setPrimitiveValue(obj, forKey: key)
                            }
                            else {
                                self.log.error("recordChangedBlock setPrimitiveValue refrenced not found = \(id)")
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

                let dels: [NSManagedObject] = changes.values.compactMap {
                    $0.mode.contains(.delete) ? $0.managedObject : nil
                }
                dels.forEach {
                    self.log.debug("delete idstr = \(String(describing: $0.idstr))")
                    self.context!.delete($0)
                }

                let debugstr: String = changes.values.map {
                    return [
                        $0.recordID!.recordName,
                        $0.recordType,
                        $0.mode.String,
                        ($0.managedObject == nil ? "nil" : "nonnil")
                        ].reduce("", { $0 + " " + $1})
                    }.reduce("", { $0 + $1 + "\n" })
                self.log.debug("changes = \n\(debugstr)")

                do {
                    try self.context!.save()
                }
                catch {
                    self.log.debug("context.save error")
                }

                let center = NotificationCenter.default
                let name   = Notification.Name(rawValue: CloudKitManager.CLOUDKIT_MANAGER_UPDATE_INTERFACE)
                let userInfo: [AnyHashable: Any] =
                    [ CloudKitManager.CLOUDKIT_MANAGER_DELETED:
                        changes.values.compactMap {
                            $0.mode.contains(.delete) ? $0.cloudRecord : nil },
                      CloudKitManager.CLOUDKIT_MANAGER_UPDATED:
                        changes.values.compactMap {
                            $0.mode == [.save] ? $0.cloudRecord : nil }
                        ]
                center.post(name: name, object: self, userInfo: userInfo)
            }

            recordOperation.recordZoneChangeTokensUpdatedBlock = { (zoneID, token, data) in
                self.log.debug("recordZoneChangeTokensUpdatedBlock token = \(String(describing: token))")
                self.log.debug("recordZoneChangeTokensUpdatedBlock data = \(String(describing: data))")
                self.fetchChangeToken = token
            }

            recordOperation.recordZoneFetchCompletionBlock = { (zoneID, token, data, more, error) in
                self.log.debug("recordZoneFetchCompletionBlock error = \(String(describing: error))")
                self.log.debug("recordZoneFetchCompletionBlock token = \(String(describing: token))")
                self.log.debug("recordZoneFetchCompletionBlock data = \(String(describing: data))")
                self.fetchChangeToken = token
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
            self.log.debug("[deleted] id = \(recid.recordName): type = \(rectype)")
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
            mocr.mode.insert(.save)
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
                    let targetid: String   = val.idstr ?? "NO UUID"
                    referenced.append(targetid)
                    self.log.debug("\(val.entity.name ?? "").\(key): referenced = \(targetid)")
                }
                else if let vals = obj.value(forKey: key) as? NSArray {
                    vals.forEach {
                        if let val = $0 as? NSManagedObject {
                            let targetid: String  = val.idstr ?? "NO UUID"
                            referenced.append(targetid)
                            self.log.debug("\(val.entity.name ?? "").\(key): referenced = \(targetid)")
                        }
                    }
                }
                else if let vals = obj.value(forKey: key) as? NSSet {
                    vals.allObjects.forEach {
                        if let val = $0 as? NSManagedObject {
                            let targetid: String  = val.idstr ?? "NO UUID"
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
                var mocr = ManagedObjectCloudRecord(recordID: recid)
                mocr.mode.insert(.save)
                managedObjectCloudRecordRelations[ref] = mocr
                self.log.debug("reference inserted = \(ref)")
            }
        }

        managedObjectCloudRecordRelations.keys.forEach {
            let mocr = managedObjectCloudRecordRelations[$0]
            self.log.debug("key = \($0)\nmocr = \(String(describing: mocr))\n")
            assert(mocr?.mode != [])
        }

        let recordIDs = managedObjectCloudRecordRelations.values.compactMap {
            $0.mode.contains(.save) ? $0.recordID! : nil
        }
        self.log.debug("recordIDs = \(recordIDs)")
        let fetchRecordsOperation = CKFetchRecordsOperation(
            recordIDs: recordIDs
        )

        fetchRecordsOperation.fetchRecordsCompletionBlock = { (records, error) in
            self.log.debug("CKFetchRecordsOperation fetchRecordsCompletionBlock error = \(String(describing: error))")
            guard records != nil else {
                assertionFailure()
                return
            }
            if records!.isEmpty {
                self.log.info("CKFetchRecordsOperation fetchRecordsCompletionBlock records = empty")
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
//                    assertionFailure()
                    continue
                }
                guard let record = mocr.cloudRecord else {
//                    assertionFailure()
                    continue
                }
                guard let obj = mocr.managedObject else {
//                    assertionFailure()
                    continue
                }
                self.setProperties(record: record,
                                   properties: obj.committedValues(forKeys: mocr.keys) )
            }

            toSave = managedObjectCloudRecordRelations.values.compactMap { $0.cloudRecord }

            self.log.debug( "fetchRecordsCompletionBlock toSave = \(String(describing: toSave))" )
            self.log.debug( "fetchRecordsCompletionBlock toDelete = \(String(describing: toDelete))" )

            let modifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: toSave,
                                                                  recordIDsToDelete: toDelete)
            modifyRecordsOperation.modifyRecordsCompletionBlock = { (save, delete, error) in
                self.log.debug("CKModifyRecordsOperation modifyRecordsCompletionBlock error = \(String(describing: error))")
                self.log.debug( "CKModifyRecordsOperation modifyRecordsCompletionBlock save = \(String(describing: save))" )
                self.log.debug( "CKModifyRecordsOperation modifyRecordsCompletionBlock delete = \(String(describing: delete))" )

            }

            modifyRecordsOperation.perRecordCompletionBlock = { (record, error) in
                self.log.debug("CKModifyRecordsOperation perRecordCompletionBlock record = \(record) error = \(String(describing: error))")
            }

            modifyRecordsOperation.addDependency(fetchRecordsOperation)
            self.database.add(modifyRecordsOperation)
        }
        self.database.add(fetchRecordsOperation)
    }

    func setProperties(record: CKRecord, properties:[String: Any?]) {
        properties.forEach {
            let (key, value) = $0
            let oldval = record.object(forKey: key)

            if (value as? NSNull) != nil {
                if oldval != nil {
                    record.setObject(nil, forKey: key)
                    self.log.debug("  \(key): NSNull = \(String(describing: value))")
                }
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
                let newref = val.idstr ?? "NO UUID"
                let oldref = (oldval as? CKRecord.Reference)
                if  oldref == nil || oldref!.recordID.recordName != newref {
                    let targetid   = CKRecord.ID(recordName: newref,
                                                 zoneID: self.zone.zoneID)
                    let reference  = CKRecord.Reference(recordID: targetid, action: .none)
                    record.setObject(reference, forKey: key)
                    self.log.debug("  \(key): CKReference = \(targetid) reference = \(reference)")
                }
            }
            else if let vals = value as? NSArray {
                let valsary = vals.map { (elem: Any) -> (Any) in
                    if let val = elem as? NSManagedObject {
//                        let newref = val.idstr ?? "NO UUID"
//                        let oldref = (oldval as? CKRecord.Reference)
//                        if  oldref == nil || oldref!.recordID.recordName != newref {
//                            let targetid   = CKRecord.ID(recordName: newref,
//                                                         zoneID: self.zone.zoneID)
//                            let reference  = CKRecord.Reference(recordID: targetid, action: .none)
//                            record.setObject(reference, forKey: key)
//                            self.log.debug("  \(key): CKReference = \(targetid) reference = \(reference)")
//                        }
//
//
                        let targetid   = CKRecord.ID(recordName: val.idstr ?? "NO UUID",
                                                     zoneID: self.zone.zoneID)
                        let reference  = CKRecord.Reference(recordID: targetid, action: .none)
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
                        let reference  = CKRecord.Reference(recordID: targetid, action: .none)
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
fileprivate struct OperationMode: OptionSet {
    let rawValue: Int

    static let save   = OperationMode(rawValue: 1 << 0)
    static let delete = OperationMode(rawValue: 1 << 1)

    public var String: String {
        var s = ""
        switch self {
        case .save:   s = "save"
        case .delete: s = "delete"
        default:      s = "UNKNOWN"
        }
        return s
    }
}

fileprivate struct ManagedObjectCloudRecord {
    var recordID:      CKRecord.ID?
    var managedObject: NSManagedObject?
    var keys:          [String]
    var _cloudRecord:  CKRecord?

    var recordType:    CKRecord.RecordType
    var mode:          OperationMode

    init() {
        self.recordID      = nil
        self.managedObject = nil
        self.keys          = []
        self._cloudRecord  = nil
        self.recordType    = "UNKNOWN_RECORD_TYPE"
        self.mode          = []
    }

    init(managedObject: NSManagedObject) {
        self.init()
        self.managedObject = managedObject
    }

    init(cloudRecord: CKRecord) {
        self.init()
        self.recordID    = cloudRecord.recordID
        self.cloudRecord = cloudRecord
        self.recordType  = cloudRecord.recordType
    }

    init(recordID: CKRecord.ID) {
        self.init()
        self.recordID = recordID
    }

    init(recordID: CKRecord.ID, recordType: CKRecord.RecordType) {
        self.init()
        self.recordID   = recordID
        self.recordType = recordType
    }

    var cloudRecord:   CKRecord? {
        get {
            return self._cloudRecord
        }
        set {
            self._cloudRecord = newValue
            self.recordType   = newValue?.recordType ?? "UNKNOWN_RECORD_TYPE"
        }
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


