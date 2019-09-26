/*
 Like all App Extensions, AUv3 plug-ins run out-of-process by default, which means the extension runs in a separate process from the host app, and all communication between the two occurs over interprocess communication (IPC). This model provides increased security and stability for the host app. For example, if an AUv3 plug-in crashes, the host app won’t crash. However, the IPC communication adds a small amount of overhead to each render cycle, which may be unacceptable depending on the needs of a given application. In macOS only, you can package your plug-in to run in-process, which eliminates the IPC communication as your Audio Unit runs as part of the host’s process.
 Running a plug-in in-process requires an agreement between the host and the Audio Unit. The host requests in-process instantiation by passing the loadInProcess option during the plug-in’s creation, and you need to package your Audio Unit as described and shown below.
 Your extension’s main binary cannot be dynamically loaded into another app, which means all executable code needs to reside in a separate framework bundle. However, the extension target still needs to contain at least one source file for the extension binary to be created, properly loaded, and linked with the framework bundle. To ensure the extension is created, add some unused placeholder code in your extension target
 */

void dummy() {}
