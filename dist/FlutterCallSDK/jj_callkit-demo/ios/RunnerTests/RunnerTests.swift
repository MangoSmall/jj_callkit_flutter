import Flutter
import UIKit
import XCTest

@testable import jj_callkit

class RunnerTests: XCTestCase {
  func testUnknownMethodIsNotImplemented() {
    let plugin = JjCallkitPlugin()
    let call = FlutterMethodCall(methodName: "notARealMethod", arguments: nil)
    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      if let result = result as? NSObject {
        XCTAssertTrue(result === FlutterMethodNotImplemented)
      } else {
        XCTFail("expected FlutterMethodNotImplemented")
      }
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }
}
