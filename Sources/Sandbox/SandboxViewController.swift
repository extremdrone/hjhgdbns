//
//  SandboxViewController.swift
//  DebugMan
//
//  Created by liman on 28/01/2018.
//  Copyright © 2018 liman. All rights reserved.
//

import Foundation

class SandboxViewController: UITableViewController {
    
    static func instanceFromStoryBoard() -> SandboxViewController {
        let storyboard = UIStoryboard(name: "Sandbox", bundle: Bundle(for: DebugMan.self))
        return storyboard.instantiateViewController(withIdentifier: "SandboxViewController") as! SandboxViewController
    }
    
    //MARK: - init
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
    }
}
