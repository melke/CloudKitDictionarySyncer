# CloudKitDictionarySyncer

Saves dictionaries locally to a plist file and remotely in CloudKit Private storage.
When loading the dictionary, it loads from CloudKit, if CloudKit is accessible for the moment, otherwise it loads from the local plist file.
If CloudKit is available and the version number of the CloudKit Dictionary differs from the Plist version, a Conflict will be returned, containing
both Dictionaries. It is then up to the calling client to handle the conflict, by merging or whatever.


