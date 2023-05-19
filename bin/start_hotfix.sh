#!/bin/bash

# ghとjqのインストール状況を確認
gh_installed=$(command -v gh &> /dev/null; echo $?)
jq_installed=$(command -v jq &> /dev/null; echo $?)

# 両方がインストールされていない場合、インストールを催促
if [[ $gh_installed -ne 0 && $jq_installed -ne 0 ]]; then
    echo "gh (GitHub CLI) and jq are not installed."
    echo "Please install them with Homebrew using the following commands:"
    echo "brew install gh"
    echo "brew install jq"
    exit 1
# ghだけがインストールされていない場合、インストールを催促
elif [[ $gh_installed -ne 0 ]]; then
    echo "gh (GitHub CLI) is not installed."
    echo "Please install it with Homebrew using the following command: brew install gh"
    exit 1
# jqだけがインストールされていない場合、インストールを催促
elif [[ $jq_installed -ne 0 ]]; then
    echo "jq is not installed."
    echo "Please install it with Homebrew using the following command: brew install jq"
    exit 1
fi

# 標準入力でcommit shaを求める
echo "Enter the commit sha:"
read commit_sha

# git fetch
git fetch

# tag名を取得
tag_name=$(git describe --tags $commit_sha 2>/dev/null)

# エラーチェック
if [ $? -ne 0 ]; then
    echo "Error: Unable to find a tag associated with the commit sha: $commit_sha"
    exit 1
fi

# git checkout
git checkout $commit_sha

# 新しいブランチを作成
new_branch="release/${tag_name}_p1"
git switch -c $new_branch

# 新しいブランチをpush
git push origin $new_branch

# workブランチを作成
work_branch="work/${tag_name}_p1"
git branch $work_branch $new_branch

# workブランチにチェックアウト
git checkout $work_branch

# empty commitを2回行う
git commit --allow-empty -m "empty commit 1"
git commit --allow-empty -m "empty commit 2"

# workブランチをpush
git push origin $work_branch

# GitHubのユーザーネームを取得
gh_username=$(gh api user --jq '.login')

# workブランチからrelease, master, developブランチに対してPRを作成する（自分自身をassigneesに割り当て、ドラフトとしてマークする）
gh pr create \
    --base $new_branch \
    --head $work_branch \
    --title "PR from $work_branch to $new_branch" \
    --body "PR from $work_branch to $new_branch" \
    --assignee $gh_username \
    --draft

gh pr create \
    --base master \
    --head $work_branch \
    --title "PR from $work_branch to master" \
    --body "PR from $work_branch to master" \
    --assignee $gh_username \
    --draft

gh pr create \
    --base develop \
    --head $work_branch \
    --title "PR from $work_branch to develop" \
    --body "PR from $work_branch to develop" \
    --assignee $gh_username \
    --draft
