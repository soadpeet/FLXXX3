#!/usr/bin/env bash
# AI disclaimer: this file was written autonomously by an AI agent (Claude).
#
# FLXXX3 GitHub workflows: shows the important lines of a failed step as one error annotation.
# Annotations can be read without logging in (the logs cannot), so a failure can be looked at
# from the development computer too.
#   annotate_failure.sh <title> <log file>
title="$1"
log="$2"
lines="$(grep -n -E -A12 'CMake Error|FATAL_ERROR|error:|Error [0-9]|No dependencies|No rule to make|not found|FAILED' "$log" | head -60)"
[ -n "$lines" ] || lines="$(tail -40 "$log")"
# Workflow commands: % and line breaks must be encoded.
lines="${lines//'%'/'%25'}"
lines="${lines//$'\r'/}"
lines="${lines//$'\n'/'%0A'}"
echo "::error title=${title} failed::${lines}"
