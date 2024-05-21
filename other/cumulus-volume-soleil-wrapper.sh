#!/bin/sh
PYTHONUNBUFFERED=TRUE ./cumulus-volume-soleil.py 2>&1 | tee /tmp/cumulus-volume-soleil.log
