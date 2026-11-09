import Foundation
import IOKit
import os

private let log = Logger(subsystem: "com.diskledplus.disk", category: "io")

/// One 30 ms slice of disk activity, expressed as deltas since the previous tick.
/// The deltas ARE the blink signal — no averaging, no rounding, no smoothing.
struct DiskTick {
    let readBytesDelta: UInt64
    let writeBytesDelta: UInt64
    let readOpsDelta: UInt64
    let writeOpsDelta: UInt64

    static let zero = DiskTick(readBytesDelta: 0, writeBytesDelta: 0, readOpsDelta: 0, writeOpsDelta: 0)
}

/// Aggregates per-physical-disk statistics from the IOKit registry, the same class of
/// data `iostat` reads. Polled once per tick; reading these properties is cheap (they
/// are kernel-maintained counters, we only snapshot and subtract).
final class DiskActivitySource {
    private var primed = false
    private var lastReadBytes: UInt64 = 0
    private var lastWriteBytes: UInt64 = 0
    private var lastReadOps: UInt64 = 0
    private var lastWriteOps: UInt64 = 0
    private var loggedEmptyEnumeration = false
    private var loggedMissingKeys = false

    func tick() -> DiskTick {
        var readBytes: UInt64 = 0
        var writeBytes: UInt64 = 0
        var readOps: UInt64 = 0
        var writeOps: UInt64 = 0
        var diskCount = 0

        var iterator: io_iterator_t = 0
        defer {
            if iterator != 0 { IOObjectRelease(iterator) }
        }

        guard let matching = IOServiceMatching("IOBlockStorageDriver") else {
            log.error("IOServiceMatching(IOBlockStorageDriver) returned nil")
            return .zero
        }
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else {
            log.error("IOServiceGetMatchingServices failed, kern=\(kr)")
            return .zero
        }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            diskCount += 1
            if let dict = registryDictionary(service, key: "Statistics") {
                readBytes += uintValue(dict, "Bytes (Read)")
                writeBytes += uintValue(dict, "Bytes (Write)")
                readOps += uintValue(dict, "Operations (Read)")
                writeOps += uintValue(dict, "Operations (Write)")
            }
            service = IOIteratorNext(iterator)
        }

        if diskCount == 0 && !loggedEmptyEnumeration {
            loggedEmptyEnumeration = true
            log.warning("no IOBlockStorageDriver services enumerated — LEDs will stay dark")
        }

        guard primed else {
            primed = true
            lastReadBytes = readBytes
            lastWriteBytes = writeBytes
            lastReadOps = readOps
            lastWriteOps = writeOps
            return .zero
        }

        // Wraparound / device removal → counter reset: clamp to zero rather than blink.
        let tick = DiskTick(
            readBytesDelta: readBytes >= lastReadBytes ? readBytes - lastReadBytes : 0,
            writeBytesDelta: writeBytes >= lastWriteBytes ? writeBytes - lastWriteBytes : 0,
            readOpsDelta: readOps >= lastReadOps ? readOps - lastReadOps : 0,
            writeOpsDelta: writeOps >= lastWriteOps ? writeOps - lastWriteOps : 0
        )
        lastReadBytes = readBytes
        lastWriteBytes = writeBytes
        lastReadOps = readOps
        lastWriteOps = writeOps
        return tick
    }

    private func registryDictionary(_ entry: io_object_t, key: String) -> [String: Any]? {
        var unmanaged: Unmanaged<CFTypeRef>?
        let kr = IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0, &unmanaged)
        guard kr == KERN_SUCCESS, let prop = unmanaged else { return nil }
        let dict = prop.takeRetainedValue() as? [String: Any]
        if dict == nil && !loggedMissingKeys && key == "Statistics" {
            loggedMissingKeys = true
            log.warning("Statistics property found but not a readable string-keyed dictionary — verify key names on this macOS build (see KB.md)")
        }
        return dict
    }

    private func uintValue(_ dict: [String: Any], _ key: String) -> UInt64 {
        guard let value = dict[key] else { return 0 }
        if let number = value as? NSNumber { return number.uint64Value }
        if let data = value as? Data {
            return data.count >= MemoryLayout<UInt64>.size
                ? data.withUnsafeBytes { $0.load(as: UInt64.self) }
                : 0
        }
        return 0
    }
}
