#!/bin/bash
# Prints the app version from its single source of truth.
set -euo pipefail
cd "$(dirname "$0")/.."
sed -n 's/.*static let version = "\(.*\)".*/\1/p' Sources/Minesweeper/AppInfo.swift
