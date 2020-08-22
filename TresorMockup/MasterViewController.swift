//
//  MasterViewController.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/02/25.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//
// http://eugeneovchynnykov.com/coredata/ios/swift/swift3/2016/12/25/core-data-ios-10-swift-swift.html

import UIKit
import CoreData
import SwiftyBeaver

class MasterViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    @IBOutlet var searchBar: UISearchBar!
    
    private let CACHE_NAME = "MASTER"
    var detailViewController: DetailViewController? = nil
    var newItem: Site? = nil
    var managedObjectContext: NSManagedObjectContext? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        navigationItem.leftBarButtonItem = editButtonItem
        
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(insertNewObject(_:)))
        navigationItem.rightBarButtonItem = addButton
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "addButton"
        
        if let split = self.splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
        
        SwiftyBeaver.self.debug("viewDidLoad")
        
        let center = NotificationCenter.default
//        let name   = Notification.Name(CloudKitManager.CLOUDKIT_MANAGER_UPDATE_INTERFACE)
        center.addObserver(self,
                           selector: #selector(viewUpdate(_ :)),
                           name: .didFindRelevantTransactions,
                           object: nil)
        
        self.searchBar.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.isCollapsed
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AuthenticationManger.shared.authenticate(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc
    func viewUpdate(_ notification: Notification) {
        //        SwiftyBeaver.self.debug("notification = \(notification)")
        SwiftyBeaver.self.debug("notification received")
        
        NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: self.CACHE_NAME)
        do {
            try self.fetchedResultsController.performFetch()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
        self.tableView.reloadData()
    }
    
    @objc
    func insertNewObject(_ sender: Any) {
        // deselect the old row
        if let indexPath = self.tableView.indexPathForSelectedRow {
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
        
        // Create a new item
        let context = CoreDataManager.shared.persistentContainer.viewContext
        self.newItem = Site(context: context)
        
        self.performSegue(withIdentifier: "editDetail", sender: nil)
    }
    
    // MARK: - Segues
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
        
        let object = { () -> Site? in
            if let indexPath = self.tableView.indexPathForSelectedRow {
                return self.fetchedResultsController.object(at: indexPath)
            }
            else {
                let object = self.newItem
                self.newItem = nil
                return object
            }
        }()
        
        controller.detailItem = object
        controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        controller.navigationItem.leftItemsSupplementBackButton = true
        
        switch segue.identifier {
        case "showDetail":
            break
        case "editDetail":
            controller.setEditing(true, animated: false)
        default:
            assertionFailure()
        }
        
    }
    
    // MARK: - Table View
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CellSite", for: indexPath)
        let site = fetchedResultsController.object(at: indexPath)
        self.configureCell(cell, withSite: site)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let context = fetchedResultsController.managedObjectContext
            context.delete(fetchedResultsController.object(at: indexPath))
            
            context.performAndWait {
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
    }
    
    func configureCell(_ cell: UITableViewCell, withSite site: Site) {
        cell.textLabel!.text       = site.title ?? ""
        cell.detailTextLabel?.text = site.url ?? ""
    }
    
    // MARK: - Fetched results controller
    
    var fetchedResultsController: NSFetchedResultsController<Site> {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        
        let fetchRequest: NSFetchRequest<Site> = Site.fetchRequest()
        
        // Set the batch size to a suitable number.
        fetchRequest.fetchBatchSize = 20
        
        // Edit the sort key as appropriate.
        let sortDescriptor = NSSortDescriptor(key: "title", ascending: true, selector:#selector(NSString.localizedStandardCompare))
        
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
        
        do {
            try _fetchedResultsController!.performFetch()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
        
        return _fetchedResultsController!
    }    
    var _fetchedResultsController: NSFetchedResultsController<Site>? = nil
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            self.tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:
            self.tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        default:
            return
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            self.tableView.insertRows(at: [newIndexPath!], with: .automatic)
        case .delete:
            self.tableView.deleteRows(at: [indexPath!], with: .automatic)
        case .update:
            guard let cell = self.tableView.cellForRow(at: indexPath!) else {
                break
            }
            configureCell(cell, withSite: anObject as! Site)
            self.tableView.reloadRows(at: [indexPath!], with: .automatic)
        case .move:
            guard let cell = self.tableView.cellForRow(at: indexPath!) else {
                break
            }
            configureCell(cell, withSite: anObject as! Site)
            self.tableView.moveRow(at: indexPath!, to: newIndexPath!)
        @unknown default:
            fatalError()
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.endUpdates()
    }
    
    /*
     // Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.
     
     func controllerDidChangeContent(controller: NSFetchedResultsController) {
     // In the simplest, most efficient, case, reload the table view.
     tableView.reloadData()
     }
     */
    
}


extension MasterViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.count == 0 {
            self.fetchedResultsController.fetchRequest.predicate = nil
        }
        else {
            let predicate = NSPredicate(format: "title CONTAINS[cd] %@", searchText)
            self.fetchedResultsController.fetchRequest.predicate = predicate
        }
        
        // clear cache before to perform fetch
        NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: CACHE_NAME)
        do {
            try self.fetchedResultsController.performFetch()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
        
        self.tableView.reloadData()
    }
    
}
