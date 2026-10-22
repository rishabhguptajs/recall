// Dev helper: prints Recall's on-screen windows (used to check the panel opens).
// Run: swift scripts/recall-windows.swift
import CoreGraphics

let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
let mine = info.filter { ($0[kCGWindowOwnerName as String] as? String) == "Recall" }
for w in mine {
    let b = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    print("layer=\(w[kCGWindowLayer as String] ?? "?") bounds=\(b["Width"] ?? 0)x\(b["Height"] ?? 0)")
}
print("count=\(mine.count)")
