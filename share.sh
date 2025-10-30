#!/bin/bash

# Loop through each file in the directory
#for file in "lib/Cron"/* "lib/Cron/Toolkit/"/* "lib/Cron/Toolkit/Visitor"/* "lib/Cron/Toolkit/Pattern"/* "t"/* "bin"/* ; do
for file in "lib/Cron"/* "lib/Cron/Toolkit/"/* "lib/Cron/Toolkit/Visitor"/* "lib/Cron/Toolkit/Pattern"/* ; do
#for file in "t"/*; do
    # Check if it is a file
    if [[ -f "$file" ]]; then
        # Echo the filename
        echo "#Filename: $(basename "$file")"
        
        # Display the content of the file
        cat "$file"
        echo
    fi
done

