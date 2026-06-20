#!/usr/bin/env python3
"""Register source/resource files into Discover.xcodeproj without opening Xcode.

Usage:
    add_to_xcode.py <target> <kind> <project-relative-path> [more paths...]

  <target>  app | tests
  <kind>    source | resource

Paths are relative to the project root (the dir containing Discover.xcodeproj),
e.g.  Discover/Features/Reader/ReaderView.swift

The script is idempotent: a path already present in the project is skipped.
File references use sourceTree = SOURCE_ROOT with the full relative path, so
group nesting is irrelevant to the build; refs are also added to the main group
purely for navigator visibility.
"""
import sys, os, hashlib

PBX = os.path.join(os.path.dirname(__file__), "..", "Discover.xcodeproj", "project.pbxproj")
PBX = os.path.abspath(PBX)

# Object ids discovered from the project.
SOURCES = {"app": "CC000001000000000000001A", "tests": "CC000001000000000000001D"}
RESOURCES = {"app": "CC000001000000000000001C", "tests": "CC0000010000000000000020"}
MAIN_GROUP = "DD000001000000000000001A"

FILETYPE = {
    ".swift": "sourcecode.swift",
    ".xml": "text.xml",
    ".sdef": "text.xml",
    ".html": "text.html",
    ".css": "text.css",
    ".js": "sourcecode.javascript",
    ".json": "text.json",
    ".plist": "text.plist.xml",
    ".entitlements": "text.plist.entitlements",
    ".xcassets": "folder.assetcatalog",
}

def gen_id(seed: str) -> str:
    return hashlib.sha1(seed.encode()).hexdigest().upper()[:24]

def insert_after_marker(text: str, marker: str, line: str) -> str:
    idx = text.index(marker)
    nl = text.index("\n", idx) + 1
    return text[:nl] + line + text[nl:]

def insert_into_list(text: str, object_id: str, entry: str) -> str:
    """Insert `entry` before the closing `);` of the first `( ... )` list that
    follows the object definition `\t\t<object_id> ... = {`."""
    anchor = "\n\t\t" + object_id + " "
    start = text.index(anchor)
    open_paren = text.index("(", start)
    close = text.index("\n\t\t\t);", open_paren)
    return text[:close + 1] + entry + text[close + 1:]

def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    target, kind, paths = sys.argv[1], sys.argv[2], sys.argv[3:]
    if target not in SOURCES:
        sys.exit(f"bad target {target!r}; use app|tests")
    if kind not in ("source", "resource"):
        sys.exit(f"bad kind {kind!r}; use source|resource")

    with open(PBX) as f:
        text = f.read()

    phase = SOURCES[target] if kind == "source" else RESOURCES[target]
    phase_word = "Sources" if kind == "source" else "Resources"

    added, skipped = [], []
    for path in paths:
        name = os.path.basename(path)
        if f"/* {name} */" in text or f" path = {path};" in text or f' path = "{path}";' in text:
            skipped.append(name)
            continue
        fref = gen_id("fref:" + path)
        bfile = gen_id("bfile:" + path)
        ext = os.path.splitext(name)[1]
        ftype = FILETYPE.get(ext, "text")
        q = '"' if (" " in path or "+" in name) else ""
        # PBXBuildFile
        text = insert_after_marker(
            text, "/* Begin PBXBuildFile section */",
            f"\t\t{bfile} /* {name} in {phase_word} */ = {{isa = PBXBuildFile; fileRef = {fref} /* {name} */; }};\n")
        # PBXFileReference (SOURCE_ROOT-relative, self-contained)
        text = insert_after_marker(
            text, "/* Begin PBXFileReference section */",
            f"\t\t{fref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; name = {q}{name}{q}; path = {q}{path}{q}; sourceTree = SOURCE_ROOT; }};\n")
        # Build phase membership (the part that actually compiles/bundles it)
        text = insert_into_list(text, phase, f"\t\t\t\t{bfile} /* {name} in {phase_word} */,\n")
        # Main group membership (navigator only)
        text = insert_into_list(text, MAIN_GROUP, f"\t\t\t\t{fref} /* {name} */,\n")
        added.append(name)

    with open(PBX, "w") as f:
        f.write(text)

    print(f"added: {added}")
    print(f"skipped (already present): {skipped}")

if __name__ == "__main__":
    main()
