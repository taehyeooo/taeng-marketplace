# lidflow

노트북 **덮개를 닫아도 잠들지 않게** 켜고 끄는 Claude Code 플러그인입니다.
휴대폰 원격(Orca Mobile, Paseo 등)으로 내 컴퓨터의 에이전트를 계속 돌려 둘 때 씁니다.

```
/lidon       # 덮개를 닫아도 안 잠듦
/lidoff      # 원래대로(가방에 넣기 전에)
/lidstatus   # 지금 상태
```

## 왜
원격 에이전트 도구는 휴대폰이 화면일 뿐이고, 실제 작업은 노트북에서 돈다. 덮개를 닫아 잠들면 연결이 끊긴다.
`caffeinate`나 그걸 감싼 앱(KeepingYouAwake 등)은 **유휴 잠자기만 막고 덮개 닫힘 잠자기는 못 막는다.**
Amphetamine의 덮개 닫힘 모드는 Apple Silicon에서 전원 상태가 바뀌면 풀린다는 보고가 많다.

## 동작
| OS | 켜기 | 끄기 |
|---|---|---|
| macOS | `pmset -a disablesleep 1` (관리자 비밀번호 창 — TTY 없는 세션에서도 동작) | `pmset -a disablesleep 0` |
| Windows (Git Bash) | 전원 옵션 덮개 닫기 동작(LIDACTION)을 AC·DC 모두 "아무것도 안 함" | 켜기 전에 저장한 값으로 복원(`~/.config/lidflow/windows-lidaction`, 없으면 절전) |
| Linux | 지원 안 함 — `/etc/systemd/logind.conf`의 `HandleLidSwitch`로 직접 | |

- 실측(macOS 26.5.1, Apple Silicon, 전원 연결): `lidon` 뒤 덮개를 닫고 20분 동안 잠들지 않았고 Tailscale 경유 휴대폰 연결이 유지됨.
- 설정은 재부팅 뒤에도 남는다. **가방에 넣기 전에 꼭 `/lidoff`** — 잠들지 않은 채 가방 안에 있으면 열이 차고 배터리가 닳는다.
- 터미널에서 바로: `bash <플러그인 경로>/scripts/lid.sh on|off|status`

## 비용
외부 서비스·API를 쓰지 않는다.

## 설치
```
/plugin marketplace add taehyeooo/taeng-marketplace
/plugin install lidflow@taeng-marketplace
```
