#!/bin/sh
rake daemon:stop
rake dev
ruby build/dexd.rb --verbose