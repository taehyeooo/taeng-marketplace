# reviewflow

PR을 **정확성 · 테스트 · 보안/시크릿 · 프로젝트 규칙** 네 관점으로 동시에 리뷰하고, 지적을 레포 코드로 다시 검증해 맞는 것만 심각도 순으로 내는 Claude Code 플러그인입니다.
짝: [devflow](../devflow)(ship pr 전후에) · [benchflow](../benchflow)(지표) · [evalflow](../evalflow)

```
/reviewflow:review 152            # PR #152
/reviewflow:review                # 현재 브랜치 vs 기본 브랜치
/reviewflow:review 152 --comment  # 결과를 PR 댓글 하나로(올리기 전에 확인)
```

## 왜
혼자 개발하면 PR을 봐 줄 사람이 없고, 일반 리뷰 도구는 **그 레포가 이미 정한 결정**(ADR)과 지침(CLAUDE.md)을 모릅니다.
reviewflow는 레포의 CLAUDE.md·AGENTS.md·`docs/adr/`를 읽는 규칙 리뷰어를 따로 두고, 모든 지적에 `경로:줄`과 실패 시나리오를 요구한 뒤 검증 에이전트가 반박해 봅니다.

## 구성
| 에이전트 | 보는 것 |
|---|---|
| review-correctness | 조건·경계값·null·예외·트랜잭션·비동기 실패·멱등성 |
| review-tests | 바뀐 동작마다 그것을 실패시킬 테스트가 있는지, 테스트 자체의 허점 |
| review-security | 인증·인가, 입력 검증·주입, 시크릿·개인정보 노출, 비용 드는 API 남용 |
| review-rules | ADR·지침 위반(문서 경로와 문장 인용 필수) |
| review-verifier | 위 지적을 코드로 다시 확인 → CONFIRMED / PLAUSIBLE / REJECTED |

지적 수(심각도별)·검증에서 뺀 수·걸린 시간은 `~/.config/reviewflow/usage.log`와 HTML 리포트(`~/.config/flow-reports/reviewflow/`)에 남습니다.

## 비용
Claude Code 구독 안의 서브에이전트만 씁니다. 외부 리뷰 서비스·유료 API를 부르지 않습니다.

## 설치
```
/plugin marketplace add taehyeooo/taeng-marketplace
/plugin install reviewflow@taeng-marketplace
```
필요: `gh`(PR 리뷰·댓글), `jq`. 설정 파일은 없습니다.
