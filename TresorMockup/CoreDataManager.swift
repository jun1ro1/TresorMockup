//
//  CoreDataManager.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/06/22.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//
// Reference
// Marcus S. Zarra "Core Data in Swift" The Pragmatic Bookshelf
// Tim Roadley "Learning Core Data for iOS with Swift" ISBN-13: 978-0-134-12003-5 December 2015 Addison-Wesley
// https://stoeffn.de/posts/persistent-history-tracking-in-core-data/


import UIKit
import CoreData
import SwiftyBeaver

class CoreDataManager {
    private static var _manager: CoreDataManager? = nil
    private var log = SwiftyBeaver.self
    
    private static var appTransactionAuthorName = "TresorMockup"

    static var shared: CoreDataManager = {
        if _manager == nil {
            _manager = CoreDataManager()
        }
        return _manager!
    }()

    init() {
        // Load the last token from the token file.
        if let tokenData = try? Data(contentsOf: tokenFile) {
            do {
                self.lastHistoryToken = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSPersistentHistoryToken.self, from: tokenData)
            } catch {
                print("###\(#function): Failed to unarchive NSPersistentHistoryToken. Error = \(error)")
            }
        }
    }

    private var _managedObjectContext: NSManagedObjectContext? = nil
    lazy var managedObjectContext: NSManagedObjectContext = {
        if self._managedObjectContext != nil {
            return self._managedObjectContext!
        }
        self._managedObjectContext = self.persistentContainer.viewContext

//        CloudKitManager.shared.addObserver(managedObjectContext: self._managedObjectContext)

        return self._managedObjectContext!
    }()

//    private var _managedObjectModel: NSManagedObjectModel? = nil
//    lazy var managedObjectModel: NSManagedObjectModel = {
//        if self._managedObjectModel != nil {
//            return self._managedObjectModel!
//        }
//        //        let bundles = [Bundle(for: type(of: self))]
//        //        print("bundles = \(bundles)")
//        //        self._managedObjectModel = NSManagedObjectModel.mergedModel(from: bundles)
//
//        let bundle = Bundle.main
//        let modelURL = bundle.url(forResource: "TresorMockup", withExtension: "momd")
//        self._managedObjectModel = NSManagedObjectModel(contentsOf: modelURL!)
//
//        //        print("_managedObjectModel = \(String(describing: self._managedObjectModel))")
//
//        return self._managedObjectModel!
//    }()


    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
//        let container = NSPersistentContainer(name: "TresorMockup")
        let container = NSPersistentCloudKitContainer(name: "TresorMockup")

        // Enable history tracking and remote notifications
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("###\(#function): Failed to retrieve a persistent store description.")
        }
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.transactionAuthor = CoreDataManager.appTransactionAuthorName
        
        // Pin the viewContext to the current generation token and set it to keep itself up to date with local changes.
        container.viewContext.automaticallyMergesChangesFromParent = true
        do {
            try container.viewContext.setQueryGenerationFrom(.current)
        } catch {
            fatalError("###\(#function): Failed to pin viewContext to the current generation:\(error)")
        }

        // Observe Core Data remote change notifications.
        NotificationCenter.default.addObserver(
            self, selector: #selector(type(of: self).storeRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange, object: container)

        return container
    }()
    
    /**
     An operation queue for handling history processing tasks: watching changes, deduplicating tags, and triggering UI updates if needed.
     */
    private lazy var historyQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    /**
      Track the last history token processed for a store, and write its value to file.
      
      The historyQueue reads the token when executing operations, and updates it after processing is complete.
    */
    private var lastHistoryToken: NSPersistentHistoryToken? = nil {
        didSet {
            guard let token = self.lastHistoryToken,
                let data = try? NSKeyedArchiver.archivedData( withRootObject: token, requiringSecureCoding: true) else { return }
            
            do {
                try data.write(to: tokenFile)
            } catch {
                print("###\(#function): Failed to write token data. Error = \(error)")
            }
        }
    }
    
    /**
     The file URL for persisting the persistent history token.
    */
    private lazy var tokenFile: URL = {
        let url = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("TresoreMockup", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("###\(#function): Failed to create persistent container URL. Error = \(error)")
            }
        }
        return url.appendingPathComponent("token.data", isDirectory: false)
    }()

}

// MARK: - Notifications

extension CoreDataManager {
    /**
     Handle remote store change notifications (.NSPersistentStoreRemoteChange).
     */
    @objc
    func storeRemoteChange(_ notification: Notification) {
        print("###\(#function): Merging changes from the other persistent store coordinator.")
        
        // Process persistent history to merge changes from other coordinators.
        self.historyQueue.addOperation {
            self.processPersistentHistory()
        }
    }
}

/**
 Custom notifications in this sample.
 */
extension Notification.Name {
    static let didFindRelevantTransactions = Notification.Name("didFindRelevantTransactions")
}


// MARK: - Persistent history processing

extension CoreDataManager {
    
    /**
     Process persistent history, posting any relevant transactions to the current view.
     */
    func processPersistentHistory() {
        let taskContext = self.persistentContainer.newBackgroundContext()
        taskContext.performAndWait {
            
            // Fetch history received from outside the app since the last token
            let historyFetchRequest = NSPersistentHistoryTransaction.fetchRequest!
            historyFetchRequest.predicate = NSPredicate(format: "author != %@", CoreDataManager.appTransactionAuthorName)
            let request = NSPersistentHistoryChangeRequest.fetchHistory(after: self.lastHistoryToken)
            request.fetchRequest = historyFetchRequest

            let result = (try? taskContext.execute(request)) as? NSPersistentHistoryResult
            guard let transactions = result?.result as? [NSPersistentHistoryTransaction],
                  !transactions.isEmpty
                else { return }

            // Post transactions relevant to the current view.
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .didFindRelevantTransactions, object: self, userInfo: ["transactions": transactions])
            }

            
            // Update the history token using the last transaction.
            self.lastHistoryToken = transactions.last!.token
        }
    }
}

