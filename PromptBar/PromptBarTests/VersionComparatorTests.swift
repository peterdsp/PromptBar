//
//  VersionComparatorTests.swift
//  PromptBarTests
//

import XCTest

final class VersionComparatorTests: XCTestCase {
  func testVersionComparisonMatchesExistingBehavior() {
    XCTAssertTrue(
      VersionComparator.isVersionNewer(current: "1.3.2", latest: "1.3.3")
    )
    XCTAssertTrue(
      VersionComparator.isVersionNewer(current: "1.3.2", latest: "1.4.0")
    )
    XCTAssertTrue(
      VersionComparator.isVersionNewer(current: "1.3", latest: "1.3.1")
    )
    XCTAssertFalse(
      VersionComparator.isVersionNewer(current: "1.3.2", latest: "1.3.2")
    )
    XCTAssertFalse(
      VersionComparator.isVersionNewer(current: "1.3.2", latest: "1.3.1")
    )
    XCTAssertFalse(
      VersionComparator.isVersionNewer(current: "1.3.2", latest: "1.3")
    )
  }
}
