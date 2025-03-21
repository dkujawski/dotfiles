
# craft a branch name based on the current jira issue
function git_branch_name {
    j=$(jira issue list -s'in progress' -a$(jira me) --plain --columns key,summary --no-headers|sed 's/[[:space:][:punct:]]/-/g;' | python -c 'import sys; import re; s=re.sub(r"-+","-", sys.stdin.read())[:45]; s=re.sub(r"_$","", s); print(s)')
    echo "personal/dk/${j}"
}

alias git-branch-name='git_branch_name'
