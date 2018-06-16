//
//  PasswordManager.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/05/24.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//

import Foundation
import CoreData

class PasswordManager: NSObject, NSFetchedResultsControllerDelegate {

    static var shared = PasswordManager()

    private let CACHE_NAME = "PASSWORD"
    var detailViewController: DetailViewController? = nil
    var managedObjectContext: NSManagedObjectContext? = nil

    var fetchedResultsController: NSFetchedResultsController<Password> {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }

        let fetchRequest: NSFetchRequest<Password> = Password.fetchRequest()

        // Set the batch size to a suitable number.
        fetchRequest.fetchBatchSize = 20

        // Edit the sort key as appropriate.
        let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)

        fetchRequest.sortDescriptors = [sortDescriptor]

        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        let aFetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: self.managedObjectContext!,
            sectionNameKeyPath: nil,
            cacheName: CACHE_NAME)
        aFetchedResultsController.delegate = self
        _fetchedResultsController = aFetchedResultsController

//        do {
//            try _fetchedResultsController!.performFetch()
//        } catch {
//            // Replace this implementation with code to handle the error appropriately.
//            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//            let nserror = error as NSError
//            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
//        }
//
        return _fetchedResultsController!
    }
    var _fetchedResultsController: NSFetchedResultsController<Password>? = nil

    func newObject(for site: Site) -> Password {
        let context = self.fetchedResultsController.managedObjectContext
        // Create a new item
        let item      = Password(context: context)
        site.addToPasswords(item)

//        item.site     = site

//        item.addObserver(self, forKeyPath: "password", options: [], context: nil)
        return item
    }

    func deleteObject(password: Password) {
        let site = password.site
        if password.current {
            site?.selectAt = nil
        }
        site?.removeFromPasswords(password)
        let context = self.fetchedResultsController.managedObjectContext
        context.delete(password)
    }

    func select(password: Password?, for site: Site) {
        let now = (password == nil) ? nil : Date() as NSDate
        password?.selectedAt = now
        site.passwords?.forEach { ($0 as! Password).current = false }
        password?.current   = true
        site.selectAt       = now // invakes observeValue
    }

    func deleteCache() {
        NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: CACHE_NAME)
    }

    func save() {
        let context = self.fetchedResultsController.managedObjectContext
        // Save the context.
        do {
            try context.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }
}



