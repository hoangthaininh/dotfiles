# Dựng lại SSH + Git trên Fedora sạch

**Dành cho:** `tainjiao-dotdev` · Fedora 45 (hoặc mới hơn) cài mới hoàn toàn
**Viết ngày:** 22/09/2026, từ cấu hình đã chạy thật trên Fedora 44
**Thời gian:** ~30 phút, chưa tính tải gói

> Guide này mô tả **cấu hình đích**, không chép nguyên trạng máy cũ. Ba điểm đã được sửa so với bản đang chạy: định tuyến danh tính chuyển sang *fail-closed*, `insteadOf` thu hẹp theo tổ chức, và thêm kiểm tra object độc hại. Lý do từng thay đổi ghi ở [§9](#9-vì-sao-guide-khác-máy-cũ).

---

## Mục lục

- [0. Trước khi xoá máy cũ](#0-trước-khi-xoá-máy-cũ)
- [1. Kiến trúc](#1-kiến-trúc)
- [2. Cài gói](#2-cài-gói)
- [3. Sinh khoá SSH](#3-sinh-khoá-ssh)
- [4. `~/.ssh/config`](#4-sshconfig)
- [5. Đăng ký khoá lên GitHub / GitLab](#5-đăng-ký-khoá-lên-github--gitlab)
- [6. Git: định tuyến danh tính](#6-git-định-tuyến-danh-tính)
- [7. Ký commit bằng khoá SSH](#7-ký-commit-bằng-khoá-ssh)
- [8. Máy công ty qua Tailscale](#8-máy-công-ty-qua-tailscale)
- [9. Vì sao guide khác máy cũ](#9-vì-sao-guide-khác-máy-cũ)
- [10. Những bẫy đã gặp thật](#10-những-bẫy-đã-gặp-thật)
- [11. Checklist xác minh](#11-checklist-xác-minh)

---

> **Trạng thái đồng bộ (22/09/2026):** ba thay đổi ở [§9.1](#91-bỏ-useremail-toàn-cục--fail-closed), [§9.2](#92-thu-hẹp-insteadof) và [§9.3](#93-thêm-fsckobjects) **đã được áp lên máy Fedora 44 đang chạy** và xác minh đạt. Guide và máy hiện khớp nhau, trừ phần GMO — xem [§9.5](#95-bỏ-gmo).

---

## 0. Trước khi xoá máy cũ

**Guide này phải nằm ngoài máy.** Ổ đã mã hoá LUKS, wipe là mất sạch. Chép nó vào repo `dotfiles`, cloud, hoặc USB trước khi cài lại.

Những thứ **không** cần sao lưu — guide dựng lại được hết:

| | |
|---|---|
| `~/.ssh/config` | §4 |
| `~/.gitconfig` và các tệp danh tính | §6 |
| `~/.gitignore_global` | §6 |
| `allowed_signers` | §7 |
| `known_hosts` | Tự dựng lại khi kết nối |

Những thứ **phải quyết trước**:

- **Khoá riêng** — sinh mới (khuyến nghị: dứt điểm, thu hồi khoá cũ) hay mang theo? Mang theo thì chép cả cặp `id_ed25519_*` + `.pub`, giữ quyền `600`/`644`. Sinh mới thì phải đăng ký lại ở GitHub, GitLab và `authorized_keys` trên Mac.
- **Khoá GPG cũ** — máy Fedora 44 còn một khoá GPG (`BD026CAF…`) không còn dùng để ký; chữ ký GPG trong lịch sử repo ký bằng khoá khác đã mất từ lâu. Không cần mang sang.

---

## 1. Kiến trúc

Nguyên tắc: **thư mục quyết định danh tính.** Không có lệnh nào phải gõ để "chuyển tài khoản".

### Toàn cảnh

```
 ┌── CÁ NHÂN ───────────────────────────────────────────────────┐
 │  thư mục   ~/Workspace/personal/                             │
 │  danh tính hoangthaininh.hgn@gmail.com                       │
 │  alias     github.com · gitlab.com                           │
 │  khoá      id_ed25519_personal      (không passphrase)       │
 └──────────────────────────────────────────────────────────────┘

 ┌── COMAC PRO ─────────────────────────────────────────────────┐
 │  thư mục   ~/Workspace/clients/cmp/                          │
 │  danh tính ninhht@comacpro.com                               │
 │  alias     github.com-cmp                                    │
 │  khoá      id_ed25519_cmp           (không passphrase)       │
 └──────────────────────────────────────────────────────────────┘

 ┌── MÁY CÔNG TY — ngoài hệ định tuyến ─────────────────────────┐
 │  thư mục   (không áp dụng — không theo thư mục)              │
 │  alias     mac-cmp · mac-cmp-file                            │
 │  khoá      id_ed25519_macos-comacpro   (CÓ passphrase)       │
 │                                                              │
 │  KHÔNG ký commit · KHÔNG vào allowed_signers                 │
 └──────────────────────────────────────────────────────────────┘

 Repo ngoài hai thư mục trên  →  ✗ LỖI, dừng lại (fail-closed, §9.1)
```

Ba lớp, mỗi lớp một việc:

| Lớp | Tệp | Việc |
|---|---|---|
| Git | `~/.gitconfig` | `includeIf` nạp danh tính theo đường dẫn |
| Git | `~/.gitconfig-personal`, `-cmp` | Email, khoá ký, viết lại URL remote |
| SSH | `~/.ssh/config` | Mỗi alias ép đúng một khoá |

### Một lệnh `git clone` đi qua những đâu

Sơ đồ dưới là toàn bộ cơ chế. Mỗi mũi tên là một từ khoá cấu hình có thật, và cột phải cho biết nó nằm ở tệp nào.

```
  BẠN GÕ
  cd ~/Workspace/clients/cmp
  git clone https://github.com/Comac-Pro/api.git
       │
       │   ~/.gitconfig
       │   includeIf "gitdir:~/Workspace/clients/cmp/"  ──► khớp
       ▼
  DANH TÍNH ĐƯỢC NẠP                                        ~/.gitconfig-cmp
       │   user.email  = ninhht@comacpro.com
       │   signingkey  = id_ed25519_cmp.pub
       │
       │   url."git@github.com-cmp:Comac-Pro/".insteadOf    ~/.gitconfig-cmp
       ▼
  URL BỊ VIẾT LẠI
       │       https://github.com/Comac-Pro/api.git
       │                      ↓
       │       git@github.com-cmp:Comac-Pro/api.git
       │
       │   Host github.com-cmp                              ~/.ssh/config
       ▼
  SSH TRA ALIAS
       │   HostName       = github.com      ← vẫn là GitHub thật
       │   IdentityFile   = id_ed25519_cmp
       │   IdentitiesOnly = yes             ← chỉ chào đúng khoá này
       ▼
  GITHUB XÁC THỰC
      Hi ninhht-cmp!
```

Người dùng không gõ gì đặc biệt — **thư mục làm việc là dữ liệu đầu vào duy nhất**.

---

## 2. Cài gói

```bash
sudo dnf install -y git openssh-clients
```

`gnome-keyring` có sẵn trong Fedora Workstation, không cần cài.

Tailscale (chỉ cần nếu dùng máy công ty từ xa — [§8](#8-máy-công-ty-qua-tailscale)):

```bash
sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
sudo dnf install -y tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up
```

`enable` là bắt buộc — thiếu nó thì sau reboot không tự lên tailnet.

**Không cài `openssh-askpass`.** GNOME đã có `gcr-ssh-askpass` sẵn; cài thêm là thừa. Xem [§10](#10-những-bẫy-đã-gặp-thật).

---

## 3. Sinh khoá SSH

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh

ssh-keygen -t ed25519 -C "hoangthaininh.hgn@gmail.com" -f ~/.ssh/id_ed25519_personal
ssh-keygen -t ed25519 -C "ninhht@comacpro.com"         -f ~/.ssh/id_ed25519_cmp
ssh-keygen -t ed25519 -C "tainjiao-dotdev"             -f ~/.ssh/id_ed25519_macos-comacpro
```

**Quy ước đặt tên — ba chỗ, ba loại thông tin:**

| Chỗ | Trả lời câu | Ai đọc |
|---|---|---|
| Tên tệp | khoá này dùng cho **danh tính nào** (Git) hoặc **mở máy nào** (đăng nhập) | bạn, lúc nhìn `~/.ssh` |
| Comment `-C` | email với khoá Git; **tên máy** với khoá đăng nhập | bạn, lúc đọc `authorized_keys` để thu hồi |
| Alias trong config | gõ gì cho nhanh | bạn, mỗi ngày |

Khoá máy đặt theo hostname vì `macos-comacpro` đã chứa sẵn tên tổ chức — được thông tin đó mà không lấn sang trục danh tính. Máy công ty thứ hai sau này là `id_ed25519_<host>` riêng, thu hồi độc lập.

**Passphrase:**

| Khoá | Passphrase | Lý do |
|---|---|---|
| `personal`, `cmp` | **Không** | Dùng hàng chục lần/ngày. Lộ thì thu hồi trong 30 giây, thiệt hại giới hạn trong repo. Chi phí không đáng |
| `macos-comacpro` | **Có** | Lộ là shell trên tài sản công ty. Dùng vài lần/ngày |

Đây là đánh đổi có chủ đích, không phải thiếu sót. Nền tảng bên dưới là LUKS toàn đĩa + khoá màn hình ≤ 5 phút; passphrase là lớp cho tình huống **máy đang mở và đã đăng nhập** — đúng chỗ LUKS không với tới.

> Với khoá có passphrase, **gõ trong terminal thật**. Chạy từ chỗ không có TTY sẽ dính bẫy askpass ở [§10](#10-những-bẫy-đã-gặp-thật).

Đặt quyền:

```bash
chmod 600 ~/.ssh/id_ed25519_*
chmod 644 ~/.ssh/*.pub
```

---

## 4. `~/.ssh/config`

```bash
cat > ~/.ssh/config << 'CONF'
# ── Máy công ty COMAC Pro (macOS, qua Tailscale) ─────────
Host mac-cmp
    HostName macos-comacpro.taila30e8c.ts.net
    User comacpro
    IdentityFile ~/.ssh/id_ed25519_macos-comacpro
    IdentitiesOnly yes
    ConnectTimeout 10
    ServerAliveInterval 30
    ServerAliveCountMax 3
    RequestTTY yes
    RemoteCommand /usr/local/bin/tmux new -A -s desk

# Không RemoteCommand — cho scp/rsync/sftp và lệnh đơn lẻ
Host mac-cmp-file
    HostName macos-comacpro.taila30e8c.ts.net
    User comacpro
    IdentityFile ~/.ssh/id_ed25519_macos-comacpro
    IdentitiesOnly yes
    ConnectTimeout 10
    ServerAliveInterval 30
    ServerAliveCountMax 3

# ── GitHub / GitLab ──────────────────────────────────────
Host github.com-cmp
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_cmp
    IdentitiesOnly yes

Match host github.com originalhost github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes

Host gitlab.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes
CONF
chmod 600 ~/.ssh/config
```

**Ba điều quyết định tính đúng đắn của tệp này:**

| | |
|---|---|
| `IdentitiesOnly yes` ở **mọi** khối | Thiếu nó, ssh-agent chào lần lượt mọi khoá nó giữ. GitHub nhận khoá hợp lệ đầu tiên — thường là khoá sai. Tệ hơn, có thể chạm `MaxAuthTries` rồi bị từ chối dù khoá đúng đang có trong agent |
| Khối cụ thể **đứng trước** khối tổng quát | SSH lấy **giá trị đầu tiên** tìm thấy cho mỗi tham số, không phải giá trị cuối. Đảo thứ tự là hỏng |
| `ConnectTimeout 10` trên **cả hai** khối Mac | Không có nó, `ssh` tới một Mac đang ngủ treo **130 giây** (đo thật 22/09/2026) rồi mới bỏ cuộc. `ServerAliveInterval` không cứu được — nó chỉ phát hiện kết nối **đã thiết lập** bị chết, không làm gì cho giai đoạn đang bắt tay. Với `ConnectTimeout 10` thì mất đúng 10 giây |
| `Match host … originalhost …` thay vì `Host github.com` | `Host` so với tên bạn *gõ ra*; `Match host` so với tên *sau khi* `HostName` thay thế. Thêm `originalhost` nghĩa là chỉ khớp khi cả hai đều là `github.com` — chặn trường hợp sau này thêm alias trỏ `HostName github.com` mà quên khai `IdentityFile`, khiến nó lặng lẽ nhận khoá cá nhân |

`HostName` của máy công ty dùng **FQDN Tailscale** chứ không phải tên trần, để không phụ thuộc search domain mà MagicDNS đẩy xuống.

---

## 5. Đăng ký khoá lên GitHub / GitLab

```bash
cat ~/.ssh/id_ed25519_personal.pub    # → tài khoản cá nhân
cat ~/.ssh/id_ed25519_cmp.pub         # → tài khoản công việc
```

Dán vào phần SSH keys của **từng tài khoản tương ứng**.

> **Muốn commit hiện "Verified":** thêm **cùng một khoá lần thứ hai**, chọn kiểu **Signing Key**. GitHub coi Authentication Key và Signing Key là hai mục riêng biệt. Bỏ bước này thì commit vẫn ký được nhưng GitHub hiển thị "Unverified".

Kiểm ngay:

```bash
ssh -T github.com          # → Hi <tài khoản cá nhân>!
ssh -T github.com-cmp      # → Hi <tài khoản công việc>!
ssh -T gitlab.com          # → Welcome to GitLab, @…
```

---

## 6. Git: định tuyến danh tính

### 6.1 Tạo cây thư mục trước

```bash
mkdir -p ~/Workspace/personal ~/Workspace/clients/cmp
```

Luật `includeIf` khớp theo đường dẫn; thư mục phải tồn tại thì repo mới rơi đúng chỗ.

### 6.2 `~/.gitconfig`

```bash
cat > ~/.gitconfig << 'CONF'
# ---- KHÔNG đặt danh tính ở đây (fail-closed) ----
# Cố ý bỏ trống: xem §9. Git sẽ từ chối commit ở thư mục chưa khai báo
# thay vì lặng lẽ dùng danh tính cá nhân.
[user]
    useConfigOnly = true

# ---- Ký commit ----
[gpg]
    format = ssh
[gpg "ssh"]
    allowedSignersFile = ~/.config/git/allowed_signers
[commit]
    gpgsign = true
    verbose = true
[tag]
    gpgsign = true
    sort = version:refname

# ---- An toàn dữ liệu ----
[transfer]
    fsckObjects = true
[fetch]
    fsckObjects = true
    prune = true
    writeCommitGraph = true
[receive]
    fsckObjects = true

# ---- Mặc định hợp lý ----
[init]
    defaultBranch = main
[pull]
    ff = only
[push]
    autoSetupRemote = true
[rebase]
    autoStash = true
    updateRefs = true
    missingCommitsCheck = warn
[rerere]
    enabled = true
    autoUpdate = true
[diff]
    algorithm = histogram
    colorMoved = default
    colorMovedWS = allow-indentation-change
[merge]
    conflictstyle = zdiff3
[branch]
    sort = -committerdate
[column]
    ui = auto
[core]
    excludesFile = ~/.gitignore_global
    fsmonitor = true
    untrackedCache = true

# ---- Danh tính theo thư mục ----
# Dấu / ở cuối là BẮT BUỘC — thiếu nó, luật khớp cả thư mục
# có tên bắt đầu giống nhau (clients/cmp-old/ chẳng hạn).
[includeIf "gitdir:~/Workspace/personal/"]
    path = ~/.gitconfig-personal
[includeIf "gitdir:~/Workspace/clients/cmp/"]
    path = ~/.gitconfig-cmp
CONF
```

### 6.3 Hai tệp danh tính

```bash
cat > ~/.gitconfig-personal << 'CONF'
[user]
    name = k-ryzhkov
    email = hoangthaininh.hgn@gmail.com
    signingkey = ~/.ssh/id_ed25519_personal.pub
CONF

cat > ~/.gitconfig-cmp << 'CONF'
[user]
    name = ninhht-cmp
    email = ninhht@comacpro.com
    signingkey = ~/.ssh/id_ed25519_cmp.pub

# Ép khoá theo THƯ MỤC, không phụ thuộc URL — xem §9.4
[core]
    sshCommand = ssh -i ~/.ssh/id_ed25519_cmp -o IdentitiesOnly=yes

# Chỉ viết lại URL của ĐÚNG các tổ chức này — xem §9.2
[url "git@github.com-cmp:Comac-Pro/"]
    insteadOf = git@github.com:Comac-Pro/
    insteadOf = https://github.com/Comac-Pro/
[url "git@github.com-cmp:ninhht-cmp/"]
    insteadOf = git@github.com:ninhht-cmp/
    insteadOf = https://github.com/ninhht-cmp/
CONF
```

`insteadOf` là lưới an toàn: copy URL `https://` từ trình duyệt thì Git vẫn đổi sang alias SSH đúng trước khi kết nối.

### 6.4 `~/.gitignore_global`

```bash
cat > ~/.gitignore_global << 'CONF'
.DS_Store
*.swp
.idea/
.vscode/
node_modules/
.env
.direnv/
__pycache__/
.python-version

**/.claude/settings.local.json
CONF
```

---

## 7. Ký commit bằng khoá SSH

Cùng một khoá vừa đăng nhập vừa ký — không cần GPG.

```bash
mkdir -p ~/.config/git
cat > ~/.config/git/allowed_signers << 'CONF'
hoangthaininh.hgn@gmail.com namespaces="git" ssh-ed25519 AAAA…<dán nội dung id_ed25519_personal.pub>
ninhht@comacpro.com         namespaces="git" ssh-ed25519 AAAA…<dán nội dung id_ed25519_cmp.pub>
CONF
```

Mỗi dòng: `<email> namespaces="git" <toàn bộ nội dung tệp .pub, bỏ phần comment cuối>`.

> **Không** thêm `id_ed25519_macos-comacpro` vào đây. Nó là khoá đăng nhập, không phải khoá ký.

Thiếu tệp này thì commit vẫn ký được, nhưng `git log --show-signature` báo *No principal matched*.

---

## 8. Máy công ty qua Tailscale

Chỉ làm nếu cần điều khiển Mac từ xa. Chi tiết đầy đủ ở runbook riêng; đây là phần tối thiểu.

**Trên Mac:** System Settings → General → Sharing → **Remote Login** bật, "Allow access for" → **Only these users**.

**Đẩy khoá sang** (lúc password auth còn bật):

```bash
ssh-copy-id -i ~/.ssh/id_ed25519_macos-comacpro.pub comacpro@macos-comacpro
```

**tmux trên Mac** — `RemoteCommand` ở §4 cần nó:

```bash
ssh mac-cmp-file '/usr/local/bin/brew install tmux'
```

> `RemoteCommand` phải ghi **đường dẫn tuyệt đối**. Xem [§10](#10-những-bẫy-đã-gặp-thật).

### Ranh giới tin cậy

```
  FEDORA (máy này)                    ┃   MAC CÔNG TY (người khác quản trị)
  ──────────────────────────────      ┃   ─────────────────────────────────
                                      ┃
  ┌─ hệ định tuyến danh tính ──┐      ┃   ~/.gitconfig RIÊNG của Mac
  │  id_ed25519_personal       │      ┃   khoá GitHub RIÊNG của Mac
  │  id_ed25519_cmp            │      ┃
  │  includeIf · insteadOf     │      ┃   (không đi theo kết nối SSH)
  │  allowed_signers · gpgsign │      ┃
  └────────────────────────────┘      ┃
                                      ┃
  id_ed25519_macos-comacpro           ┃
        │                             ┃
        │  ssh mac-cmp                ┃
        └──── mang ĐÚNG 1 khoá ───────╂──►  ~/.ssh/authorized_keys
                                      ┃     1 dòng · comment = tainjiao-dotdev
                                      ┃
        ForwardAgent yes              ┃
        ╳ sẽ mang CẢ BỘ khoá ─────────╂──►  root trên Mac dùng được hết
          suốt phiên kết nối          ┃     ĐỪNG BẬT
                                      ┃
                              ranh giới tin cậy
```

### Mac ngủ — vấn đề vận hành chính

macOS ngủ khi không ai đụng tới, và Tailscale **không** đánh thức được máy đang ngủ qua relay. Trong Tailscale, máy ngủ và máy tắt hiện giống hệt nhau:

```
macos-comacpro  …  offline, last seen 1m ago
```

`ConnectTimeout 10` chỉ làm thất bại **nhanh hơn** — nó không giúp bạn kết nối được. Kiểm tra rẻ hơn nhiều, và Tailscale đã biết sẵn câu trả lời trong **0 giây**:

```bash
tailscale status | grep macos-comacpro
# "offline, last seen …"  → đừng ssh, sẽ timeout
# "active; relay …"       → kết nối được
```

Ba hướng xử lý, mỗi hướng một giá:

| Hướng | Được | Mất |
|---|---|---|
| `sudo pmset -a sleep 0` trên Mac | Luôn với tới được | Máy công ty chạy 24/7, tốn điện, có thể trái chính sách IT |
| `caffeinate -s` trước khi rời bàn | Chỉ tỉnh khi cần | Phải nhớ; quên là mất truy cập cả ngày |
| Kiểm `tailscale status` trước khi kết nối | Không đổi gì trên máy công ty | Không truy cập được ngoài ý muốn |

Đổi chính sách nguồn trên tài sản của công ty là việc nên hỏi IT trước, nên hướng 3 là mặc định hợp lý.

**Đừng bật `ForwardAgent`.** Nó mở socket agent trên máy đích, cho ai có quyền root ở đó dùng mọi khoá trong agent của bạn suốt phiên — gồm cả khoá cá nhân. Mac nên có bộ khoá GitHub riêng của nó. OpenSSH mặc định tắt, nên chỉ cần đừng copy dòng đó từ blog nào vào.

**Danh tính Git không đi theo kết nối SSH.** `includeIf`, `insteadOf`, `allowed_signers` nằm trong `~/.gitconfig` của Fedora. Commit tạo trên Mac dùng cấu hình của Mac.

---

## 9. Vì sao guide khác máy cũ

### 9.1 Bỏ `user.email` toàn cục — fail-closed

Máy cũ đặt email cá nhân làm mặc định toàn cục, `includeIf` chỉ ghi đè cho hai thư mục. Nghĩa là mọi repo **không** khớp đều im lặng nhận danh tính cá nhân — không cảnh báo, không lỗi. Và hướng thất bại luôn là hướng xấu: dùng danh tính cá nhân cho việc khách hàng, không bao giờ ngược lại.

```
  FAIL-OPEN  (máy cũ)                  FAIL-CLOSED  (guide này)
  ═══════════════════════              ════════════════════════

  ~/.gitconfig                         ~/.gitconfig
    user.email = …gmail.com              user.useConfigOnly = true
              ↑ mặc định TOÀN CỤC        (không có danh tính mặc định)
    includeIf clients/cmp/               includeIf personal/
                                         includeIf clients/cmp/

  repo trong clients/cmp/              repo trong clients/cmp/
      → ninhht@comacpro.com   ✓            → ninhht@comacpro.com   ✓

  repo trong personal/                 repo trong personal/
      → …gmail.com            ✓            → …gmail.com            ✓

  repo Ở BẤT KỲ ĐÂU KHÁC               repo Ở BẤT KỲ ĐÂU KHÁC
      → …gmail.com            ✗            → DỪNG LẠI, báo lỗi     ✓
        im lặng, không cảnh báo              "Please tell me who you are"
```

Hướng thất bại của fail-open luôn là hướng xấu: danh tính **cá nhân** rò vào việc của **khách hàng**, không bao giờ ngược lại. Bỏ `[user]` khỏi global biến im lặng thành lỗi:

```
Author identity unknown
*** Please tell me who you are.
```

`user.useConfigOnly = true` là chốt chặn thứ hai. Không có nó, Git vẫn có thể tự đoán danh tính từ `$USER@$(hostname)` trong một số môi trường và commit kèm cảnh báo — tức là vẫn sai lặng lẽ, chỉ ồn ào hơn chút. Dòng này cấm đoán, bắt buộc phải có cấu hình tường minh.

**Đánh đổi:** repo tạm ở `/tmp` hay `~/` sẽ không commit được cho tới khi thêm include hoặc `git config --local user.email`. Một số tool giả định luôn có email toàn cục. Với người làm nhiều khách hàng, cái giá này rẻ hơn một commit sai danh tính trong repo của khách.

> **Tăng cường (tuỳ chọn):** Git ≥ 2.36 hỗ trợ định tuyến theo *remote* thay vì theo thư mục — khớp với ý định thật hơn, vì danh tính đúng do ai sở hữu remote quyết định chứ không phải repo nằm ở đâu:
> ```gitconfig
> [includeIf "hasconfig:remote.*.url:git@github.com*:Comac-Pro/**"]
>     path = ~/.gitconfig-cmp
> ```
> Chỉ áp dụng sau khi remote tồn tại, nên `git init` rồi commit trước khi `git remote add` vẫn lọt. Dùng **cùng** fail-closed, không thay thế.

### 9.2 Thu hẹp `insteadOf`

Máy cũ viết lại **mọi** URL GitHub trong `clients/cmp/`, kể cả repo bên thứ ba:

```
https://github.com/torvalds/linux.git  →  git@github.com-cmp:torvalds/linux.git
```

Clone repo công khai sẽ hỏng (nó không cần auth), và bạn trình khoá công việc cho một repo chẳng liên quan. Bản trong guide chỉ viết lại đúng hai tổ chức.

**Đánh đổi — và nó có thật:** thu hẹp tạo ra chiều thất bại ngược lại. Org khách hàng **chưa khai báo** sẽ không được viết lại, URL đi thẳng `github.com`, và ssh rơi về khoá cá nhân:

```
https://github.com/Comac-Pro/x.git      → git@github.com-cmp:…   ✓ viết lại
https://github.com/comacpro-labs/x.git  → https://github.com/…   ✗ LỌT
                                          → Offering: id_ed25519_personal
```

Email vẫn đúng (do `includeIf` theo thư mục) nhưng **khoá SSH thì sai**, và im lặng. Đó là lý do có [§9.4](#94-coresshcommand--lưới-thứ-hai-cho-khoá) — `insteadOf` không nên là thứ duy nhất gánh phần bảo mật.

### 9.3 Thêm `fsckObjects`

Ba dòng `transfer/fetch/receive.fsckObjects` bảo Git từ chối object dị dạng hoặc độc hại từ remote.

**Đánh đổi:** fetch chậm hơn chút, và thỉnh thoảng gặp repo cũ có object lỗi lịch sử sẽ bị từ chối — lúc đó tắt tạm bằng `git -c transfer.fsckObjects=false`.

### 9.4 `core.sshCommand` — lưới thứ hai cho khoá

`insteadOf` chọn khoá **gián tiếp**, qua việc viết lại URL. Nếu URL không khớp mẫu, không có gì xảy ra và ssh dùng mặc định — tức là khoá cá nhân. `core.sshCommand` chọn khoá **trực tiếp theo thư mục**, cùng trục với `includeIf` đang chọn email:

```gitconfig
[core]
    sshCommand = ssh -i ~/.ssh/id_ed25519_cmp -o IdentitiesOnly=yes
```

Đo bằng `ssh -v` với một org không có trong `insteadOf`:

```
không có sshCommand:   Offering public key: id_ed25519_personal   ✗
có sshCommand:         Offering public key: id_ed25519_cmp        ✓
```

**Giới hạn — cần biết chính xác nó làm được gì:** `-i` **chèn lên đầu** danh sách chứ không thay thế khoá mà `~/.ssh/config` đã khai. Với URL đi thẳng `github.com`, ssh vẫn giữ khoá cá nhân làm dự phòng:

```
Will attempt key: id_ed25519_cmp        ← thử TRƯỚC
Will attempt key: id_ed25519_personal   ← vẫn còn dự phòng
```

Qua alias `github.com-cmp` thì kín hoàn toàn — chỉ khoá cmp trong danh sách. Nên hai cơ chế bổ trợ nhau:

| Đường | `insteadOf` | `sshCommand` | Kết quả |
|---|---|---|---|
| Org đã khai báo | ✓ viết lại → alias | ✓ | **Kín** — chỉ khoá cmp |
| Org chưa khai báo | ✗ không khớp | ✓ | Khoá cmp **thử trước**, còn dự phòng cá nhân |

Dự phòng chỉ thắng khi khoá cmp bị từ chối *và* khoá cá nhân có quyền — tức là repo được cấp qua tài khoản cá nhân. Hiếm, và không còn là "sai lặng lẽ".

**Đánh đổi:** `core.sshCommand` áp cho mọi thao tác SSH của Git trong cây đó, kể cả clone repo public bằng SSH — chúng sẽ trình khoá cmp. Với repo public thì vô hại vì không cần xác thực. Không ảnh hưởng `ssh` gõ tay ngoài Git.

> Không thêm dòng này vào `~/.gitconfig-personal`: khoá cá nhân vốn đã là mặc định của `~/.ssh/config` cho `github.com` và `gitlab.com`, nên thêm chỉ là thừa và làm mất linh hoạt.

### 9.5 Bỏ GMO

Đã rời công ty. Khoá `id_ed25519_gmo`, alias `github.com-gmo` và `includeIf` cho `clients/gmo/` không dựng lại.

> **Khác biệt có chủ đích với máy Fedora 44.** Máy cũ vẫn giữ nguyên phần GMO — khoá, alias, `includeIf`, và `insteadOf` rộng của nó — vì dọn một cấu hình đang chạy không đem lại gì ngoài rủi ro. Thư mục `clients/gmo/` rỗng nên phần đó vô hại. Cài lại là dịp tự nhiên để bỏ, nên guide bỏ. Nếu sau này đọc guide và thấy thiếu GMO, đó là cố ý, không phải sót.

### 9.6 Gom `[tag]`

Máy cũ khai `[tag]` hai lần ở hai chỗ. Git gộp đúng nên không phải lỗi, chỉ gom lại cho gọn.

---

## 10. Những bẫy đã gặp thật

Bốn thứ dưới đây đều đã cắn trong lần dựng trước. Cả bốn đều **im lặng** — không có thông báo lỗi nào chỉ đúng nguyên nhân.

### `ssh-keygen` nuốt passphrase mà vẫn báo thành công

**Triệu chứng:** đặt passphrase xong, báo `Your identification has been saved with the new passphrase`, nhưng khoá vẫn không mã hoá.

**Nguyên nhân:** khi có `DISPLAY` và stdin **không phải TTY**, `ssh-keygen` bỏ qua bàn phím và gọi hộp thoại ở đường dẫn biên dịch sẵn `/usr/libexec/openssh/ssh-askpass` — tệp này thuộc gói `openssh-askpass`, không cài mặc định trên Fedora. Gọi hỏng → coi input là chuỗi rỗng → vẫn in thông báo thành công.

**Cách xử lý** (đừng cài `openssh-askpass`, GNOME đã có `gcr-ssh-askpass`):

```bash
# Cách 1 — terminal thật, có TTY. Lưu ý: gõ passphrase KHÔNG hiện ký tự nào.
ssh-keygen -p -f ~/.ssh/id_ed25519_macos-comacpro

# Cách 2 — dấu nhắc có hiện dấu sao, chắc ăn hơn
ssh-keygen -p -P "" \
  -N "$(systemd-ask-password 'Passphrase moi:')" \
  -f ~/.ssh/id_ed25519_macos-comacpro
```

**Luôn kiểm sau khi đặt** — đừng tin thông báo:

```bash
ssh-keygen -y -P "" -f ~/.ssh/id_ed25519_macos-comacpro >/dev/null 2>&1 \
  && echo ">>> VẪN RỖNG" || echo ">>> OK, đã mã hoá"
```

Fingerprint **không đổi** khi đặt passphrase, nên `authorized_keys` trên Mac không phải làm lại.

### `ssh-add -l` liệt kê cả khoá chưa mở khoá

Có **hai socket**, `$SSH_AUTH_SOCK` trỏ vào lớp proxy chứ không phải agent thật:

```
                      ssh · git · ssh-add
                              │
                              ▼
              $SSH_AUTH_SOCK = /run/user/1000/gcr/ssh
                              │
                  ┌───────────┴────────────┐
                  │     gcr-ssh-agent      │   lớp proxy
                  └───────────┬────────────┘
                              │
           ┌──────────────────┴──────────────────┐
           ▼                                     ▼
   quét ~/.ssh/*.pub                  /run/user/1000/gcr/.ssh
   QUẢNG BÁ mọi khoá thấy             ssh-agent chuẩn của OpenSSH
   trên đĩa — kể cả khoá              GIỮ khoá đã thực sự mở khoá
   CÓ passphrase chưa mở                      │
           │                                  │
           └─────────────┬────────────────────┘
                         ▼
             ssh-add -l gộp CẢ HAI  ←── nguồn hiểu nhầm
```

Khoá mới tạo xuất hiện trong `ssh-add -l` ngay, chưa cần `ssh-add` — kể cả khoá **có** passphrase. Đó không phải Keyring tự mở khoá.

```bash
# Khoá nào THẬT SỰ đang mở trong bộ nhớ:
SSH_AUTH_SOCK=/run/user/1000/gcr/.ssh ssh-add -l
```

`ssh-add -d` báo `agent refused operation` là bình thường — gcr không giữ khoá đó nên không có gì để xoá. Đặt passphrase xong, xả agent bằng `systemctl --user restart gcr-ssh-agent.service`.

> `gcr-ssh-agent` là wrapper proxy tới `ssh-agent` chuẩn của OpenSSH, nên **`ssh-add -t 8h` có hiệu lực thật** (đã kiểm chứng trên Fedora 44 bằng khoá mồi hết hạn sau 60 giây). Chạy lại bài test đó nếu đổi bản phân phối.

### `RemoteCommand` cần đường dẫn tuyệt đối

`RemoteCommand` chạy qua zsh **không tương tác** — `.zshrc` không được đọc, `PATH` trên macOS chỉ còn `/usr/bin:/bin:/usr/sbin:/sbin`. Homebrew ở `/usr/local/bin` (Intel) hoặc `/opt/homebrew/bin` (Apple Silicon) nằm ngoài đó.

Viết `RemoteCommand tmux …` sẽ chết với `command not found: tmux` **dù tmux đã cài**. Triệu chứng đánh lừa: `mac-cmp-file` vào được bình thường còn `mac-cmp` thì chết — trông như lỗi alias.

```bash
ssh mac-cmp-file 'ls -l /usr/local/bin/tmux'   # xác nhận đường dẫn thật trước
```

### `RemoteCommand` phá `scp` / `rsync` / `sftp`

Chúng cần một kênh sạch, không có tmux. Đó là lý do có khối `mac-cmp-file` thứ hai:

```bash
rsync -av ~/file mac-cmp-file:~/dest/
scp mac-cmp-file:~/log.txt .
```

---

## 11. Checklist xác minh

Chạy hết sau khi dựng xong. Mỗi lệnh trả lời một câu hỏi khác nhau.

```bash
# --- Quyền tệp ---
stat -c '%a %n' ~/.ssh ~/.ssh/config ~/.ssh/id_ed25519_*
# mong đợi: 700 thư mục · 600 config và khoá riêng · 644 khoá .pub

# --- SSH chọn đúng khoá cho từng alias ---
for h in github.com github.com-cmp gitlab.com mac-cmp mac-cmp-file; do
  printf '%-16s %s\n' "$h" "$(ssh -G $h | grep -m1 '^identityfile')"
done

# --- IdentitiesOnly có ở MỌI khối ---
for h in github.com github.com-cmp gitlab.com mac-cmp mac-cmp-file; do
  printf '%-16s %s\n' "$h" "$(ssh -G $h | grep -m1 '^identitiesonly')"
done
# mong đợi: 5/5 đều 'yes'

# --- Xác thực thật ---
ssh -T github.com          # Hi <cá nhân>!
ssh -T github.com-cmp      # Hi <công việc>!
ssh -T gitlab.com          # Welcome to GitLab!

# --- fail-closed có hoạt động ---
cd /tmp && mkdir -p t && cd t && git init -q && git commit --allow-empty -m x
# mong đợi: LỖI "Please tell me who you are" ← đúng là đạt
cd /tmp && rm -rf t

# --- Định tuyến danh tính (trong repo thật) ---
cd ~/Workspace/clients/cmp/<repo> && git config user.email   # ninhht@comacpro.com
cd ~/Workspace/personal/<repo>    && git config user.email   # hoangthaininh.hgn@gmail.com

# --- insteadOf viết lại đúng, và KHÔNG viết lại repo bên thứ ba ---
cd ~/Workspace/clients/cmp/<repo>
git ls-remote --get-url origin
# → git@github.com-cmp:…                               (đã viết lại — đúng)
git ls-remote --get-url https://github.com/Comac-Pro/bat-ky.git
# → git@github.com-cmp:Comac-Pro/bat-ky.git            (đã viết lại — đúng)
git ls-remote --get-url https://github.com/torvalds/linux.git
# → https://github.com/torvalds/linux.git              (GIỮ NGUYÊN — đúng)

# --- Ký commit xác minh được ---
cd ~/Workspace/clients/cmp/<repo>
git log --show-signature -1 --format='%G? %GS'
# mong đợi: G <email>   ← G là Good

# --- Máy công ty ---
ssh mac-cmp-file 'whoami; hostname'   # kênh sạch
ssh mac-cmp                            # vào thẳng tmux 'desk'
rsync -av /tmp/x mac-cmp-file:~/       # chuyển file được

# --- Khoá nào thật sự đang mở trong agent ---
SSH_AUTH_SOCK=/run/user/1000/gcr/.ssh ssh-add -l
```

### Khoanh vùng nhanh khi hỏng

| Triệu chứng | Nhìn vào đâu |
|---|---|
| `Permission denied (publickey)` | `ssh -vT <alias>` → đọc dòng `Offering public key`. Khoá đúng mà vẫn từ chối = chưa đăng ký ở phía server |
| Commit sai email | Repo nằm ngoài thư mục đã khai `includeIf`. Với fail-closed thì nó báo lỗi thay vì sai lặng lẽ |
| Chữ ký "Unverified" trên GitHub | Chưa thêm khoá lần hai dưới dạng **Signing Key** |
| `No principal matched` | Thiếu dòng trong `allowed_signers` |
| `scp`/`rsync` treo | Dùng nhầm `mac-cmp` thay vì `mac-cmp-file` |
| `command not found` qua `RemoteCommand` | Đường dẫn không tuyệt đối |
| Đặt passphrase xong vẫn rỗng | Bẫy askpass — xem §10 |
