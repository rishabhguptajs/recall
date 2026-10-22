// Dev helper: sends a command to a running Debug build of Recall.
// Usage: swift scripts/recall-debug.swift <command> [arg]   (see App/DebugBridge.swift)
import Foundation

let args = CommandLine.arguments.dropFirst().joined(separator: " ")
DistributedNotificationCenter.default().postNotificationName(
    Notification.Name("dev.recall.debug"), object: args, userInfo: nil, deliverImmediately: true)
