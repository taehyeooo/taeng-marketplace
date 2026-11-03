#!/bin/sh
# 러스트 검사 — 레포 안 cargo 프로젝트(워크스페이스 루트)마다 포맷·린트·테스트 (.claude/rules/rust.md)
# 사용: sh scripts/check_rust.sh   (CI `rust`가 러스트 파일이 바뀐 PR에서 돌린다, 커밋 전 로컬에서도)
# 러스트 프로젝트가 없으면 건너뛴다. 워크스페이스 멤버는 루트에서 한 번만 돈다.
set -eu

roots=$(git ls-files '*Cargo.toml' | while read -r manifest; do
  (cd "$(dirname "$manifest")" && cargo locate-project --workspace --message-format plain)
done | sort -u)

if [ -z "$roots" ]; then
  echo "러스트 프로젝트 없음 — 건너뜀"
  exit 0
fi

for root in $roots; do
  dir=$(dirname "$root")
  echo "== $dir"
  (cd "$dir" && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test)
done
echo "러스트 검사 통과"
