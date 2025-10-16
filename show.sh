#!/bin/bash

# Specify the directory (change this to your desired directory)
#DIRECTORY="./lib/Cron/Describe"

# Loop through each file in the directory
#for file in "lib/Cron/Describe"/* "lib/Cron"/* "t"/* "t/data"/*json; do
for file in "lib/Cron/Describe"/*; do
    # Check if it is a file
    if [[ -f "$file" ]]; then
        # Echo the filename
        echo "#Filename: $(basename "$file")"
        
        # Display the content of the file
        cat "$file"
        echo
    fi
done

