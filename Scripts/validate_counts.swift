#!/usr/bin/env swift
// validate_counts.swift
// Integration test: reads counts.json and validates the data schema and consistency.
// Usage: swift Scripts/validate_counts.swift
//
// Add new assertions here as each Phase 1 Issue is implemented.

import Foundation

// MARK: - Helpers

var passed = 0
var failed = 0

func check(_ label: String, _ condition: Bool, detail: String = "") {
    if condition {
        print("  ✅ \(label)")
        passed += 1
    } else {
        print("  ❌ \(label)\(detail.isEmpty ? "" : " — \(detail)")")
        failed += 1
    }
}

func section(_ title: String) {
    print("\n[\(title)]")
}

// MARK: - Load

let jsonURL = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("Library/Application Support/KeyLens/counts.json")

guard let data = try? Data(contentsOf: jsonURL),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    print("❌ Failed to load counts.json at \(jsonURL.path)")
    exit(1)
}

print("KeyLens counts.json validator")
print("File: \(jsonURL.path)")

// MARK: - Phase 0: Required fields

section("Phase 0 – Required fields")

let requiredFields = [
    "startedAt", "counts", "dailyCounts",
    "sameFingerCount", "totalBigramCount",
    "dailySameFingerCount", "dailyTotalBigramCount",
    "handAlternationCount", "dailyHandAlternationCount",
    "hourlyCounts",
    "bigramCounts", "dailyBigramCounts"  // Issue #12
]
for field in requiredFields {
    check("field '\(field)' present", json[field] != nil)
}

// MARK: - Phase 0: Numeric consistency

section("Phase 0 – Numeric consistency")

let total    = json["totalBigramCount"]    as? Int ?? 0
let sameFing = json["sameFingerCount"]     as? Int ?? 0
let handAlt  = json["handAlternationCount"] as? Int ?? 0

check("totalBigramCount > 0", total > 0, detail: "got \(total)")
check("sameFingerCount <= totalBigramCount",
      sameFing <= total, detail: "\(sameFing) vs \(total)")
check("handAlternationCount <= totalBigramCount",
      handAlt <= total, detail: "\(handAlt) vs \(total)")
check("sameFingerCount + handAlternationCount <= totalBigramCount",
      sameFing + handAlt <= total,
      detail: "\(sameFing) + \(handAlt) = \(sameFing + handAlt) vs \(total)")

let sfRate  = total > 0 ? Double(sameFing) / Double(total) : 0
let altRate = total > 0 ? Double(handAlt)  / Double(total) : 0
check("same-finger rate in [0, 1]", sfRate  >= 0 && sfRate  <= 1, detail: String(format: "%.1f%%", sfRate  * 100))
check("hand-alt rate in [0, 1]",    altRate >= 0 && altRate <= 1, detail: String(format: "%.1f%%", altRate * 100))

// MARK: - Phase 0 Issue #12: Bigram frequency table

section("Issue #12 – Bigram frequency table")

let bigrams = json["bigramCounts"] as? [String: Int] ?? [:]
check("bigramCounts is non-empty", !bigrams.isEmpty, detail: "\(bigrams.count) pairs")

let allPairsValid = bigrams.keys.allSatisfy { $0.contains("→") }
check("all pairs contain '→' separator", allPairsValid)

let allCountsPositive = bigrams.values.allSatisfy { $0 > 0 }
check("all pair counts > 0", allCountsPositive)

// Bigram total should be <= totalBigramCount (some bigrams are mouse/unmapped, excluded)
let bigramSum = bigrams.values.reduce(0, +)
check("sum of bigramCounts <= totalBigramCount",
      bigramSum <= total, detail: "\(bigramSum) vs \(total)")

let dailyBigrams = json["dailyBigramCounts"] as? [String: [String: Any]] ?? [:]
check("dailyBigramCounts is non-empty", !dailyBigrams.isEmpty, detail: "\(dailyBigrams.count) days")

let dailyKeysValid = dailyBigrams.keys.allSatisfy { key in
    // Key format: "yyyy-MM-dd"
    key.count == 10 && key.contains("-")
}
check("dailyBigramCounts keys are 'yyyy-MM-dd' format", dailyKeysValid)

// MARK: - Summary

print("\n" + String(repeating: "─", count: 40))
let total_checks = passed + failed
print("Result: \(passed)/\(total_checks) passed")

// Top 5 bigrams
if !bigrams.isEmpty {
    print("\nTop 5 bigrams:")
    for (pair, count) in bigrams.sorted(by: { $0.value > $1.value }).prefix(5) {
        let padded = pair.padding(toLength: max(pair.count, 16), withPad: " ", startingAt: 0)
        print("  \(padded) \(count)")
    }
    print(String(format: "\nSame-finger rate : %.1f%%", sfRate  * 100))
    print(String(format: "Hand-alt rate    : %.1f%%", altRate * 100))
}

exit(failed > 0 ? 1 : 0)
