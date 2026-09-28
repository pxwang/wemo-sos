#!/usr/bin/env python3
"""CLI for scheduled Wemo control. Discovers devices by friendly name each
run (so it survives DHCP address changes) then sets on/off state via SOAP.
Standard library only, no cloud involved.

Usage:
    wemo_ctl.py on  "Night Light"
    wemo_ctl.py off "Night Light"
    wemo_ctl.py list
"""
import socket
import sys
import time
import re
import urllib.request
import xml.etree.ElementTree as ET

SSDP_ADDR = "239.255.255.250"
SSDP_PORT = 1900
SEARCH_TARGET = "urn:Belkin:device:**"

MSEARCH = (
    "M-SEARCH * HTTP/1.1\r\n"
    f"HOST: {SSDP_ADDR}:{SSDP_PORT}\r\n"
    'MAN: "ssdp:discover"\r\n'
    "MX: 3\r\n"
    f"ST: {SEARCH_TARGET}\r\n"
    "\r\n"
).encode("utf-8")


def discover(timeout=6):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.settimeout(1)

    locations = set()
    sock.sendto(MSEARCH, (SSDP_ADDR, SSDP_PORT))

    start = time.time()
    while time.time() - start < timeout:
        try:
            data, _ = sock.recvfrom(4096)
        except socket.timeout:
            continue
        text = data.decode("utf-8", errors="ignore")
        m = re.search(r"LOCATION:\s*(\S+)", text, re.IGNORECASE)
        if m:
            locations.add(m.group(1).strip())
    sock.close()
    return locations


def get_friendly_name(setup_xml_url):
    try:
        with urllib.request.urlopen(setup_xml_url, timeout=3) as resp:
            xml_data = resp.read()
        root = ET.fromstring(xml_data)
        ns = {"u": "urn:Belkin:device-1-0"}
        name = root.find(".//u:friendlyName", ns)
        return name.text if name is not None else None
    except Exception:
        return None


def soap_request(location_url, action, body_inner):
    m = re.match(r"http://([^/]+)/", location_url)
    if not m:
        raise ValueError("bad location url")
    control_url = f"http://{m.group(1)}/upnp/control/basicevent1"

    soap_action = f'"urn:Belkin:service:basicevent:1#{action}"'
    body = (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        "<s:Body>"
        f'<u:{action} xmlns:u="urn:Belkin:service:basicevent:1">'
        f"{body_inner}"
        f"</u:{action}>"
        "</s:Body></s:Envelope>"
    ).encode("utf-8")

    req = urllib.request.Request(control_url, data=body, method="POST")
    req.add_header("Content-Type", 'text/xml; charset="utf-8"')
    req.add_header("SOAPAction", soap_action)
    with urllib.request.urlopen(req, timeout=3) as resp:
        return resp.read().decode("utf-8", errors="ignore")


def set_binary_state(location_url, on: bool):
    val = "1" if on else "0"
    return soap_request(location_url, "SetBinaryState", f"<BinaryState>{val}</BinaryState>")


def find_device_by_name(name_substring, timeout=6):
    for loc in discover(timeout=timeout):
        found_name = get_friendly_name(loc)
        if found_name and name_substring.lower() in found_name.lower():
            return loc, found_name
    return None, None


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "list":
        for loc in sorted(discover()):
            print(f"{get_friendly_name(loc)}\t{loc}")
        return

    if len(sys.argv) != 3 or sys.argv[1] not in ("on", "off"):
        print(__doc__)
        sys.exit(1)

    action, device_name = sys.argv[1], sys.argv[2]
    loc, found_name = find_device_by_name(device_name)
    if not loc:
        print(f"ERROR: no device matching '{device_name}' found on the network", file=sys.stderr)
        sys.exit(2)

    set_binary_state(loc, action == "on")
    print(f"{found_name} -> {action.upper()} ({loc})")


if __name__ == "__main__":
    main()
