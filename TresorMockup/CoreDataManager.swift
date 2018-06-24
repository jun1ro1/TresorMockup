//
//  CoreDataManager.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/06/22.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//
// Reference
// Marcus S. Zarra "Core Data in Swift" The Pragmatic Bookshelf


import UIKit
import CoreData

class CoreDataManager: NSObject {
    private static var _manager: CoreDataManager? = nil
    static var shared: CoreDataManager = {
        if _manager == nil {
            _manager = CoreDataManager()
        }
        return _manager!
    }()

    private var _managedObjectContext: NSManagedObjectContext? = nil
    lazy var managedObjectContext: NSManagedObjectContext = {
        if self._managedObjectContext != nil {
            return self._managedObjectContext!
        }
        let coordinator = self.persistentStoreCoordinator
        let moc = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        moc.performAndWait {
            moc.persistentStoreCoordinator = coordinator
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(mergeChnagesFrom_iCloud),
                name: NSNotification.Name.NSPersistentStoreDidImportUbiquitousContentChanges,
                object: coordinator)
        }
        self._managedObjectContext = moc
        return self._managedObjectContext!
    }()

    private var _managedObjectModel: NSManagedObjectModel? = nil
    lazy var managedObjectModel: NSManagedObjectModel = {
        if self._managedObjectModel != nil {
            return self._managedObjectModel!
        }
        let bundles = [Bundle(for: type(of: self))]
        print("bundles = \(bundles)")
        self._managedObjectModel = NSManagedObjectModel.mergedModel(from: bundles)
        print("_managedObjectModel = \(String(describing: self._managedObjectModel))")
        return self._managedObjectModel!
    }()

    private var _persistentStoreCoordinator: NSPersistentStoreCoordinator? = nil
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        if self._persistentStoreCoordinator != nil {
            return self._persistentStoreCoordinator!
        }

        guard var storeURL =
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else {
            assertionFailure()
            return nil
        }
        storeURL = storeURL.appendingPathComponent("TresorMockup.sqlite")
        print("storeURL = \(storeURL)")
        self._persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        guard self._persistentStoreCoordinator != nil else {
            assertionFailure()
            return nil
        }

        var psc: NSPersistentStoreCoordinator = self._persistentStoreCoordinator!
        DispatchQueue.global(qos: .background).async {
            let fileManager = FileManager.default
            var options: [String: Any] = [:]
            options[NSMigratePersistentStoresAutomaticallyOption] = true
            options[NSInferMappingModelAutomaticallyOption]       = true

            if let cloudURL = fileManager.url(forUbiquityContainerIdentifier: nil) {
                let url = cloudURL.path.appending("data")
                let key = NSURL.fileURL(withPath: url)
                print("url = \(url)")
                print("key = \(key)")
                options[NSPersistentStoreUbiquitousContentNameKey] = "TresorMockup"
                options[NSPersistentStoreUbiquitousContentURLKey]  = key
            }

            psc.performAndWait {
                do {
                    try psc.addPersistentStore(ofType: NSSQLiteStoreType,
                                               configurationName: nil,
                                               at: storeURL,
                                               options: options)
                }
                catch {
                    assertionFailure()
                }
            }

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "RefetchAllDatabaseData"), object: self, userInfo: nil)
            }
        }

        return self._persistentStoreCoordinator
    }()

    func mergeiCloudChanges(notification note: Notification, forContext moc: NSManagedObjectContext) {
        moc.mergeChanges(fromContextDidSave: note)
        let notification = Notification(name: Notification.Name(rawValue: "RefreshAllVies"),
                                        object: self, userInfo: note.userInfo)
        NotificationCenter.default.post(notification)
    }


    @objc func mergeChnagesFrom_iCloud(notification: Notification) {
        let moc = self.managedObjectContext
        moc.perform {
            self.mergeiCloudChanges(notification: notification, forContext: moc)
        }

    }

}
