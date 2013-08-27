#!/bin/sh
rake extension:build_dev
rake daemon:build
# ruby -w build/dexd.rb --verbose
ruby build/dexd.rb --verbose