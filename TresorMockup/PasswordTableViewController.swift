//
//  PasswordTableViewController.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/05/26.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//

import UIKit

class PasswordTableViewController: UITableViewController {

    var detailItem: Site?
    var selected: Password?
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

        self.selected = self.detailItem?.password

        eyeButton?.addTarget(self,
                             action: #selector(showPassword(sender:)),
                             for: .touchDown)
        eyeButton?.addTarget(self,
                             action: #selector(hidePoassword(sender:)),
                             for: [.touchUpInside, .touchUpOutside])

        self.navigationItem.rightBarButtonItem = editButtonItem
        self.navigationController?.setToolbarHidden(false, animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)



        self.clearsSelectionOnViewWillAppear = self.splitViewController!.isCollapsed


        self.passwordManager?.deleteCache()
        do {
            try self.passwordManager!.fetchedResultsController.performFetch()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        self.update(force: true)
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

        // Configure the cell...
        //        cell.textLabel?.text = self.passwords[indexPath.row].password
        let password = self.passwordManager?.fetchedResultsController.object(at: indexPath)
        cell.password?.value = password?.password
        cell.password?.secret(true)

        cell.createdAt?.text = { () -> String? in
            //            if let date = self.passwords[indexPath.row].selectedAt {
            if let date = password?.createdAt {
                return DateFormatter.localizedString(from: date as Date, dateStyle: .short, timeStyle: .short)
            }
            else {
                return ""
            }
        }()

        cell.selectedAt?.text = { () -> String? in
            //            if let date = self.passwords[indexPath.row].selectedAt {
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
        return cell
    }

    //    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    //        self.selected = self.passwordManager?.fetchedResultsController.object(at: indexPath)
    //        self.selected?.selectedAt = Date() as NSDate
    //        self.detailItem?.selectAt = self.selected?.selectedAt
    //
    ////        self.update()
    //
    //        self.performSegue(withIdentifier: "PasswordTableToMaster", sender: self)
    //    }

    func update(force: Bool = false) {
        var cond = false
        if let svc = self.splitViewController {
            cond = (!svc.isCollapsed || force)
        }
        else {
            cond = force
        }

        guard cond else { return }

        if self.selected != nil && self.selected != self.detailItem?.password {
            self.detailItem?.password = self.selected
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
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            assertionFailure()
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }

    // MARK: - Swipe acions
    // http://an.hatenablog.jp/entry/2017/10/23/225424
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(style: .normal,
                                        title: "select") {
                                            (_: UIContextualAction,
                                            _: UIView,
                                            completion: (Bool) -> Void) -> Void in
                                            self.selected = self.passwordManager?.fetchedResultsController.object(at: indexPath)
                                            self.selected?.selectedAt = Date() as NSDate
                                            self.detailItem?.selectAt = self.selected?.selectedAt
                                            self.tableView.reloadData()
                                            completion(true)

        }

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
}

// MARK: -


