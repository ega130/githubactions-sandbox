#!/bin/bash

# Check if gh is installed
if ! command -v gh &> /dev/null
then
    missing_tools+="GitHub CLI (gh), "
fi

# Check if jq is installed
if ! command -v jq &> /dev/null
then
    missing_tools+="jq, "
fi

# If any tool is missing
if [ ! -z "$missing_tools" ]
then
    # Remove the trailing comma and space
    missing_tools=${missing_tools%??}

    echo "The following tool(s) are not found: $missing_tools. Please install them using Homebrew by running: brew install $missing_tools"
    exit 1
fi

# 標準入力からcommit shaを読み取る
echo "Enter commit sha:"
read commit_sha

# git fetch
git fetch

# tag名を取得する
tag_name=$(git describe --tags $commit_sha)

# tagの取得が失敗したらエラーメッセージを表示して終了
if [ -z "$tag_name" ]; then
  echo "Failed to get the tag name. Exiting."
  exit 1
fi

# タグ名を利用者に確認する
echo "Tag name is: $tag_name"
echo "Is this correct? (y/n)"
read confirm

if [ "$confirm" != "y" ]; then
  echo "Tag name is not confirmed. Exiting."
  exit 1
fi

# パッチバージョンの選択肢を表示する
echo "Please select a patch version:"
select patch_version in 1 2 3 4 5 6 7 8 9 10
do
  if [ -n "$patch_version" ]; then
    echo "You have selected patch version: $patch_version"
    break
  else
    echo "Invalid selection. Please try again."
  fi
done

# GitHubのユーザー名を取得します。これはassigneeとして使用されます。
github_user=$(gh api user | jq -r '.login')

# git checkout
git checkout $commit_sha

# releaseブランチが存在するかチェックする
if ! git rev-parse --quiet --verify release/${tag_name}_${patch_version} > /dev/null
then
    # releaseブランチを作成する
    git switch -c release/${tag_name}_${patch_version}

    # releaseブランチをpushする
    git push origin release/${tag_name}_${patch_version}
else
    echo "Branch release/${tag_name}_${patch_version} already exists. Skipping branch creation and push."
fi

# workを作成する
git branch work/${tag_name}_${patch_version}_${github_user} release/${tag_name}_${patch_version}

# workブランチにcheckoutする
git checkout work/${tag_name}_${patch_version}_${github_user}

# empty commitを行う
git commit --allow-empty -m "hotfix ${tag_name}_${patch_version}"

# ブランチをpushする
git push origin work/${tag_name}_${patch_version}_${github_user}

# PRを作成する
# PRを作成する
gh pr create --title "PR from work/${tag_name}_${patch_version}_${github_user} to release/${tag_name}_${patch_version}" \
              --body "" \
              --base release/${tag_name}_${patch_version} \
              --head work/${tag_name}_${patch_version}_${github_user} \
              --draft \
              --assignee "$github_user"

gh pr create --title "PR from work/${tag_name}_${patch_version}_${github_user} to master" \
              --body "" \
              --base master \
              --head work/${tag_name}_${patch_version}_${github_user} \
              --draft \
              --assignee "$github_user"

gh pr create --title "PR from work/${tag_name}_${patch_version}_${github_user} to develop" \
              --body "" \
              --base develop \
              --head work/${tag_name}_${patch_version}_${github_user} \
              --draft \
              --assignee "$github_user"
