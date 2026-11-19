"""Build the bundled index from Dell/Lenovo XML catalogs and Google's USB ZIP."""
import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urlsplit
from zipfile import ZipFile

dell, lenovo, usb, output = map(Path, sys.argv[1:])
records = []


def add(source, model, ids, os_name, version, url, digest):
    if not re.fullmatch(r"[0-9a-fA-F]{64}", digest or ""):
        return
    if urlsplit(url).hostname not in {"downloads.dell.com", "download.lenovo.com", "dl.google.com"} or not url.startswith("https://"):
        return
    records.append(dict(source=source, model=model.strip(), ids=sorted(set(ids)), os=os_name,
                        version=version, url=url, sha256=digest.lower()))


for pkg in ET.parse(dell).findall(".//{*}DriverPackage"):
    dig = pkg.find("{*}Cryptography/{*}Hash[@algorithm='SHA256']")
    if dig is None:
        continue
    for os_node in pkg.findall("{*}SupportedOperatingSystems/{*}OperatingSystem"):
        os_code = os_node.get("osCode")
        if os_code not in ("Windows10", "Windows11") or os_node.get("osArch") != "x64":
            continue
        for model in pkg.findall("{*}SupportedSystems/{*}Brand/{*}Model"):
            add("Dell", model.get("name") or model.findtext("{*}Display", ""),
                [model.get("systemID", "")], os_code[-2:], pkg.get("dellVersion", ""),
                "https://downloads.dell.com/" + pkg.get("path"), dig.text)
for model in ET.parse(lenovo).findall(".//Model"):
    for pkg in model.findall("SCCM"):
        if pkg.get("os") not in ("win10", "win11") or model.get("arch","").lower() in ("arm","arm64","qualcomm"):
            continue
        add("Lenovo", model.get("name"), [t.text for t in model.findall("Types/Type")],
            pkg.get("os")[-2:], (pkg.get("version","")+" "+pkg.get("date","")).strip(), pkg.text.strip(), pkg.get("crc"))
with ZipFile(usb) as package:
    inf = package.read("usb_driver/android_winusb.inf").decode("latin1")
    section = re.search(r"(?ims)^\[Google\.NTamd64\]\s*(.*?)(?=^\[)", inf)
    ids = re.findall(r"(?i)USB\\VID_[0-9A-F]{4}&PID_[0-9A-F]{4}(?:&MI_[0-9A-F]{2})?", section.group(1))
    add("Google", "Android USB Driver (ADB / Bootloader)", ids, "10/11", "r13",
        "https://dl.google.com/android/repository/usb_driver_r13-windows.zip", hashlib.sha256(usb.read_bytes()).hexdigest())
if not all(any(x["source"] == brand and x["ids"] for x in records) for brand in ("Dell","Lenovo","Google")):
    raise ValueError("Incomplete source catalog")
output.write_text(json.dumps(records, ensure_ascii=True, separators=(",", ":")), encoding="ascii")
print(len(records), "model/package records")
