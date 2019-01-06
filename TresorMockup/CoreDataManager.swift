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


import UIKit
import CoreData
import SwiftyBeaver

class CoreDataManager: NSObject {
    private static var _manager: CoreDataManager? = nil
    private var log = SwiftyBeaver.self

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
        let container = NSPersistentContainer(name: "TresorMockup")
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
        return container
    }()
}
