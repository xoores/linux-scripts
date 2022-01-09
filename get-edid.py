#!/usr/bin/env python
"""
Script used for getting EDID info from monitors.

Usefull in one of my scripts to identify each monitor regardless of what
input it uses and what name is being used by Xrandr.

It returns EDID as BINARY DATA so you will probably want to pipe the
output to whichever checksum you want to use - something like this:

/scripts/get-edid.py eDP-1 | sha256sum
a04679750ce46557edf59295cde189d33d689a1b787ce2b09d8cf27dbd83b02d  -

I honestly don't know where I got this script but it is not mine. It was
a long time ago and I did not save the source - sorry :-(
"""

import binascii
import re
import subprocess
import sys
from os.path import basename

XRANDR_BIN = 'xrandr'

# re.RegexObject: expected format of xrandr's EDID ascii representation
EDID_DATA_PATTERN = re.compile(r'^\t\t[0-9a-f]{32}$')


def get_edid_for_connector(connector_name):
    """Finds the EDID for the given connector.

    Args:
        connector_name (str): Name of a connector, i.e. HDMI-0, DP-1

    Returns:
        Binary EDID for the connector, or None if not found.

    Raises:
        OSError: Failed to run xrandr.
    """

    # re.RegexObject: pattern for this connector's xrandr --props section
    connector_pattern = re.compile('^{} connected'.format(connector_name))

    try:
        xrandr_output = subprocess.check_output([XRANDR_BIN, '--props'])
    except OSError as e:
        sys.stderr.write('Failed to run {}\n'.format(XRANDR_BIN))
        raise e

    output_lines = xrandr_output.decode('ascii').split('\n')

    def slurp_edid_string(line_num):
        """Helper for getting the EDID from a line match in xrandr output."""
        edid = ''
        offset=1

        for i in range(line_num + 1, len(output_lines)):
            if re.match(r'\tEDID:', output_lines[line_num+offset]):
                break
            else:
                offset += 1

        if (line_num+offset) >= len(output_lines):
            return None

        for i in range(line_num + offset + 1, len(output_lines)):
            line = output_lines[i]
            if EDID_DATA_PATTERN.match(line):
                edid += line.strip()
            else:
                break
        return edid if len(edid) > 0 else None

    for i in range(len(output_lines)):
        connector_match = connector_pattern.match(output_lines[i])
        if connector_match:
            edid_str = slurp_edid_string(i)
            if edid_str is None:
                return None
            return binascii.unhexlify(edid_str)

    return None


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('Usage: {} <OUTPUT>'.format(basename(sys.argv[0])))

    connector_name = sys.argv[1]

    edid_bin = get_edid_for_connector(connector_name)
    if edid_bin is None:
        sys.exit('No EDID found for output {}'.format(connector_name))

    if sys.version_info >= (3, 0):
        sys.stdout.buffer.write(edid_bin)
    else:
        sys.stdout.write(edid_bin)

    sys.exit(0)

# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4
