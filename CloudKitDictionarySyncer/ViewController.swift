//
//  ViewController.swift
//  CloudKitDictionarySyncer
//
//  Created by Mats Melke on 08/02/15.
//  Copyright (c) 2015 Baresi. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet var myTableView: UITableView!
    var dict:NSMutableDictionary = NSMutableDictionary()
    var syncer = CloudKitDictionarySyncer(dictname: "exampledict", debug: true)
    
    override func viewDidLoad() {
        super.viewDidLoad()
 
        self.syncer.loadDictionary(onComplete: {
            loadResult in
            switch loadResult {
                case .Dict(let loadeddict):
                    self.dict = loadeddict
                    if let rowlabels = self.dict["rowlabels"] as? [String] { // TODO simplify example
                        // Yes, we already got the rowlabel key, do nothing
                    } else {
                        // init rowlabel key with empty array
                        self.dict["rowlabels"] = [String]()
                    }
                case .Conflict(let localdict, let clouddict, let latest):
                    self.dict = [:] // TODO handle conflict
                    switch latest {
                    case .Plist:
                        if let dict = localdict {
                            
                        }
                    case .CloudKit:
                        if let dict = clouddict {
                            
                        }
                    }
                
            }

            // reload table
            dispatch_async(dispatch_get_main_queue(), {
                self.myTableView.reloadData()
            })
        })
//        self.syncer.loadDictionary(onComplete: {
//            loadeddict in
//            if loadeddict == nil {
//                self.dict = [:]
//                self.dict!["rowlabels"] = [String]()
//            } else {
//                self.dict = loadeddict
//            }
//            dispatch_async(dispatch_get_main_queue(), {
//                self.myTableView.reloadData()
//            })
//        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        println("tapped row \(indexPath.row)")
        let numrows = self.tableView(tableView, numberOfRowsInSection: 1)
        if indexPath.row == numrows - 1 {
            if var tablerows = self.dict["rowlabels"] as? [String] {
                tablerows.append("Row \(indexPath.row+1)")
                self.dict["rowlabels"] = tablerows

                // Note that the saving is done in background, but your Dictionary is already
                // updated, so there is no need to wait for the saving to complete before you reload the table
                dispatch_async(dispatch_get_main_queue(), {
                    self.myTableView.reloadData()
                })
                self.syncer.saveDictionary(self.dict, onComplete: {
                    status in
                        println("Save status = \(status)")
                })
                
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
            if let tablerows = self.dict["rowlabels"] as? [String] {
                println("\(tablerows[indexPath.row])")
                cell?.textLabel?.text = tablerows[indexPath.row]
            }
        }

        return cell!
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var rowcount = 1 // One for the row with the "Add new row" button
        if let tablerows = self.dict["rowlabels"] as? [String] {
            rowcount += tablerows.count
        }
        return rowcount
    }

    

}

