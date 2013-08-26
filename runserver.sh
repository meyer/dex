#!/bin/sh
rake extension:build_dev && rake daemon:build && build/dexd.rb