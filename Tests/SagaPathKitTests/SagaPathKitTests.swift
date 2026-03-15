import Foundation
@testable import SagaPathKit
import XCTest

struct ThrowError: Error, Equatable {}

struct FakeFSInfo: FileSystemInfo {
  let caseSensitive: Bool

  func isFSCaseSensitiveAt(path: Path) -> Bool {
    return caseSensitive
  }
}

class SagaPathKitTests: XCTestCase {
  var fixtures: Path!

  override func setUp() {
    super.setUp()
    let filePath = #file
    fixtures = Path(filePath).parent() + "Fixtures"
    Path.current = Path(filePath).parent()
  }

  // MARK: - Basics

  func testSystemSeparator() {
    XCTAssertEqual(Path.separator, "/")
  }

  func testCurrentWorkingDirectory() {
    XCTAssertEqual(Path.current.description, FileManager().currentDirectoryPath)
  }

  // MARK: - Initialisation

  func testInitNoArguments() {
    XCTAssertEqual(Path().description, "")
  }

  func testInitWithString() {
    let path = Path("/usr/bin/swift")
    XCTAssertEqual(path.description, "/usr/bin/swift")
  }

  func testInitWithComponents() {
    let path = Path(components: ["/usr", "bin", "swift"])
    XCTAssertEqual(path.description, "/usr/bin/swift")
  }

  // MARK: - Convertable

  func testConvertFromStringLiteral() {
    let path: Path = "/usr/bin/swift"
    XCTAssertEqual(path.description, "/usr/bin/swift")
  }

  func testConvertToStringDescription() {
    XCTAssertEqual(Path("/usr/bin/swift").description, "/usr/bin/swift")
  }

  func testConvertToString() {
    XCTAssertEqual(Path("/usr/bin/swift").string, "/usr/bin/swift")
  }

  func testConvertToURL() {
    XCTAssertEqual(Path("/usr/bin/swift").url, URL(fileURLWithPath: "/usr/bin/swift"))
  }

  // MARK: - Equatable

  func testEquatable() {
    XCTAssertEqual(Path("/usr"), Path("/usr"))
  }

  func testNotEquatable() {
    XCTAssertNotEqual(Path("/usr"), Path("/bin"))
  }

  // MARK: - Hashable

  func testHashable() {
    XCTAssertEqual(Path("/usr").hashValue, Path("/usr").hashValue)
  }

  // MARK: - Absolute / Relative

  func testRelativePathToAbsolute() {
    let path = Path("swift")
    XCTAssertEqual(path.absolute(), Path.current + Path("swift"))
  }

  func testRelativePathIsNotAbsolute() {
    XCTAssertFalse(Path("swift").isAbsolute)
  }

  func testRelativePathIsRelative() {
    XCTAssertTrue(Path("swift").isRelative)
  }

  func testTildePathToAbsolute() {
    let path = Path("~")
    #if os(Linux)
      if NSUserName() == "root" {
        XCTAssertEqual(path.absolute(), Path("/root"))
      } else {
        XCTAssertEqual(path.absolute(), Path("/home/" + NSUserName()))
      }
    #else
      XCTAssertEqual(path.absolute(), Path("/Users/" + NSUserName()))
    #endif
  }

  func testTildePathIsNotAbsolute() {
    XCTAssertFalse(Path("~").isAbsolute)
  }

  func testTildePathIsRelative() {
    XCTAssertTrue(Path("~").isRelative)
  }

  func testAbsolutePathToAbsolute() {
    let path = Path("/usr/bin/swift")
    XCTAssertEqual(path.absolute(), path)
  }

  func testAbsolutePathIsAbsolute() {
    XCTAssertTrue(Path("/usr/bin/swift").isAbsolute)
  }

  func testAbsolutePathIsNotRelative() {
    XCTAssertFalse(Path("/usr/bin/swift").isRelative)
  }

  // MARK: - Normalize

  func testNormalize() {
    let path = Path("/usr/./local/../bin/swift")
    XCTAssertEqual(path.normalize(), Path("/usr/bin/swift"))
  }

  // MARK: - Abbreviate

  func testAbbreviate() {
    let home = Path.home.string

    XCTAssertEqual(Path("\(home)/foo/bar").abbreviate(), Path("~/foo/bar"))
    XCTAssertEqual(Path("\(home)").abbreviate(), Path("~"))
    XCTAssertEqual(Path("\(home)/").abbreviate(), Path("~"))
    XCTAssertEqual(Path("\(home)/backups\(home)").abbreviate(), Path("~/backups\(home)"))
    XCTAssertEqual(Path("\(home)/backups\(home)/foo/bar").abbreviate(), Path("~/backups\(home)/foo/bar"))

    #if os(Linux)
      XCTAssertEqual(Path("\(home.uppercased())").abbreviate(), Path("\(home.uppercased())"))
    #else
      XCTAssertEqual(Path("\(home.uppercased())").abbreviate(), Path("~"))
    #endif
  }

  func testAbbreviateCaseSensitiveFS() {
    let home = Path.home.string
    let fakeFSInfo = FakeFSInfo(caseSensitive: true)
    let path = Path("\(home.uppercased())", fileSystemInfo: fakeFSInfo)

    XCTAssertEqual(path.abbreviate().string, home.uppercased())
  }

  func testAbbreviateCaseInsensitiveFS() {
    let home = Path.home.string
    let fakeFSInfo = FakeFSInfo(caseSensitive: false)
    let path = Path("\(home.uppercased())", fileSystemInfo: fakeFSInfo)

    XCTAssertEqual(path.abbreviate(), Path("~"))
  }

  // MARK: - Symlinking

  func testSymlinkRelativeDestination() throws {
    let path = fixtures + "symlinks/file"
    let resolvedPath = try path.symlinkDestination()
    XCTAssertEqual(resolvedPath.normalize(), fixtures + "file")
  }

  func testSymlinkAbsoluteDestination() throws {
    let path = fixtures + "symlinks/swift"
    let resolvedPath = try path.symlinkDestination()
    XCTAssertEqual(resolvedPath, Path("/usr/bin/swift"))
  }

  func testSymlinkSameDirectory() throws {
    #if os(Linux)
      throw XCTSkip("Not supported on Linux")
    #else
      let path = fixtures + "symlinks/same-dir"
      let resolvedPath = try path.symlinkDestination()
      XCTAssertEqual(resolvedPath.normalize(), fixtures + "symlinks/file")
    #endif
  }

  // MARK: - Components

  func testLastComponent() {
    XCTAssertEqual(Path("a/b/c.d").lastComponent, "c.d")
    XCTAssertEqual(Path("a/..").lastComponent, "..")
  }

  func testLastComponentWithoutExtension() {
    XCTAssertEqual(Path("a/b/c.d").lastComponentWithoutExtension, "c")
    XCTAssertEqual(Path("a/..").lastComponentWithoutExtension, "..")
  }

  func testComponents() {
    XCTAssertEqual(Path("a/b/c.d").components, ["a", "b", "c.d"])
    XCTAssertEqual(Path("/a/b/c.d").components, ["/", "a", "b", "c.d"])
    XCTAssertEqual(Path("~/a/b/c.d").components, ["~", "a", "b", "c.d"])
  }

  func testExtension() {
    XCTAssertEqual(Path("a/b/c.d").extension, "d")
    XCTAssertEqual(Path("a/b.c.d").extension, "d")
    XCTAssertNil(Path("a/b").extension)
  }

  // MARK: - Exists

  func testExists() {
    XCTAssertTrue(fixtures.exists)
  }

  func testNotExists() {
    XCTAssertFalse(Path("/pathkit/test").exists)
  }

  // MARK: - File Info

  func testIsDirectory() {
    XCTAssertTrue((fixtures + "directory").isDirectory)
    XCTAssertTrue((fixtures + "symlinks/directory").isDirectory)
  }

  func testIsSymlink() {
    XCTAssertFalse((fixtures + "file/file").isSymlink)
    XCTAssertTrue((fixtures + "symlinks/file").isSymlink)
  }

  func testIsFile() {
    XCTAssertTrue((fixtures + "file").isFile)
    XCTAssertTrue((fixtures + "symlinks/file").isFile)
  }

  func testIsExecutable() {
    XCTAssertTrue((fixtures + "permissions/executable").isExecutable)
  }

  func testIsReadable() {
    XCTAssertTrue((fixtures + "permissions/readable").isReadable)
  }

  func testIsWritable() {
    XCTAssertTrue((fixtures + "permissions/writable").isWritable)
  }

  func testIsDeletable() throws {
    #if os(Linux)
      throw XCTSkip("isDeletableFile(atPath:) is not yet implemented on Linux")
    #else
      XCTAssertTrue((fixtures + "permissions/deletable").isDeletable)
    #endif
  }

  // MARK: - Changing Directory

  func testChdir() {
    let current = Path.current

    Path("/usr/bin").chdir {
      XCTAssertEqual(Path.current, Path("/usr/bin"))
    }

    XCTAssertEqual(Path.current, current)
  }

  func testChdirWithThrowingClosure() throws {
    let current = Path.current
    let error = ThrowError()

    XCTAssertThrowsError(try Path("/usr/bin").chdir {
      XCTAssertEqual(Path.current, Path("/usr/bin"))
      throw error
    }) { thrownError in
      XCTAssertEqual(thrownError as? ThrowError, error)
    }

    XCTAssertEqual(Path.current, current)
  }

  // MARK: - Special Paths

  func testHomePath() {
    XCTAssertEqual(Path.home, Path("~").normalize())
  }

  func testTemporaryPath() {
    XCTAssertEqual(Path.temporary, Path(NSTemporaryDirectory()))
    XCTAssertTrue(Path.temporary.exists)
  }

  // MARK: - Reading

  func testReadData() throws {
    let path = fixtures + "hello"
    let contents: Data = try path.read()
    let string = String(data: contents, encoding: .utf8)

    XCTAssertEqual(string, "Hello World\n")
  }

  func testReadDataFromNonExistingFile() {
    let path = Path("/tmp/pathkit-testing")

    XCTAssertThrowsError(try path.read() as Data)
  }

  func testReadString() throws {
    let path = fixtures + "hello"
    let contents: String = try path.read()

    XCTAssertEqual(contents, "Hello World\n")
  }

  func testReadStringFromNonExistingFile() {
    let path = Path("/tmp/pathkit-testing")

    XCTAssertThrowsError(try path.read() as String)
  }

  // MARK: - Writing

  func testWriteData() throws {
    let path = Path("/tmp/pathkit-testing")
    let data = "Hi".data(using: .utf8)!

    XCTAssertFalse(path.exists)

    try path.write(data)
    XCTAssertEqual(try path.read() as String, "Hi")
    try path.delete()
  }

  func testWriteDataThrowsOnFailure() throws {
    #if os(Linux)
      throw XCTSkip("Not supported on Linux")
    #else
      let path = Path("/")
      let data = "Hi".data(using: .utf8)!

      XCTAssertThrowsError(try path.write(data))
    #endif
  }

  func testWriteString() throws {
    let path = Path("/tmp/pathkit-testing")

    try path.write("Hi")
    XCTAssertEqual(try path.read() as String, "Hi")
    try path.delete()
  }

  func testWriteStringThrowsOnFailure() throws {
    #if os(Linux)
      throw XCTSkip("Not supported on Linux")
    #else
      let path = Path("/")

      XCTAssertThrowsError(try path.write("hi"))
    #endif
  }

  // MARK: - Parent

  func testParent() {
    XCTAssertEqual((fixtures + "directory/child").parent(), fixtures + "directory")
    XCTAssertEqual((fixtures + "symlinks/directory").parent(), fixtures + "symlinks")
    XCTAssertEqual((fixtures + "directory/..").parent(), fixtures + "directory/../..")
    XCTAssertEqual(Path("/").parent(), Path("/"))
  }

  // MARK: - Children

  func testChildren() throws {
    let children = try fixtures.children().sorted(by: <)
    let expected = ["hello", "directory", "file", "permissions", "symlinks"].map { fixtures + $0 }.sorted(by: <)
    XCTAssertEqual(children, expected)
  }

  func testRecursiveChildren() throws {
    let parent = fixtures + "directory"
    let children = try parent.recursiveChildren().sorted(by: <)
    let expected = [".hiddenFile", "child", "subdirectory", "subdirectory/child"].map { parent + $0 }.sorted(by: <)
    XCTAssertEqual(children, expected)
  }

  // MARK: - Sequence

  func testSequenceWithoutOptions() {
    let path = fixtures + "directory"
    var children = ["child", "subdirectory", ".hiddenFile"].map { path + $0 }
    let generator = path.makeIterator()
    while let child = generator.next() {
      generator.skipDescendants()
      if let index = children.firstIndex(of: child) {
        children.remove(at: index)
      } else {
        XCTFail("Generated unexpected element: <\(child)>")
      }
    }

    XCTAssertTrue(children.isEmpty)
    XCTAssertNil(Path("/non/existing/directory/path").makeIterator().next())
  }

  func testSequenceWithOptions() throws {
    #if os(Linux)
      throw XCTSkip("Not supported on Linux")
    #else
      let path = fixtures + "directory"
      var children = ["child", "subdirectory"].map { path + $0 }
      let generator = path.iterateChildren(options: .skipsHiddenFiles).makeIterator()
      while let child = generator.next() {
        generator.skipDescendants()
        if let index = children.firstIndex(of: child) {
          children.remove(at: index)
        } else {
          XCTFail("Generated unexpected element: <\(child)>")
        }
      }

      XCTAssertTrue(children.isEmpty)
      XCTAssertNil(Path("/non/existing/directory/path").makeIterator().next())
    #endif
  }

  // MARK: - Pattern Matching

  func testPatternMatching() {
    XCTAssertFalse(Path("/var") ~= "~")
    XCTAssertTrue(Path("/Users") ~= "/Users")
    XCTAssertTrue((Path.home + "..") ~= "~/..")
  }

  // MARK: - Comparable

  func testComparable() {
    XCTAssertLessThan(Path("a"), Path("b"))
  }

  // MARK: - Appending

  func testAppending() {
    // Trivial cases
    XCTAssertEqual(Path("a/b"), "a" + "b")
    XCTAssertEqual(Path("a/b"), "a/" + "b")

    // Appending (to) absolute paths
    XCTAssertEqual(Path("/"), "/" + "/")
    XCTAssertEqual(Path("/"), "/" + "..")
    XCTAssertEqual(Path("/a"), "/" + "../a")
    XCTAssertEqual(Path("/b"), "a" + "/b")

    // Appending (to) '.'
    XCTAssertEqual(Path("a"), "a" + ".")
    XCTAssertEqual(Path("a"), "a" + "./.")
    XCTAssertEqual(Path("a"), "." + "a")
    XCTAssertEqual(Path("a"), "./." + "a")
    XCTAssertEqual(Path("."), "." + ".")
    XCTAssertEqual(Path("."), "./." + "./.")
    XCTAssertEqual(Path("../a"), "." + "./../a")
    XCTAssertEqual(Path("../a"), "." + "../a")

    // Appending (to) '..'
    XCTAssertEqual(Path("."), "a" + "..")
    XCTAssertEqual(Path("a"), "a/b" + "..")
    XCTAssertEqual(Path("../.."), ".." + "..")
    XCTAssertEqual(Path("b"), "a" + "../b")
    XCTAssertEqual(Path("a/c"), "a/b" + "../c")
    XCTAssertEqual(Path("a/b/d/e"), "a/b/c" + "../d/e")
    XCTAssertEqual(Path("../../a"), ".." + "../a")
  }

  // MARK: - Glob

  func testStaticGlob() throws {
    let pattern = (fixtures + "permissions/*able").description
    let paths = Path.glob(pattern)

    let results = try (fixtures + "permissions").children().map { $0.absolute() }.sorted(by: <)
    XCTAssertEqual(paths, results.sorted(by: <))
  }

  func testGlobInsideDirectory() throws {
    let paths = fixtures.glob("permissions/*able")

    let results = try (fixtures + "permissions").children().map { $0.absolute() }.sorted(by: <)
    XCTAssertEqual(paths, results.sorted(by: <))
  }

  // MARK: - Codable

  func testEncode() throws {
    let path = Path("/usr/bin/swift")
    let data = try JSONEncoder().encode(path)
    let decoded = try JSONDecoder().decode(String.self, from: data)
    XCTAssertEqual(decoded, "/usr/bin/swift")
  }

  func testDecode() throws {
    let json = #""/usr/bin/swift""#.data(using: .utf8)!
    let path = try JSONDecoder().decode(Path.self, from: json)
    XCTAssertEqual(path, Path("/usr/bin/swift"))
  }

  func testRoundTrip() throws {
    let original = Path("content/articles/hello-world/index.html")
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(Path.self, from: data)
    XCTAssertEqual(decoded, original)
  }

  // MARK: - Match

  func testMatchRelativePath() {
    XCTAssertTrue(Path("test.txt").match("test.txt"))
    XCTAssertTrue(Path("test.txt").match("*.txt"))
    XCTAssertTrue(Path("test.txt").match("*"))
    XCTAssertFalse(Path("test.txt").match("test.md"))
  }

  func testMatchAbsolutePath() {
    XCTAssertTrue(Path("/home/kyle/test.txt").match("*.txt"))
    XCTAssertTrue(Path("/home/kyle/test.txt").match("/home/*.txt"))
    XCTAssertFalse(Path("/home/kyle/test.txt").match("*.md"))
  }
}
