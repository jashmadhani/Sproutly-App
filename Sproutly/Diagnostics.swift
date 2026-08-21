//
//  Diagnostics.swift
//  Sproutly
//

import Foundation

// Failure-path diagnostics. These describe conditions a parent can't act on and
// that only a developer reading a console would ever want — a release build has
// no reason to write them to the system log, so the call compiles away entirely
// rather than being merely silenced at runtime.
//
// Deliberately not os.Logger: nothing here should be persisted to the unified
// log on a device holding a child's health-adjacent data.
@inlinable
func sproutlyLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print("⚠️ Sproutly: \(message())")
    #endif
}
