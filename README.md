# CloudKitDictionarySyncer

CloudKitDictionarySyncer is a utility that you can use in your app to save a Dictionary to both a local plist file and 
remotely in the user's CloudKit private database. If CloudKit is not available, because the user is offline, not logged in or for some other 
 reason, the Dictionary will be saved to the local plist only.
 
At app startup, when you load the Dictionary, CloudKitDictionarySyncer will return a single Dictionary if the plist and iCloud version is 
  identical. If not, a Conflict tuple containing both dictionaries will be returned. Handle the conflict in a way appropriate for your app, 
  for example by merging the data in both dictionaries or by simply choosing the last saved dictionary (last method not recommended). After
  the conflict is solved, you should save the Dictionary immediately. This will resync the local plist dictionary and the iCloud dictionary.
  
##Installation

Add the file [CloudKitDictionarySyncer.swift!](CloudKitDictionarySyncer/CloudKitDictionarySyncer.swift) to your project


##Usage

### Setup CloudKit

### Your client code

  - Create a syncer object for each dictionary that you want to persist/sync. If you set the debug flag to true you will get some
 debug log messages in your console log.

```swift
let exampledictSyncer = CloudKitDictionarySyncer(dictname: "exampledict", debug: true)

  - Load your dictionary. Pass a function that takes a LoadResult, that will contain either a NSMutableDictionary or a Conflict tuple.
  
```swift
self.exampledictSyncer.saveDictionary(self.dict, onComplete: {
    status in
    println("Save status = \(status)")
})
  
  - Save your NSDictionary. Pass a function that takes a String, that will contain an informational status message from the save operation.
  
```swift
self.exampledictSyncer.saveDictionary(self.dict, onComplete: {
    status in
    println("Save status = \(status)")
})
  
  
##Example Project


##Feedback and Contribution

All feedback and contribution is very appreciated. Please send pull requests, create issues
or just send an email to [mats.melke@gmail.com](mailto:mats.melke@gmail.com).

##Copyrights

* Copyright (c) 2015- Mats Melke. Please see LICENSE.txt for details.
