//
//  SplitViewController.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2020/10/05.
//  Copyright (C) 2020 OKU Junichirou. All rights reserved.
//

import UIKit
import CoreData
import SwiftyBeaver

class SplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //    let splitViewController = self.window!.rootViewController as! UISplitViewController
        let navigationController = self.viewControllers[self.viewControllers.count-1] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = self.displayModeButtonItem
        self.delegate = self
        self.preferredDisplayMode = DisplayMode.oneBesideSecondary
        
        let masterNavigationController = self.viewControllers[0] as! UINavigationController
        let controller = masterNavigationController.topViewController as! MasterViewController
        //        controller.managedObjectContext = self.persistentContainer.viewContext
        //        PasswordManager.shared.managedObjectContext = self.persistentContainer.viewContext
        
        controller.managedObjectContext = CoreDataManager.shared.persistentContainer.viewContext
        PasswordManager.shared.managedObjectContext = CoreDataManager.shared.persistentContainer.viewContext
    }
    
    // MARK: - Split view
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
        guard let secondaryAsNavController = secondaryViewController as? UINavigationController else { return false }
        guard let topAsDetailController = secondaryAsNavController.topViewController as? DetailViewController else { return false }
        if topAsDetailController.detailItem == nil {
            // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
            return true
        }
        return false
    }
    
}
