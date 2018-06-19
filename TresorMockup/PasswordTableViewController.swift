//
//  PasswordTableViewController.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/05/26.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//

import UIKit
import CoreData

class PasswordTableViewController: UITableViewController, NSFetchedResultsControllerDelegate {

    var detailItem: Site?
    private weak var selected: Password?
    private weak var selectedOriginal: Password?
    private weak var passwordManager = PasswordManager.shared

    @IBOutlet weak var eyeButton: UIButton?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem

        self.tableView.estimatedRowHeight      = 80.0
        self.tableView.rowHeight               = UITableViewAutomaticDimension

        let predicate = NSPredicate(format: "%K == %@", "site", self.detailItem ?? "")
        self.passwordManager?.fetchedResultsController.fetchRequest.predicate = predicate

        eyeButton?.addTarget(self,
                             action: #selector(showPassword(sender:)),
                             for: .touchDown)
        eyeButton?.addTarget(self,
                             action: #selector(hidePoassword(sender:)),
                             for: [.touchUpInside, .touchUpOutside])

        self.navigationItem.rightBarButtonItem = editButtonItem
        self.navigationController?.setToolbarHidden(false, animated: false)

        self.selectedOriginal = self.detailItem?.currentPassword
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.clearsSelectionOnViewWillAppear = self.splitViewController!.isCollapsed

        self.passwordManager?.fetchedResultsController.delegate = self
        self.passwordManager?.deleteCache()
        do {
            try self.passwordManager!.fetchedResultsController.performFetch()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
        self.selected = self.detailItem?.currentPassword
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        self.save(force: true)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        //        return 1
        return self.passwordManager?.fetchedResultsController.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        //       return self.detailItme?.passwords?.count ?? 0
        let sectionInfo = self.passwordManager?.fetchedResultsController.sections![section]
        return sectionInfo?.numberOfObjects ?? 0
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CellPassword", for: indexPath) as! PasswordTableCell
        let password = self.passwordManager?.fetchedResultsController.object(at: indexPath)
        self.configureCell(cell, with: password)
        return cell
    }

    fileprivate func configureCell(_ cell: PasswordTableCell, with password: Password?) {
        // Configure the cell...
        cell.password?.value = password?.password
        cell.password?.secret(true)

        cell.createdAt?.text = { () -> String? in
            if let date = password?.createdAt {
                return DateFormatter.localizedString(from: date as Date, dateStyle: .short, timeStyle: .short)
            }
            else {
                return ""
            }
        }()

        cell.selectedAt?.text = { () -> String? in
            if let date = password?.selectedAt {
                return DateFormatter.localizedString(from: date as Date, dateStyle: .short, timeStyle: .short)
            }
            else {
                return ""
            }
        }()

        if self.selected != nil {
            cell.accessoryType = ( self.selected == password ) ? .checkmark : .none
        }
        else {
            cell.accessoryType = .none
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
    }

    func save(force: Bool = false) {
        var cond = false
        if let svc = self.splitViewController {
            cond = (!svc.isCollapsed || force)
        }
        else {
            cond = force
        }
        guard cond else { return }

        if self.selected == nil || self.selected != self.selectedOriginal {
            self.passwordManager?.select(password: self.selected, for: self.detailItem!)
        }
        if let context = self.detailItem?.managedObjectContext {
            do {
                try context.save()
            }
            catch {
                print("error = \(error)")
                abort()
            }
        }

    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }


    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .delete
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            guard let object = self.passwordManager?.fetchedResultsController.object(at: indexPath) else {
                assertionFailure()
                return
            }
            if self.selected == object {
                self.selected = nil
            }
            self.passwordManager?.deleteObject(password: object)
            self.passwordManager?.deleteCache()
        } else if editingStyle == .insert {
            assertionFailure()
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }

    // MARK: - NSFetchedResultsControllerDelegate
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        default:
            return
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            guard let cell = self.tableView.cellForRow(at: indexPath!) as? PasswordTableCell else {
                break
            }
            self.configureCell(cell, with: anObject as? Password)
            tableView.reloadRows(at: [indexPath!], with: .fade)
        case .move:
            guard let cell = self.tableView.cellForRow(at: indexPath!) as? PasswordTableCell else {
                break
            }
            self.configureCell(cell, with: anObject as? Password)
            tableView.moveRow(at: indexPath!, to: newIndexPath!)
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }


    // MARK: - Swipe acions
    // http://an.hatenablog.jp/entry/2017/10/23/225424
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let handler =  {
            (_: UIContextualAction, _: UIView, completion: (Bool) -> Void) -> Void in
            let oldIndex = self.passwordManager?.fetchedResultsController.indexPath(forObject: self.selected!)
            self.selected = self.passwordManager?.fetchedResultsController.object(at: indexPath)
            let indexPaths = [oldIndex!, indexPath].compactMap { $0 }
            self.tableView.performBatchUpdates(
                { self.tableView.reloadRows(at: indexPaths, with: .automatic) },
                completion: nil)

//            self.tableView.reloadData()

            completion(true)
        }
        let action = UIContextualAction(style: .normal, title: "select", handler: handler)
        return UISwipeActionsConfiguration(actions: [action])
    }

    /*
     // Override to support rearranging the table view.
     override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

     }
     */

    /*
     // Override to support conditional rearranging of the table view.
     override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
     // Return false if you do not want the item to be re-orderable.
     return true
     }
     */

    /*
     // MARK: - Navigation

     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */

    // MARK: - Copyable Label
    @objc func showPassword(sender: UIControl) {
        guard let indexPaths = self.tableView.indexPathsForVisibleRows else {
            return
        }
        indexPaths.forEach {
            if let cell = self.tableView.cellForRow(at: $0) as? PasswordTableCell {
                cell.password!.secret(false)
            }
            else {
                assertionFailure()
            }

        }
    }

    @objc func hidePoassword(sender: UIControl) {
        guard let indexPaths = self.tableView.indexPathsForVisibleRows else {
            return
        }
        indexPaths.forEach {
            if let cell = self.tableView.cellForRow(at: $0) as? PasswordTableCell {
                cell.password!.secret(true)
            }
            else {
                assertionFailure()
            }
        }
    }
}

// MARK: -
class PasswordTableCell: UITableViewCell {
    @IBOutlet weak var password:   CopyableValueLabel?
    @IBOutlet weak var createdAt:  UILabel?
    @IBOutlet weak var selectedAt: UILabel?
    @IBOutlet weak var eyeButton:  UIButton?
}

// MARK: -


