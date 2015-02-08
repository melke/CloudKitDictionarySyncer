//
//  ViewController.swift
//  CloudKitDictionarySyncer
//
//  Created by Mats Melke on 08/02/15.
//  Copyright (c) 2015 Baresi. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var dict:NSMutableDictionary?
    var syncer = CloudKitDictionarySyncer(dictname: "exampledict", debug: true)

    override func viewDidLoad() {
        super.viewDidLoad()
        syncer.loadDictionary(onComplete: {
            loadeddict in
            if loadeddict == nil {
                self.dict = [:]
                self.dict!["rowlabels"] = [String]()
            } else {
                self.dict = loadeddict
            }
            
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        println("tapped row \(indexPath.row)")
        let numrows = self.tableView(tableView, numberOfRowsInSection: 1)
        if indexPath.row == numrows - 1 {
            if var tablerows = self.dict?["rowlabels"] as? [String] {
                tablerows.append("Row \(indexPath.row+1)")
                self.dict!["rowlabels"] = tablerows
                self.syncer.saveDictionary(self.dict!, onComplete: {
                    status in
                        println("Save status = \(status)")
                })
                tableView.reloadData()
            }
        }
        
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier("exampleCell", forIndexPath: indexPath) as? UITableViewCell
        if (cell == nil) {
            cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "exampleCell")
        }

        let numrows = self.tableView(tableView, numberOfRowsInSection: 1)
        if indexPath.row == numrows - 1 {
            cell?.textLabel?.text = "Tap here to add row"
        } else {
            if let tablerows = self.dict?["rowlabels"] as? [String] {
                println("row \(indexPath.row) set to \(tablerows[indexPath.row])")
                cell?.textLabel?.text = tablerows[indexPath.row]
            }
        }

        return cell!
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var rowcount = 1 // One for the row with the "Add new row" button
        if let tablerows = self.dict?["rowlabels"] as? [String] {
            rowcount += tablerows.count
        }
        return rowcount
    }

    

}

