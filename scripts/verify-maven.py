import hashlib
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

repository = Path(sys.argv[1]).resolve()
base = repository / "com/github/gycrosskit"
modules = sorted(base.rglob("*.module"))
assert len(modules) == 5, modules
for file in modules:
    metadata = json.loads(file.read_text())
    assert metadata["component"]["group"] == "com.github.gycrosskit"
    assert metadata["component"]["version"] == "0.1.0"
    for variant in metadata["variants"]:
        available = variant.get("available-at")
        if available:
            target = (file.parent / available["url"]).resolve()
            assert target.is_relative_to(repository) and target.is_file(), target
        for artifact in variant.get("files", []):
            target = (file.parent / artifact["url"]).resolve()
            assert target.is_relative_to(repository) and target.is_file(), target
            assert hashlib.sha256(target.read_bytes()).hexdigest() == artifact["sha256"], target
assert len(list(base.rglob("*.aar"))) == 1
assert len(list(base.rglob("*.klib"))) == 3
assert not any("/Users/" in file.read_text() for file in modules)
print("5 Maven module metadata, AAR and 3 KLIB artifacts verified")

namespace = {"m": "http://maven.apache.org/POM/4.0.0"}
poms = sorted(base.rglob("*.pom"))
assert len(poms) == 5, poms
for file in poms:
    root = ET.parse(file).getroot()
    assert root.findtext("m:licenses/m:license/m:name", namespaces=namespace) == "Apache License, Version 2.0"
    assert root.findtext("m:licenses/m:license/m:url", namespaces=namespace) == "https://www.apache.org/licenses/LICENSE-2.0.txt"
print("5 Apache-2.0 POM license declarations verified")
