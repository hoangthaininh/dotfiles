# Remote access: điều khiển máy công ty (macOS) từ xa — Runbook

**Phiên bản:** v5.7 · 23/09/2026 · [nhật ký thay đổi](#nhật-ký-thay-đổi)
**Máy đích:** macOS 15, Intel Core i5 (máy công ty) · iTerm2 tại bàn
**Client:** Fedora 44 (máy cá nhân, đường chính) · iPhone (tuỳ chọn)

---

## Đang ở đâu — 23/09/2026

Setup đã chạy và được kiểm chứng đầu-cuối. Bảng này để bạn quay lại sau vài tháng mà không phải đọc lại cả tài liệu.

| Phase | | Bằng chứng |
|---|---|---|
| 1 Tailscale | ✅ | 2 node, MagicDNS chạy |
| 2 Client Fedora | ✅ | Key có passphrase, `~/.ssh/config` 2 khối, `known_hosts` đã đối chiếu |
| 3 iPhone | ⬜ tuỳ chọn | Bỏ qua được |
| 4 Harden sshd | ✅ | Đo từ ngoài: `Permission denied (publickey)` |
| 5 tmux config | ✅ | `~/.config/tmux/tmux.conf` — prefix, màu, `pbcopy` đã nạp |
| 6 Một chiều | ✅ | Từ Mac: `ping` 100% loss, port 22 đóng |
| 7 Môi trường | ⬜ | Chỉ cần mở Docker Desktop trước khi rời bàn |
| 8 Preflight | ✅ | `~/bin/preflight` → `SẴN SÀNG`, exit 0 |
| 9 Bảo mật | ✅ phần lớn | LUKS ✓ · khoá màn hình 5 phút ✓ · shields ✓ |
| 10 Bom hẹn giờ | ✅ | auto-update tắt · `sleep 0` · timer cảnh báo key expiry |

**Một việc đáng làm, chưa làm:** cắm **Ethernet** cho Mac. Nó đang chạy Wi-Fi, và đo được jitter **62ms** giữa hai máy cùng LAN (gateway chỉ 5ms) — đó là độ nhão bạn cảm thấy ở mỗi phím gõ trong tmux. Chi phí: một sợi cáp. Xem [10.3](#103-mac-ngủ--vấn-đề-vận-hành-chính).

**Hai thứ còn hở, không gấp:**

- Compose bind `0.0.0.0` — Postgres/MongoDB/MySQL/Redis mở ra LAN và tailnet. Docker bỏ qua cả firewalld lẫn shields-up. Xem [6.3](#63-ba-thứ---shields-up-không-giải-quyết).
- Nhóm `docker` ≈ root không mật khẩu. Xem [9.1](#91-fedora).

**Hạn duy nhất có thật:** node key hết hạn **21/03/2027**. Re-auth cần GUI tại máy, không sửa được từ xa. Timer `tailscale-key-expiry` trên Fedora sẽ cảnh báo từ 30 ngày trước.

---

## Mục lục

- [0. Đọc trước khi chạm bàn phím](#0-đọc-trước-khi-chạm-bàn-phím)
- [1. Kiến trúc và các quyết định](#1-kiến-trúc-và-các-quyết-định)
- **Phần chính** — [Phase 1](#phase-1--tailscale) · [2](#phase-2--client-fedora-44) · [3](#phase-3--client-iphone-tuỳ-chọn) · [4](#phase-4--harden-sshd) · [5](#phase-5--tmux) · [6](#phase-6--một-chiều) · [7](#phase-7--chuẩn-bị-môi-trường) · [8](#phase-8--preflight) · [9](#phase-9--bảo-mật) · [10](#phase-10--bom-hẹn-giờ)
- [Acceptance test](#acceptance-test)
- [Checklist triển khai](#checklist-triển-khai)
- [Troubleshooting](#troubleshooting)
- **Phụ lục** — [A: Full Disk Access](#phụ-lục-a--full-disk-access) · [B: mosh](#phụ-lục-b--mosh) · [C: Screen Sharing](#phụ-lục-c--screen-sharing) · [D: Đích là server?](#phụ-lục-d--nếu-đích-thật-là-server)
- [Những gì chưa xác minh được](#những-gì-chưa-xác-minh-được)
- [Đang ở đâu](#đang-ở-đâu--23092026)
- [Nhật ký thay đổi](#nhật-ký-thay-đổi)
- [Tham khảo nhanh](#tham-khảo-nhanh)

---

## 0. Đọc trước khi chạm bàn phím

### 0.1 Guide này giả định gì

Thứ bạn cần truy cập từ xa **nằm trên chính cái Mac công ty** — local repo, Docker compose, dev server, simulator.

Nếu thứ bạn thực sự cần là **hệ thống đã deploy** (xem build xong chưa, restart service, đọc log production), thì Mac là một hop thừa và mong manh. Đọc **[Phụ lục D](#phụ-lục-d--nếu-đích-thật-là-server)** trước rồi hãy quay lại.

### 0.2 Hai client, hai vai trò

| Client | Vai trò | Vì sao |
|---|---|---|
| **Fedora 44** (máy cá nhân) | Đường chính — làm việc thật | Có shell thật, bàn phím thật, OpenSSH sẵn có. Không cần app bên thứ ba nào |
| **iPhone** | Tuỳ chọn — xử lý gấp khi đang di chuyển | iOS không có shell nên phải dùng app; chỉ đáng cho việc ngắn |

Fedora là [Phase 2](#phase-2--client-fedora-44), iPhone là [Phase 3](#phase-3--client-iphone-tuỳ-chọn). **Làm Phase 2, bỏ qua Phase 3 nếu chưa cần.** Thêm client sau rất rẻ — mỗi client chỉ là thêm một dòng vào `authorized_keys`.

> **Vì sao không cài Termius lên Fedora:** bạn cần Termius trên iPhone vì iOS không có shell. Fedora không có lỗ đó. Cài Termius lên Linux nghĩa là thêm một app Electron, một lớp snap confinement, một tài khoản bắt buộc và đồng bộ credentials lên cloud — để làm việc mà `ssh mac-cmp` đã làm tốt hơn: script được, `rsync`/`scp` dùng chung config, không phụ thuộc nhà cung cấp. Termius cũng **không có .rpm chính thức**, chỉ có .deb và Snap.

### 0.3 Điều kiện bắt buộc

- [ ] Máy công ty → Remote Login + VPN mesh **cần IT/security duyệt**. Xác nhận trước khi làm.
- [ ] Công ty đã có tailnet → **join tailnet đó**, đừng kéo máy công ty vào tailnet cá nhân.
- [ ] Phần cấu hình trên Mac làm **tại bàn**. Không có bước nào làm được từ xa.
- [ ] Có ít nhất 90 phút liền mạch. Dừng giữa Phase 4 là nơi duy nhất nguy hiểm.

### 0.4 Tailnet nào?

| | Hệ quả |
|---|---|
| **Cá nhân** | Toàn quyền. [Phase 6](#phase-6--một-chiều) chỉ cần một lệnh trên máy bạn |
| **Công ty** | Máy cá nhân của bạn hiện trong admin console của IT. `--shields-up` vẫn tự làm được vì nó cục bộ; chỉ phần ACL mới cần IT |

Khi đăng ký Tailscale, nếu được hỏi: **Role = Engineer**, **Primary reason = Personal or At-Home Use**. Chọn "Infrastructure Access" dễ bị đẩy vào trial gói trả phí — trial hết hạn giữa chừng là một cách bất ngờ để mất truy cập.

### 0.5 Ranh giới của setup này

| Làm được | Không làm được |
|---|---|
| Shell đầy đủ trên Mac, cùng UID, `sudo` | Sống sót qua **reboot** Mac — FileVault chặn ở pre-boot |
| Sống sót khoá màn hình, mất mạng, đổi mạng | Đánh thức Mac đang **ngủ** |
| `~/projects`, `~/work`, git, docker, build, test | `~/Documents`, `~/Desktop`, iCloud → [Phụ lục A](#phụ-lục-a--full-disk-access) |
| tmux session bền qua mọi lần rớt kết nối | Điều khiển GUI app qua CLI — `osascript` bị TCC chặn |
| | Hoạt động sau khi **đăng xuất** khỏi Mac — keychain khoá |

> ### Nguyên tắc vận hành (áp cho máy Mac)
> **Khoá màn hình — đừng đăng xuất — đừng reboot.**
> Ba câu này giải thích 90% các lần setup hỏng.

---

## 1. Kiến trúc và các quyết định

```
Fedora 44  ─┐
            ├── WireGuard (Tailscale) ──▶ Mac ──▶ sshd (pubkey only) ──▶ tmux
iPhone     ─┘        (tuỳ chọn)
```

Một cổng vào duy nhất trên Mac. Không port nào phơi ra internet. Mỗi client có key riêng.

### Các quyết định và lý do

| Quyết định | Vì sao | Điều gì lật ngược nó |
|---|---|---|
| **Tailscale**, không port-forward / Cloudflare Tunnel / VPS jump host | Không mở port nào; NAT traversal tự lo; không thêm service phải vận hành | Công ty cấm VPN bên thứ ba |
| **OpenSSH trên Fedora**, không Termius | Fedora đã có shell; Termius thêm Electron + snap + account + cloud sync mà không thêm gì | Bạn quản lý hàng chục host và thật sự cần danh sách đồng bộ |
| **OpenSSH trên Mac**, không Tailscale SSH | `tailscale up --ssh` chỉ chạy server-side trên Linux | Đích chuyển sang Linux |
| **Key riêng cho từng client** | Mất một thiết bị → xoá một dòng, các thiết bị khác không ảnh hưởng | Không bao giờ |
| **SSH + tmux**, không mosh | mosh trên macOS có chế độ hỏng im lặng ([Phụ lục B](#phụ-lục-b--mosh)) | Mạng của bạn tệ thật và độ trễ gõ phiền |
| **Không Full Disk Access** | Code nằm ngoài vùng TCC bảo vệ. Cấp quyền trước khi có nhu cầu là sai thứ tự | Gặp `Operation not permitted` thật |
| **Không Screen Sharing** | Bề mặt tấn công đang bị khai thác; hiếm khi thật sự cần | Buộc phải bấm GUI |
| **`--shields-up`**, không ACL | Tailnet cá nhân hai node: một lệnh cục bộ, không rủi ro tự khoá, không phải sửa lại mỗi lần thêm port ([6.2](#62-vì-sao-không-dùng-acl)) | Tailnet có node của người khác |
| Nếu phải dùng ACL: **`hosts`**, không `tag:` | Tag không phù hợp cho thiết bị người dùng cuối, và gắn tag rồi xác thực sẽ **tự tắt key expiry** | Tailnet lớn lên, cần phân nhóm thật |

> **Vì sao mặc định là tắt:** thêm một quyền sau thì rẻ, gỡ một quyền đã cấp thì không ai gỡ. Bạn sẽ không bao giờ quay lại tắt Full Disk Access sau khi đã bật, kể cả khi hoá ra không cần.

---

# PHẦN CHÍNH

## Phase 1 — Tailscale

### 1.1 Trên Mac: gỡ bản cũ nếu có

**Không bao giờ chạy đồng thời bản App Store và bản standalone.** Xung đột VPN cực khó debug.

Kiểm tra variant: mở Settings **trong app** Tailscale — `tailscale --version` không cho biết.

Đang là bản App Store → xoá app → dọn Trash → **reboot** → mới cài bản mới.

### 1.2 Trên Mac: cài standalone

Tải pkg từ `tailscale.com/download`. Đây là bản khuyến nghị chính thức; bản App Store bị sandbox nặng hơn và không phát hiện được công cụ bên thứ ba can thiệp vào VPN tunnel.

Duyệt **system extension** khi macOS hỏi.

```bash
tailscale status
tailscale ip -4          # ghi lại: 100.x.y.z
```

### 1.3 Trên Fedora 44

Fedora 41 trở lên dùng cú pháp dnf5 — **khác với hướng dẫn cho Fedora 40 trở về trước**:

```bash
sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
sudo dnf install tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up
tailscale ip -4
```

`--from-repofile=` là dạng dnf5. Nếu gặp hướng dẫn cũ ghi `sudo dnf config-manager --add-repo <url>` thì đó là cú pháp dnf4, sẽ lỗi trên F44.

`systemctl enable --now` là bắt buộc — thiếu `enable` thì sau reboot Fedora không tự lên tailnet.

### 1.4 Admin console — login.tailscale.com

- DNS → bật **MagicDNS**
- Machines → tên máy trên tailnet: máy công ty là `macos-comacpro`, Fedora là `tainjiao-dotdev`
- Settings → Device management → **giữ Key Expiry bật** cho `macos-comacpro` ([Phase 10.2](#102-tailscale-node-key-hết-hạn))

> **Quy ước tên trong guide này — đọc một lần rồi khỏi nhầm:**
>
> | | Là gì | Sống ở đâu |
> |---|---|---|
> | `macos-comacpro` | **Tên máy trên tailnet**, thứ MagicDNS phân giải được | Tailscale admin |
> | `macos-comacpro.taila30e8c.ts.net` | FQDN đầy đủ, không phụ thuộc search domain | Tailscale admin |
> | `mac-cmp` | **Alias SSH** bạn tự đặt ở [2.5](#25-sshconfig) — theo quy ước `<thiết bị>-<tổ chức>` giống `github.com-cmp` | Chỉ trong `~/.ssh/config` của Fedora |
>
> **Đừng đổi tên máy trong Tailscale admin.** `known_hosts` trên Fedora đã có entry cho `macos-comacpro` — đổi tên là phải xác nhận lại fingerprint mà không được lợi gì. Tên ngắn lấy ở tầng alias SSH, đúng chỗ của nó.

### 1.5 Checkpoint

Trên Fedora:

```bash
tailscale status                # phải thấy cả macos-comacpro
ping -c 3 macos-comacpro     # phải trả lời
```

`ping` không ra thì dừng lại, đừng đi tiếp. Lỗi ở đây là lỗi mạng, không phải lỗi SSH.

---

## Phase 2 — Client: Fedora 44

Đây là đường chính. Không cài app nào — mọi thứ dùng OpenSSH sẵn có.

### 2.1 Bật Remote Login trên Mac

System Settings → General → Sharing → **Remote Login** bật
→ nút **(i)** → "Allow access for" → **Only these users** → chỉ user của bạn.

Không bật "Allow full disk access for remote users". Đó là [Phụ lục A](#phụ-lục-a--full-disk-access), chỉ làm khi thực sự cần.

```bash
# trên Mac
whoami                   # ghi lại username — gọi là <macuser> từ đây
ssh localhost            # phải vào được
```

### 2.2 Test đường mạng bằng password

Làm **trước** khi động vào key — để tách bạch lỗi mạng và lỗi auth. Bỏ qua nó thì lúc hỏng bạn sẽ không biết đang hỏng ở đâu.

```bash
# trên Fedora
ssh <macuser>@macos-comacpro
```

Nhập password macOS. Vào được = đường Tailscale thông. Thoát ra bằng `exit`.

### 2.3 Tạo key trên Fedora

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_macos-comacpro -C "tainjiao-dotdev"
```

**Ba chỗ đặt tên, ba loại thông tin — đừng để chúng lặp nhau:**

| Chỗ | Trả lời câu | Ai đọc |
|---|---|---|
| Tên tệp `id_ed25519_macos-comacpro` | khoá này mở **máy nào** | bạn, lúc nhìn `~/.ssh` |
| Comment `-C tainjiao-dotdev` | khoá này **nằm ở máy nào** | bạn, lúc đọc `authorized_keys` trên Mac để thu hồi |
| Alias `mac-cmp` | gõ gì cho nhanh | bạn, mỗi ngày |

Tên tệp đặt theo **máy đích** chứ không theo tổ chức, vì hostname `macos-comacpro` đã chứa sẵn tên tổ chức — đặt theo máy thì được luôn thông tin đó mà không lấn sang trục danh tính của ba khoá Git (`_personal`, `_cmp`, `_gmo`). Máy công ty thứ hai sau này là `id_ed25519_<host>` riêng, thu hồi độc lập.

**Đặt passphrase.** Khác với trường hợp điện thoại: file key nằm trên đĩa và đọc được bằng quyền user thường. Passphrase là lớp thứ hai nếu ai đó lấy được máy hoặc một process đọc trộm `~/.ssh`. Phiền toái được `ssh-agent` xử lý ở 2.6.

> **LUKS không thay thế được passphrase — hai lớp cho hai mối đe doạ khác nhau.** Đã xác minh trên máy này (22/09/2026): `nvme0n1p3` là `crypto_LUKS`, và **cả `/` lẫn `/home`** đều là subvolume btrfs nằm trên volume đã mở khoá đó. Tức là mã hoá toàn đĩa đầy đủ.
>
> Nhưng LUKS chỉ bảo vệ **lúc máy tắt**. Máy đang mở và đã đăng nhập thì volume đã mở khoá, `~/.ssh` đọc được bằng quyền user thường, và LUKS không còn ý nghĩa gì. Đó chính xác là kịch bản passphrase nhắm tới — xem lại [9.1](#91-fedora).
>
> Ba key GitHub hiện có trên máy **không có passphrase**. Đừng lấy đó làm chuẩn cho key này: key GitHub lộ thì thu hồi trong 30 giây và thiệt hại giới hạn trong repo; key vào máy công ty lộ thì là shell trên tài sản của công ty.

> **Bẫy: `ssh-keygen` có thể nuốt passphrase mà vẫn báo thành công.** Khi có `DISPLAY` và stdin **không phải TTY**, `ssh-keygen` bỏ qua bàn phím và gọi hộp thoại ở đường dẫn biên dịch sẵn `/usr/libexec/openssh/ssh-askpass` — file này thuộc gói `openssh-askpass`, **không cài mặc định trên Fedora**. Gọi hỏng → coi input là chuỗi rỗng → vẫn in `Your identification has been saved with the new passphrase`.
>
> Đừng cài `openssh-askpass` (GNOME đã có `gcr-ssh-askpass`). Làm một trong hai:
>
> ```bash
> # Cách 1 — terminal thật, có TTY. Gõ passphrase KHÔNG hiện ký tự nào.
> ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_macos-comacpro -C "tainjiao-dotdev"
>
> # Cách 2 — dấu nhắc có hiện dấu sao
> ssh-keygen -p -P "" -N "$(systemd-ask-password 'Passphrase moi:')" \
>   -f ~/.ssh/id_ed25519_macos-comacpro
> ```
>
> **Luôn kiểm sau khi đặt** — đừng tin thông báo:
>
> ```bash
> ssh-keygen -y -P "" -f ~/.ssh/id_ed25519_macos-comacpro >/dev/null 2>&1 \
>   && echo ">>> VẪN RỖNG" || echo ">>> OK, đã mã hoá"
> ```
>
> Fingerprint **không đổi** khi đặt passphrase, nên `authorized_keys` trên Mac không phải làm lại.

Key này **chỉ dùng cho Mac công ty**. Đừng dùng lại key GitHub hay key nào khác — một key một mục đích, thu hồi độc lập.

### 2.4 Đẩy public key sang Mac

```bash
ssh-copy-id -i ~/.ssh/id_ed25519_macos-comacpro.pub <macuser>@macos-comacpro
```

`ssh-copy-id` tự tạo `~/.ssh`, đặt quyền đúng, và **thêm newline đúng chỗ** — tránh được lỗi dính key vào dòng trước mà cách copy-paste thủ công hay mắc.

Xác nhận trên Mac:

```bash
tail -1 ~/.ssh/authorized_keys      # phải là dòng ssh-ed25519 ... tainjiao-dotdev
ls -l ~/.ssh/authorized_keys        # phải là -rw-------
```

Test:

```bash
# trên Fedora
ssh -i ~/.ssh/id_ed25519_macos-comacpro <macuser>@macos-comacpro
```

Phải vào được (có thể hỏi passphrase của key — đúng, chưa dùng agent).

### 2.5 `~/.ssh/config`

```bash
cat >> ~/.ssh/config << 'CONF'

Host mac-cmp
    HostName macos-comacpro.taila30e8c.ts.net
    User <macuser>
    IdentityFile ~/.ssh/id_ed25519_macos-comacpro
    IdentitiesOnly yes
    ConnectTimeout 10
    ServerAliveInterval 30
    ServerAliveCountMax 3
    RequestTTY yes
    RemoteCommand /usr/local/bin/tmux new -A -s desk

# Không có RemoteCommand — dùng cho scp/sftp/rsync
Host mac-cmp-file
    HostName macos-comacpro.taila30e8c.ts.net
    User <macuser>
    IdentityFile ~/.ssh/id_ed25519_macos-comacpro
    IdentitiesOnly yes
    ConnectTimeout 10
    ServerAliveInterval 30
    ServerAliveCountMax 3
CONF
chmod 600 ~/.ssh/config
```

Thay `<macuser>`. Giờ chỉ cần `ssh mac-cmp` là vào thẳng tmux.

`HostName` dùng **FQDN** (`…​.ts.net`) chứ không phải tên trần: FQDN không phụ thuộc vào search domain mà MagicDNS đẩy xuống, nên vẫn phân giải được cả khi resolver bị cấu hình lại. Đánh đổi: `known_hosts` hiện có entry cho tên trần `macos-comacpro`, nên lần kết nối đầu qua alias sẽ hỏi xác nhận fingerprint thêm **một lần**. Đối chiếu với entry cũ trước khi gõ `yes`:

```bash
ssh-keygen -lf <(ssh-keyscan -t ed25519 macos-comacpro 2>/dev/null)
ssh-keygen -F macos-comacpro -l
```

Hai fingerprint phải trùng nhau.

| Dòng | Vì sao |
|---|---|
| `IdentitiesOnly yes` | Không có nó, ssh thử lần lượt mọi key trong agent và có thể chạm `MaxAuthTries 3` rồi bị từ chối dù key đúng có trong đó |
| `ConnectTimeout 10` | **Đo thật 22/09/2026:** không có nó, `ssh` tới Mac đang ngủ treo **130 giây**; có nó thì đúng 10 giây. Phải đặt trên **cả hai** khối |
| `ServerAliveInterval 30` | Phát hiện kết nối **đã thiết lập** bị chết. Nó **không** che được giai đoạn đang bắt tay — đó là việc của `ConnectTimeout` |
| `RequestTTY` + `RemoteCommand` | Vào thẳng tmux, không cần gõ gì thêm |

> **Bẫy thứ nhất — đường dẫn tuyệt đối.** `RemoteCommand` chạy qua zsh **không tương tác**, nên `.zshrc` không được đọc và `PATH` chỉ là `/usr/bin:/bin:/usr/sbin:/sbin`. Homebrew nằm ở `/usr/local/bin` (Mac Intel) hoặc `/opt/homebrew/bin` (Apple Silicon) — **không có trong PATH đó**. Viết `RemoteCommand tmux …` sẽ chết với `command not found: tmux` dù tmux đã cài. Phải ghi đường dẫn đầy đủ.
>
> Kiểm tra đường dẫn thật trên máy đích trước khi viết vào config:
> ```bash
> ssh <macuser>@macos-comacpro 'command -v brew; brew --prefix'
> ssh <macuser>@macos-comacpro 'ls -l /usr/local/bin/tmux'
> ```
> Đây cùng gốc với vấn đề mosh ở [Phụ lục B.1](#phụ-lục-b--mosh) — chỉ khác là nó chạm vào tmux và xảy ra ngay ở Phase 2.

> **Bẫy thứ hai:** `RemoteCommand` **phá `scp`, `sftp` và `rsync`** tới host đó — chúng cần một kênh sạch, không có tmux. Đó là lý do có entry thứ hai. Chuyển file thì dùng:
> ```bash
> rsync -av ~/file mac-cmp-file:~/dest/
> scp mac-cmp-file:~/log.txt .
> ```

### 2.6 ssh-agent

Để không phải gõ passphrase mỗi lần:

```bash
ssh-add -t 8h ~/.ssh/id_ed25519_macos-comacpro
ssh-add -l                                  # xác nhận key đã nạp
```

`-t 8h` đặt thời hạn — hết 8 tiếng agent tự quên key. Đây là điểm khác biệt an ninh chính so với việc nạp vĩnh viễn: máy bị bỏ mở qua đêm thì key không còn sẵn sàng.

#### GNOME Keyring có tôn trọng `-t` không? — đã xác minh, có

Trên Fedora 44, `$SSH_AUTH_SOCK` trỏ tới `/run/user/1000/gcr/ssh`, tức là GNOME Keyring chứ không phải `ssh-agent` bạn tự chạy. Câu hỏi hợp lý: nó có thật sự quên key sau `-t` không, hay nhận lệnh rồi bỏ qua?

**Đã test trên máy này (22/09/2026): nó tôn trọng `-t`.**

```bash
ssh-keygen -q -t ed25519 -N "" -f /tmp/tkey -C throwaway   # key dùng một lần
ssh-add -t 60 /tmp/tkey                                    # "Lifetime set to 00:01:00"
sleep 70 && ssh-add -l | grep throwaway                    # không còn → đã hết hạn
ssh-add -d /tmp/tkey; rm -f /tmp/tkey*
```

Lý do nằm ở kiến trúc — `gcr-ssh-agent` chỉ là **wrapper proxy**, phía sau vẫn là `ssh-agent` chuẩn của OpenSSH:

```
$ ps -u $USER -o args= | grep -E 'gcr|ssh-agent'
/usr/libexec/gcr-ssh-agent --base-dir /run/user/1000/gcr
/usr/bin/ssh-agent -D -a /run/user/1000/gcr/.ssh
```

Nên **không cần tắt phần SSH của GNOME Keyring**, và không cần `AddKeysToAgent no` trong `~/.ssh/config`. `ssh-add -t 8h` ở trên là một đảm bảo thật.

> **Cảnh báo này áp dụng cho bản GNOME cũ.** Các bản gnome-keyring đời trước tự cài đặt agent riêng và bỏ qua ràng buộc thời hạn. Nếu chạy guide này trên máy khác, **chạy lại bài test 70 giây ở trên** thay vì tin kết quả này — nó đúng cho Fedora 44, không phải cho mọi bản phân phối.

#### `ssh-add -l` nói dối — có hai socket, không phải một

Đây là chỗ dễ hoảng nhầm. Tạo một key mới trong `~/.ssh`, chưa chạy `ssh-add` lần nào, `ssh-add -l` đã thấy nó ngay. Trông như Keyring tự nạp key và passphrase thành vô nghĩa. **Không phải vậy.**

```
/run/user/1000/gcr/.ssh    ssh-agent THẬT   → chỉ key đã thực sự mở khoá
/run/user/1000/gcr/ssh     gcr proxy        → $SSH_AUTH_SOCK trỏ vào đây
```

`gcr-ssh-agent` **liệt kê mọi `~/.ssh/*.pub` nó thấy trên đĩa**, kể cả key có passphrase mà nó chưa mở được. Xuất hiện trong `ssh-add -l` chỉ nghĩa là "có key này trên máy", không phải "private key đang nằm trong bộ nhớ". Lúc nào thật sự dùng tới, gcr mới đọc tệp và hỏi passphrase.

Đã kiểm chứng (22/09/2026) — tạo key **có passphrase**, không chạy `ssh-add`:

```bash
ssh-keygen -q -t ed25519 -N "matkhau-test" -C probe -f ~/.ssh/id_ed25519_probe
ssh-add -l | grep probe        # vẫn hiện ra ngay
rm -f ~/.ssh/id_ed25519_probe*
```

Hệ quả thực tế:

| | |
|---|---|
| Muốn biết key nào **thật sự đang mở khoá** | `SSH_AUTH_SOCK=/run/user/1000/gcr/.ssh ssh-add -l` |
| `ssh-add -d <key>` báo `agent refused operation` | Bình thường — gcr không giữ key đó nên không có gì để xoá |
| Passphrase có tác dụng không | **Có.** gcr sẽ phải hỏi mỗi khi dùng tới key |
| Key vẫn hiện trong `ssh-add -l` sau khi đặt passphrase | Đúng như thiết kế, không phải lỗi |

> Cập nhật 22/09/2026, sau khi đặt passphrase cho key Mac: agent thật giữ `id_ed25519_cmp`, `id_ed25519_personal` **và** `id_ed25519_macos-comacpro`. Key Mac đã mã hoá thật (`aes256-ctr` trong header) nhưng gnome-keyring đã lưu passphrase vào `login.keyring` và tự mở khoá khi đăng nhập — xem [2.7](#27-passphrase-và-login-keyring).

### 2.7 Passphrase và login-keyring

Đặt passphrase xong, đừng cho rằng từ nay mỗi lần kết nối sẽ bị hỏi. Trên máy này **không** — và lý do đáng biết.

Trạng thái đo được 22/09/2026:

```bash
# Key ĐÃ mã hoá thật
sed -e '1d' -e '$d' ~/.ssh/id_ed25519_macos-comacpro | tr -d '\n' \
  | base64 -d | head -c 40 | strings | sed -n '2p'
# → aes256-ctr

# Nhưng nó đang nằm MỞ trong agent thật
SSH_AUTH_SOCK=/run/user/1000/gcr/.ssh ssh-add -l
# → … tainjiao-dotdev (ED25519)
```

Lần mở khoá đầu tiên, hộp thoại gcr có ô **"tự động mở khoá khi đăng nhập"**. Tích vào là passphrase được cất trong `~/.local/share/keyrings/login.keyring`, và keyring đó tự mở bằng chính mật khẩu đăng nhập.

**Passphrase vẫn có giá trị, chỉ không phải giá trị bạn tưởng:**

| Kịch bản | Có được bảo vệ? |
|---|---|
| Ai đó chép riêng file `id_ed25519_macos-comacpro` | ✅ cần passphrase mới dùng được |
| Ai đó chép cả `~/.local/share/keyrings/` | ✅ keyring mã hoá bằng mật khẩu đăng nhập |
| Máy bị lấy lúc **đang mở và đã đăng nhập** | ❌ key nằm sẵn trong agent |
| Ai đó chạy được lệnh dưới user của bạn | ❌ dùng socket agent được |

Tức là nó chặn được việc **rò file**, không chặn được việc **chiếm phiên đang mở**. Với đa số người thì đánh đổi này hợp lý — bấm passphrase mỗi lần kết nối là chi phí thật.

**Muốn hỏi passphrase thật sự mỗi phiên**, xoá mục đã lưu trong keyring:

```bash
seahorse    # Passwords → Login → tìm mục "Unlock password for: id_ed25519_macos-comacpro" → xoá
systemctl --user restart gcr-ssh-agent.service
```

Sau đó dùng `ssh-add -t 8h` đầu ngày nếu thấy phiền — thời hạn đã kiểm chứng là có hiệu lực (xem [2.6](#26-ssh-agent)).

---

## Phase 3 — Client: iPhone (tuỳ chọn)

Bỏ qua phase này nếu bạn chỉ dùng Fedora. Thêm lại lúc nào cũng được — chỉ là thêm một dòng vào `authorized_keys`.

### 3.1 Tailscale trên iPhone

Đăng nhập **cùng account** → duyệt VPN profile.

- **Low Power Mode có thể ngắt VPN** — biết trước để không debug nhầm
- Settings → General → VPN & Device Management → Tailscale → bật **Connect On Demand**

**Checkpoint:** Safari → `http://macos-comacpro`. (iPhone không có `~/.ssh/config` của Fedora, nên ở đây phải dùng tên máy thật, không phải alias `mac-cmp`.) Safari dùng **hai câu khác nhau**:

| Safari nói | Nghĩa | |
|---|---|---|
| "…could not **connect to** the server" | DNS ok, TCP bị từ chối (chưa có web server ở port 80) | ✅ đi tiếp |
| "…can't **find** the server" | MagicDNS chưa hoạt động | ❌ dừng lại, sửa 1.4 |

### 3.2 Termius: tắt sync credentials

`Settings → Account` → mục **Synchronization** → tắt **"Sync keys and identities"**.

> ⚠️ **Bẫy:** đăng xuất khỏi Termius sẽ xoá toàn bộ dữ liệu local. Khi sync credentials đang tắt, credentials **cũng bị xoá theo** và Termius không khôi phục được. Không phá setup (public key vẫn nằm trên Mac), nhưng bạn phải tạo key mới — mà lúc đó có thể bạn đang ở xa và không vào được Mac để thay dòng.

Sync không hoạt động ở gói Starter miễn phí, nhưng nếu sau này bạn kích hoạt trial Pro/Team thì dữ liệu sẽ được sync. Tắt bây giờ là **phòng ngừa**, không phải sửa vấn đề đang có.

### 3.3 Tạo key

Keychain → **+** → SSH key generator → **Ed25519** → tên `iphone`.

**Passphrase: bỏ trống.** Termius có tuỳ chọn "Save passphrase" để không bị hỏi mỗi lần — nhưng passphrase lưu ngay cạnh key thì không bảo vệ thêm gì. Lớp bảo vệ thật là **Face ID lock cho Termius** ([Phase 9](#phase-9--bảo-mật)).

### 3.4 Đưa public key sang Mac

Hai cách:

- **Export to host** trong Termius — chọn host (đã có từ password auth), tự ghi vào `authorized_keys`
- AirDrop public key sang Mac rồi:
  ```bash
  printf '%s\n' "$(pbpaste)" >> ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  ```
  `printf '%s\n'` là bắt buộc — `pbpaste >>` trần sẽ dính key vào cuối dòng trước nếu clipboard không kết thúc bằng newline.

Dù dùng cách nào, verify trên Mac: `tail -3 ~/.ssh/authorized_keys`.

### 3.5 Host trong Termius

| Trường | Giá trị |
|---|---|
| Address | `macos-comacpro` |
| Port | `22` |
| Username | `<macuser>` |
| Key | `iphone` |
| Startup command | `tmux new -A -s phone` |

Session tên `phone` **khác** session `desk` của Fedora — xem [Phase 5](#phase-5--tmux) để biết vì sao.

---

## Phase 4 — Harden sshd

> ### ⚠️ Bước này khoá được bạn ra khỏi máy
> Mở một tab iTerm2 trên Mac, chạy `ssh localhost`, **giữ nguyên tab đó cho tới hết Phase 4.**
>
> Session đang mở **sống sót**, nhưng không phải vì "chỉ listener khởi động lại" — trên macOS **không có listener nào cả**. Chính launchd giữ socket port 22 và sinh một `sshd-session` mới cho mỗi kết nối. Job khai `abandon process group`, nghĩa là launchd cố ý không quản các tiến trình con đã sinh. Thấy được trong cây tiến trình: phiên đang mở có cha là **PID 1**, không phải một sshd mẹ.
>
> Hệ quả: đường lui vững hơn tài liệu cũ mô tả, và **cấu hình có hiệu lực ngay ở kết nối kế tiếp mà không cần restart gì**.

Chỉ làm sau khi **mọi client** đã test được bằng key. Tắt password auth khi key chưa chạy là tự khoá mình.

### 4.1 Xác định nơi ghi config

```bash
grep -nE '^(Include|PasswordAuthentication|PermitRootLogin|KbdInteractive|PubkeyAuth)' /etc/ssh/sshd_config
```

OpenSSH lấy **giá trị đầu tiên** cho mỗi keyword, không phải giá trị cuối:

- `Include` có số dòng **nhỏ nhất** → dùng drop-in (4.2a)
- `Include` không tồn tại, **hoặc** nằm sau directive khác → sửa trực tiếp (4.2b)

> Bỏ qua bước này là cách phổ biến nhất để **tưởng đã harden xong** trong khi password auth vẫn mở. File drop-in tồn tại, nội dung đúng, và bị bỏ qua hoàn toàn.

**Đã đo trên macOS 15.7.9 (23/09/2026):**

```
18:Include /etc/ssh/sshd_config.d/*
```

Đó là dòng **duy nhất** khớp — không `PasswordAuthentication`, `PermitRootLogin` hay `KbdInteractive` nào đứng trước. → **dùng 4.2a**.

Thư mục đã có sẵn một tệp:

```
/etc/ssh/sshd_config.d/100-macos.conf
    UsePAM yes
    AcceptEnv LANG LC_*
    Subsystem sftp /usr/libexec/sftp-server
```

Hai điều rút ra:

- Glob `*` đọc theo thứ tự từ điển: `100-local.conf` < `100-macos.conf`, nên tệp của bạn đọc trước và **thắng** ở mọi keyword trùng.
- `UsePAM yes` là lý do `KbdInteractiveAuthentication no` **bắt buộc** chứ không tuỳ chọn: PAM mở keyboard-interactive như một đường riêng mà `PasswordAuthentication no` không đóng được.

### 4.2a Drop-in (khi `Include` ở đầu file)

**Soạn tệp trên Fedora, đẩy sang, rồi mới `install`** — thay vì dán heredoc trực tiếp trên Mac. Đây là bước khoá được mình ra ngoài, nên đáng tách phần "soạn nội dung" (gõ sai thì vô hại) khỏi phần "áp vào hệ thống".

```bash
# ── trên FEDORA ──
cat > /tmp/100-local.conf <<'CONF'
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers <macuser>
MaxAuthTries 3
LoginGraceTime 20
ClientAliveInterval 30
ClientAliveCountMax 3
CONF
scp /tmp/100-local.conf mac-cmp-file:~/
```

```bash
# ── trên MAC ──
sudo mkdir -p /etc/ssh/sshd_config.d
sudo install -o root -g wheel -m 644 ~/100-local.conf /etc/ssh/sshd_config.d/100-local.conf
rm ~/100-local.conf
```

`install` đặt owner và mode trong một bước. Không phải trang trí: **sshd từ chối đọc file cấu hình mà user thường ghi được**. Copy bằng `cp` để nguyên chủ sở hữu `<macuser>` là sshd bỏ qua nó.

Lấy `<macuser>` từ `whoami` trên Mac, đừng gõ từ trí nhớ — `AllowUsers` sai là tự khoá.

Ưu điểm của drop-in: bản update macOS không ghi đè file này.

### 4.2b Sửa trực tiếp (khi không có `Include`, hoặc nó ở cuối)

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudo nano /etc/ssh/sshd_config      # đặt các directive trên ở ĐẦU file
```

Bản update macOS lớn có thể ghi đè file này. **Kiểm tra lại sau mỗi lần nâng cấp OS** bằng lệnh ở 4.3.

### Ý nghĩa từng directive

| Directive | Tác dụng |
|---|---|
| `PasswordAuthentication no` | Chặn brute-force hoàn toàn. Dòng quan trọng nhất |
| `KbdInteractiveAuthentication no` | Bịt đường vòng qua PAM — thiếu dòng này thì dòng trên có thể vô hiệu |
| `AllowUsers` | Allowlist. Tài khoản khác trên máy không SSH vào được |
| `MaxAuthTries 3` | Giảm cửa sổ tấn công. Cũng là lý do cần `IdentitiesOnly yes` ở [2.5](#25-sshconfig) |
| `ClientAlive*` | Dọn session chết khi client rớt mạng đột ngột |

### 4.3 Áp dụng và xác minh

Thay `YOUR_USERNAME` trước khi chạy.

**Không cần restart sshd.** Tài liệu cũ có `launchctl kickstart -k system/com.openssh.sshd`; đó là thói quen mang từ Linux sang. Trên macOS job này là socket-activated:

```
system/com.openssh.sshd = {
    active count = 0
    state = not running
    sockets = { 39, 41 }
    properties = … | inetd-compatible | abandon process group
}
```

`state = not running` — không có tiến trình nào để khởi động lại. launchd giữ socket, và mỗi kết nối mới sinh một `sshd-session` đọc cấu hình từ đầu. **Hiệu lực ngay ở kết nối kế tiếp.**

Một lệnh vừa kiểm cú pháp vừa in ra cấu hình hiệu lực:

```bash
# ── trên MAC ──
sudo sshd -T | grep -E '^(pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|maxauthtries|allowusers)'
```

Phải thấy đúng năm dòng:

```
pubkeyauthentication yes
passwordauthentication no
kbdinteractiveauthentication no
maxauthtries 3
allowusers <macuser>
```

`sshd -T` phân tích **toàn bộ** cấu hình gồm cả các file `Include`, nên nó là nguồn sự thật — không phải nội dung file bạn vừa ghi. Thấy `passwordauthentication yes` → có directive phía trên ghi đè, quay lại 4.1.

### 4.4 Test rồi mới đóng tab

Connect từ **mọi client** bạn đã cấu hình. **Chỉ đóng tab iTerm2 sau khi tất cả vào được.**

**Kiểm chứng mạnh nhất là từ bên ngoài**, vì nó đo hành vi thật của server chứ không đọc file:

```bash
# ── trên FEDORA ──
ssh -o PreferredAuthentications=none probe@macos-comacpro 2>&1 | grep -i denied
```

| Kết quả | Nghĩa |
|---|---|
| `Permission denied (publickey)` | ✅ xong — password và keyboard-interactive đã tắt |
| `(publickey,password,keyboard-interactive)` | ❌ chưa ăn, quay lại 4.1 |

Đo được ngày 23/09/2026: trước là `publickey,password,keyboard-interactive`, sau là `publickey`.

Rollback, chạy trong tab đang mở:

```bash
# ── trên MAC ──
sudo rm /etc/ssh/sshd_config.d/100-local.conf
```

Không cần restart — kết nối kế tiếp trở lại như cũ ngay.

---

## Phase 5 — tmux

Không có tmux thì mỗi lần rớt mạng là mất toàn bộ công việc đang dở. Đây là thứ biến SSH từ "dùng tạm" thành "dùng thật".

```bash
# ── trên MAC ──
brew install tmux
```

### 5.1 Config: cùng phản xạ, khác nền tảng

Bản tối thiểu (`mouse on`, `history-limit`, `escape-time`) đủ để tmux dùng được. Nhưng nếu bạn đã có `tmux.conf` trên máy client, **chép phản xạ sang là đáng** — bạn sẽ chuyển qua lại giữa hai máy suốt ngày, và phím tắt khác nhau là nguồn sai lầm nhỏ nhưng liên tục.

Đừng chép nguyên tệp. Ba thứ không port được:

| Trên Linux | Trên macOS |
|---|---|
| `wl-copy` (Wayland) | `pbcopy` |
| Popup gọi hàm zsh cục bộ (`tp`) | Bỏ — hàm đó không tồn tại bên Mac |
| Prefix `C-s` dựa vào `NO_FLOW_CONTROL` của zsh | Xem cảnh báo dưới |

> **`pbcopy` không cần `reattach-to-user-namespace`.** Trình bao bọc đó cần cho macOS 10.x; từ 10.12 trở đi tmux gọi thẳng `pbcopy` được. Đã xác nhận trên macOS 15.7.9 + tmux 3.7c.

> **Prefix `C-s` và flow control.** tmux đọc terminal của client ở chế độ raw nên **bản thân prefix hoạt động bình thường**. Nhưng nếu bạn bấm prefix hai lần để gửi một `C-s` **thật** xuống shell, và zsh của máy đó chưa tắt XON/XOFF, pane sẽ đứng cho tới khi bấm `C-q`. Sửa: `echo 'stty -ixon' >> ~/.zshrc` trên Mac.

Đặt tại `~/.config/tmux/tmux.conf` (XDG, tmux ≥3.1 hỗ trợ) cho khớp phía Fedora, thay vì `~/.tmux.conf`.

Bản đã dùng thật: `dotfiles/mac/tmux.conf`. Deploy:

```bash
# ── trên FEDORA ──
ssh mac-cmp-file 'mkdir -p ~/.config/tmux'
scp mac/tmux.conf mac-cmp-file:~/.config/tmux/tmux.conf
ssh mac-cmp-file '/usr/local/bin/tmux kill-server; /usr/local/bin/tmux new -d -s desk'
```

Xác minh giá trị **thực tế đã nạp**, không đọc tệp:

```bash
ssh mac-cmp-file '/usr/local/bin/tmux show-options -g  | grep -E "^(prefix|status-position|history-limit|mouse) "
                  /usr/local/bin/tmux show-options -sg | grep escape-time
                  /usr/local/bin/tmux list-keys | grep -c pbcopy'
```

Đo được 23/09/2026: `prefix C-s` · `status-position top` · `history-limit 50000` · `mouse on` · `escape-time 10` · 2 binding `pbcopy`.

> **`status-position top`** ở đây không phải vì iPhone. Starship cũng cài trên Mac, prompt hai dòng, nên status bar ở đáy sẽ đè lên nó — cùng lý do với phía Fedora. Nếu bạn dùng iPhone thì nó còn giải quyết chuyện bàn phím ảo iOS che đáy màn hình.
>
> Một khác biệt có chủ đích: `status-right` bên Mac có chữ `mac`. Hai máy cùng bảng màu nên nhìn giống hệt nhau — cần một thứ để biết đang nhìn máy nào.

### Một session hay nhiều?

| | Ưu | Nhược |
|---|---|---|
| **Một session chung** | Đang dở việc trên Fedora, mở phone là thấy nguyên trạng | Attach hai nơi cùng lúc **ép window về kích thước màn hình nhỏ nhất** — mở phone là Fedora bị bóp lại |
| **Session riêng** (`desk` / `phone`) ✅ | Không bao giờ bị bóp | Không tự động thấy việc của nhau |

Guide này dùng session riêng. Cần chuyển việc qua lại thì attach thủ công: `tmux attach -t desk` từ phone.

### Từ iTerm2 tại bàn

```bash
tmux -CC attach -t desk
```

Control mode — tmux window thành iTerm2 tab native. Lưu ý điều kiện bóp kích thước ở trên vẫn áp dụng.

---

## Phase 6 — Một chiều

Mục tiêu: client chạm được Mac, **Mac không chạm được client nào**.

Điều này quan trọng hơn khi client là máy Fedora chứ không phải iPhone. Một desktop Linux có sshd, có thể có Samba, CUPS, dev server đang chạy — bề mặt thật để tấn công, khác với iPhone gần như không có service nào lắng nghe.

### 6.1 Một lệnh — chạy TRÊN FEDORA

> **Máy nào chạy quyết định kết quả, và chạy nhầm là phá đúng thứ cần giữ.**
> `--shields-up` chặn kết nối **đi vào** chính máy chạy lệnh.
>
> | Chạy trên | Kết quả |
> |---|---|
> | **Fedora** ✓ | Mac không vào được Fedora · `ssh mac-cmp` vẫn chạy |
> | Mac ✗ | Fedora không vào được Mac → **mất luôn `ssh mac-cmp`**, phải ngồi trước máy Mac để gỡ |
>
> Máy cần bọc giáp là **client**, tức máy Fedora.

```bash
# trên Fedora
sudo tailscale set --shields-up
```

**`set`, không phải `up`.** Help của chính Tailscale: *"Unlike `tailscale up`, this command does not require the complete set of desired settings. Only settings explicitly mentioned will be set."* Nghĩa là `tailscale up --shields-up` gửi lại **toàn bộ** bộ preference, và những thứ không ghi ra có thể bị đặt lại về mặc định — `--accept-dns`, `--accept-routes`, exit node. `set` chỉ đổi đúng thứ được nêu tên. Có từ Tailscale 1.36.

Fedora vẫn **đi ra** bình thường nhưng không **nhận vào** từ bất kỳ node nào trong tailnet.

Kiểm (trên Fedora):

```bash
tailscale debug prefs | grep ShieldsUp     # → true
ssh mac-cmp-file 'whoami'                  # vẫn phải chạy được
```

Hoàn tác: `sudo tailscale set --shields-up=false`

### 6.2 Vì sao không dùng ACL

Bản trước của guide này dựng một tệp ACL trong admin console. Nó hoạt động, nhưng với tailnet cá nhân hai node thì đó là chọn sai công cụ:

| | `--shields-up` | ACL |
|---|---|---|
| Thực thi ở | chính thiết bị | coordination server, toàn tailnet |
| Công sức | một lệnh | sửa JSON trong admin console |
| Rủi ro tự khoá mình | không — cục bộ, hoàn tác tức thì | có thật |
| Phải sửa khi thêm port (mosh, VNC) | không | có, và quên là lỗi khó chẩn đoán |
| Đúng tầm cho | tailnet cá nhân, ít node | nhiều người dùng, nhiều máy, cần phân nhóm |

**Quay lại ACL khi nào:** tailnet có node của người khác, hoặc bạn cần chính sách áp cho mọi thiết bị kể cả khi ai đó cấu hình lại máy họ. Lúc đó `--shields-up` không đủ vì nó là thiết lập cục bộ — người dùng thiết bị tắt được.

Cú pháp ACL cho trường hợp đó, giữ lại để tham khảo:

```json
{
  "hosts": { "mac-cmp": "100.74.168.122" },
  "acls": [
    { "action": "accept", "src": ["autogroup:member"], "dst": ["mac-cmp:22"] }
  ]
}
```

> `mac-cmp` ở đây là **nhãn nội bộ của ACL**, không liên quan tới DNS lẫn alias SSH cùng tên.

### 6.3 Ba thứ `--shields-up` KHÔNG giải quyết

**1. Cổng do Docker publish vẫn mở.** Đây là lỗ lớn nhất còn lại, và cả ACL lẫn shields-up đều không bịt được.

Docker ghi thẳng netfilter, bỏ qua firewalld. Và `--shields-up` chặn ở chain `INPUT` (traffic tới chính host), trong khi cổng Docker đi qua DNAT rồi `FORWARD` — đường khác hoàn toàn.

Compose mặc định bind mọi interface:

```yaml
ports:
  - "5530:5432"             # → 0.0.0.0:5530, cả LAN lẫn tailnet thấy
```

Sửa bằng cách ghi rõ IP host:

```yaml
ports:
  - "127.0.0.1:5530:5432"   # chỉ máy này
```

Đáng làm vì database dev thường dùng mật khẩu mặc định. Bỏ tiền tố chỉ khi thật sự cần truy cập từ máy khác, cho đúng service đó.

Kiểm nhanh những gì đang mở:

```bash
ss -tuln | grep -vE '127\.0\.0\.1|::1'
docker ps --format '{{.Names}}\t{{.Ports}}'
```

**2. ACL/shields chỉ quản traffic qua tailnet.** Mac và Fedora nếu từng ở chung LAN thì vẫn thấy nhau qua LAN. Firewalld giữ phần đó — để nó bật.

**3. Mac vẫn biết các thiết bị khác tồn tại.** `tailscale status` hiện tên, IP, trạng thái online. Shields chặn kết nối, không ẩn danh sách.

### 6.4 Đánh đổi

**Taildrop nhận file sẽ hỏng** — `tailscale file cp` gửi *tới* máy này không còn nhận được. Gửi *đi* vẫn chạy. Dùng `rsync` qua `mac-cmp-file` thay thế, vốn đã là cách chuyển file chính trong guide này.

Bỏ shields khi cần: `sudo tailscale set --shields-up=false` (trên Fedora).

---

## Phase 7 — Chuẩn bị môi trường

Quyền UNIX từ xa **giống hệt** tại bàn — cùng UID, cùng `sudo`, cùng filesystem, cùng `.zshrc`. Khác biệt nằm ở các lớp macOS gắn với giả định "có người đang ngồi trước máy".

### Keychain

Login keychain chỉ mở khi bạn đăng nhập ở màn hình GUI.

| | |
|---|---|
| Khoá màn hình | ✅ keychain vẫn mở |
| Đăng xuất / reboot | ❌ keychain khoá → `git push` HTTPS, `npm publish`, `docker login` fail với lỗi khó hiểu |

Né bằng cách không phụ thuộc keychain:

```bash
git remote set-url origin git@github.com:user/repo.git    # SSH thay vì HTTPS
```

Token registry để trong `.npmrc` hoặc biến môi trường, đừng để keychain giữ.

### Danh tính Git nằm trên Fedora, không nằm trên Mac

Hai máy có hai `~/.gitconfig` riêng. Hệ định tuyến danh tính trên Fedora — `includeIf`, `url.insteadOf`, `allowed_signers`, `commit.gpgsign` — **không đi theo kết nối SSH**. Commit tạo trên Mac dùng cấu hình của Mac.

Điều đó **không** có nghĩa Mac là tờ giấy trắng. Hiện trạng đo được trên `macos-comacpro` (22/09/2026):

```
user.name         ninhht-cmp
user.email        ninhht@comacpro.com
~/.ssh/           id_ed25519, id_github_org
~/.ssh/config     Host github.com → IdentityFile ~/.ssh/id_github_org
```

Không có `includeIf`, không `insteadOf`, không `gpg.format`, không `allowed_signers`.

Đây là một máy **một danh tính**, cấu hình đúng cho công việc của khách hàng đó — hợp lý với máy công ty. Nên đối chiếu thật sự là:

| | Fedora | Mac |
|---|---|---|
| Email commit | Theo thư mục (`includeIf`) | Cố định `ninhht@comacpro.com` — **đúng** cho repo của khách hàng này |
| Chọn khoá GitHub | Theo alias (`insteadOf` → `github.com-cmp`) | Cố định `id_github_org` cho mọi repo GitHub |
| Chữ ký commit | ✅ ký bằng khoá danh tính | ❌ **không ký** — thiếu `commit.gpgsign` và `allowed_signers` |

**Rủi ro còn lại, hẹp hơn nhiều so với "commit sai tên":**

1. **Commit từ Mac không có chữ ký.** Nếu repo hoặc branch protection yêu cầu signed commits thì sẽ bị chặn.
2. **Email là toàn cục, không định tuyến.** Clone một repo cá nhân hay của khách hàng khác về Mac thì nó vẫn mang email CMP, im lặng. Trên Fedora `includeIf` chặn được việc này; trên Mac thì không.
3. **`~/.ssh/config` của Mac thiếu `IdentitiesOnly yes`.** Có 2 khoá trong `~/.ssh`, ssh có thể chào lần lượt và chạm `MaxAuthTries` trước khi tới khoá đúng. Thêm một dòng là xong.

Muốn commit ký được trên Mac thì bổ sung ba thứ vào `~/.gitconfig` của nó — không cần dựng lại gì, không phụ thuộc Fedora:

```bash
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_github_org.pub
git config --global commit.gpgsign true
```

Rồi thêm khoá đó vào GitHub **lần thứ hai** với kiểu Signing Key, và tạo `~/.config/git/allowed_signers` trên Mac để `--show-signature` xác minh được.

#### Đừng bật `ForwardAgent`

Cám dỗ sẽ đến đúng lúc bạn cần `git pull` một repo trên Mac: agent forwarding nghe rất tiện, và nó giải quyết đúng vấn đề đó.

Đừng. `ForwardAgent yes` mở một socket agent trên máy đích, và **bất kỳ ai có quyền root trên máy đó dùng được mọi key trong agent của bạn** trong suốt phiên kết nối — gồm cả ba key GitHub cá nhân, không chỉ key của máy công ty. Trên máy do người khác quản trị, đó là trao chìa khoá chứ không phải cho mượn.

Cách đúng: Mac có **bộ key GitHub riêng của nó**, đăng ký riêng, thu hồi riêng. Chậm hơn năm phút lúc setup, và không có gì phải hối tiếc về sau.

```sshconfig
# KHÔNG thêm dòng này vào bất kỳ khối nào
#   ForwardAgent yes
```

OpenSSH mặc định `ForwardAgent no`, nên không làm gì là đã đúng. Chỉ cần đừng copy dòng đó từ một blog nào đó vào.

### Bốn thứ còn lại

| | |
|---|---|
| **App GUI phải chạy sẵn** | `docker ps` fail nếu Docker Desktop chưa lên. `open -a Docker` mở app trên màn hình bạn không nhìn thấy, đôi khi kèm dialog chờ |
| **Touch ID cho `sudo` không dùng được từ xa** | Phải gõ password. Chỉ phiền, không chặn |
| **`osascript` điều khiển app khác sẽ fail** | Quyền Automation không cấp được cho session SSH. Cần thì dùng [Phụ lục C](#phụ-lục-c--screen-sharing) |
| **Prompt/font có thể vỡ** | Nerd Font icon thành ô vuông nếu terminal Fedora chưa cài font tương ứng. `sudo dnf install <nerd-font>` hoặc dùng prompt tối giản |

> **Mô hình đúng:** bạn không phải một user khác với ít quyền hơn. Bạn là **chính bạn, nhưng không có màn hình và không có bàn tay**. Mọi thứ macOS gắn với sự hiện diện vật lý là thứ phải chuẩn bị trước, không phải thứ xin được lúc đang ở xa.

---

## Phase 8 — Preflight

Setup này hiếm khi hỏng vì cấu hình sai. Nó hỏng vì **máy Mac ở sai trạng thái lúc bạn cần**: đã ngủ, đã logout, Docker chưa chạy, quên `caffeinate`, node key sắp hết hạn. Toàn bộ là lỗi con người — và lỗi con người phải xử bằng tự động hoá, không phải bằng checklist trong đầu.

Script này chạy **trên Mac**, trước khi bạn rời công ty.

### 8.1 Cài

```bash
mkdir -p ~/bin
grep -q 'HOME/bin' ~/.zshenv || echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshenv
```

> **`.zshenv`, không phải `.zshrc` — và đây là cùng một cái bẫy với `RemoteCommand` ở [2.5](#25-sshconfig).** zsh chỉ nạp `.zshrc` cho phiên **tương tác**. Lệnh chạy qua `ssh host <cmd>` là phiên **không tương tác**, chỉ nạp `.zshenv`. Đặt `PATH` trong `.zshrc` thì `ssh mac-cmp-file preflight` sẽ báo `command not found: preflight` dù script đã cài đúng.
>
> Đã kiểm chứng trên chính máy này: `ssh mac-cmp-file 'echo $PATH'` trả về `/usr/bin:/bin:/usr/sbin:/sbin` — không có `~/bin`, không có `/usr/local/bin`.

Rồi dán toàn bộ khối dưới đây vào terminal trên Mac (một lần, chạy cả khối):

```bash
cat > ~/bin/preflight << 'PREFLIGHT_SCRIPT'
#!/bin/zsh
#
# preflight — check and arm the work Mac for remote access before leaving.
#
# Remote access rarely breaks because a config is wrong; it breaks because the
# machine is in the wrong state when you need it — asleep, logged out, Docker not
# started, node key about to expire. This moves detection to while you can still
# walk over and fix it.
#
# Usage:
#   preflight            check only, change nothing
#   preflight --arm      check, then start caffeinate and create the tmux session
#   preflight --help     print this header
#
# Exit: 0 = ready (warnings allowed) · 1 = something FAILed · 2 = bad argument
#
# Runs ON THE MAC. From Fedora: `macstatus` / `macarm` (zsh/conf.d/aliases.zsh).
#
# Status output is Vietnamese to match the runbook this belongs to; comments are
# English to match the rest of the repo.
#
# Environment:
#   PREFLIGHT_TMUX_SESSION   tmux session name      (default: desk)
#   PREFLIGHT_WORKDIR        directory for it       (default: $HOME)
#   PREFLIGHT_CAFFEINATE     seconds to stay awake  (default: 28800 = 8h)
#   NO_COLOR                 set to anything to disable colour
#

emulate -L zsh
set -u

# Set PATH ourselves; never trust the inherited one.
#
# `ssh host <cmd>` is a NON-INTERACTIVE session: zsh reads .zshenv and skips
# .zshrc, leaving PATH as /usr/bin:/bin:/usr/sbin:/sbin — no /usr/local/bin and
# no /opt/homebrew/bin. Without this line tailscale, tmux and docker all come
# back "not found" and the script reports NOT READY on a perfectly healthy Mac.
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

# ----------------------------------------------------------------- arguments

ARM=0
case "${1:-}" in
  --arm)      ARM=1 ;;
  --help|-h)  sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
  "")         ;;
  *)          print -u2 -r -- "preflight: tham số lạ: $1 (dùng --help)"; exit 2 ;;
esac

SESSION="${PREFLIGHT_TMUX_SESSION:-desk}"
WORKDIR="${PREFLIGHT_WORKDIR:-$HOME}"
CAFFEINATE_SECONDS="${PREFLIGHT_CAFFEINATE:-28800}"

FAIL=0
WARN=0

# Colour on by default: the main caller is `ssh mac-cmp-file preflight`, where
# stdout is a pipe but a human terminal is still reading it. Honour NO_COLOR.
if [[ -n "${NO_COLOR:-}" ]]; then
  G=""; Y=""; R=""; DIM=""; B=""; N=""
else
  G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; DIM=$'\e[2m'; B=$'\e[1m'; N=$'\e[0m'
fi

ok()   { print -r -- "  ${G}ok  ${N} $1" }
warn() { print -r -- "  ${Y}warn${N} $1"; WARN=1 }
bad()  { print -r -- "  ${R}FAIL${N} $1"; FAIL=1 }
act()  { print -r -- "  ${B}-->${N}  $1" }
skip() { print -r -- "  ${DIM}skip${N} $1" }
sec()  { print -r -- ""; print -r -- "${DIM}$1${N}" }

# ------------------------------------------------------------------- network

sec "Mạng"

if ! command -v tailscale >/dev/null 2>&1; then
  bad "không tìm thấy tailscale trong PATH"
elif tailscale status >/dev/null 2>&1; then
  ok "tailscale up — $(tailscale ip -4 2>/dev/null | head -1)"

  # An expired node key drops the machine off the tailnet, and re-auth needs a
  # GUI session AT the machine — which is exactly what you will not have.
  DAYS=$(tailscale status --json 2>/dev/null | python3 -c '
import sys, json, datetime
try:
    exp = json.load(sys.stdin).get("Self", {}).get("KeyExpiry")
    if not exp:
        print("none"); sys.exit()
    exp = exp.split(".")[0].rstrip("Z")
    d = datetime.datetime.fromisoformat(exp) - datetime.datetime.utcnow()
    print(d.days)
except Exception:
    print("?")
' 2>/dev/null)

  case "$DAYS" in
    none)   warn "key expiry đã TẮT cho máy này — ở lại tailnet vô thời hạn" ;;
    ''|\?)  skip "key expiry (không đọc được)" ;;
    *)      if (( DAYS < 0 )); then
              bad "node key ĐÃ HẾT HẠN — re-auth tại máy"
            elif (( DAYS < 21 )); then
              bad "node key hết hạn sau ${DAYS} ngày — re-auth TẠI MÁY trước khi đi xa"
            else
              ok "node key còn ${DAYS} ngày"
            fi ;;
  esac
else
  bad "tailscale down — chạy: tailscale up"
fi

# ----------------------------------------------------------------- way in

sec "Đường vào"

if nc -z -G 2 localhost 22 >/dev/null 2>&1; then
  ok "sshd đang nghe trên 22"
else
  bad "sshd không nghe — bật Remote Login trong System Settings"
fi

AK="$HOME/.ssh/authorized_keys"
if [[ -f "$AK" ]]; then
  # grep -c prints "0" AND exits 1 when nothing matches, so `|| echo 0` appends
  # a second "0", giving "0\n0". Capture the status separately instead.
  KEYS=$(grep -c '^ssh-' "$AK" 2>/dev/null) || KEYS=0
  PERM=$(stat -f '%OLp' "$AK" 2>/dev/null || print -r -- "?")
  if [[ "$PERM" == "600" ]]; then
    ok "authorized_keys: ${KEYS} key, quyền ${PERM}"
  else
    bad "authorized_keys quyền ${PERM} (phải 600) — chmod 600 $AK"
  fi
else
  bad "không có $AK"
fi

if command -v sshd >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  PW=$(sudo -n sshd -T 2>/dev/null | awk '/^passwordauthentication/{print $2}')
  [[ "$PW" == "no" ]] && ok "password auth: tắt" || warn "password auth: ${PW:-?} — xem lại harden"
else
  skip "password auth (cần sudo không mật khẩu)"
fi

# Screen Sharing is expected to be OFF here; finding it on is the anomaly.
if nc -z -G 2 localhost 5900 >/dev/null 2>&1; then
  warn "Screen Sharing ĐANG BẬT trên 5900 — tắt nếu không dùng"
else
  ok "Screen Sharing: tắt"
fi

# ------------------------------------------------------------ login session

sec "Phiên đăng nhập"

if launchctl print "gui/$(id -u)" >/dev/null 2>&1; then
  ok "GUI session còn sống (keychain mở được)"
else
  bad "KHÔNG có GUI session — đã đăng xuất. git/npm/docker qua SSH sẽ hỏng"
fi

KC="$HOME/Library/Keychains/login.keychain-db"
if [[ -f "$KC" ]]; then
  # Two dead ends here, both measured on this Mac:
  #   grep -qi lock   — an UNLOCKED keychain prints "lock-on-sleep", so it warns
  #                     on every single run.
  #   exit code       — over SSH `security` always fails with 36, "User
  #                     interaction is not allowed", whether locked or not.
  # So lock state is simply not observable from a non-GUI session. Say that
  # instead of guessing; the GUI-session check above already catches the case
  # this was meant to detect (logged out => keychain locked => git push fails).
  if security show-keychain-info "$KC" >/dev/null 2>&1; then
    ok "login keychain mở"
  else
    skip "login keychain (không đọc được từ phiên SSH — xem mục GUI session)"
  fi
fi

# ---------------------------------------------------------- power and sleep

sec "Nguồn & giấc ngủ"

if pmset -g ps 2>/dev/null | head -1 | grep -q 'AC Power'; then
  ok "đang cắm nguồn"
else
  bad "đang chạy pin — cắm sạc, nếu không máy sẽ ngủ"
fi

if pgrep -x caffeinate >/dev/null 2>&1; then
  ok "caffeinate đang chạy"
elif (( ARM )); then
  # nohup: over `ssh host <cmd>` the channel closes as soon as the script exits.
  # Without it caffeinate takes the SIGHUP and dies with the session — precisely
  # when you just asked it to keep the machine awake.
  nohup caffeinate -dims -t "$CAFFEINATE_SECONDS" >/dev/null 2>&1 &
  disown
  act "đã bật caffeinate (${CAFFEINATE_SECONDS}s)"
else
  warn "caffeinate chưa chạy — máy có thể ngủ. Dùng --arm để bật"
fi

DSLEEP=$(pmset -g 2>/dev/null | awk '/^[[:space:]]*sleep/{print $2; exit}')
if [[ -z "$DSLEEP" ]]; then
  skip "system sleep (không đọc được pmset)"
elif [[ "$DSLEEP" == "0" ]]; then
  ok "system sleep: tắt"
elif (( DSLEEP <= 5 )); then
  # Anything this short means the machine is unreachable within minutes of you
  # walking away, which defeats the whole setup. Worth a FAIL, not a warning.
  bad "system sleep sau ${DSLEEP} phút — quá ngắn, máy rơi khỏi tailnet gần như ngay lập tức"
else
  warn "system sleep sau ${DSLEEP} phút — máy sẽ rơi khỏi tailnet"
fi

# Auto-installed macOS update => reboot => FileVault pre-boot screen => the
# machine is unreachable until someone types the password at the keyboard.
AUTOOS=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate \
         AutomaticallyInstallMacOSUpdates 2>/dev/null || print -r -- "unset")
case "$AUTOOS" in
  1) bad  "macOS tự cài update → sẽ reboot → FileVault khoá bạn ra ngoài" ;;
  0) ok   "auto-install macOS updates: tắt" ;;
  *) warn "không đọc được cài đặt auto-update (có thể do MDM quản lý)" ;;
esac

# ------------------------------------------------------------------ workspace

sec "Workspace"

if ! command -v tmux >/dev/null 2>&1; then
  bad "chưa cài tmux — brew install tmux"
elif tmux has-session -t "$SESSION" 2>/dev/null; then
  W=$(tmux list-windows -t "$SESSION" 2>/dev/null | wc -l | tr -d ' ')
  ok "tmux session '$SESSION' tồn tại (${W} window)"
elif (( ARM )); then
  tmux new-session -d -s "$SESSION" -c "$WORKDIR"
  act "đã tạo tmux session '$SESSION' tại $WORKDIR"
else
  warn "chưa có tmux session '$SESSION' — dùng --arm để tạo"
fi

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    ok "docker daemon đang chạy"
  else
    warn "docker daemon chưa chạy — mở Docker Desktop TRƯỚC khi rời bàn"
  fi
else
  skip "docker (chưa cài)"
fi

# On macOS `/` is the sealed, read-only system snapshot: it reports ~28% while
# the data volume sits at 87%. Free space is shared across the APFS container so
# the Avail figure matches either way, but the PERCENTAGE — the thing that
# triggers the FAIL — is meaningless read off `/`. Measured, not assumed.
DISK_MP=/System/Volumes/Data
[[ -d $DISK_MP ]] || DISK_MP=/
AVAIL=$(df -h "$DISK_MP" 2>/dev/null | awk 'NR==2{print $4}')
PCT=$(df "$DISK_MP" 2>/dev/null | awk 'NR==2{gsub("%","",$5); print $5}')
if [[ -z "$PCT" ]]; then
  skip "dung lượng đĩa (không đọc được df)"
elif (( PCT > 90 )); then
  bad "đĩa còn ${AVAIL} (đã dùng ${PCT}%)"
else
  ok "đĩa còn ${AVAIL}"
fi

# -------------------------------------------------------------------- verdict

print -r -- ""
if (( FAIL )); then
  print -r -- "${R}${B}CHƯA SẴN SÀNG${N} — sửa các mục FAIL ở trên."
  exit 1
elif (( WARN )); then
  print -r -- "${Y}${B}SẴN SÀNG (có cảnh báo)${N} — đọc lại các mục warn."
  exit 0
else
  print -r -- "${G}${B}SẴN SÀNG${N} — khoá màn hình, đừng đăng xuất, đừng reboot."
  exit 0
fi
PREFLIGHT_SCRIPT
chmod +x ~/bin/preflight
```

Kiểm tra: `preflight` (không tham số) phải chạy và in ra bảng trạng thái.

> **Đã chạy thật trên macOS 15.7.9 ngày 23/09/2026** — cả 14 mục đều thực thi, và lần chạy đó lộ thêm 3 lỗi nữa (xem [changelog v5.2](#v52--preflight-chạy-thật-trên-macos-lộ-3-lỗi)). Bản dưới đây là bản đã vá.
>
> **Bản script này đã sửa 6 lỗi so với bản v4.7.** Quan trọng nhất là dòng `export PATH=...` ở đầu: `tailscale`, `tmux` và `docker` đều nằm ở `/usr/local/bin`, không có trong `PATH` của phiên không tương tác — thiếu dòng đó thì `macstatus` báo **CHƯA SẴN SÀNG** với 2 FAIL trên một máy hoàn toàn khoẻ mạnh. Chi tiết ở [nhật ký thay đổi](#v41--v49--tóm-tắt).
>
> Bản dùng được cũng nằm ở `dotfiles/mac/preflight`, đã kiểm cú pháp bằng `zsh -n`.

### 8.2 Dùng

```bash
preflight           # chỉ kiểm tra, không thay đổi gì
preflight --arm     # kiểm tra + bật caffeinate, tạo tmux session nếu thiếu
```

Chạy `preflight --arm` **trước khi rời bàn**. Chạy `preflight` từ Fedora khi thấy có gì đó lạ.

Script kiểm tra 14 mục: tailscale up, số ngày còn lại của node key, sshd nghe port 22, quyền `authorized_keys`, password auth đã tắt chưa, Screen Sharing có đang bật ngoài ý muốn không, GUI session, keychain, nguồn điện, cài đặt sleep, auto-update macOS, tmux session, docker daemon, dung lượng đĩa.

Exit code `0` = sẵn sàng, `1` = có mục FAIL. Mọi check đều **fail mềm** — không check nào có thể làm chết script.

Script trong guide này đã đặt mặc định `desk` cho khớp [Phase 5](#phase-5--tmux), nên **không cần** khai thêm biến. Nếu muốn đổi, dùng `.zshenv` chứ không phải `.zshrc` — cùng lý do ở 8.1:

```bash
echo 'export PREFLIGHT_TMUX_SESSION=<tên khác>' >> ~/.zshenv
```

| Biến | Mặc định |
|---|---|
| `PREFLIGHT_TMUX_SESSION` | `desk` |
| `PREFLIGHT_WORKDIR` | `$HOME` |
| `PREFLIGHT_CAFFEINATE` | `28800` (8 tiếng) |

### 8.3 Chạy từ Fedora bằng một lệnh

```bash
alias macstatus='ssh mac-cmp-file ~/bin/preflight'
alias macarm='ssh mac-cmp-file "~/bin/preflight --arm"'
alias macup='tailscale status | grep macos-comacpro'
```

Ba điểm:

- Dùng host `mac-cmp-file` (không có `RemoteCommand`) để output không bị bọc trong tmux.
- **Đường dẫn tuyệt đối `~/bin/preflight`**, không phải `preflight` trần — vì `~/bin` không có trong `PATH` của phiên không tương tác (xem 8.1). `~` vẫn nở đúng vì shell phía Mac xử lý nó.
- `macup` không cần SSH gì cả: Tailscale biết Mac ngủ hay tỉnh trong **0 giây**, còn `macstatus` với máy đang ngủ sẽ mất 10 giây rồi timeout. Chạy `macup` trước ([Phase 10.3](#103-mac-ngủ--vấn-đề-vận-hành-chính)).

---

## Phase 9 — Bảo mật

Thiết bị nào chạm được vào máy công ty thì **là** đường vào máy công ty. Bảo vệ client là phần quan trọng nhất của setup này — quan trọng hơn mọi thứ ở Phase 4 và Phase 6.

### 9.1 Fedora

| | |
|---|---|
| **Mã hoá toàn đĩa (LUKS)** | ✅ **Đã xác minh 22/09/2026** — `nvme0n1p3` là `crypto_LUKS`, cả `/` lẫn `/home` nằm trên đó. Bảo vệ khi máy **tắt**. Không bảo vệ gì khi máy đang mở — đó là việc của hai dòng dưới |
| **Passphrase trên key** | Đã làm ở [2.3](#23-tạo-key-trên-fedora). Đây là lớp duy nhất còn lại nếu ai đó lấy được file khi máy đang mở |
| **`ssh-add -t 8h`** | Agent tự quên key. Nạp vĩnh viễn thì máy bỏ mở qua đêm = key sẵn sàng cho bất kỳ ai ngồi vào. ✅ **Đã xác minh** GNOME Keyring trên Fedora 44 tôn trọng `-t` — xem [2.6](#26-ssh-agent) |
| **Không `ForwardAgent`** | Bật là cho máy công ty dùng mọi key trong agent của bạn suốt phiên kết nối. Xem [Phase 7](#danh-tính-git-nằm-trên-fedora-không-nằm-trên-mac) |
| **Khoá màn hình tự động** | GNOME Settings → Privacy → Screen Lock, ≤ 5 phút |
| **firewalld** | Fedora bật mặc định. Kiểm tra: `sudo firewall-cmd --state`. ⚠ **Nó không che được cổng do Docker publish** — xem dòng dưới |
| **Cổng Docker publish** | Docker ghi thẳng netfilter, bỏ qua firewalld **và** `--shields-up`. Compose bind `"5432:5432"` là mở ra cả LAN lẫn tailnet. Dùng `"127.0.0.1:5432:5432"` — xem [6.3](#63-ba-thứ---shields-up-không-giải-quyết) |
| **`--shields-up` trên Fedora** | Chặn mọi kết nối vào từ tailnet. Thay cho ACL với tailnet cá nhân — xem [6.1](#61-một-lệnh--chạy-trên-fedora) |
| **Dịch vụ nghe trên `0.0.0.0`** | Zone `FedoraWorkstation` chỉ mở những gì khai báo, nên wifi đã được chặn. Nhưng `tailscale0` **không thuộc zone firewalld nào** — mọi thứ nghe wildcard đều mở với tailnet cho tới khi bật shields. Rà: `ss -tuln \| grep -vE '127\.0\.0\.1\|::1'` |

**Dịch vụ mặc định không cần trên máy trạm.** Đối chiếu với phần cứng thật trước khi tắt — đây là kết quả đo trên máy này (22/09/2026), máy khác có thể khác:

| Dịch vụ | Tắt được khi |
|---|---|
| `passim` | Daemon chia sẻ metadata firmware của fwupd, nghe `0.0.0.0:27500`. Vô dụng nếu bạn không có nhiều máy chia nhau băng thông. Unit là `static` nên phải `mask`, và **đừng gỡ gói** — `fwupd` liên kết `libpassim.so.1` |
| `livesys`, `livesys-late` | Dành cho Live ISO; máy đã cài đặt thì là rác sót |
| `qemu-guest-agent` | `systemd-detect-virt` trả về `none` (máy thật) |
| `iscsi-onboot`, `iscsi-starter` | `ls /etc/iscsi/nodes` rỗng |
| `mdmonitor` | `/proc/mdstat` không có mảng RAID |
| `lvm2-monitor` | `lvs` không có volume (btrfs trên LUKS trực tiếp) |
| `ModemManager` | Không có interface `ww*`/`wwan*`. Cắm USB 4G sau này thì bật lại |

```bash
sudo systemctl mask --now passim.service
sudo systemctl disable --now livesys livesys-late qemu-guest-agent \
  iscsi-onboot iscsi-starter mdmonitor lvm2-monitor ModemManager
```

> **Nhóm `docker` ≈ root không cần mật khẩu.** Ai chạy được `docker` là mount được `/` của host vào container và thành root, bỏ qua hoàn toàn mật khẩu `sudo`. Đây là đánh đổi cố hữu của Docker trên Linux, không phải lỗi cấu hình. Hết hẳn chỉ khi chuyển sang Docker rootless hoặc Podman rootless — cả hai đều là dự án riêng, không phải việc làm kèm.

**Trần journal.** Mặc định là 10% đĩa (≈47G trên ổ 475G):

```bash
echo 'SystemMaxUse=200M' | sudo tee -a /etc/systemd/journald.conf
sudo systemctl restart systemd-journald
```

### 9.2 iPhone (nếu dùng)

- [ ] Termius → Settings → Security → **khoá bằng Face ID**
- [ ] Termius → **tắt cloud sync cho Keychain** (nhắc lại từ 3.2)
- [ ] iOS passcode ≥ 6 chữ số, bật **Stolen Device Protection**
- [ ] Bật Find My iPhone

### 9.3 Runbook: mất một thiết bị

Theo đúng thứ tự. Bước 1 hiệu lực tức thì và không cần chạm vào Mac:

1. **Admin console Tailscale** → Machines → **xoá thiết bị đó**
   *Cắt đường mạng. Làm trước tiên, từ bất kỳ trình duyệt nào.*
2. Từ một client còn lại, hoặc tại Mac:
   ```bash
   ssh mac-cmp-file
   # XEM TRƯỚC khi ghi đè — phải thấy đúng dòng sắp bị xoá
   grep 'tainjiao-dotdev' ~/.ssh/authorized_keys
   grep -v 'tainjiao-dotdev' ~/.ssh/authorized_keys > /tmp/ak && mv /tmp/ak ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   wc -l ~/.ssh/authorized_keys        # phải giảm đúng 1 dòng
   ```
   `tainjiao-dotdev` là comment của key Fedora — đã đối chiếu với `authorized_keys` thật trên Mac (22/09/2026). Đổi thành comment của thiết bị bị mất nếu là máy khác.

   > **Chạy `grep` xem trước, đừng chạy thẳng `grep -v`.** Nếu chuỗi sai, `grep -v` khớp mọi dòng, ghi lại file y nguyên và **không xoá gì** — trong khi bạn tưởng đã thu hồi xong. Đó là lỗi im lặng đúng vào lúc tệ nhất.
3. Xoá từ xa thiết bị (Find My iPhone / công cụ tương ứng)
4. Đổi password tài khoản macOS

> **Đây là lý do đáng giữ cả hai client.** Có Fedora và iPhone nghĩa là mất một cái vẫn còn đường vào Mac để thu hồi key. Chỉ một client thì mất nó là phải có mặt tại máy.

---

## Phase 10 — Bom hẹn giờ

Hai sự kiện tự động sẽ cắt truy cập mà không cần bạn làm gì sai. Cả hai xảy ra khi bạn đang ở xa và **không sửa được từ xa**.

### 10.1 macOS tự update rồi reboot

Máy khởi động lại lúc 3h sáng → dừng ở pre-boot FileVault → mất truy cập cho tới khi có người gõ mật khẩu tại chỗ. **Đây là cách setup này hỏng thường gặp nhất trong thực tế.**

```bash
defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates 2>/dev/null
softwareupdate --schedule
```

System Settings → General → Software Update → **(i)**:

| Mục | Đặt |
|---|---|
| Install macOS updates | **Tắt** — đây là cái gây reboot |
| Install Security Responses and system files | **Giữ bật** — vá bảo mật, hiếm khi reboot |

**Đánh đổi:** bạn phải tự cài update OS. Trên máy công ty có MDM, IT có thể ép cài và ghi đè cài đặt này — hỏi trước và biết lịch patch window của họ.

**Quy tắc:** trước kỳ nghỉ dài, cài hết update *khi đang ngồi trước máy* thay vì để nó tự làm lúc bạn đi vắng.

### 10.2 Tailscale node key hết hạn

Mặc định 180 ngày. Hết hạn → máy rơi khỏi tailnet. `tailscale up --force-reauth` cần tương tác GUI tại máy, nên **không sửa được từ xa** — và bản thân lệnh đó có cảnh báo là nó làm rớt kết nối tailnet, không nên chạy qua SSH khi không có đường vào thay thế.

Áp cho **cả `macos-comacpro` lẫn `tainjiao-dotdev`**. Fedora hết hạn thì bạn còn ngồi trước máy để re-auth; Mac hết hạn thì mất luôn.

| | Ưu | Nhược |
|---|---|---|
| **Giữ expiry + nhắc lịch** ✅ | Giữ được tính chất bảo mật của re-auth định kỳ | Phải nhớ; re-auth tại bàn mỗi ~6 tháng |
| Tắt expiry cho Mac | Không bao giờ bị cắt bất ngờ | Máy công ty ở lại tailnet vô thời hạn kể cả khi bạn nghỉ việc |
| Kéo dài expiry | Dung hoà | Vẫn phải nhớ, chỉ thưa hơn |

Chọn cái đầu → **tạo ngay một sự kiện lịch lặp lại, ngày thứ 150**: "re-auth Tailscale trên macos-comacpro (phải ngồi trước máy)". `preflight` cũng cảnh báo khi còn dưới 21 ngày.

### 10.3 Mac ngủ — vấn đề vận hành chính

Hai mục trên là bom hẹn giờ hiếm khi nổ. Cái này nổ **mỗi ngày**.

macOS ngủ khi không ai đụng tới, và Tailscale **không** đánh thức được máy đang ngủ qua relay. Đo thật 22/09/2026: `uptime` trên Mac là `up 28 days` — máy chưa hề tắt, chỉ ngủ. Trong một phiên đo ngắn nó tỉnh một lần rồi ngủ lại.

Trong Tailscale, **ngủ và tắt hiện giống hệt nhau**:

```
macos-comacpro  …  offline, last seen 1m ago
```

Kiểm tra trước khi kết nối — Tailscale đã biết sẵn, mất **0 giây**:

```bash
tailscale status | grep macos-comacpro
# "offline, last seen …"  → đừng ssh, sẽ timeout 10s
# "active; relay …"       → kết nối được
```

Đây chính là việc `preflight` ở [Phase 8](#phase-8--preflight) làm. Nếu chưa cài Phase 8, đó là mảnh ghép thiếu có giá trị cao nhất trong toàn bộ setup này.

### Đã chốt: `sleep 0`, và **không** xây Wake-on-LAN

```bash
# ── trên MAC ──
sudo pmset -a sleep 0          # máy không ngủ
sudo pmset -a displaysleep 10  # màn hình vẫn tắt — đây mới là phần tiết kiệm thật
```

Áp 23/09/2026. Xác minh bằng cách **gỡ `caffeinate`** rồi để yên một tiếng: Mac vẫn online, `ssh` trả lời trong 0 giây. Trước đó là `offline, last seen 5m ago` và timeout 130 giây.

Điểm quan trọng: setup không còn phụ thuộc việc bạn **nhớ** chạy `--arm`. `preflight --arm` từ bắt buộc xuống tuỳ chọn.

#### Vì sao không bật sleep rồi đánh thức từ xa

Đây là câu hỏi ai cũng hỏi, nên ghi lại kết luận cùng số đo thay vì suy luận lại từ đầu.

**Cái được rất nhỏ.** Mac mini cắm điện: ngủ tiết kiệm vài watt, cỡ 30–40 kWh/năm. Không đáng kể.

**Cái mất là cả một nhóm chế độ hỏng.** Đo trên máy này:

| Điều kiện | Kết quả |
|---|---|
| `en0` Ethernet | **inactive** — máy chạy Wi-Fi (`en1`) |
| Wake-on-LAN qua Wi-Fi trên macOS | Cần **Bonjour Sleep Proxy** trong LAN; quét không thấy cái nào |
| Private Wi-Fi Address | MAC đang dùng `72:e5:…` khác MAC phần cứng `38:f9:…`, và có thể xoay → magic packet nhắm ai? |
| Magic packet | Gói **layer 2**, không qua router. Chỉ gửi được khi client ở **cùng LAN** — mang laptop về nhà là hết |
| `powernap 1` + `tcpkeepalive 1` | Máy tỉnh định kỳ, Tailscale nối lại vài giây rồi ngủ tiếp → **khả dụng ngắt quãng** |

Dòng cuối là điều tệ nhất: **khả dụng ngắt quãng còn tệ hơn tắt hẳn**, vì bạn không biết lúc nào dùng được.

Và điều quyết định: **Tailscale không đánh thức được máy.** Gói đánh thức phải do một thiết bị **trong cùng LAN với Mac** gửi. Traffic từ internet chỉ tới router; Mac đang ngủ thì đã rớt khỏi tailnet.

Muốn có WoL thật thì cần một máy luôn bật trong LAN văn phòng làm trạm trung chuyển — tức thêm một hệ thống phải bảo trì, để giải quyết một vấn đề mà `sleep 0` xoá bỏ miễn phí.

> **Nếu đổi `pmset` trên máy công ty là vấn đề chính sách**, dùng `preflight --arm` trước khi rời bàn (bật `caffeinate` 8 tiếng) và `macup` trước khi kết nối. Kém tin cậy hơn vì phụ thuộc trí nhớ, nhưng không đụng cấu hình hệ thống.

#### Việc đáng làm hơn: cắm dây mạng

Mac mini có cổng Ethernet đang bỏ trống. Đo chất lượng đường Wi-Fi hiện tại, hai máy **cùng LAN**:

| Đích | avg | max | jitter |
|---|---|---|---|
| Fedora → gateway `192.168.1.1` | 8ms | 25ms | 5ms |
| Fedora → Mac `192.168.1.63` | **78ms** | **230ms** | **62ms** |

Cùng card Wi-Fi Fedora, cùng thời điểm. Gateway trả lời nhanh gấp 10 lần và ổn định gấp 12 lần → **độ trễ nằm ở phía Mac**, là Wi-Fi power management của nó, không phải đường truyền.

Jitter 62ms nghĩa là trong phiên tmux tương tác, mỗi phím gõ hiện ra sau 8ms tới 230ms. Không hỏng, nhưng nhão — và đây thường bị đổ nhầm cho "SSH lag".

Cắm Ethernet được ba thứ cùng lúc:

- Độ trễ dưới 1ms, jitter gần bằng không
- Bỏ một lớp phụ thuộc: AP reboot, nhiễu kênh, roaming
- Card Ethernet vẫn có điện khi ngủ → **WoL trở nên khả thi thật**, không cần sleep proxy

Chi phí: một sợi cáp.

#### Điểm yếu còn lại — không phải sleep, mà là reboot

Mac reboot vì bất cứ lý do gì thì dừng ở màn hình **FileVault pre-boot**: không mạng, không SSH, không Tailscale. **Không có đường phục hồi từ xa.**

Tắt auto-update ([10.1](#101-macos-tự-update-rồi-reboot)) đã bỏ được nguyên nhân phổ biến nhất. Phần còn lại — mất điện, kernel panic — là rủi ro chấp nhận được với máy văn phòng có người lui tới. Nhưng hãy **biết** đường phục hồi là "nhờ ai đó tới gõ mật khẩu", đừng phát hiện điều đó lúc đang cần.

Đừng tắt FileVault để né. Đó là máy công ty, và đánh đổi sai hướng.

> `ConnectTimeout 10` ở [2.5](#25-sshconfig) chỉ làm thất bại **nhanh hơn** (130 giây → 10 giây). Nó không giúp bạn kết nối được. Đừng nhầm hai việc.

---

## Acceptance test

Chạy sau khi hoàn thành Phase 1–10. Tất cả phải pass trước khi bạn tin vào setup này.

> ### Kết quả chạy thật — 23/09/2026
>
> | Bước | Kết quả |
> |---|---|
> | `preflight` | ✅ `SẴN SÀNG (có cảnh báo)`, exit 0 — cảnh báo duy nhất là Docker Desktop chưa mở |
> | `sshd -T \| grep passwordauthentication` | ✅ `no` |
> | Đo từ Fedora: `PreferredAuthentications=none` | ✅ `Permission denied (publickey)` — trước harden là `publickey,password,keyboard-interactive` |
> | 1. `ssh mac-cmp` → tmux `desk` | ✅ vào thẳng session |
> | 7. `rsync … mac-cmp-file:~/` | ✅ file đi và về đúng |
> | 9. Từ Mac `ping tainjiao-dotdev` | ✅ **100% packet loss** · `nc -z … 22` đóng — shields-up hiệu lực |
> | Nguồn: `pmset -g` | ✅ `sleep 0` — giữ được **sau khi gỡ `caffeinate`**, nên máy ở lại tailnet nhờ cấu hình chứ không nhờ một tiến trình phải nhớ bật |
> | Auto-update macOS | ✅ `AutomaticallyInstallMacOSUpdates = 0` |
>
> **Chưa chạy:** bước 2–6 và 8 (cần thao tác tương tác), Phase 3 (iPhone, tuỳ chọn), Phase 5 (`.tmux.conf`), Phase 7, Phase 9.2–9.3, Phase 10.2 (lịch nhắc — node key còn 179 ngày).
>
> **Lưu ý bước 8** (`ssh-add -D && ssh mac-cmp` phải hỏi passphrase): trên máy này gnome-keyring đã lưu passphrase vào `login.keyring` nên nó có thể **không** hỏi. Đó không phải lỗi — xem [2.7](#27-passphrase-và-login-keyring).

**Trên Mac:**

```bash
preflight                                    # không có mục FAIL
sudo sshd -T | grep passwordauthentication   # phải ra: no
tailscale status                             # thấy mọi thiết bị
```

**Từ Fedora — đúng theo thứ tự:**

1. `ssh mac-cmp` → vào thẳng tmux session `desk`, không hỏi passphrase (agent đã nạp)
2. Tạo một thứ trong tmux: `htop` hoặc `tail -f` một file log
3. **Đóng cửa sổ terminal đột ngột** (giả lập rớt mạng) → `ssh mac-cmp` lại → thấy đúng màn hình cũ
4. **Ngắt mạng Fedora 30 giây rồi nối lại** → `ssh mac-cmp` → session vẫn còn
5. `sudo -v` trên Mac → gõ password → thành công
6. `cd ~/projects && git status` → chạy được (đổi sang thư mục code thật của bạn)
7. `rsync -av /tmp/test.txt mac-cmp-file:~/` → chuyển file được
8. `ssh-add -D && ssh mac-cmp` → **phải hỏi passphrase** (xác nhận key thật sự có passphrase)
9. **Trên Mac:** `ping tainjiao-dotdev` → phải FAIL. Kiểm thêm cổng cho chắc:
   ```bash
   # ── trên MAC ──
   nc -z -G 3 tainjiao-dotdev 22 && echo "MỞ — shields không hiệu lực" || echo "đóng — đúng"
   ```

Bước 3 và 4 chứng minh tmux thực sự làm được việc của nó. Bước 7 xác nhận entry `mac-cmp-file` hoạt động. Bước 9 xác nhận Phase 6.

**Trên Mac, khoá màn hình rồi SSH lại từ Fedora** → vẫn vào được, keychain vẫn mở. Đây là trạng thái vận hành hằng ngày.

---

## Checklist triển khai

```
[x]  0  Xác nhận IT/security; xác định tailnet cá nhân hay công ty
[ ]  0  Đọc Phụ lục D — đích thật là Mac hay là server?
[ ]  1  Mac: gỡ Tailscale App Store nếu có (xoá → Trash → reboot)
[x]  1  Mac: cài standalone, system extension, MagicDNS (tên máy: macos-comacpro)
[x]  1  Fedora: dnf5 addrepo → install → enable --now → tailscale up
[x]  1  Checkpoint: ping macos-comacpro từ Fedora
[x]  2  Mac: Remote Login (Only these users); test password từ Fedora
[x]  2  Fedora: ssh-keygen CÓ passphrase → ssh-copy-id → test
[x]  2  Fedora: ~/.ssh/config (2 entry: mac-cmp và mac-cmp-file)
[x]  2  Fedora: ssh-add -t 8h; kiểm key nào thật sự mở khoá bằng SSH_AUTH_SOCK=/run/user/1000/gcr/.ssh ssh-add -l
[x]  2  Fedora: KHÔNG bật ForwardAgent; dựng git identity riêng trên Mac nếu định commit ở đó
[ ]  3  (tuỳ chọn) iPhone: Tailscale, tắt sync Termius, key, host
[x]  4  grep Include → scp+install drop-in → sshd -T → kiểm từ Fedora → đóng tab
[x]  5  Mac: tmux + ~/.config/tmux/tmux.conf (mac/tmux.conf)
[x]  6  Fedora: tailscale set --shields-up
[ ]  7  git remote sang SSH; app GUI chạy sẵn
[x]  8  Cài preflight vào ~/bin (mặc định session đã là 'desk', không cần biến môi trường)
[x]  9  Fedora: xác nhận LUKS (nvme0n1p3 crypto_LUKS, cả / lẫn /home)
[ ]  9  Fedora: khoá màn hình ≤5 phút; đọc runbook mất thiết bị 9.3
[x] 10  Tắt auto-install macOS updates; nhắc lịch re-auth (ngày 150)
[ ]  ✓  Chạy Acceptance test đầy đủ
```

Thứ tự có chủ đích: **mạng → client → auth → harden → tự động hoá → bảo mật → mở quyền (nếu cần)**.
Dừng ở bất kỳ điểm nào thì cái đang chạy vẫn là cấu hình an toàn, không phải nửa vời có lỗ hổng.

---

## Troubleshooting

### Theo triệu chứng

| Triệu chứng | Nguyên nhân thường gặp | Xử lý |
|---|---|---|
| Fedora: `ping macos-comacpro` không ra | MagicDNS chưa bật, hoặc `tailscaled` chưa chạy | `sudo systemctl status tailscaled`; thử IP thô `100.x.y.z` để khoanh vùng |
| Fedora: sau reboot mất tailnet | Quên `systemctl enable` | `sudo systemctl enable --now tailscaled` |
| `ssh: Could not resolve hostname` | Như trên | `tailscale status` |
| `Connection refused` | sshd trên Mac không chạy | Phase 2.1; `nc -z localhost 22` trên Mac |
| `Connection timed out` | Mac đang ngủ, hoặc Tailscale down trên Mac | `preflight`; Phase 10 nếu vừa reboot |
| **`Permission denied (publickey)`** | Key chưa vào `authorized_keys`, quyền sai, `AllowUsers` sai tên, hoặc agent thử nhầm key trước | `tail -3 ~/.ssh/authorized_keys`; `ls -l ~/.ssh`; thêm `IdentitiesOnly yes` |
| Vẫn hỏi password sau Phase 4 | Drop-in bị ghi đè — `Include` nằm sau directive khác | Phase 4.1, xác minh bằng `sudo sshd -T` |
| Vào được nhưng ngắt sau vài phút | NAT timeout | Kiểm tra `ServerAliveInterval` trong `~/.ssh/config` |
| **`scp`/`rsync`/`sftp` treo hoặc lỗi lạ** | `RemoteCommand tmux` trên host đó | Dùng `mac-cmp-file` ([2.5](#25-sshconfig)) |
| Bị hỏi passphrase mỗi lần dù đã `ssh-add` | Terminal mới không thấy agent cũ, hoặc GNOME Keyring chiếm chỗ | `ssh-add -l`; `echo $SSH_AUTH_SOCK` |
| `ssh-add` báo `Could not open a connection to your authentication agent` | Chưa có agent trong shell đó | `eval "$(ssh-agent -s)"` rồi `ssh-add` lại |
| **Mất truy cập sau một đêm** | macOS auto-update → reboot → FileVault | Phase 10.1. Phải có người tại máy |
| **Mất truy cập sau vài tháng** | Node key hết hạn | Phase 10.2. Phải re-auth tại máy |
| `docker ps`: cannot connect | Docker Desktop chưa chạy | Mở trước khi rời bàn; `preflight` cảnh báo |
| `git push` hỏi password hoặc fail | Keychain khoá (đã logout) hoặc remote còn HTTPS | Phase 7; `git remote set-url` sang SSH |
| `ls ~/Documents`: Operation not permitted | TCC | [Phụ lục A](#phụ-lục-a--full-disk-access) — chỉ bật nếu thật cần |
| `osascript` fail | Quyền Automation không cấp được cho SSH | Không có workaround CLI; [Phụ lục C](#phụ-lục-c--screen-sharing) |
| Prompt toàn ô vuông | Terminal Fedora thiếu Nerd Font | `sudo dnf install <nerd-font>` hoặc đổi prompt |
| mosh: `Did not find mosh server startup message` | `/usr/local/bin` không có trong PATH của SSH | [Phụ lục B.1](#phụ-lục-b--mosh) |
| mosh im lặng sau `brew upgrade` | Firewall exception trỏ đường dẫn Cellar cũ | [Phụ lục B.2](#phụ-lục-b--mosh) |

### Khoanh vùng nhanh

```bash
# Lỗi ở tầng nào?
#   ping macos-comacpro fail    → mạng/Tailscale
#   "Could not resolve"         → MagicDNS
#   "Connection refused"        → mạng ok, sshd không chạy
#   "Connection timed out"      → Mac ngủ hoặc Tailscale down phía Mac
#   "Permission denied"         → mạng + sshd ok, vấn đề ở key

# Từ Fedora — xem ssh đang làm gì:
ssh -vvv mac-cmp 2>&1 | grep -E 'Offering|Authentications|debug1: Next'

# Trên Mac — xem sshd thực sự từ chối vì gì:
log stream --predicate 'process == "sshd"' --info
```

`ssh -vvv` phía client và `log stream` phía server là hai công cụ mạnh nhất để debug auth. Chúng cho biết **thực sự** chuyện gì xảy ra thay vì để bạn đoán.

---

# PHỤ LỤC

Mỗi phụ lục thêm một thứ vào đường chính. **Chỉ làm khi có lý do cụ thể, không làm trước.**

## Phụ lục A — Full Disk Access

> **Điều kiện kích hoạt:** bạn thực sự gặp `Operation not permitted` ở một đường dẫn bạn thật sự cần.

TCC chỉ bảo vệ `~/Desktop`, `~/Documents`, `~/Downloads`, iCloud Drive và data của app. `~/projects`, `~/work`, `~/code`, `/usr/local` — **không bị chặn**. Phần lớn công việc dev không cần quyền này.

Kiểm tra trước khi quyết định:

```bash
ls ~/Documents >/dev/null 2>&1 && echo "không cần FDA" || echo "TCC đang chặn ~/Documents"
ls ~/projects  >/dev/null 2>&1 && echo "thư mục code: ok"
```

Thư mục code chạy được thì **dừng ở đây**.

Nếu thật sự cần: System Settings → General → Sharing → **(i)** cạnh Remote Login → bật **"Allow full disk access for remote users"**.

> Nó nằm **ở đây**, không phải Privacy & Security → Full Disk Access. Thêm `sshd` vào danh sách kia **không có tác dụng**. Đây là chỗ nhiều người mất cả buổi.

**Cái giá:** mọi session SSH đọc được toàn bộ đĩa — gồm cả Mail, Messages, browser data, Photos. Trên máy công ty đây là một quyền rất lớn, và nó áp cho *mọi* kết nối SSH chứ không riêng của bạn.

## Phụ lục B — mosh

> **Điều kiện kích hoạt:** mạng của bạn tệ thật và độ trễ gõ phiền. Với Fedora nối mạng dây hoặc WiFi ổn định thì gần như chắc chắn **không cần**.

| | SSH + tmux | + mosh |
|---|---|---|
| Mất mạng | Reconnect vài giây, `tmux attach` khôi phục nguyên trạng | Liền mạch |
| Gõ khi mạng lag | Có độ trễ | Local echo, mượt |
| Port forwarding / SFTP | ✅ | ❌ |
| Nợ vận hành | Không | **Hỏng lại sau mỗi `brew upgrade mosh`** |

Client trên Fedora dễ: `sudo dnf install mosh`. Vấn đề nằm hoàn toàn ở phía macOS.

### B.1 Phía Mac: cài và sửa PATH

```bash
brew install mosh
```

Session SSH **không tương tác** trên macOS nhận `PATH=/usr/bin:/bin:/usr/sbin:/sbin` — **không có `/usr/local/bin`**, dù `/etc/paths` có. mosh sẽ fail với `Did not find mosh server startup message`.

```bash
ssh localhost 'echo $PATH; which mosh-server'        # kiểm chứng trước

printf '\nexport PATH="/usr/local/bin:$PATH"\n' >> ~/.zshenv
ssh localhost 'which mosh-server'                    # giờ phải ra đường dẫn
```

zsh đọc `.zshenv` cho **mọi** invocation, kể cả không tương tác — đó là lý do dùng file này chứ không phải `.zshrc`.

Dự phòng từ Fedora: `mosh --server=/usr/local/bin/mosh-server mac-cmp`.

### B.2 Phía Mac: Application Firewall

```bash
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

Đang bật (máy công ty có MDM thì gần như chắc chắn) → phải cho phép **binary thật, không phải symlink**:

```bash
REAL=$(readlink -f "$(which mosh-server)")
echo "$REAL"        # /usr/local/Cellar/mosh/<version>/bin/mosh-server
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "$REAL"
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$REAL"
```

> **Nợ vận hành:** đường dẫn Cellar chứa số version. Mỗi `brew upgrade mosh` là phải chạy lại hai lệnh trên, và triệu chứng lúc đó là **mosh im lặng không kết nối được từ xa** — đúng lúc bạn không ngồi trước máy để sửa. Đây là lý do mosh không nằm trong đường chính.

### B.3 Port cho mosh

Với `--shields-up` ([Phase 6](#phase-6--một-chiều)) không cần mở port gì — shields chặn chiều vào máy này, còn mosh đi chiều ra tới Mac. Nếu bạn dùng ACL thay vì shields, thêm `"mac-cmp:60000-61000"` vào `dst`.

Quên bước này → mosh chết trong khi SSH vẫn chạy, và bạn sẽ đi tìm nguyên nhân ở nhầm chỗ.

### B.4 Dùng từ Fedora

```bash
mosh mac-cmp -- tmux new -A -s desk
```

`~/.ssh/config` vẫn được mosh đọc cho phần SSH bootstrap, nên `User` và `IdentityFile` tự áp dụng.

**Giữ `ssh mac-cmp` làm mặc định** — mosh không có port forwarding và không có SFTP.

## Phụ lục C — Screen Sharing

> **Điều kiện kích hoạt:** buộc phải bấm GUI, và macOS đã vá đầy đủ.

> ⚠️ Tháng 8/2026 có hai lỗ hổng nghiêm trọng trong phần Apple bổ sung vào VNC, **đang bị khai thác ngoài thực địa**. Khuyến cáo hiện hành: hệ thống có screen sharing phơi ra ngoài nên được coi là đã bị xâm nhập.

### C.1 Cấu hình một lần, tại bàn

System Settings → General → Sharing → Screen Sharing → **(i)**:

- "Allow access for" → **Only these users** → chỉ user của bạn
- **KHÔNG đặt VNC password.** Đó là đường auth yếu — client chỉ bị hỏi password, không hỏi username — và chính nó góp phần vào lỗ hổng vừa rồi. Dùng xác thực bằng tài khoản macOS.

Cấu hình xong thì **tắt Screen Sharing đi**. Với `--shields-up` không cần khai báo thêm gì; nếu dùng ACL thì thêm `"mac-cmp:5900"` vào `dst`.

### C.2 Bật/tắt từ xa qua SSH

```bash
# Bật
sudo launchctl enable system/com.apple.screensharing
sudo launchctl kickstart -k system/com.apple.screensharing
sudo lsof -iTCP:5900 -sTCP:LISTEN          # xác nhận đang nghe

# Tắt — chạy ngay khi xong việc
sudo launchctl disable system/com.apple.screensharing
sudo launchctl kill SIGTERM system/com.apple.screensharing
```

`preflight` cảnh báo nếu bạn quên tắt.

### C.3 Client

**Fedora:** Remmina (`sudo dnf install remmina remmina-plugins-vnc`) hoặc `vinagre`. Kết nối `macos-comacpro:5900`, đăng nhập bằng tài khoản macOS. (Remmina không đọc `~/.ssh/config`, phải dùng tên máy thật.)

**iPhone:** Screens hoặc Jump Desktop. Nói thẳng — VNC trên màn hình điện thoại không dùng được thật sự; trên Fedora với màn hình lớn thì bình thường.

## Phụ lục D — Nếu đích thật là server

Đọc mục này nếu 90% việc bạn làm từ xa là: xem build/deploy xong chưa, restart service, đọc log production, chạy migration.

Trong trường hợp đó **Mac là một hop thừa và mong manh**. Cài Tailscale lên chính các server và SSH thẳng từ Fedora.

| | Qua Mac | Thẳng tới server |
|---|---|---|
| Chống ngủ | Bắt buộc | Không cần |
| FileVault pre-boot | Chết sau mọi reboot | Không tồn tại |
| TCC / keychain / GUI session | Phải xử lý hết | Không tồn tại |
| macOS auto-update reboot | Bom hẹn giờ | Không liên quan |
| Điểm hỏng | Mac **và** server | Chỉ server |
| **Phải mở Remote Login trên máy công ty** | **Có** | **Không** |

Dòng cuối là quan trọng nhất: bạn tránh được toàn bộ cuộc trao đổi với IT, và máy công ty không cần thay đổi gì.

```bash
# Trên từng server:
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh          # Tailscale SSH CHẠY ĐƯỢC trên Linux
sudo dnf install tmux            # hoặc apt, tuỳ distro
```

Trong admin console: gắn tag cho các server — **server đúng là thiết bị không người dùng, tag dùng đúng chỗ ở đây**, khác hẳn trường hợp máy cá nhân ở Phase 6. ACL cho phép `autogroup:member` → `tag:server:22`.

Hai kiến trúc không loại trừ nhau; nhiều người cần cả hai. Nhưng nếu chỉ làm một, **hãy làm cái này trước** — nó rẻ hơn, bền hơn, và không cần xin phép ai.

---

## Những gì chưa xác minh được

Nêu ra để bạn không tin nhầm. Mỗi dòng kèm cách tự kiểm tra.

| Điểm | Cách tự kiểm tra |
|---|---|
| ~~`Include` có trong `sshd_config` của macOS 15 không~~ — **đã xác minh 23/09/2026: có, dòng 18**, không directive nào đứng trước | Đã ghi vào [4.1](#41-xác-định-nơi-ghi-config) |
| Nhãn menu trong System Settings có thể khác giữa các bản 15.x | Nhìn màn hình |
| Nhãn `launchctl` cho screensharing (Phụ lục C.2) | `sudo lsof -iTCP:5900 -sTCP:LISTEN` sau khi chạy |
| ~~Taildrop có bị ACL Phase 6 chặn không~~ — **đã biết:** `--shields-up` chặn chiều *nhận*, xem [6.4](#64-đánh-đổi) | `tailscale file cp` tới máy này sau khi bật shields |
| Trường `Self.KeyExpiry` trong `tailscale status --json` (preflight dùng) | `tailscale status --json \| grep -i expiry`. Sai tên → check hiện "skip", không phá script |
| ~~Hành vi của GNOME Keyring với `ssh-add -t` trên Fedora 44~~ — **đã xác minh 22/09/2026: tôn trọng `-t`** | Bài test 70 giây ở [2.6](#26-ssh-agent). Chạy lại nếu đổi máy hoặc đổi bản phân phối |
| ~~GNOME Keyring có **tự nạp** key lúc đăng nhập hay không~~ — **đã xác minh 22/09/2026: không.** gcr chỉ *quảng bá* key từ đĩa, không mở khoá | So `ssh-add -l` với `SSH_AUTH_SOCK=/run/user/1000/gcr/.ssh ssh-add -l` — xem [2.6](#26-ssh-agent) |
| Termius mobile dùng implementation mosh riêng, không phải mosh gốc | Interop lỗi → thử Blink Shell |

---

## Nhật ký thay đổi

### v5.7 — chốt quyết định sleep, kèm số đo

Phase 10.3 trước đây đưa ba hướng và để người đọc tự chọn. Giờ đã chạy thật nên chốt được, và ghi lại **số đo** thay vì lập luận — sáu tháng nữa đọc lại, con số trả lời nhanh hơn.

**Chốt `sleep 0`, không xây WoL.** Lý do đo được, không suy đoán:

| | |
|---|---|
| `en0` Ethernet | inactive — Mac chạy Wi-Fi |
| WoL qua Wi-Fi trên macOS | cần Bonjour Sleep Proxy; quét không thấy |
| Private Wi-Fi Address | MAC đang dùng khác MAC phần cứng, có thể xoay |
| Magic packet | layer 2, không qua router — chỉ gửi được khi cùng LAN |
| `powernap` + `tcpkeepalive` | máy tỉnh định kỳ → **khả dụng ngắt quãng**, tệ hơn tắt hẳn |

**Thêm khuyến nghị cắm Ethernet**, với số đo làm bằng chứng:

```
Fedora → gateway   avg   8ms · max  25ms · jitter  5ms
Fedora → Mac       avg  78ms · max 230ms · jitter 62ms
```

Cùng card Wi-Fi, cùng lúc, cùng LAN. Chênh lệch nằm ở phía Mac — Wi-Fi power management. Jitter 62ms là thứ bạn cảm thấy ở mỗi phím gõ trong tmux.

**Nêu rõ điểm yếu còn lại là reboot, không phải sleep:** FileVault pre-boot, không có đường phục hồi từ xa.

---

### v5.6 — Phase 5 có config thật

Phase 5 trước đây là ba dòng `set -g`. Đủ để chạy, nhưng bỏ qua điều quan trọng nhất khi bạn dùng hai máy: **phản xạ phím phải giống nhau**.

Viết `mac/tmux.conf` port từ bản Fedora, với ba chỗ không port được ghi rõ lý do — `wl-copy` → `pbcopy`, bỏ popup gọi hàm zsh cục bộ, và cảnh báo về `C-s` với flow control.

Ba điều đo được, không đoán:

- `pbcopy` chạy thẳng trên macOS 15.7.9 + tmux 3.7c, **không cần** `reattach-to-user-namespace` — trình bao bọc đó chỉ cần cho macOS 10.x.
- Hai máy cùng tmux **3.7c** nên không có chênh lệch tính năng.
- Prefix `C-s` hoạt động vì tmux đọc terminal ở chế độ raw; chỉ literal `C-s` gửi xuống shell mới đứng pane, và zsh của Mac chưa tắt XON/XOFF.

Thêm bước xác minh bằng `show-options`/`list-keys` — đọc giá trị đã nạp thay vì tin nội dung tệp.

---

### v5.5 — đọc soát toàn văn: 4 mâu thuẫn, thêm mục trạng thái

Tài liệu đã qua 14 bản vá trong hai ngày. Đọc soát một lượt như người lần đầu đọc, tìm chỗ thân bài nói một đằng changelog nói một nẻo.

| Chỗ | Vấn đề |
|---|---|
| **Tham khảo nhanh** | Vẫn dạy `launchctl kickstart` sau rollback — §4.3 đã bỏ bước đó. Và lệnh thu hồi key ở đây vẫn là bản cũ dùng `<comment-key>`, **thiếu bước `grep` xem trước** mà v4.6 thêm vào §9.3 |
| Bảng quyết định (mục 1) | Dòng ACL vẫn trình bày ACL như phương pháp mặc định |
| Phụ lục B.3 | Tiêu đề còn là *"Mở port trong ACL"* dù thân bài đã nói shields-up không cần mở port |
| Chân trang | Ghi "tính đến 22/09/2026" |

Chỗ đầu nghiêm trọng nhất: **Tham khảo nhanh là thứ người ta copy khi đang hoảng**, và nó đang giữ bản thu hồi key thiếu lưới an toàn.

**Thêm mục "Đang ở đâu"** ngay đầu tài liệu — bảng trạng thái từng phase kèm bằng chứng, để quay lại sau vài tháng không phải đọc lại 1900 dòng.

**Gộp v4.1–v4.9** thành một bảng tóm tắt. Lý do của từng thay đổi đã nằm trong thân bài rồi, nên changelog chỉ cần giữ dấu vết: 296 → 181 dòng (14% → 9% tài liệu).

---

### v5.4 — acceptance test có kết quả thật

Ghi kết quả đo được vào đầu mục Acceptance test, thay vì để nó là danh sách việc phải làm. Tám mục đã chạy và pass; những mục chưa chạy được liệt kê thẳng thay vì im lặng.

Đáng chú ý nhất là **bước 9** — lần đầu có bằng chứng `--shields-up` thật sự chặn chiều Mac → Fedora:

```
ping tainjiao-dotdev   → 100.0% packet loss
nc -z … 22             → đóng
```

Và **`sleep 0` giữ được sau khi gỡ `caffeinate`**: máy ở lại tailnet nhờ cấu hình nguồn chứ không nhờ một tiến trình phải nhớ bật. `preflight --arm` từ bắt buộc xuống tuỳ chọn.

Thêm cảnh báo cho bước 8: gnome-keyring lưu passphrase trong `login.keyring` nên `ssh-add -D` rồi kết nối có thể **không** hỏi passphrase — đúng như [2.7](#27-passphrase-và-login-keyring) mô tả, không phải lỗi.

Bước 9 thêm lệnh `nc -z` bên cạnh `ping`, vì ICMP và TCP có thể bị lọc khác nhau.

---

### v5.3 — Phase 4 chạy thật: bỏ một bước thừa, sửa một lời giải thích sai

Harden sshd trên `macos-comacpro` ngày 23/09/2026. Kết quả đo từ bên ngoài:

```
trước:  Permission denied (publickey,password,keyboard-interactive)
sau:    Permission denied (publickey)
```

| | v5.2 | v5.3 |
|---|---|---|
| §4.1 `Include` | "chưa xác minh" | **Dòng 18**, không directive nào đứng trước → nhánh 4.2a. Kèm nội dung `100-macos.conf` có sẵn |
| §4.2a ghi file | `sudo tee` heredoc trên Mac | Soạn trên Fedora → `scp` → `sudo install -o root -g wheel -m 644` |
| §4.3 restart | `sudo launchctl kickstart -k` | **Bỏ** — không cần trên macOS |
| §4.4 xác minh | chỉ `sshd -T` | Thêm kiểm từ Fedora bằng `PreferredAuthentications=none` |
| Cảnh báo đường lui | "chỉ listener khởi động lại" | Sai cơ chế — sửa lại |

**Vì sao không cần restart.** Job `com.openssh.sshd` là socket-activated: `state = not running`, `active count = 0`, `properties = inetd-compatible | abandon process group`. launchd giữ socket port 22 và sinh một `sshd-session` mới cho mỗi kết nối, tiến trình đó đọc cấu hình từ đầu. Không có listener nào tồn tại để khởi động lại.

**Vì sao đường lui vẫn vững.** `abandon process group` — launchd cố ý không quản tiến trình con đã sinh. Cây tiến trình xác nhận: phiên đang mở có cha là PID 1, không phải một sshd mẹ. Kết luận của tài liệu cũ đúng, lý do thì sai.

**`UsePAM yes` trong `100-macos.conf`** là lý do `KbdInteractiveAuthentication no` bắt buộc chứ không tuỳ chọn — PAM mở keyboard-interactive như đường riêng mà `PasswordAuthentication no` không đóng. Sau khi áp, `keyboard-interactive` biến mất khỏi danh sách server chào, chứng minh dòng đó có tác dụng thật.

**`install` thay `cp`:** sshd từ chối đọc file cấu hình mà user thường ghi được, nên owner/mode phải khai tường minh.

---

### v5.2 — preflight chạy thật trên macOS, lộ 3 lỗi

Deploy lên `macos-comacpro` (macOS 15.7.9) ngày 23/09/2026 và chạy lần đầu. Bản vá PATH ở v4.9 hiệu quả — `tailscale`, `tmux`, `docker` đều nhận diện được qua SSH. Nhưng chạy thật lộ ba thứ không thể phát hiện từ Fedora:

| # | Lỗi | Đo được |
|---|---|---|
| 1 | **Check đĩa đọc nhầm volume** | Trên macOS `/` là snapshot hệ thống chỉ đọc, báo **28%**; volume dữ liệu `/System/Volumes/Data` thật ra **87%**. Free space chung nên số Avail đúng, nhưng **phần trăm** — thứ kích hoạt FAIL — thì vô nghĩa. Check coi như chết trên macOS |
| 2 | **Check keychain luôn cảnh báo** | Qua SSH, `security show-keychain-info` **luôn** trả exit 36 "User interaction is not allowed", khoá hay không cũng vậy. Cả bản `grep -qi lock` lẫn bản exit-code đều sai. Trạng thái khoá đơn giản là không quan sát được từ phiên không có GUI |
| 3 | **`sleep` quá ngắn chỉ là `warn`** | Máy đặt sleep **1 phút**. Mức đó thì đi khỏi bàn là mất máy — đáng FAIL chứ không phải cảnh báo |

Sửa: đĩa đọc `/System/Volumes/Data` (fallback `/`), keychain đổi sang `skip` kèm lý do thật — mục GUI session ở trên vốn đã bắt được đúng tình huống nó định phát hiện, và `sleep ≤ 5` phút thành FAIL.

**Hai FAIL thật trên máy đó**, không phải lỗi script:

- `sleep 1` — nguyên nhân gốc của toàn bộ chuyện Mac "offline" suốt buổi. `womp 1` (Wake on LAN) có bật, nhưng WoL cần magic packet trong cùng LAN, Tailscale qua relay không đánh thức được.
- macOS tự cài update → reboot → FileVault pre-boot → mất máy cho tới khi có người gõ mật khẩu. Đúng bom hẹn giờ [10.1](#101-macos-tự-update-rồi-reboot).

---

### v5.1 — sửa lệnh shields-up, và đưa kết quả rà hệ thống vào Phase 9

**Hai lỗi trong §6.1 của v5.0, cả hai đều gây hậu quả thật:**

| | v5.0 | v5.1 |
|---|---|---|
| Máy nào chạy | "máy này" — mơ hồ, runbook nói về **hai** máy | Ghi rõ **TRÊN FEDORA**, kèm bảng hậu quả nếu chạy nhầm |
| Lệnh | `tailscale up --shields-up` | `tailscale set --shields-up` |

Chạy trên Mac là chặn chiều Fedora → Mac, tức **mất luôn `ssh mac-cmp`** và phải ngồi trước máy Mac để gỡ — đúng tình huống setup này sinh ra để tránh.

`up` gửi lại **toàn bộ** bộ preference; thứ không ghi ra có thể bị đặt lại về mặc định. Help của chính Tailscale nói `set` mới là lệnh đổi từng preference. Có từ 1.36.

**Phase 9.1 mở rộng** với kết quả rà hệ thống Fedora — trước đây những phát hiện này không có chỗ nào để lưu và sẽ mất khi cài lại máy:

- Cổng do Docker publish: firewalld **và** shields-up đều không chặn được
- `tailscale0` không thuộc zone firewalld nào — mọi service nghe `0.0.0.0` đều mở với tailnet cho tới khi bật shields
- 8 dịch vụ mặc định không cần trên máy trạm, kèm **cách tự kiểm chứng** từng cái thay vì tin danh sách
- `passim` phải `mask` (unit `static`), và không được gỡ gói vì `fwupd` liên kết `libpassim.so.1`
- Nhóm `docker` ≈ root không mật khẩu
- Trần journal (mặc định 10% đĩa)

**Một link nội bộ gãy** đã sửa: `#khi-mất-thiết-bị` → `#93-runbook-mất-một-thiết-bị`. Toàn bộ 33 link nội bộ giờ đều trỏ đúng.

---

### v5.0 — Phase 6 đổi từ ACL sang `--shields-up`, và lỗ Docker

**Phase 6 viết lại.** Bản cũ dựng một tệp ACL trong admin console. Nó chạy được, nhưng với tailnet cá nhân hai node thì sai công cụ: một lệnh cục bộ làm đúng việc đó, không có rủi ro tự khoá mình, và không phải sửa lại mỗi lần thêm port (mosh, VNC).

```bash
# trên Fedora — KHÔNG phải trên Mac
sudo tailscale set --shields-up
```

Cú pháp ACL giữ lại trong §6.2 cho trường hợp tailnet có node của người khác — lúc đó shields không đủ vì nó là thiết lập cục bộ, người dùng thiết bị tắt được.

**Lỗ Docker — mục mới ở §6.3.** Kiểm 6 tệp compose trong `~/Workspace`: không tệp nào chỉ định IP host.

```yaml
- "5530:5432"      # Postgres  → 0.0.0.0:5530
- "27018:27017"    # MongoDB   → 0.0.0.0:27018
- "3307:3306"      # MySQL     → 0.0.0.0:3307
```

Docker ghi thẳng netfilter nên firewalld không chặn, và `--shields-up` cũng không: shields lọc ở chain `INPUT` còn cổng Docker đi qua DNAT rồi `FORWARD`. Cả ACL lẫn shields đều vô hiệu ở đây. Cách sửa duy nhất là ghi rõ `127.0.0.1:` trong compose.

**Hệ quả với phần trước:** zone `FedoraWorkstation` chỉ mở `53317/tcp+udp` (LocalSend), nên các service nghe trên `0.0.0.0` vốn **đã** bị chặn ở wifi từ trước. Đường vào thật sự là `tailscale0` — interface không thuộc zone firewalld nào, và `ShieldsUp` khi đó là `False`. Đó mới là lý do đúng để bật shields, không phải "wifi quán cà phê".

Sửa theo các tham chiếu chết: Phụ lục B.3 (mosh), C (Screen Sharing), checklist, bảng quyết định tailnet ở mục 1.

---

### v4.1 – v4.9 — tóm tắt

Chín bản vá trong ngày 22/09/2026, khi đối chiếu guide với máy thật lần đầu. Lý do của từng thay đổi đã được đưa vào đúng mục trong thân tài liệu, nên ở đây chỉ giữ dấu vết.

| | Thay đổi | Đã ghi ở |
|---|---|---|
| **v4.1** | Tên máy giả định → tên thật (`macos-comacpro`); FQDN Tailscale cho `HostName`; LUKS và `ssh-add -t` chuyển từ "cần kiểm tra" sang đã xác minh | [1.4](#14-admin-console--logintailscalecom) · [2.5](#25-sshconfig) · [9.1](#91-fedora) |
| **v4.2** | Đặt lại tên: `id_ed25519_macwork` → `id_ed25519_macos-comacpro`, alias `mac-work` → `mac-cmp`. Tên tệp theo **máy đích**, alias theo quy ước `<thiết bị>-<tổ chức>` sẵn có | [2.3](#23-tạo-key-trên-fedora) |
| **v4.3** | `ssh-add -l` gộp hai socket: gcr quảng bá mọi `~/.ssh/*.pub` từ đĩa, kể cả key chưa mở khoá | [2.6](#26-ssh-agent) |
| **v4.4** | `RemoteCommand` cần đường dẫn tuyệt đối — phiên không tương tác không có `/usr/local/bin` trong `PATH` | [2.5](#25-sshconfig) |
| **v4.5** | Mục *Danh tính Git* viết lại: Mac không phải tờ giấy trắng, nó là máy một danh tính đã cấu hình sẵn | [Phase 7](#phase-7--chuẩn-bị-môi-trường) |
| **v4.6** | **Lỗi nghiêm trọng:** lệnh thu hồi key dùng sai chuỗi `grep -v`, nên nó ghi lại file y nguyên và không xoá gì. Thêm bước xem trước | [9.3](#93-runbook-mất-một-thiết-bị) |
| **v4.7** | `ConnectTimeout 10` — thiếu nó, `ssh` tới Mac đang ngủ treo 130 giây. `ServerAlive*` không che được giai đoạn bắt tay | [2.5](#25-sshconfig) |
| **v4.8** | Phase 8 không chạy được như viết: `PATH` phải đặt ở `.zshenv` chứ không `.zshrc`, alias phải dùng đường dẫn tuyệt đối | [8.1](#81-cài) · [8.3](#83-chạy-từ-fedora-bằng-một-lệnh) |
| **v4.9** | preflight sửa 6 lỗi, quan trọng nhất là script tự đặt `PATH` — thiếu nó thì `macstatus` báo CHƯA SẴN SÀNG trên máy khoẻ mạnh | [8.1](#81-cài) |

Điểm chung của gần như toàn bộ danh sách: **mọi lỗi đều im lặng.** Không cái nào báo lỗi rõ ràng — chúng chỉ làm sai một cách êm ả cho tới khi ai đó đo.

---

## Tham khảo nhanh

```bash
# ── Trên Mac, trước khi rời công ty ──────────────────────
preflight --arm

# ── Từ Fedora, hằng ngày ─────────────────────────────────
ssh mac-cmp                      # vào thẳng tmux 'desk'
ssh mac-cmp-file                 # shell sạch, cho scp/rsync/preflight
rsync -av ./file mac-cmp-file:~/dest/
alias macstatus='ssh mac-cmp-file preflight'

# ── ssh-agent ────────────────────────────────────────────
ssh-add -t 8h ~/.ssh/id_ed25519_macos-comacpro
ssh-add -l                        # xem key đang nạp
ssh-add -D                        # xoá hết khỏi agent

# ── Chẩn đoán ────────────────────────────────────────────
tailscale status
ssh -vvv mac-cmp                                       # phía client
log stream --predicate 'process == "sshd"' --info       # phía Mac
sudo sshd -T | grep -E '^(passwordauthentication|allowusers)'

# ── Khôi phục sshd (chạy TẠI Mac) ────────────────────────
sudo rm /etc/ssh/sshd_config.d/100-local.conf
# Không cần restart: sshd là socket-activated, kết nối kế tiếp đọc lại config

# ── Mất thiết bị (theo thứ tự — xem 9.3) ─────────────────
# 1. Admin console → Machines → xoá thiết bị   ← cắt mạng, làm TRƯỚC
# 2. Trên Mac, XEM TRƯỚC rồi mới xoá:
#      grep 'tainjiao-dotdev' ~/.ssh/authorized_keys
#      grep -v 'tainjiao-dotdev' ~/.ssh/authorized_keys > /tmp/ak && mv /tmp/ak ~/.ssh/authorized_keys
#      chmod 600 ~/.ssh/authorized_keys && wc -l ~/.ssh/authorized_keys   # giảm đúng 1 dòng
#    Chuỗi sai → grep -v khớp MỌI dòng → ghi lại y nguyên, không xoá gì
# 3. Xoá từ xa thiết bị
# 4. Đổi password macOS
```

---

*Guide này mô tả trạng thái công cụ tính đến 23/09/2026, và đã được chạy thật đầu-cuối trên `tainjiao-dotdev` ↔ `macos-comacpro` — xem [Acceptance test](#acceptance-test). Phần "Những gì chưa xác minh được" liệt kê các điểm còn phải tự kiểm tra trên máy bạn.*
