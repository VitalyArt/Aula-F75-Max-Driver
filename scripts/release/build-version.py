#!/usr/bin/env python3
"""Resolve the shared build version and export it for subsequent Actions steps."""
import sys
from identity import main

if __name__ == '__main__':
    sys.argv.extend(['--field', 'version', '--github-env'])
    main()
