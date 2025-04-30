#!/bin/bash

# Tiny little script to update all git repositories from a folder at once

for dir in ./*/;
do
cd "$dir" && git pull && cd ..;
done