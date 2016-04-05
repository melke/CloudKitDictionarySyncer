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
    let syncer = CloudKitDictionarySyncer(dictname: "anexampledict", debug: true)
    
    override func viewDidLoad() {
        super.viewDidLoad()
 
        self.syncer.loadDictionary({
            loadResult in
            switch loadResult {
                case .Dict(let loadeddict):
                    self.dict = loadeddict
                    print("EXAMPLE: Dict loaded dict = \(loadeddict)")
                    if let rowlabels = self.dict["rowlabels"] as? [String] {
                        // Yes, we already got the rowlabel key, do nothing
                    } else {
                        // init rowlabel key with empty array
                        self.dict["rowlabels"] = [String]()
                    }
                case .Conflict(let localdict, let clouddict, let latest):
                    // Handle conflict. In this example, we are merging all unique rowlabels from both dicts.
                   print("EXAMPLE: Conflict detected")
                   var localrows = localdict["rowlabels"] as? [String]
                   var cloudrows = clouddict["rowlabels"] as? [String]
                   if localrows != nil && cloudrows != nil {
                       print("Both dicts have rowlabels array, will merge cloud array into local array")
                       for label in cloudrows! {
                           if localrows!.contains(label) {
                               localrows!.append(label)
                           }
                       }
                       self.dict = localdict
                       self.dict["rowlabels"] = localrows
                       // The dict has changed, thanks to the merge, so we need to resave it
                       self.syncer.saveDictionary(self.dict, onComplete: {
                          status in
                          print("Resaved merged dict. Save status = \(status)")
                       })
                   } else if let rows = localrows {
                       // We only have rows in localdict
                       self.dict = localdict
                       self.dict["rowlabels"] = localrows
                   } else if let rows = cloudrows {
                       // We only have rows in clouddict
                       self.dict = clouddict
                       self.dict["rowlabels"] = cloudrows
                   } else {
                       // we don't have any rows in any of the dicts
                       self.dict = localdict
                       // init rowlabel key with empty array
                       self.dict["rowlabels"] = [String]()
                   }

                    /*
                    // A simple alternative is to always use the latest saved dict (can be dangerous):
                    switch latest {
                    case .Plist:
                        self.dict = localdict
                    case .CloudKit:
                        self.dict = clouddict
                    }
                    */
            }

            // reload table
            dispatch_async(dispatch_get_main_queue(), {
                self.myTableView.reloadData()
            })
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        print("tapped row \(indexPath.row)")
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
                        print("Save status = \(status)")
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
                print("\(tablerows[indexPath.row])")
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

