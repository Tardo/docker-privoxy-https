#!/bin/sh
set -e
privman --init
exec "$@"
