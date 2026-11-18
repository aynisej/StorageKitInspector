import Foundation
import AppKit
import ObjectiveC.runtime
import Darwin

//======================================================
// MARK: - StorageKit Runtime Explorer v4.1
//======================================================

@discardableResult
func loadFramework(_ path: String) -> Bool {

    guard let bundle = Bundle(path: path) else {

        print(" Bundle not found")
        print(path)

        return false
    }

    if bundle.load() {

        print(" Loaded: \(path)")
        return true
    }

    print(" Failed: \(path)")
    return false
}

//======================================================
// MARK: - Pretty Printing
//======================================================

func banner(_ title: String) {

    print("")
    print(String(repeating: "=", count: 70))
    print(title)
    print(String(repeating: "=", count: 70))
}

func section(_ title: String) {

    print("")
    print(String(repeating: "-", count: 50))
    print(title)
    print(String(repeating: "-", count: 50))
}

func objectAddress(_ object: NSObject) -> String {
    String(describing: Unmanaged.passUnretained(object).toOpaque())
}

func isAppleEventDescriptorClassName(_ className: String) -> Bool {
    className.contains("NSAppleEventDescriptor")
}

func isAppleEventDescriptorObject(_ object: NSObject) -> Bool {
    isAppleEventDescriptorClassName(NSStringFromClass(type(of: object)))
}

func safeObjectDescription(_ object: NSObject) -> String {
    if isAppleEventDescriptorObject(object) {
        return "(description skipped for NSAppleEventDescriptor)"
    }

    return object.description
}

func safeObjectDebugDescription(_ object: NSObject) -> String? {
    if isAppleEventDescriptorObject(object) {
        return nil
    }

    return object.debugDescription
}

func printObjectDetails(_ object: NSObject, indent: String = "") {
    print("\(indent)Class:")
    print("\(indent)\(NSStringFromClass(type(of: object)))")
    print("")
    print("\(indent)Address:")
    print("\(indent)\(objectAddress(object))")
    print("")
    print("\(indent)Description:")
    print("\(indent)\(safeObjectDescription(object))")
}

//======================================================
// MARK: - Runtime
//======================================================

func runtimeClasses() -> [AnyClass] {

    var count: UInt32 = 0

    guard let list = objc_copyClassList(&count) else {

        return []
    }

    defer {

        free(UnsafeMutableRawPointer(list))
    }

    let buffer = UnsafeBufferPointer(
        start: list,
        count: Int(count)
    )

    return Array(buffer)
}

func runtimeClassNames(
    prefixes: [String]
) -> [String] {

    runtimeClasses()

        .map(NSStringFromClass)

        .filter { name in

            prefixes.contains {

                name.hasPrefix($0)
            }

        }

        .sorted()
}

//======================================================
// MARK: - Safety
//======================================================

let dangerousPrefixes = [

    "create",
    "erase",
    "repair",
    "resize",
    "partition",
    "destroy",
    "mount",
    "unmount",
    "eject",
    "sync",
    "composite",
    "format"

]

func isDangerousSelector(
    _ selector: String
) -> Bool {

    dangerousPrefixes.contains {

        selector.lowercased().hasPrefix($0)

    }
}

//======================================================
// MARK: - Runtime Listing
//======================================================

func printMethods(

    of cls: AnyClass,

    classMethods: Bool

) {

    let target: AnyClass

    if classMethods {

        guard let meta = object_getClass(cls) else {

            print("(no metaclass)")
            return
        }

        target = meta

    } else {

        target = cls
    }

    var count: UInt32 = 0

    guard let methods = class_copyMethodList(
        target,
        &count
    ) else {

        print("(none)")
        return
    }

    defer {

        free(methods)
    }

    let buffer = UnsafeBufferPointer(
        start: methods,
        count: Int(count)
    )

    for method in buffer {

        let selector = method_getName(method)

        let name = NSStringFromSelector(selector)

        let encoding = method_getTypeEncoding(method)

            .map {

                String(cString: $0)

            } ?? ""

        let marker = isDangerousSelector(name)

            ? "Warning"

            : " "

        print(

            "\(marker) \(name)    [\(encoding)]"

        )
    }

    print("")
    print("Total methods: \(count)")
}
//======================================================
// MARK: - Properties
//======================================================

func printProperties(
    of cls: AnyClass
) {

    section("Properties")

    var count: UInt32 = 0

    guard let properties = class_copyPropertyList(
        cls,
        &count
    ) else {

        print("(none)")
        return
    }

    defer {
        free(properties)
    }

    let buffer = UnsafeBufferPointer(
        start: properties,
        count: Int(count)
    )

    for property in buffer {

        let name = String(
            cString: property_getName(property)
        )

        let attributes = property_getAttributes(property)
            .map { String(cString: $0) } ?? ""

        print("\(name)    [\(attributes)]")
    }

    print("")
    print("Total properties: \(count)")
}

//======================================================
// MARK: - Ivars
//======================================================

func printIvars(
    of cls: AnyClass
) {

    section("Ivars")

    var count: UInt32 = 0

    guard let ivars = class_copyIvarList(
        cls,
        &count
    ) else {

        print("(none)")
        return
    }

    defer {
        free(ivars)
    }

    let buffer = UnsafeBufferPointer(
        start: ivars,
        count: Int(count)
    )

    for ivar in buffer {

        let name = ivar_getName(ivar)
            .map { String(cString: $0) } ?? "(unknown)"

        let type = ivar_getTypeEncoding(ivar)
            .map { String(cString: $0) } ?? ""

        let offset = ivar_getOffset(ivar)

        print(
            "\(name)    [\(type)]    offset=\(offset)"
        )
    }

    print("")
    print("Total ivars: \(count)")
}

//======================================================
// MARK: - Object Printer
//======================================================

func printObjectSummary(
    _ object: Any
) {

    section("Returned Object")

    print("Swift type: \(type(of: object))")

    if let object = object as? NSObject {

        print("Objective-C class:")
        print(NSStringFromClass(type(of: object)))
        print("Memory address: \(objectAddress(object))")
        let description = safeObjectDescription(object)
        print("Description: \(description)")
        if let debugDescription = safeObjectDebugDescription(object), debugDescription != description {
            print("Debug Description: \(debugDescription)")
        }
    }

    switch object {

    case let string as NSString:

        print("")
        print(string)

    case let number as NSNumber:

        print("")
        print(number)

    case let array as NSArray:

        print("")
        print("NSArray")
        print("Count: \(array.count)")

        for (index, value) in array.enumerated() {

            if let object = value as? NSObject {

                print("[\(index)]")
                printObjectDetails(object)

            } else {

                print("[\(index)] \(type(of: value))")
            }
        }

    case let set as NSSet:

        print("")
        print("NSSet")
        print("Count: \(set.count)")

        for value in set {

            if let object = value as? NSObject {

                printObjectDetails(object)

            } else {

                print(type(of: value))
            }
        }

    case let dictionary as NSDictionary:

        print("")
        print("NSDictionary")
        print("Count: \(dictionary.count)")

        for (key, value) in dictionary {

            print("\(key)")

            if let object = value as? NSObject {
                printObjectDetails(object)
            } else {
                print("Class:")
                print(type(of: value))
                print("")
                print("Description:")
                print(value)
            }
        }

    default:

        print("")
        print(object)
    }
}

//======================================================
// MARK: - Safe Invocation
//======================================================

func methodReturnsObject(
    _ method: Method
) -> Bool {

    let returnType = method_copyReturnType(method)
    defer {
        free(returnType)
    }
    let encoding = String(cString: returnType)
    return encoding == "@"
}

func invokeObjectMethod(
    on object: NSObject,
    selector: Selector,
    method: Method
) -> AnyObject? {

    typealias ObjectMethodIMP = @convention(c) (AnyObject, Selector) -> AnyObject?

    let imp = method_getImplementation(method)
    let function = unsafeBitCast(imp, to: ObjectMethodIMP.self)

    return function(object, selector)
}

func invokeClassObjectMethod(
    on cls: AnyClass,
    selector: Selector,
    method: Method
) -> AnyObject? {

    typealias ClassObjectMethodIMP = @convention(c) (AnyClass, Selector) -> AnyObject?

    let imp = method_getImplementation(method)
    let function = unsafeBitCast(imp, to: ClassObjectMethodIMP.self)

    return function(cls, selector)
}

func invokeNoArgumentMethod(
    on object: NSObject,
    selectorName: String
) {

    if isDangerousSelector(selectorName) {
        print(" Skipped dangerous selector \(selectorName)")
        return
    }

    let selector = NSSelectorFromString(selectorName)

    guard object.responds(to: selector) else {
        print("Object does not respond to \(selectorName)")
        return
    }

    guard let method = class_getInstanceMethod(type(of: object), selector) else {
        print("Unable to resolve method \(selectorName)")
        return
    }

    let argumentCount = method_getNumberOfArguments(method)

    guard argumentCount == 2 else {
        print("Skipping \(selectorName): requires \(argumentCount - 2) argument(s)")
        return
    }
    guard methodReturnsObject(method) else {
        print("Skipping \(selectorName): return type is not an Objective-C object")
        return
    }

    print("")
    print("Invoking \(selectorName)")

    let className = NSStringFromClass(type(of: object))
    traceInvocationCall(
        className: className,
        selectorName: selectorName,
        depth: 0
    )

    guard let value = invokeObjectMethod(
        on: object,
        selector: selector,
        method: method
    ) else {
        traceInvocationNilReturn()
        printInvocationSeparator()
        return
    }

    traceInvocationReturn(value)
    printInvocationSeparator()

    printObjectSummary(value)
}
//======================================================
// MARK: - Explorer
//======================================================

let maxDepth = 4

final class ExplorerNode {
    let className: String
    let selector: String
    let address: String
    var children: [ExplorerNode]

    init(
        className: String,
        selector: String,
        address: String,
        children: [ExplorerNode] = []
    ) {
        self.className = className
        self.selector = selector
        self.address = address
        self.children = children
    }
}

extension ExplorerNode: Codable {}

struct ExplorerInvocationError: Codable {
    let className: String
    let selector: String
    let reason: String
}

struct ExplorerReportSummary: Codable {
    let scenario: String
    let objectsExplored: Int
    let uniqueClasses: Int
    let methodsDiscovered: Int
    let methodsInvoked: Int
    let classMethodsDiscovered: Int
    let classMethodsInvoked: Int
    let selectorsBlockedBySafety: Int
    let objectsSkipped: Int
    let maximumRecursionDepth: Int
    let explorerRoots: Int
}

struct ExplorerReport: Codable {
    let summary: ExplorerReportSummary
    let classCounts: [String: Int]
    let relationships: [String: [String: [String]]]
    let roots: [ExplorerNode]
    let invocationErrors: [ExplorerInvocationError]
}

struct ExplorerConfiguration {
    let classNamePatterns: [String]
    let minimumOutputDepth: Int
    let exploreClassMethods: Bool
    let exportName: String?

    static let `default` = ExplorerConfiguration(
        classNamePatterns: [],
        minimumOutputDepth: 0,
        exploreClassMethods: false,
        exportName: nil
    )
}

struct ExplorerScenario {
    let name: String
    let configuration: ExplorerConfiguration
    let startObject: () -> NSObject?
}

var exploredObjects = Set<ObjectIdentifier>()
var exploredClasses = Set<String>()
var discoveredClassCounts: [String: Int] = [:]
var relationshipGraph: [String: [String: Set<String>]] = [:]
var explorerRoots: [ExplorerNode] = []
var invocationErrors: [ExplorerInvocationError] = []
var explorerConfiguration = ExplorerConfiguration.default
var shouldShowNativeGUI = false
var nativeReports: [ExplorerReport] = []
var objectsExplored = 0
var methodsDiscovered = 0
var methodsInvoked = 0
var classMethodsDiscovered = 0
var classMethodsInvoked = 0
var objectsSkipped = 0
var selectorsBlockedBySafety = 0
var maximumRecursionDepth = 0

let ignoredSelectors: Set<String> = [
    "init",
    "dealloc",
    "retain",
    "release",
    "autorelease",
    "copy",
    "mutableCopy",
    "hash",
    "class",
    "self",
    "superclass",
    "respondsToSelector:",
    "forwardInvocation:",
    "methodSignatureForSelector:"
]

let blockedSelectorNames: Set<String> = [
    "imageSrcArray"
]

let blockedSelectorFragments = [
    "imageSrc",
    "bundle",
    "resourcePath",
    "resourceURL"
]

let blockedSelectorsByClass: [String: Set<String>] = [
    "NSAppleEventDescriptor": [
        "data"
    ]
]

let explorableClassPrefixes = [
    "SK",
    "StorageKit.",
    "DM",
    "Disk"
]

func classNameMatches(_ className: String, pattern: String) -> Bool {
    if pattern.hasSuffix("*") {
        return className.hasPrefix(String(pattern.dropLast()))
    }

    return className == pattern || className.hasPrefix("\(pattern).")
}

func shouldOutputObject(className: String, depth: Int) -> Bool {
    guard depth >= explorerConfiguration.minimumOutputDepth else {
        return false
    }

    guard !explorerConfiguration.classNamePatterns.isEmpty else {
        return true
    }

    return explorerConfiguration.classNamePatterns.contains { pattern in
        classNameMatches(className, pattern: pattern)
    }
}

func shouldExploreObject(_ object: NSObject) -> Bool {
    if object is NSArray || object is NSSet || object is NSDictionary {
        return true
    }

    let className = NSStringFromClass(type(of: object))
    return explorableClassPrefixes.contains { prefix in
        className.hasPrefix(prefix)
    }
}

func recordInvocationError(
    className: String,
    selectorName: String,
    reason: String
) {
    invocationErrors.append(
        ExplorerInvocationError(
            className: className,
            selector: selectorName,
            reason: reason
        )
    )
}

func printInvocationSeparator() {
    print("")
    print(String(repeating: "=", count: 60))
    print("")
}

func traceInvocationCall(
    className: String,
    selectorName: String,
    depth: Int
) {
    printInvocationSeparator()
    print("CALL")
    print("")
    print("Class:")
    print(className)
    print("")
    print("Selector:")
    print(selectorName)
    print("")
    print("Depth:")
    print(depth)
    print("")
}

func traceInvocationReturn(_ value: AnyObject) {
    print("RETURN")
    print("")
    print("Returned class:")
    print(NSStringFromClass(type(of: value)))
    print("")

    if let object = value as? NSObject {
        print("Returned address:")
        print(objectAddress(object))
        print("")
    }

    if let array = value as? NSArray {
        print("NSArray")
        print("Count:")
        print(array.count)
    } else if let set = value as? NSSet {
        print("NSSet")
        print("Count:")
        print(set.count)
    } else if let dictionary = value as? NSDictionary {
        print("NSDictionary")
        print("Count:")
        print(dictionary.count)
    }
}

func traceInvocationNilReturn() {
    print("RETURN")
    print("")
    print("nil")
}

func traceInvocationFailed(reason: String) {
    print("FAILED")
    print("")
    print("Reason:")
    print(reason)
}

func recordRelationship(
    sourceClassName: String,
    selectorName: String,
    target: NSObject
) {
    let targetClassName = NSStringFromClass(type(of: target))
    relationshipGraph[sourceClassName, default: [:]][selectorName, default: []].insert(targetClassName)
}

func shouldInvokeSelector(_ selectorName: String, method: Method) -> Bool {
    if ignoredSelectors.contains(selectorName) {
        return false
    }
    if isDangerousSelector(selectorName) {
        return false
    }
    if method_getNumberOfArguments(method) != 2 {
        return false
    }
    return methodReturnsObject(method)
}

func selectorSafetyBlockReason(
    _ selectorName: String,
    className: String
) -> String? {
    if selectorName == "data", isAppleEventDescriptorClassName(className) {
        return "Blocked selector for NSAppleEventDescriptor"
    }

    if blockedSelectorsByClass[className]?.contains(selectorName) == true {
        return "Blocked selector for class: \(className)"
    }

    if blockedSelectorNames.contains(selectorName) {
        return "Blocked selector name"
    }

    let lowercasedSelector = selectorName.lowercased()
    for fragment in blockedSelectorFragments {
        if lowercasedSelector.contains(fragment.lowercased()) {
            return "Blocked selector fragment: \(fragment)"
        }
    }

    return nil
}

func recordBlockedSelector(
    className: String,
    selectorName: String,
    reason: String
) {
    selectorsBlockedBySafety += 1
    recordInvocationError(
        className: className,
        selectorName: selectorName,
        reason: reason
    )
}

func exploreChild(
    _ child: NSObject,
    selectorName: String,
    parent: NSObject,
    parentNode: ExplorerNode,
    sourceClassName: String,
    depth: Int
) {
    recordRelationship(
        sourceClassName: sourceClassName,
        selectorName: selectorName,
        target: child
    )

    guard child !== parent else {
        objectsSkipped += 1
        return
    }

    guard shouldExploreObject(child) else {
        objectsSkipped += 1
        return
    }

    if let childNode = exploreObject(child, selectorName: selectorName, depth: depth + 1) {
        parentNode.children.append(childNode)
    }
}

func exploreReturnValue(
    _ returnValue: AnyObject,
    selectorName: String,
    parent: NSObject,
    parentNode: ExplorerNode,
    sourceClassName: String,
    depth: Int
) {
    if let array = returnValue as? NSArray {
        for (index, element) in array.enumerated() {
            if let object = element as? NSObject {
                exploreChild(
                    object,
                    selectorName: "\(selectorName)[\(index)]",
                    parent: parent,
                    parentNode: parentNode,
                    sourceClassName: sourceClassName,
                    depth: depth
                )
            }
        }
    } else if let set = returnValue as? NSSet {
        for element in set {
            if let object = element as? NSObject {
                exploreChild(
                    object,
                    selectorName: "\(selectorName)[set]",
                    parent: parent,
                    parentNode: parentNode,
                    sourceClassName: sourceClassName,
                    depth: depth
                )
            }
        }
    } else if let dictionary = returnValue as? NSDictionary {
        for (key, value) in dictionary {
            if let object = value as? NSObject {
                exploreChild(
                    object,
                    selectorName: "\(selectorName)[\(key)]",
                    parent: parent,
                    parentNode: parentNode,
                    sourceClassName: sourceClassName,
                    depth: depth
                )
            }
        }
    } else if let object = returnValue as? NSObject {
        exploreChild(
            object,
            selectorName: selectorName,
            parent: parent,
            parentNode: parentNode,
            sourceClassName: sourceClassName,
            depth: depth
        )
    }
}

func exploreClassMethods(
    of object: NSObject,
    parentNode: ExplorerNode,
    sourceClassName: String,
    depth: Int
) {
    let cls: AnyClass = type(of: object)

    guard let metaClass = object_getClass(cls) else {
        return
    }

    var methodCount: UInt32 = 0
    guard let methods = class_copyMethodList(metaClass, &methodCount) else {
        return
    }
    defer {
        free(methods)
    }

    let buffer = UnsafeBufferPointer(start: methods, count: Int(methodCount))
    for method in buffer {
        classMethodsDiscovered += 1

        let selector = method_getName(method)
        let selectorName = NSStringFromSelector(selector)

        guard shouldInvokeSelector(selectorName, method: method) else {
            continue
        }

        let tracedSelectorName = "+\(selectorName)"
        if let blockReason = selectorSafetyBlockReason(selectorName, className: sourceClassName) {
            recordBlockedSelector(
                className: sourceClassName,
                selectorName: tracedSelectorName,
                reason: blockReason
            )
            continue
        }

        classMethodsInvoked += 1

        traceInvocationCall(
            className: sourceClassName,
            selectorName: tracedSelectorName,
            depth: depth
        )

        guard let returnValue = invokeClassObjectMethod(on: cls, selector: selector, method: method) else {
            recordInvocationError(
                className: sourceClassName,
                selectorName: tracedSelectorName,
                reason: "Returned nil"
            )
            traceInvocationNilReturn()
            printInvocationSeparator()
            continue
        }

        traceInvocationReturn(returnValue)
        printInvocationSeparator()

        exploreReturnValue(
            returnValue,
            selectorName: tracedSelectorName,
            parent: object,
            parentNode: parentNode,
            sourceClassName: sourceClassName,
            depth: depth
        )
    }
}

func exploreObject(_ object: NSObject, selectorName: String = "root", depth: Int = 0) -> ExplorerNode? {
    if depth > maxDepth {
        return nil
    }
    if depth > maximumRecursionDepth {
        maximumRecursionDepth = depth
    }
    let identifier = ObjectIdentifier(object)
    if exploredObjects.contains(identifier) {
        objectsSkipped += 1
        return nil
    }
    exploredObjects.insert(identifier)
    objectsExplored += 1

    let className = NSStringFromClass(type(of: object))
    exploredClasses.insert(className)
    discoveredClassCounts[className, default: 0] += 1

    let node = ExplorerNode(
        className: className,
        selector: selectorName,
        address: objectAddress(object)
    )

    if shouldOutputObject(className: className, depth: depth) {
        printObjectSummary(object)
        print("Exploring depth \(depth): \(NSStringFromClass(type(of: object)))")
    }

    var methodCount: UInt32 = 0
    guard let methods = class_copyMethodList(type(of: object), &methodCount) else {
        return node
    }
    defer {
        free(methods)
    }
    let buffer = UnsafeBufferPointer(start: methods, count: Int(methodCount))
    for method in buffer {
        methodsDiscovered += 1

        let selector = method_getName(method)
        let selectorName = NSStringFromSelector(selector)

        guard shouldInvokeSelector(selectorName, method: method) else {
            continue
        }

        if let blockReason = selectorSafetyBlockReason(selectorName, className: className) {
            recordBlockedSelector(
                className: className,
                selectorName: selectorName,
                reason: blockReason
            )
            continue
        }

        methodsInvoked += 1

        traceInvocationCall(
            className: className,
            selectorName: selectorName,
            depth: depth
        )

        guard let returnValue = invokeObjectMethod(on: object, selector: selector, method: method) else {
            recordInvocationError(
                className: className,
                selectorName: selectorName,
                reason: "Returned nil"
            )
            traceInvocationNilReturn()
            printInvocationSeparator()
            continue
        }

        traceInvocationReturn(returnValue)
        printInvocationSeparator()

        exploreReturnValue(
            returnValue,
            selectorName: selectorName,
            parent: object,
            parentNode: node,
            sourceClassName: className,
            depth: depth
        )
    }

    if explorerConfiguration.exploreClassMethods {
        exploreClassMethods(
            of: object,
            parentNode: node,
            sourceClassName: className,
            depth: depth
        )
    }

    return node
}

func printTopDiscoveredClasses() {
    section("Top discovered classes")

    let sortedCounts = discoveredClassCounts.sorted { lhs, rhs in
        if lhs.value == rhs.value {
            return lhs.key < rhs.key
        }
        return lhs.value > rhs.value
    }

    if sortedCounts.isEmpty {
        print("(none)")
        return
    }

    for (className, count) in sortedCounts {
        print(String(format: "%-40@ %d", className as NSString, count))
    }
}

func printRelationshipGraph() {
    section("Object Relationship Graph")

    if relationshipGraph.isEmpty {
        print("(none)")
        return
    }

    for sourceClassName in relationshipGraph.keys.sorted() {
        print(sourceClassName)

        let selectors = relationshipGraph[sourceClassName] ?? [:]
        for selectorName in selectors.keys.sorted() {
            let targets = selectors[selectorName, default: []].sorted().joined(separator: ", ")
            print(" ├── \(selectorName) -> \(targets)")
        }

        print("")
    }
}

func relationshipGraphForExport() -> [String: [String: [String]]] {
    var exportGraph: [String: [String: [String]]] = [:]

    for (sourceClassName, selectors) in relationshipGraph {
        var exportSelectors: [String: [String]] = [:]

        for (selectorName, targetClasses) in selectors {
            exportSelectors[selectorName] = targetClasses.sorted()
        }

        exportGraph[sourceClassName] = exportSelectors
    }

    return exportGraph
}

func exportJSON<T: Encodable>(
    _ value: T,
    fileName: String
) {
    let fileManager = FileManager.default
    let directoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        .appendingPathComponent("ExplorerExports", isDirectory: true)

    do {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]

        let data = try encoder.encode(value)
        let fileURL = directoryURL.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        print("Exported JSON: \(fileURL.path)")
    } catch {
        print("JSON export failed for \(fileName): \(error)")
    }
}

func explorerExportDirectoryURL() -> URL {
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("ExplorerExports", isDirectory: true)
}

func makeExplorerReport(scenarioName: String) -> ExplorerReport {
    ExplorerReport(
        summary: ExplorerReportSummary(
            scenario: scenarioName,
            objectsExplored: objectsExplored,
            uniqueClasses: exploredClasses.count,
            methodsDiscovered: methodsDiscovered,
            methodsInvoked: methodsInvoked,
            classMethodsDiscovered: classMethodsDiscovered,
            classMethodsInvoked: classMethodsInvoked,
            selectorsBlockedBySafety: selectorsBlockedBySafety,
            objectsSkipped: objectsSkipped,
            maximumRecursionDepth: maximumRecursionDepth,
            explorerRoots: explorerRoots.count
        ),
        classCounts: discoveredClassCounts,
        relationships: relationshipGraphForExport(),
        roots: explorerRoots,
        invocationErrors: invocationErrors
    )
}

func summaryText(for report: ExplorerReport) -> String {
    let summary = report.summary
    return """
Scenario: \(summary.scenario)

Objects explored: \(summary.objectsExplored)
Unique classes: \(summary.uniqueClasses)
Methods discovered: \(summary.methodsDiscovered)
Methods invoked: \(summary.methodsInvoked)
Class methods discovered: \(summary.classMethodsDiscovered)
Class methods invoked: \(summary.classMethodsInvoked)
Selectors blocked by safety: \(summary.selectorsBlockedBySafety)
Objects skipped: \(summary.objectsSkipped)
Maximum recursion depth: \(summary.maximumRecursionDepth)
Explorer roots: \(summary.explorerRoots)
"""
}

func classesText(for report: ExplorerReport) -> String {
    let rows = report.classCounts.sorted { lhs, rhs in
        if lhs.value == rhs.value {
            return lhs.key < rhs.key
        }
        return lhs.value > rhs.value
    }

    guard !rows.isEmpty else {
        return "(none)"
    }

    return rows
        .map { className, count in
            String(format: "%-48@ %d", className as NSString, count)
        }
        .joined(separator: "\n")
}

func treeText(for node: ExplorerNode, depth: Int = 0) -> String {
    let indent = String(repeating: "  ", count: depth)
    var lines = [
        "\(indent)\(node.selector) -> \(node.className)",
        "\(indent)  \(node.address)"
    ]

    for child in node.children {
        lines.append(treeText(for: child, depth: depth + 1))
    }

    return lines.joined(separator: "\n")
}

func treeText(for report: ExplorerReport) -> String {
    guard !report.roots.isEmpty else {
        return "(none)"
    }

    return report.roots
        .map { treeText(for: $0) }
        .joined(separator: "\n\n")
}

func relationshipsText(for report: ExplorerReport) -> String {
    guard !report.relationships.isEmpty else {
        return "(none)"
    }

    var lines: [String] = []

    for sourceClassName in report.relationships.keys.sorted() {
        lines.append(sourceClassName)

        let selectors = report.relationships[sourceClassName] ?? [:]
        for selectorName in selectors.keys.sorted() {
            let targets = selectors[selectorName, default: []].joined(separator: ", ")
            lines.append("  \(selectorName) -> \(targets)")
        }

        lines.append("")
    }

    return lines.joined(separator: "\n")
}

func errorsText(for report: ExplorerReport) -> String {
    guard !report.invocationErrors.isEmpty else {
        return "(none)"
    }

    return report.invocationErrors.map { error in
        """
        Class: \(error.className)
        Selector: \(error.selector)
        Reason: \(error.reason)
        """
    }
    .joined(separator: "\n\n")
}

func combinedReportText(
    _ reports: [ExplorerReport],
    formatter: (ExplorerReport) -> String
) -> String {
    reports.map { report in
        """
        ======================================================================
        \(report.summary.scenario)
        ======================================================================

        \(formatter(report))
        """
    }
    .joined(separator: "\n\n")
}

func makeReportTextView(_ text: String) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = true
    scrollView.autohidesScrollers = false

    let textView = NSTextView()
    textView.isEditable = false
    textView.isSelectable = true
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    textView.string = text
    textView.textContainerInset = NSSize(width: 12, height: 12)
    textView.minSize = NSSize(width: 0, height: 0)
    textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = true
    textView.autoresizingMask = [
        .width,
        .height
    ]

    scrollView.documentView = textView
    return scrollView
}

func makeReportTab(
    title: String,
    text: String
) -> NSTabViewItem {
    let item = NSTabViewItem(identifier: title)
    item.label = title
    item.view = makeReportTextView(text)
    return item
}

final class NativeReportWindowDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let reports: [ExplorerReport]
    var window: NSWindow?

    init(reports: [ExplorerReport]) {
        self.reports = reports
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.addTabViewItem(
            makeReportTab(
                title: "Summary",
                text: combinedReportText(reports, formatter: summaryText)
            )
        )
        tabView.addTabViewItem(
            makeReportTab(
                title: "Classes",
                text: combinedReportText(reports, formatter: classesText)
            )
        )
        tabView.addTabViewItem(
            makeReportTab(
                title: "Tree",
                text: combinedReportText(reports, formatter: treeText)
            )
        )
        tabView.addTabViewItem(
            makeReportTab(
                title: "Relationships",
                text: combinedReportText(reports, formatter: relationshipsText)
            )
        )
        tabView.addTabViewItem(
            makeReportTab(
                title: "Errors",
                text: combinedReportText(reports, formatter: errorsText)
            )
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable
            ],
            backing: .buffered,
            defer: false
        )
        window.title = "StorageKit Inspector"
        window.center()
        window.contentView = tabView
        window.delegate = self
        window.makeKeyAndOrderFront(nil)

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }
}

var nativeReportWindowDelegate: NativeReportWindowDelegate?

func showNativeReportWindow(reports: [ExplorerReport]) {
    guard !reports.isEmpty else {
        return
    }

    let app = NSApplication.shared
    let delegate = NativeReportWindowDelegate(reports: reports)
    nativeReportWindowDelegate = delegate
    app.setActivationPolicy(.regular)
    app.delegate = delegate
    app.run()
}

func writeExplorerHTMLReport(
    _ report: ExplorerReport,
    fileName: String
) {
    let fileManager = FileManager.default
    let directoryURL = explorerExportDirectoryURL()

    do {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys
        ]

        let reportData = try encoder.encode(report)
        let reportBase64 = reportData.base64EncodedString()
        let html = #"""
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>StorageKit Inspector Report</title>
<style>
:root {
    color-scheme: light;
    --bg: #f6f7f8;
    --panel: #ffffff;
    --line: #d9dee3;
    --text: #182026;
    --muted: #66717c;
    --accent: #0b6bcb;
    --danger: #b42318;
}
* { box-sizing: border-box; }
body {
    margin: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    background: var(--bg);
    color: var(--text);
}
header {
    position: sticky;
    top: 0;
    z-index: 2;
    display: grid;
    grid-template-columns: 1fr minmax(240px, 360px);
    gap: 16px;
    align-items: center;
    padding: 14px 18px;
    background: var(--panel);
    border-bottom: 1px solid var(--line);
}
h1 {
    margin: 0;
    font-size: 20px;
    font-weight: 650;
}
input {
    width: 100%;
    padding: 9px 11px;
    border: 1px solid var(--line);
    border-radius: 6px;
    font-size: 14px;
}
main {
    display: grid;
    grid-template-columns: 320px 1fr;
    min-height: calc(100vh - 59px);
}
aside {
    padding: 16px;
    border-right: 1px solid var(--line);
    background: #fbfcfd;
}
section {
    padding: 16px 20px;
}
h2 {
    margin: 0 0 10px;
    font-size: 15px;
    color: var(--muted);
    text-transform: uppercase;
}
.metrics {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 8px;
}
.metric, .panel {
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 8px;
}
.metric {
    padding: 10px;
}
.metric strong {
    display: block;
    font-size: 18px;
}
.metric span {
    color: var(--muted);
    font-size: 12px;
}
.panel {
    margin-bottom: 14px;
    padding: 12px;
}
.row {
    display: grid;
    grid-template-columns: minmax(180px, 1fr) auto;
    gap: 12px;
    padding: 7px 0;
    border-bottom: 1px solid #edf0f2;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 12px;
}
.row:last-child { border-bottom: 0; }
.muted { color: var(--muted); }
.error { color: var(--danger); }
details {
    margin: 4px 0;
}
summary {
    cursor: pointer;
    padding: 5px 0;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}
.children {
    margin-left: 18px;
    padding-left: 12px;
    border-left: 1px solid var(--line);
}
.selector {
    color: var(--accent);
}
.address {
    color: var(--muted);
}
@media (max-width: 860px) {
    header, main {
        display: block;
    }
    aside {
        border-right: 0;
        border-bottom: 1px solid var(--line);
    }
}
</style>
</head>
<body>
<header>
    <h1>StorageKit Inspector Report</h1>
    <input id="search" type="search" placeholder="Filter classes, selectors, addresses">
</header>
<main>
    <aside>
        <h2>Summary</h2>
        <div id="summary" class="metrics"></div>
        <h2 style="margin-top:18px">Top Classes</h2>
        <div id="classes" class="panel"></div>
    </aside>
    <section>
        <h2>Object Tree</h2>
        <div id="tree" class="panel"></div>
        <h2>Relationship Graph</h2>
        <div id="relationships" class="panel"></div>
        <h2>Invocation Errors</h2>
        <div id="errors" class="panel"></div>
    </section>
</main>
<script>
const report = JSON.parse(atob('\#(reportBase64)'));
const search = document.getElementById('search');
const byId = id => document.getElementById(id);
const esc = value => String(value ?? '').replace(/[&<>"']/g, ch => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
}[ch]));
const matches = text => text.toLowerCase().includes(search.value.trim().toLowerCase());

function renderSummary() {
    const labels = {
        scenario: 'Scenario',
        objectsExplored: 'Objects',
        uniqueClasses: 'Classes',
        methodsDiscovered: 'Methods Seen',
        methodsInvoked: 'Methods Called',
        classMethodsDiscovered: 'Class Methods Seen',
        classMethodsInvoked: 'Class Methods Called',
        selectorsBlockedBySafety: 'Blocked',
        objectsSkipped: 'Skipped',
        maximumRecursionDepth: 'Max Depth',
        explorerRoots: 'Roots'
    };
    byId('summary').innerHTML = Object.entries(labels).map(([key, label]) =>
        '<div class="metric"><strong>' + esc(report.summary[key]) + '</strong><span>' + label + '</span></div>'
    ).join('');
}

function renderClasses() {
    const rows = Object.entries(report.classCounts)
        .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
        .filter(([name]) => matches(name))
        .map(([name, count]) => '<div class="row"><span>' + esc(name) + '</span><strong>' + count + '</strong></div>');
    byId('classes').innerHTML = rows.join('') || '<span class="muted">No classes</span>';
}

function nodeText(node) {
    return [node.className, node.selector, node.address].join(' ');
}

function renderNode(node) {
    if (!matches(nodeText(node)) && !node.children.some(child => matches(nodeText(child)))) {
        return '';
    }
    const children = node.children.map(renderNode).filter(Boolean).join('');
    return '<details open><summary><span class="selector">' + esc(node.selector) + '</span> ' +
        esc(node.className) + ' <span class="address">' + esc(node.address) + '</span></summary>' +
        '<div class="children">' + children + '</div></details>';
}

function renderTree() {
    byId('tree').innerHTML = report.roots.map(renderNode).filter(Boolean).join('') ||
        '<span class="muted">No matching tree nodes</span>';
}

function renderRelationships() {
    const rows = [];
    Object.entries(report.relationships).sort().forEach(([source, selectors]) => {
        Object.entries(selectors).sort().forEach(([selector, targets]) => {
            const text = source + ' ' + selector + ' ' + targets.join(' ');
            if (matches(text)) {
                rows.push('<div class="row"><span>' + esc(source) + '<br><span class="selector">' +
                    esc(selector) + '</span></span><span>' + esc(targets.join(', ')) + '</span></div>');
            }
        });
    });
    byId('relationships').innerHTML = rows.join('') || '<span class="muted">No relationships</span>';
}

function renderErrors() {
    const rows = report.invocationErrors
        .filter(error => matches(error.className + ' ' + error.selector + ' ' + error.reason))
        .map(error => '<div class="row"><span class="error">' + esc(error.className) +
            '<br>' + esc(error.selector) + '</span><span>' + esc(error.reason) + '</span></div>');
    byId('errors').innerHTML = rows.join('') || '<span class="muted">No invocation errors</span>';
}

function render() {
    renderSummary();
    renderClasses();
    renderTree();
    renderRelationships();
    renderErrors();
}

search.addEventListener('input', render);
render();
</script>
</body>
</html>
"""#

        let fileURL = directoryURL.appendingPathComponent(fileName)
        try html.write(to: fileURL, atomically: true, encoding: .utf8)
        print("Exported HTML report: \(fileURL.path)")
    } catch {
        print("HTML report export failed for \(fileName): \(error)")
    }
}

func exportExplorerResults(
    name: String,
    report: ExplorerReport
) {
    exportJSON(
        explorerRoots,
        fileName: "\(name)-tree.json"
    )
    exportJSON(
        relationshipGraphForExport(),
        fileName: "\(name)-relationships.json"
    )
    exportJSON(
        report,
        fileName: "\(name)-report.json"
    )
    writeExplorerHTMLReport(
        report,
        fileName: "\(name)-report.html"
    )
}

func printInvocationErrorSummary() {
    section("Invocation Errors")

    if invocationErrors.isEmpty {
        print("(none)")
        return
    }

    for error in invocationErrors {
        print("\(error.className)")
        print("Selector: \(error.selector)")
        print("Reason: \(error.reason)")
        print("")
    }
}

//======================================================
// MARK: - Inspector
//======================================================

func inspect(
    _ className: String
) {

    banner("Inspecting \(className)")

    guard let cls = NSClassFromString(className) else {

        print(" Class not found")
        return
    }

    section("Instance Methods")
    printMethods(
        of: cls,
        classMethods: false
    )

    section("Class Methods")
    printMethods(
        of: cls,
        classMethods: true
    )

    printProperties(of: cls)
    printIvars(of: cls)
}

//======================================================
// MARK: - Class List
//======================================================

func printInterestingClasses() {

    let prefixes = [
        "SK",
        "DM",
        "Storage",
        "Disk"
    ]

    let classes = runtimeClassNames(
        prefixes: prefixes
    )

    banner("FOUND \(classes.count) CLASSES")

    for cls in classes {

        print(cls)
    }
}

//======================================================
// MARK: - Shared Manager
//======================================================

func sharedManager() -> NSObject? {

    guard
        let cls = NSClassFromString("SKManager")
    else {

        return nil
    }

    let selector = NSSelectorFromString("sharedManager")

    guard
        cls.responds(to: selector)
    else {

        return nil
    }

    typealias SharedManagerIMP = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>?

    guard let method = class_getClassMethod(cls, selector) else {
        return nil
    }

    let imp = method_getImplementation(method)
    let function = unsafeBitCast(imp, to: SharedManagerIMP.self)

    guard let unmanaged = function(cls, selector) else {
        return nil
    }

    return unmanaged.takeUnretainedValue() as? NSObject
}

//======================================================
// MARK: - Exploration Scenarios
//======================================================

func resetExplorerState(configuration: ExplorerConfiguration) {
    explorerConfiguration = configuration

    exploredObjects.removeAll()
    exploredClasses.removeAll()
    discoveredClassCounts.removeAll()
    relationshipGraph.removeAll()
    explorerRoots.removeAll()
    invocationErrors.removeAll()
    objectsExplored = 0
    methodsDiscovered = 0
    methodsInvoked = 0
    classMethodsDiscovered = 0
    classMethodsInvoked = 0
    objectsSkipped = 0
    selectorsBlockedBySafety = 0
    maximumRecursionDepth = 0
}

func runExplorerScenario(_ scenario: ExplorerScenario) {

    banner("Scenario: \(scenario.name)")
    resetExplorerState(configuration: scenario.configuration)

    guard let rootObject = scenario.startObject() else {

        print("Unable to obtain scenario root object")
        return
    }

    if let root = exploreObject(rootObject) {
        explorerRoots.append(root)
    }

    print("")
    print("Exploration Summary:")
    print("Objects explored: \(objectsExplored)")
    print("Unique classes: \(exploredClasses.count)")
    print("Methods discovered: \(methodsDiscovered)")
    print("Methods invoked: \(methodsInvoked)")
    print("Class methods discovered: \(classMethodsDiscovered)")
    print("Class methods invoked: \(classMethodsInvoked)")
    print("Selectors blocked by safety: \(selectorsBlockedBySafety)")
    print("Objects skipped: \(objectsSkipped)")
    print("Maximum recursion depth: \(maximumRecursionDepth)")
    print("Explorer roots: \(explorerRoots.count)")

    printTopDiscoveredClasses()
    printRelationshipGraph()
    printInvocationErrorSummary()

    let report = makeExplorerReport(scenarioName: scenario.name)
    if shouldShowNativeGUI {
        nativeReports.append(report)
    }

    if let exportName = scenario.configuration.exportName {
        exportExplorerResults(
            name: exportName,
            report: report
        )
    }
}

func exploreManager() {
    runExplorerScenario(
        ExplorerScenario(
            name: "SKManager overview",
            configuration: ExplorerConfiguration(
                classNamePatterns: [
                    "SKManager",
                    "StorageKit.SKAnalyticsHub"
                ],
                minimumOutputDepth: 0,
                exploreClassMethods: false,
                exportName: "manager"
            ),
            startObject: sharedManager
        )
    )
}

func exploreFilesystem() {
    runExplorerScenario(
        ExplorerScenario(
            name: "Filesystems",
            configuration: ExplorerConfiguration(
                classNamePatterns: [
                    "SKFilesystem*"
                ],
                minimumOutputDepth: 1,
                exploreClassMethods: false,
                exportName: "filesystem"
            ),
            startObject: sharedManager
        )
    )
}

func exploreDisk() {
    runExplorerScenario(
        ExplorerScenario(
            name: "Disks and partitions",
            configuration: ExplorerConfiguration(
                classNamePatterns: [
                    "SKDisk*",
                    "SKPartition*",
                    "SKMediaKit*",
                    "SKVolumeDescriptor*"
                ],
                minimumOutputDepth: 1,
                exploreClassMethods: false,
                exportName: "disk"
            ),
            startObject: sharedManager
        )
    )
}

func exploreAPFS() {
    runExplorerScenario(
        ExplorerScenario(
            name: "APFS objects",
            configuration: ExplorerConfiguration(
                classNamePatterns: [
                    "SKAPFS*"
                ],
                minimumOutputDepth: 1,
                exploreClassMethods: false,
                exportName: "apfs"
            ),
            startObject: sharedManager
        )
    )
}

func exploreStorageAnalytics() {
    runExplorerScenario(
        ExplorerScenario(
            name: "Storage analytics",
            configuration: ExplorerConfiguration(
                classNamePatterns: [
                    "StorageKit.SKAnalyticsHub",
                    "SKAnalytics*",
                    "SKUsage*",
                    "SKCategory*",
                    "SKStorage*"
                ],
                minimumOutputDepth: 1,
                exploreClassMethods: false,
                exportName: "storage-analytics"
            ),
            startObject: sharedManager
        )
    )
}

func runResearchScenarios() {
    exploreManager()
    exploreFilesystem()
    exploreDisk()
    exploreAPFS()
    exploreStorageAnalytics()
}

func printUsage() {
    print("")
    print("Usage:")
    print("  StorageKitInspector [scenario]")
    print("")
    print("Scenarios:")
    print("  disk        Explore disks, partitions, media kit, volume descriptors")
    print("  apfs        Explore APFS objects")
    print("  filesystem  Explore filesystems")
    print("  analytics   Explore storage analytics objects")
    print("  manager     Explore SKManager overview")
    print("  all         Run every scenario")
    print("  classes     Print discovered StorageKit-related runtime classes")
    print("")
    print("Inspection:")
    print("  --inspect <ClassName>")
    print("  --inspect=<ClassName>")
    print("  --gui")
    print("  --no-gui")
    print("")
    print("Default:")
    print("  disk with native GUI")
}

func runScenario(named name: String) -> Bool {
    switch name.lowercased() {
    case "manager":
        exploreManager()
    case "filesystem", "filesystems", "fs":
        exploreFilesystem()
    case "disk", "disks":
        exploreDisk()
    case "apfs":
        exploreAPFS()
    case "analytics", "storage-analytics", "storageanalytics":
        exploreStorageAnalytics()
    case "all":
        runResearchScenarios()
    case "classes", "list-classes":
        printInterestingClasses()
    default:
        return false
    }

    return true
}

func runCommandLine() {
    let arguments = Array(CommandLine.arguments.dropFirst())
    shouldShowNativeGUI = !arguments.contains("--no-gui")
    let commandArguments = arguments.filter { argument in
        argument != "--gui" && argument != "--no-gui"
    }

    guard !commandArguments.isEmpty else {
        _ = runScenario(named: "disk")
        return
    }

    if commandArguments.contains("--help") || commandArguments.contains("-h") {
        printUsage()
        return
    }

    if let inspectArgument = commandArguments.first(where: { $0.hasPrefix("--inspect=") }) {
        let className = String(inspectArgument.dropFirst("--inspect=".count))
        guard !className.isEmpty else {
            printUsage()
            return
        }

        inspect(className)
        return
    }

    if let inspectIndex = commandArguments.firstIndex(of: "--inspect") {
        let classNameIndex = inspectIndex + 1
        guard commandArguments.indices.contains(classNameIndex) else {
            printUsage()
            return
        }

        inspect(commandArguments[classNameIndex])
        return
    }

    for argument in commandArguments {
        guard !argument.hasPrefix("-") else {
            print("Unknown option: \(argument)")
            printUsage()
            return
        }

        guard runScenario(named: argument) else {
            print("Unknown scenario: \(argument)")
            printUsage()
            return
        }
    }
}

//======================================================
// MARK: - Main
//======================================================

final class StorageDashboard: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private struct FileEntry {
        let url: URL
        let isDirectory: Bool
        var size: Int64
    }

    private var window: NSWindow!
    private let table = NSTableView()
    private let pathLabel = NSTextField(labelWithString: "Выберите папку, чтобы просматривать файлы и папки")
    private let statusLabel = NSTextField(labelWithString: "Удаление отправляет выбранное в Корзину")
    private var rows: [FileEntry] = []
    private var currentDirectory: URL?
    private var entriesByParent: [String: [FileEntry]] = [:]
    private var sizeByPath: [String: Int64] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        let root = NSView()
        let title = NSTextField(labelWithString: "Хранилище")
        title.font = .systemFont(ofSize: 26, weight: .bold)
        pathLabel.textColor = .secondaryLabelColor
        statusLabel.textColor = .secondaryLabelColor
        let open = NSButton(title: "Открыть папку…", target: self, action: #selector(chooseFolder))
        let up = NSButton(title: "↑ Вверх", target: self, action: #selector(goUp))
        let refresh = NSButton(title: "Обновить", target: self, action: #selector(refreshFolder))
        let delete = NSButton(title: "Переместить в Корзину", target: self, action: #selector(deleteSelected))
        let forceDelete = NSButton(title: "Завершить процессы и удалить навсегда…", target: self, action: #selector(forceDeleteSelected))
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name")); nameCol.title = "Имя"; nameCol.width = 520
        let kindCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("kind")); kindCol.title = "Тип"; kindCol.width = 115
        let sizeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size")); sizeCol.title = "Размер"; sizeCol.width = 140
        table.addTableColumn(nameCol); table.addTableColumn(kindCol); table.addTableColumn(sizeCol); table.delegate = self; table.dataSource = self
        table.doubleAction = #selector(openSelectedDirectory)
        table.target = self
        scroll.documentView = table
        [title, pathLabel, open, up, refresh, scroll, delete, forceDelete, statusLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; root.addSubview($0) }
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: 24), title.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            pathLabel.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8), pathLabel.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            open.topAnchor.constraint(equalTo: root.topAnchor, constant: 24), open.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            up.topAnchor.constraint(equalTo: pathLabel.bottomAnchor, constant: 12), up.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            refresh.centerYAnchor.constraint(equalTo: up.centerYAnchor), refresh.leadingAnchor.constraint(equalTo: up.trailingAnchor, constant: 8),
            scroll.topAnchor.constraint(equalTo: up.bottomAnchor, constant: 10), scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28), scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28), scroll.bottomAnchor.constraint(equalTo: delete.topAnchor, constant: -16),
            delete.leadingAnchor.constraint(equalTo: title.leadingAnchor), delete.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -12),
            forceDelete.leadingAnchor.constraint(equalTo: delete.trailingAnchor, constant: 12), forceDelete.centerYAnchor.constraint(equalTo: delete.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: title.leadingAnchor), statusLabel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18)
        ])
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 920, height: 640), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Storage Inspector"; window.contentView = root; window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = tableColumn!.identifier
        let entry = rows[row]
        let text: String
        switch id.rawValue {
        case "name": text = entry.url.lastPathComponent
        case "kind": text = entry.isDirectory ? "Папка" : (entry.url.pathExtension.isEmpty ? "Файл" : entry.url.pathExtension.uppercased())
        default: text = entry.isDirectory && entry.size == 0 ? "—" : ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)
        }
        let cell = NSTextField(labelWithString: text)
        cell.lineBreakMode = .byTruncatingMiddle
        return cell
    }

    private func stillMatches(_ pid: Int32, processName: String) -> Bool {
        let ps = Process(); ps.executableURL = URL(fileURLWithPath: "/bin/ps"); ps.arguments = ["-p", "\(pid)", "-o", "uid=,comm="]
        let output = Pipe(); ps.standardOutput = output; ps.standardError = FileHandle.nullDevice
        do {
            try ps.run(); let data = output.fileHandleForReading.readDataToEndOfFile(); ps.waitUntilExit()
            let parts = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard parts.count == 2, UInt32(parts[0]) == getuid() else { return false }
            return URL(fileURLWithPath: String(parts[1])).lastPathComponent == processName
        } catch { return false }
    }

    @objc private func chooseFolder() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadFolder(url, forceRescan: false)
    }

    private func loadFolder(_ url: URL, forceRescan: Bool) {
        currentDirectory = url.standardizedFileURL
        pathLabel.stringValue = currentDirectory!.path
        if !forceRescan, let cached = entriesByParent[currentDirectory!.path] {
            showEntries(cached, cached: true)
            return
        }
        statusLabel.stringValue = "Первое сканирование папки… найденные файлы сохранятся в кэше"
        let root = currentDirectory!
        DispatchQueue.global(qos: .userInitiated).async {
            var newEntries: [String: [FileEntry]] = [:]
            var newSizes: [String: Int64] = [:]
            var directories: [String] = []
            var stack = [root]
            let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .totalFileAllocatedSizeKey, .isSymbolicLinkKey]
            while let directory = stack.popLast() {
                let children = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys), options: [])) ?? []
                var entries: [FileEntry] = []
                for item in children {
                    guard let values = try? item.resourceValues(forKeys: keys) else { continue }
                    let isDir = values.isDirectory == true && values.isSymbolicLink != true
                    let size = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
                    newSizes[item.standardizedFileURL.path] = size
                    entries.append(FileEntry(url: item, isDirectory: isDir, size: size))
                    if isDir { directories.append(item.standardizedFileURL.path); stack.append(item) }
                }
                newEntries[directory.standardizedFileURL.path] = entries
            }
            // Fold child sizes into parent directory sizes, deepest folders first.
            for path in directories.sorted(by: { $0.count > $1.count }) {
                guard let children = newEntries[path] else { continue }
                newSizes[path] = children.reduce(Int64(0)) { $0 + (newSizes[$1.url.standardizedFileURL.path] ?? $1.size) }
            }
            for key in newEntries.keys {
                newEntries[key] = newEntries[key]?.map { entry in
                    var updated = entry
                    if entry.isDirectory { updated.size = newSizes[entry.url.standardizedFileURL.path] ?? 0 }
                    return updated
                }
            }
            DispatchQueue.main.async {
                self.entriesByParent = newEntries
                self.sizeByPath = newSizes
                self.showEntries(newEntries[root.standardizedFileURL.path] ?? [], cached: false)
            }
        }
    }

    private func showEntries(_ entries: [FileEntry], cached: Bool) {
        rows = entries.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
        }
        table.reloadData()
        statusLabel.stringValue = "Элементов: \(rows.count) · файлы и скрытые элементы показаны · \(cached ? "из кэша" : "сканирование завершено")"
    }

    @objc private func openSelectedDirectory() {
        guard let index = table.clickedRow >= 0 ? table.clickedRow : Optional(table.selectedRow),
              rows.indices.contains(index), rows[index].isDirectory else { return }
        loadFolder(rows[index].url, forceRescan: false)
    }

    @objc private func goUp() {
        guard let currentDirectory else { return }
        let parent = currentDirectory.deletingLastPathComponent()
        guard parent.path != currentDirectory.path else { return }
        if entriesByParent[parent.path] != nil { loadFolder(parent, forceRescan: false) }
        else { loadFolder(parent, forceRescan: false) }
    }

    @objc private func refreshFolder() {
        guard let currentDirectory else { return }
        loadFolder(currentDirectory, forceRescan: true)
    }

    @objc private func deleteSelected() {
        let indexes = table.selectedRowIndexes
        guard !indexes.isEmpty else { statusLabel.stringValue = "Сначала выберите файл или папку"; return }
        let alert = NSAlert(); alert.messageText = "Переместить выбранное в Корзину?"; alert.informativeText = "Элементы можно будет восстановить из Корзины."; alert.alertStyle = .warning; alert.addButton(withTitle: "Переместить в Корзину"); alert.addButton(withTitle: "Отмена")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            for index in indexes.sorted(by: >) { try FileManager.default.trashItem(at: rows[index].url, resultingItemURL: nil); rows.remove(at: index) }
            entriesByParent.removeAll(); sizeByPath.removeAll()
            table.reloadData(); statusLabel.stringValue = "Готово. Элементы перемещены в Корзину."
        } catch { statusLabel.stringValue = "Не удалось удалить: \(error.localizedDescription)" }
    }

    @objc private func forceDeleteSelected() {
        let indexes = table.selectedRowIndexes
        guard !indexes.isEmpty else { statusLabel.stringValue = "Сначала выберите файл или папку"; return }
        let targets = indexes.map { rows[$0].url.standardizedFileURL }
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let protected = ["/", "/System", "/Library", "/Applications", "/usr", "/bin", "/sbin", "/private", "/Volumes"]
        guard targets.allSatisfy({ url in
            let p = url.path
            return p != home && p.hasPrefix(home + "/") && !protected.contains(where: { p == $0 || p.hasPrefix($0 + "/") })
        }) else {
            statusLabel.stringValue = "Необратимое удаление разрешено только для элементов внутри вашей домашней папки"
            return
        }

        statusLabel.stringValue = "Поиск процессов, использующих выбранное…"
        DispatchQueue.global(qos: .userInitiated).async {
            var pids = Set<Int32>()
            for url in targets {
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
                process.arguments = isDirectory ? ["-t", "+D", url.path] : ["-t", url.path]
                let pipe = Pipe(); process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
                do { try process.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit();
                    String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline).compactMap { Int32($0) }.forEach { pids.insert($0) }
                } catch { }
            }
            let ownPID = getpid(); let ownUID = getuid()
            let candidates: [(Int32, String)] = pids.compactMap { pid in
                guard pid > 1, pid != ownPID else { return nil }
                let ps = Process(); ps.executableURL = URL(fileURLWithPath: "/bin/ps"); ps.arguments = ["-p", "\(pid)", "-o", "uid=,comm="]
                let output = Pipe(); ps.standardOutput = output; ps.standardError = FileHandle.nullDevice
                do { try ps.run(); let data = output.fileHandleForReading.readDataToEndOfFile(); ps.waitUntilExit()
                    let line = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                    let parts = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
                    guard parts.count == 2, UInt32(parts[0]) == ownUID else { return nil }
                    let executable = String(parts[1]); guard !executable.hasPrefix("/System/") && !executable.hasPrefix("/usr/libexec/") else { return nil }
                    return (pid, URL(fileURLWithPath: executable).lastPathComponent)
                } catch { return nil }
            }.sorted { $0.0 < $1.0 }

            DispatchQueue.main.async {
                let list = candidates.isEmpty ? "Открытых файлов от пользовательских процессов не найдено." : candidates.map { "\($0.1) (PID \($0.0))" }.joined(separator: "\n")
                let alert = NSAlert(); alert.messageText = "Удалить выбранное без возможности восстановления?"
                alert.informativeText = "Будут отправлены SIGTERM, затем SIGKILL тем перечисленным пользовательским процессам, которые всё ещё работают. Все несохранённые данные этих приложений могут быть потеряны. После этого файлы будут удалены навсегда.\n\n\(list)"
                alert.alertStyle = .critical; alert.addButton(withTitle: "Завершить процессы и удалить навсегда"); alert.addButton(withTitle: "Отмена")
                guard alert.runModal() == .alertFirstButtonReturn else { self.statusLabel.stringValue = "Отменено"; return }
                do {
                    for (pid, _) in candidates { _ = Darwin.kill(pid, SIGTERM) }
                    Thread.sleep(forTimeInterval: 1.0)
                    for (pid, name) in candidates where self.stillMatches(pid, processName: name) {
                        if Darwin.kill(pid, 0) == 0 { _ = Darwin.kill(pid, SIGKILL) }
                    }
                    for url in targets { try FileManager.default.removeItem(at: url) }
                    for index in indexes.sorted(by: >) { self.rows.remove(at: index) }
                    self.entriesByParent.removeAll(); self.sizeByPath.removeAll()
                    self.table.reloadData(); self.statusLabel.stringValue = "Удалено навсегда; найденные пользовательские процессы завершены."
                } catch { self.statusLabel.stringValue = "Ошибка удаления: \(error.localizedDescription)" }
            }
        }
    }
}

var storageDashboard: StorageDashboard?
let cliArguments = Array(CommandLine.arguments.dropFirst())
if cliArguments.isEmpty || cliArguments == ["--gui"] {
    let app = NSApplication.shared; storageDashboard = StorageDashboard(); app.setActivationPolicy(.regular); app.delegate = storageDashboard; app.run()
} else {

banner("StorageKit Runtime Explorer v4.1")

_ = loadFramework(
    "/System/Library/PrivateFrameworks/StorageKit.framework"
)

_ = loadFramework(
    "/System/Library/PrivateFrameworks/StorageManagement.framework"
)

runCommandLine()

if shouldShowNativeGUI {
    showNativeReportWindow(reports: nativeReports)
}

banner("Done")
}
