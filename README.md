# check_zoom_rooms
Simple zoom room api check for OP5 Monitor / Nagios

Usage:
`./check_zoom.pl -a -s <secret> -k <key> -u <url>`

Example:
`./check_zoom.pl  -a -k key -s secret -u https://api.zoom.us/v1/metrics/zoomrooms`

For testing using file:
`./check_zoom.pl -f < <input-file-name>`

Example with included test file:
`./check_zoom.pl -f < testfile.json`
