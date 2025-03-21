
# Search for a string in terraform files recursively in the current directory.
# Ex: tfgrep bucketname
function tfgrep {
    grep -r -n --include "*.tf" --include "*.tfvars" "${1}" .
}

