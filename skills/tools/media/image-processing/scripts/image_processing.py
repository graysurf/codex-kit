#!/usr/bin/env python3
from __future__ import annotations

import os
import sys


def main() -> None:
    os.execvp("image-processing", ["image-processing", *sys.argv[1:]])


if __name__ == "__main__":
    main()
