import json
import os
from pathlib import Path
import re
import subprocess
import sys


LINUX_MODULES = {
    "BoardCore", "BoardOpsHarness", "BoardWasm", "ChatWireKit", "ContextCore", "CSQLite", "TouchReplay",
    "CoreFoundation", "Dispatch", "Distributed", "Foundation", "FoundationEssentials",
    "FoundationInternationalization", "FoundationNetworking", "FoundationXML", "Glibc",
    "Observation", "RegexBuilder", "Swift", "Synchronization", "Testing", "XCTest",
    "_Concurrency", "_StringProcessing",
}
PACKAGE_FIXTURES = Path("Tests/ContextCoreTests/Fixtures")
URL_TYPES = re.compile(r"\b(URLRequest|URLSession|URLResponse|HTTPURLResponse)\b")
NETWORKING_IMPORT = re.compile(
    r"^[ \t]*#if canImport\(FoundationNetworking\)[ \t]*\n"
    r"[ \t]*import FoundationNetworking[ \t]*$",
    re.MULTILINE,
)


def scan_error(error):
    raise error


def swift_files(root):
    for directory, subdirs, names in os.walk(root, onerror=scan_error):
        directory = Path(directory)
        subdirs[:] = [name for name in subdirs if directory / name != PACKAGE_FIXTURES]
        yield from (directory / name for name in names if name.endswith(".swift"))


def unavailable_imports(command, files):
    output = subprocess.check_output([*command, *files], text=True)
    return set(json.loads(output)["imports"]) - LINUX_MODULES


def locate_imports(command, files, unavailable):
    if not unavailable:
        return
    if len(files) == 1:
        yield from ((files[0], module) for module in unavailable)
        return
    middle = len(files) // 2
    for group in (files[:middle], files[middle:]):
        yield from locate_imports(command, group, unavailable_imports(command, group))


def check_frameworks(files):
    prescan = [
        "swiftc", "-frontend", "-scan-dependencies", "-import-prescan", "-suppress-warnings",
        "-nostdimport", "-parse-stdlib", "-module-name", "LinuxImportCheck",
        "-swift-version", "5", "-D", "SWIFT_PACKAGE",
    ]
    for module in sorted(LINUX_MODULES):
        prescan.extend(["-module-can-import", module])

    targets = {}
    for path in files:
        targets.setdefault(path.parts[:2], []).append(path)

    violations = set()
    for arch in ("aarch64", "x86_64"):
        for configuration in ([], ["-D", "DEBUG"]):
            command = [*prescan, "-target", f"{arch}-unknown-linux-gnu", *configuration]
            for target_files in targets.values():
                unavailable = unavailable_imports(command, target_files)
                locations = set(locate_imports(command, target_files, unavailable))
                unlocated = unavailable - {module for _, module in locations}
                if unlocated:
                    raise ValueError(f"could not locate imports of {', '.join(sorted(unlocated))}")
                violations.update(locations)

    for path, module in sorted(violations):
        print(f"FAIL {path} imports {module} on Linux. Guard it with #if canImport({module}) or an Apple OS check.")
    if not violations:
        print("ok   every Apple-only import in ContextCore's sources and tests is excluded on Linux")
    return bool(violations)


def main():
    sources = sorted(swift_files("Sources"))
    tests = sorted(swift_files("Tests"))
    missing_networking = []
    for path in sources:
        source = path.read_text(encoding="utf-8")
        if URL_TYPES.search(source) and not NETWORKING_IMPORT.search(source):
            missing_networking.append(path)
    for path in missing_networking:
        print(f"FAIL {path} uses URL loading without '#if canImport(FoundationNetworking) import FoundationNetworking'")
    if not missing_networking:
        print("ok   every ContextCore file with URL loading imports FoundationNetworking on Linux")

    missing_frameworks = check_frameworks(sources + tests)
    return int(bool(missing_networking) or missing_frameworks)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f"FAIL could not scan Linux imports: {error}")
