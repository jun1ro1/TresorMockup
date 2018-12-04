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

    private static var _manager: PasswordManager? = nil
    static var shared: PasswordManager = {
        if _manager == nil {
            _manager = PasswordManager()
        }
        return _manager!
    }()

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
//        let sortDescriptor1 =
//            NSSortDescriptor(key: "current",
//                             ascending: false,
//                             comparator: { (x, y) -> ComparisonResult in
//                                let a = x as? Bool
//                                let b = y as? Bool
//                                switch (a, b) {
//                                case (nil, _?):
//                                    return .orderedAscending
//                                case (_?, nil):
//                                    return .orderedDescending
//                                case (false, true):
//                                    return .orderedAscending
//                                case (true, false):
//                                    return .orderedDescending
//                                default:
//                                    return .orderedSame
//                                }
//        })

        let sortDescriptor1 = NSSortDescriptor(key: "current",    ascending: false)
        let sortDescriptor2 = NSSortDescriptor(key: "selectedAt", ascending: false)

        fetchRequest.sortDescriptors = [sortDescriptor1, sortDescriptor2]

        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        // https://qiita.com/color_box/items/fe383fd0896318ed49ee
        let aFetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: self.managedObjectContext!,
            sectionNameKeyPath: "section",
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
        if password.current == 1 {
            site?.selectAt = nil
        }
        site?.removeFromPasswords(password)
        let context = self.fetchedResultsController.managedObjectContext
        context.delete(password)
    }

    func select(password: Password?, for site: Site) {
        let now = (password == nil) ? nil : Date() as NSDate
        password?.selectedAt = now
        site.passwords?.forEach {
            if ($0 as! Password).current == 1 {
                ($0 as! Password).current = 0
            }
        }
        site.passwordCurrent = (password?.password ?? "") as NSString
        password?.current    = 1
        site.selectAt        = now // invakes observeValue
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



