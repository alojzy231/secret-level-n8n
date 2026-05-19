#!/bin/bash
set -euo pipefail
trap 'echo "at line $LINENO, exit code $? from $BASH_COMMAND" >&2; exit 1' ERR

# Claude Code UserPromptSubmit hook — prevents reflexive "you are right" responses.
#
# Checks the last 5 assistant messages in the transcript. If any start with
# sycophantic agreement ("You're right", "Absolutely", etc.), injects a
# system-reminder into the next prompt that enforces substantive technical analysis.

stdin=$(cat)
transcript_path=$(echo "$stdin" | jq -r ".transcript_path")

items=$(grep '"role":"assistant"' "$transcript_path" | tail -n 5 || true)
needs_reminder=false
while IFS= read -r item; do
    [[ "$(jq -r '.type // empty' <<< "$item")" == "assistant" ]] || continue
    [[ "$(jq -r '.message.content[0].type // empty' <<< "$item")" == "text" ]] || continue
    text=$(jq -r '.message.content[0].text' <<< "$item")
    [[ "${text:0:80}" =~ .*[Yy]ou.*(right|correct) ]] && needs_reminder=true
    [[ "${text:0:80}" =~ .*[Aa]bsolutely ]] && needs_reminder=true
    [[ "${text:0:80}" =~ .*사용자가.*맞다 ]] && needs_reminder=true  # Korean
    [[ "${text:0:80}" =~ .*맞습니다 ]] && needs_reminder=true  # Korean
done <<< "$items"
[[ "$needs_reminder" == "true" ]] || exit 0

# Exit code 0 causes Claude Code to append stdout to the context.
cat <<'EOF'
<system-reminder>
You MUST NEVER use the phrase 'you are right' or similar.
Avoid reflexive agreement. Instead, provide substantive technical analysis.
You must always look for flaws, bugs, loopholes, counter-examples,
invalid assumptions in what the user writes. If you find none,
and find that the user is correct, you must state that dispassionately
and with a concrete specific reason for why you agree, before
continuing with your work.
<example>
user: It's failing on empty inputs, so we should add a null-check.
assistant: That approach seems to avoid the immediate issue.
However it's not idiomatic, and hasn't considered the edge case
of an empty string. A more general approach would be to check
for falsy values.
</example>
<example>
user: I'm concerned that we haven't handled connection failure.
assistant: [thinks hard] I do indeed spot a connection failure
edge case: if the connection attempt on line 42 fails, then
the catch handler on line 49 won't catch it.
[ultrathinks] The most elegant and rigorous solution would be
to move failure handling up to the caller.
</example>
</system-reminder>
EOF

exit 0
