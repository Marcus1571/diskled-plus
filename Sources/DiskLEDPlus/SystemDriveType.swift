import Foundation
import IOKit
import DiskArbitration
import os

private let log = Logger(subsystem: "com.diskledplus.disk", category: "drive")

/// The physical medium type of the drive hosting the root volume.
enum SystemDriveType {
    case ssd
    case hdd
    case unknown

    /// Status-bar label for the labeled LED layouts. "unknown" keeps the
    /// historical "SSD" label — most Macs are SSD, and a blank slot would be
    /// worse than a possibly-stale one. The detector logs which step failed
    /// so an "unknown" is diagnosable from the unified log.
    var label: String {
        switch self {
        case .ssd, .unknown: return "SSD"
        case .hdd: return "HDD"
        }
    }
}

/// One-shot resolver for the system drive's medium type, run once at launch
/// (a system drive's medium type cannot change while the process runs).
///
/// Chain, each step verified live on macOS 27.2 (see KB.md §Drive type):
///   1. DiskArbitration: the root volume's `DAMediaBSDName` (e.g. "disk3s1s1",
///      a synthesized APFS snapshot volume).
///   2. Strip slice suffixes → whole container disk ("disk3"); find the whole
///      `IOMedia` with that `BSD Name` property in the IOKit registry.
///   3. Walk up that media's parent chain to the first `IOBlockStorageDriver`
///      ancestor — the physical drive hosting the volume — then keep walking
///      to the provider device node, which carries a `Device Characteristics`
///      dictionary with `Medium Type` ("Solid State" / "Rotational") and the
///      drive's product name. Falls back to `Protocol Characteristics` and a
///      `Rotational Rate` number for devices that report only those.
enum SystemDriveTypeDetector {
    static func detect() -> SystemDriveType {
        guard let rootBSDName = rootVolumeBSDName() else { return .unknown }
        guard let whole = wholeDiskName(from: rootBSDName) else { return .unknown }
        guard let media = wholeMedia(named: whole) else {
            log.error("no whole IOMedia with BSD Name \(whole, privacy: .public) in the registry — system drive type unknown")
            return .unknown
        }
        return mediumType(walkingUpFrom: media, rootBSDName: rootBSDName, whole: whole)
    }

    // MARK: - Step 1: root volume BSD name via DiskArbitration

    private static func rootVolumeBSDName() -> String? {
        guard let session = DASessionCreate(kCFAllocatorDefault) else {
            log.error("DASessionCreate failed — cannot resolve the root volume's BSD name")
            return nil
        }
        let url = URL(fileURLWithPath: "/") as CFURL
        guard let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url),
              let description = DADiskCopyDescription(disk) as? [String: Any],
              let bsdName = description[kDADiskDescriptionMediaBSDNameKey as String] as? String else {
            log.error("root volume's DiskArbitration description lacks a BSD name — system drive type unknown")
            return nil
        }
        return bsdName
    }

    /// "disk3s1s1" → "disk3" (slice suffixes stripped; anchored at the start so
    /// multi-digit disk numbers survive).
    private static func wholeDiskName(from bsdName: String) -> String? {
        guard let match = bsdName.range(of: #"^disk\d+"#, options: .regularExpression) else {
            log.error("root volume BSD name \(bsdName, privacy: .public) is not a diskN device — system drive type unknown")
            return nil
        }
        return String(bsdName[match])
    }

    // MARK: - Step 2: the whole IOMedia for that BSD name

    /// Returns a retained registry entry the caller owns (release when done).
    private static func wholeMedia(named name: String) -> io_object_t? {
        guard let matching = IOServiceMatching("IOMedia") else {
            log.error("IOServiceMatching(IOMedia) returned nil")
            return nil
        }
        var iterator: io_iterator_t = 0
        defer { if iterator != 0 { IOObjectRelease(iterator) } }
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            log.error("IOServiceGetMatchingServices(IOMedia) failed")
            return nil
        }
        // Explicit release before fetching the next entry — a `defer` inside the
        // loop body would run at each iteration's end, i.e. after `service` has
        // already been reassigned to the NEXT handle, releasing every entry
        // before it is ever read (bug found 2026-11-12; same pattern fixed in
        // DiskActivitySource).
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if stringProperty(service, "BSD Name") == name,
               (numberProperty(service, "Whole") ?? 0) != 0 {
                return service // still owned by this fetch — caller takes ownership
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        log.error("IOMedia enumeration found no whole media with BSD Name \(name, privacy: .public) — system drive type unknown")
        return nil
    }

    // MARK: - Step 3: parent walk to the drive's medium type

    private static func mediumType(walkingUpFrom media: io_object_t, rootBSDName: String, whole: String) -> SystemDriveType {
        // `media`'s ownership moves into this walk; released on every exit path.
        var current = media
        var passedDriver = false
        var depth = 0
        while depth < 16 {
            depth += 1
            var parent: io_object_t = 0
            guard IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent) == KERN_SUCCESS else {
                break // `current` stays owned; released by the post-loop release
            }
            IOObjectRelease(current)
            current = parent

            if entryClass(current) == "IOBlockStorageDriver" {
                passedDriver = true // everything above the driver is the physical drive
                continue
            }
            guard passedDriver, let characteristics = properties(current),
                  let deviceCharacteristics = characteristics["Device Characteristics"] as? [String: Any],
                  let type = classify(deviceCharacteristics) else { continue }

            let product = deviceCharacteristics["Product Name"] as? String ?? "?"
            let medium = deviceCharacteristics["Medium Type"] as? String ?? "?"
            log.info("system drive \(rootBSDName, privacy: .public) → \(whole, privacy: .public): \(product, privacy: .public) reports Medium Type \(medium, privacy: .public) → label \(type.label, privacy: .public)")
            IOObjectRelease(current)
            return type
        }
        IOObjectRelease(current)
        log.error("parent chain of \(whole, privacy: .public) ended without a Device Characteristics Medium Type above an IOBlockStorageDriver — system drive type unknown")
        return .unknown
    }

    /// "Medium Type" carries the verdict when present; otherwise a nonzero
    /// "Rotational Rate" means spinning platters, and an explicit 0 (SSD
    /// convention for "not applicable") means solid state.
    private static func classify(_ deviceCharacteristics: [String: Any]) -> SystemDriveType? {
        if let medium = deviceCharacteristics["Medium Type"] as? String {
            let lowered = medium.lowercased()
            if lowered.contains("solid") { return .ssd }
            if lowered.contains("rotat") { return .hdd }
        }
        if let rate = (deviceCharacteristics["Rotational Rate"] ?? deviceCharacteristics["RotationRate"]) as? NSNumber {
            return rate.intValue > 0 ? .hdd : .ssd
        }
        return nil
    }

    // MARK: - Registry helpers

    private static func stringProperty(_ entry: io_object_t, _ key: String) -> String? {
        guard let prop = IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0) else { return nil }
        return prop.takeRetainedValue() as? String
    }

    private static func numberProperty(_ entry: io_object_t, _ key: String) -> UInt64? {
        guard let prop = IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0) else { return nil }
        return (prop.takeRetainedValue() as? NSNumber)?.uint64Value
    }

    private static func properties(_ entry: io_object_t) -> [String: Any]? {
        var propsPointer: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &propsPointer, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = propsPointer?.takeRetainedValue() as? [String: Any] else { return nil }
        return dict
    }

    private static func entryClass(_ entry: io_object_t) -> String {
        var cls = [CChar](repeating: 0, count: 128) // io_name_t
        guard IOObjectGetClass(entry, &cls) == KERN_SUCCESS else { return "" }
        return String(cString: cls)
    }
}
