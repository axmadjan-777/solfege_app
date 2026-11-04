#!/usr/bin/env bash
# Verify exactly the index, so unstaged fixes cannot hide a broken commit.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

if [[ -n "$(git ls-files --unmerged)" ]]; then
  echo "QA: сначала разрешите конфликты в индексе." >&2
  exit 1
fi
git diff --cached --check

# Resolve machine-local SDK paths before entering the isolated snapshot.
# shellcheck source=tool/toolchain.sh
source tool/toolchain.sh

qa_tmp=$(mktemp -d "${TMPDIR:-/tmp}/solfege-staged-qa.XXXXXX")
trap 'rm -rf "$qa_tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# write-tree reads the index; it does not create a commit or move any ref.
qa_tree=$(git write-tree)
mkdir "$qa_tmp/source"
git archive "$qa_tree" | tar -x -C "$qa_tmp/source"
echo "QA staged tree: $qa_tree (изолированная копия, без незакоммиченных файлов)"

# Compare the whole staged tree to HEAD, including both sides of renames.
# An initial commit has no trusted baseline and always receives full QA.
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  git diff --no-renames --name-only -z HEAD "$qa_tree" > "$qa_tmp/paths"
else
  : > "$qa_tmp/paths"
fi

# Git sets these for hooks; clear them only in the QA subprocess. Preserve
# the caller's index (including GIT_INDEX_FILE) for the final consistency check.
(
  while IFS= read -r git_variable; do
    unset "$git_variable"
  done < <(git rev-parse --local-env-vars)
  cd "$qa_tmp/source"
  if [[ ! -f tool/verify.sh ]]; then
    echo "QA: tool/verify.sh отсутствует в подготовленном коммите." >&2
    exit 1
  fi
  qa_scope=$(python3 tool/qa_scope.py < "$qa_tmp/paths")
  echo "QA scope: $qa_scope"
  if [[ "$qa_scope" == docs ]]; then
    bash tool/verify.sh --docs-only
  else
    bash tool/verify.sh
  fi
)
if [[ "$(git write-tree)" != "$qa_tree" ]]; then
  echo "QA: индекс изменился во время проверки; повторите коммит для нового снимка." >&2
  exit 1
fi
echo "QA staged tree $qa_tree пройден."
