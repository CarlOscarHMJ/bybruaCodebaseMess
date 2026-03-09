#!/bin/bash

# Create a backup directory just in case
mkdir -p ./pdf_backups

for file in *.pdf; do
    # Skip if no pdf files are found
    [ -e "$file" ] || continue
    
    echo "Processing $file..."
    
    # Define temporary output name
    tmp_file="fixed_$file"
    
    # Run Ghostscript to flatten/standardize transparency
    gs -sDEVICE=pdfwrite \
       -dCompatibilityLevel=1.4 \
       -dColorConversionStrategy=/LeaveColorUnchanged \
       -dNOPAUSE \
       -dQUIET \
       -dBATCH \
       -sOutputFile="$tmp_file" "$file"
    
    if [ $? -eq 0 ]; then
        # Move original to backup and replace with fixed version
        mv "$file" "./pdf_backups/$file"
        mv "$tmp_file" "$file"
        echo "Successfully fixed $file (Original moved to ./pdf_backups)"
    else
        echo "Error: Failed to process $file"
        rm -f "$tmp_file"
    fi
done

echo "Done! All vector PDFs standardized for LaTeX."
