# วิธีทำงานร่วมกัน (Git + GitHub)

เป้าหมายคือให้ทุก commit บน `main` **ย้อนกลับไปหา issue และ PR ที่มาได้เสมอ** และ revert ทีละงานได้ถ้ามีปัญหา

## กติกาหลัก

1. **1 issue = 1 branch = 1 PR** ทุกงานต้องมี issue ก่อน (ดูได้จาก [Project board](https://github.com/users/Kritternai/projects/4))
2. **ห้าม push ตรงเข้า `main`** ทุกอย่างต้องผ่าน PR
3. **Merge ด้วย "Squash and merge" เท่านั้น** แล้วกด **Delete branch** (ห้ามใช้ "Create a merge commit" หรือ "Rebase and merge")
4. **ไม่บังคับรีวิว:** เจ้าของ PR merge เองได้เมื่อ `flutter analyze` และ `flutter test` ผ่าน และทำครบ checklist ใน PR template แล้ว ถ้าอยากให้เพื่อนช่วยดูก็ขอได้ (`--reviewer <ชื่อ>`) แต่ไม่ต้องรอ
5. ถ้า PR แก้ `lib/domain/` หรือ `lib/app/theme/` ต้อง**แจ้งในกลุ่มก่อน merge** เพราะกระทบงานของทุกคน

## ชื่อ branch

```
<type>/<เลข issue>-<คำอธิบายสั้น-kebab-case>
```

| type | ใช้เมื่อ | ตัวอย่าง |
|---|---|---|
| `feat` | ฟีเจอร์ใหม่ หรือข้อมูลใหม่ | `feat/18-trip-request-form` |
| `fix` | แก้บั๊ก | `fix/52-cost-negative-buffer` |
| `test` | เพิ่มหรือแก้ test อย่างเดียว | `test/32-demo-scenarios` |
| `refactor` | ปรับโค้ดโดยพฤติกรรมไม่เปลี่ยน | `refactor/60-split-route-orderer` |
| `chore` | ตั้งค่า, dependency, build | `chore/13-firebase-setup` |
| `docs` | เอกสารอย่างเดียว | `docs/61-update-readme` |

ชื่อ branch ทุก issue เขียนไว้แล้วในหัวข้อ **Git workflow** ของ issue นั้น ให้ copy ไปใช้ได้เลย

## ข้อความ commit ([Conventional Commits](https://www.conventionalcommits.org/))

```
<type>(<scope>): <สิ่งที่ทำ ภาษาอังกฤษ ขึ้นต้นด้วยกริยา ตัวพิมพ์เล็ก> (#<เลข issue>)
```

ตัวอย่าง:
```
feat(trip-request): add date range step (#18)
test(planner): cover same-province intercity cost (#34)
fix(auth): handle cancelled google sign-in (#14)
```

- **scope** ใช้ชื่อโมดูล: `app`, `theme`, `domain`, `data`, `auth`, `profile`, `home`, `trip-request`, `suggestion`, `planner`, `ai`, `trip-plan`, `map`, `trips`
- **1 commit = 1 เรื่อง** ที่ build ผ่าน ห้ามรวม "แก้ทุกอย่าง" ไว้ใน commit เดียว
- ทุก commit ต้องลงท้ายด้วย `(#เลข issue)`

## ขั้นตอนทำงาน (copy ไปใช้ได้)

```bash
# 1) เริ่มงาน: แตก branch จาก main ล่าสุด
git switch main
git pull --ff-only
git switch -c feat/18-trip-request-form

# 2) ระหว่างทำ: commit ทีละเรื่อง
git add lib/features/trip_request/...
git commit -m "feat(trip-request): add date range step (#18)"

# 3) ก่อนเปิด PR: อัปเดตจาก main แล้วตรวจให้ผ่าน
git fetch origin
git rebase origin/main
dart format lib test
flutter analyze
flutter test

# 4) push แล้วเปิด PR (ชื่อ PR = ข้อความ commit หลักของงานนั้น)
git push -u origin feat/18-trip-request-form
gh pr create --base main \
  --title "feat(trip-request): add multi-step trip request form (#18)" \
  --body "Closes #18" \
  --assignee @me

# ถ้า rebase หลัง push ไปแล้ว ให้ใช้คำสั่งนี้แทน git push ธรรมดา
git push --force-with-lease

# 5) หลัง merge แล้ว: ลบ branch ในเครื่อง (squash ทำให้ต้องใช้ -D)
git switch main
git pull --ff-only
git branch -D feat/18-trip-request-form
```

## Pull Request

- ชื่อ PR ใช้รูปแบบ Conventional Commits และลงท้ายด้วย `(#เลข issue)` เพราะตอน squash จะกลายเป็นข้อความ commit บน `main`
- ใส่ `Closes #เลข` ใน PR เพื่อให้ issue ปิดเองเมื่อ merge
- กรอก checklist ใน PR template ให้ครบ ถ้ามี UI ต้องแนบภาพตาม [docs/DESIGN.md](docs/DESIGN.md)
- PR ควรเล็ก ถ้าเกิน ~400 บรรทัด (ไม่นับไฟล์ JSON ข้อมูล) ให้แบ่งเป็นหลาย PR

## สถานะบน Project board

| สถานะ | เมื่อไร |
|---|---|
| **Todo** | ยังไม่เริ่ม |
| **In Progress** | แตก branch แล้ว |
| **In Review** | เปิด PR แล้ว ยังไม่ merge |
| **Done** | merge แล้ว (issue ปิดอัตโนมัติจาก `Closes #`) |

## ถ้าต้อง revert

```bash
git switch main && git pull --ff-only
git switch -c revert/<เลข issue>-<สิ่งที่ revert>
git revert <sha ของ squash commit>
git push -u origin HEAD
gh pr create --base main --title "revert: <ชื่อ PR เดิม>" --body "Reverts #<เลข PR เดิม>"
```
