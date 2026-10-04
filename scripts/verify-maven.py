import hashlib
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

repository = Path(sys.argv[1]).resolve()
base = repository / "com/github/gycrosskit"
version = "0.1.1"
modules = sorted(file for file in base.rglob("*.module") if file.parent.name == version)
assert len(modules) == 5, modules
for file in modules:
    metadata = json.loads(file.read_text())
    assert metadata["component"]["group"] == "com.github.gycrosskit"
    assert metadata["component"]["version"] == version
    for variant in metadata["variants"]:
        assert variant["name"] != "metadataSourcesElements"
        assert not variant["name"].endswith(("SourcesElements-published", "MetadataElements-published"))
        available = variant.get("available-at")
        if available:
            target = (file.parent / available["url"]).resolve()
            assert target.is_relative_to(repository) and target.is_file(), target
        for artifact in variant.get("files", []):
            target = (file.parent / artifact["url"]).resolve()
            assert target.is_relative_to(repository) and target.is_file(), target
            assert hashlib.sha256(target.read_bytes()).hexdigest() == artifact["sha256"], target
    for algorithm in ("sha1", "sha256", "sha512", "md5"):
        checksum = file.with_name(file.name + "." + algorithm)
        if checksum.exists():
            assert checksum.read_text().strip() == hashlib.new(algorithm, file.read_bytes()).hexdigest(), checksum
assert len([file for file in base.rglob("*.aar") if file.parent.name == version]) == 1
assert len([file for file in base.rglob("*.klib") if file.parent.name == version]) == 3
assert not any("/Users/" in file.read_text() for file in modules)
print("5 Maven module metadata, AAR and 3 KLIB artifacts verified")

namespace = {"m": "http://maven.apache.org/POM/4.0.0"}
poms = sorted(file for file in base.rglob("*.pom") if file.parent.name == version)
assert len(poms) == 5, poms
for file in poms:
    root = ET.parse(file).getroot()
    assert root.findtext("m:licenses/m:license/m:name", namespaces=namespace) == "Apache License, Version 2.0"
    assert root.findtext("m:licenses/m:license/m:url", namespaces=namespace) == "https://www.apache.org/licenses/LICENSE-2.0.txt"
print("5 Apache-2.0 POM license declarations verified")
