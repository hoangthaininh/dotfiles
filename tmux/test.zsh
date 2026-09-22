#!/usr/bin/env zsh
# Bộ test cho tmux setup. Chạy: zsh -i tmux-test.zsh
emulate -L zsh
setopt local_options

typeset -g PASS=0 FAIL=0
typeset -ga FAILED

ok()   { print "  \e[32m✓\e[0m $1"; (( ++PASS )); return 0 }
no()   { print "  \e[31m✗\e[0m $1"; print "      → $2"; (( ++FAIL )); FAILED+=("$1"); return 0 }
chk()  { [[ "$2" == "$3" ]] && ok "$1" || no "$1" "mong: '$3'  nhận: '$2'" }
has()  { [[ "$2" == *"$3"* ]] && ok "$1" || no "$1" "không thấy '$3' trong: '$2'" }
sec()  { print "\n\e[1m── $1 ──\e[0m" }

SP=${0:A:h}
clean() { tmux kill-server 2>/dev/null; rm -rf $SP/tw; }
clean
mkdir -p $SP/tw/{alpha,beta,gamma}/web $SP/tw/solo
for d in $SP/tw/{alpha,beta,gamma}/web $SP/tw/solo; do git -C $d init -q .; done

# ═══ 1. CONFIG ═══
sec "1. Config nạp được"
out=$(tmux -f ~/.config/tmux/tmux.conf new-session -d -s _t 2>&1)
chk "tmux.conf nạp không lỗi" "$out" ""
chk "prefix = C-s" "$(tmux show-option -gv prefix)" "C-s"
chk "base-index = 1" "$(tmux show-option -gv base-index)" "1"
chk "mouse bật" "$(tmux show-option -gv mouse)" "on"
chk "detach-on-destroy tắt" "$(tmux show-option -gv detach-on-destroy)" "off"
chk "escape-time = 10" "$(tmux show-option -sgv escape-time)" "10"
chk "history-limit = 50000" "$(tmux show-option -gv history-limit)" "50000"
n=$(tmux list-keys 2>/dev/null | grep -cE 'display-popup')
[[ $n -ge 3 ]] && ok "3 popup binding (G, S, Enter)" || no "popup binding" "chỉ có $n"
has "không có hook auto-save" "$(tmux show-hooks -g 2>/dev/null | grep -c layout-save)" "0"
tmux kill-server 2>/dev/null

# ═══ 2. TP: TẠO SESSION ═══
sec "2. tp tạo session"
tp $SP/tw/solo >/dev/null 2>&1
chk "session tên theo basename" "$(tmux ls -F '#{session_name}')" "solo"
chk "có đúng 2 window" "$(tmux list-windows -t '=solo' -F x | wc -l)" "2"
chk "window 1 = dev" "$(tmux display-message -p -t '=solo:1' '#{window_name}')" "dev"
chk "window 2 = git" "$(tmux display-message -p -t '=solo:2' '#{window_name}')" "git"
chk "active = git" "$(tmux list-windows -t '=solo' -F '#{?window_active,#{window_name},}' | tr -d '\n')" "git"
chk "@tp_dir đúng" "$(tmux show-option -qv -t solo @tp_dir)" "$SP/tw/solo"
chk "pane ở đúng thư mục" "$(tmux display-message -p -t '=solo:git' '#{pane_current_path}')" "$SP/tw/solo"

# ═══ 3. TP: IDEMPOTENT ═══
sec "3. tp gọi lại không tạo trùng"
tp $SP/tw/solo >/dev/null 2>&1
chk "vẫn đúng 1 session" "$(tmux ls -F x | wc -l)" "1"
tp solo >/dev/null 2>&1
chk "gọi bằng TÊN cũng không tạo thêm" "$(tmux ls -F x | wc -l)" "1"

# ═══ 4. TP: TRÙNG TÊN ═══
sec "4. Chống trùng tên"
tp $SP/tw/alpha/web >/dev/null 2>&1
tp $SP/tw/beta/web  >/dev/null 2>&1
chk "repo 1 → 'web'" "$(tmux show-option -qv -t web @tp_dir)" "$SP/tw/alpha/web"
chk "repo 2 → 'beta_web'" "$(tmux show-option -qv -t beta_web @tp_dir)" "$SP/tw/beta/web"
tp $SP/tw/gamma/web >/dev/null 2>&1
chk "repo 3 → 'gamma_web'" "$(tmux show-option -qv -t gamma_web @tp_dir)" "$SP/tw/gamma/web"

# ═══ 5. TP: LỖI ═══
sec "5. tp báo lỗi rõ ràng"
err=$(tp /khong/ton/tai 2>&1)
has "target không tồn tại" "$err" "no live session and no directory"

# ═══ 6. ALIAS ═══
sec "6. Alias"
out=$(tl 2>&1)
has "tl có ký hiệu ○/●" "$out" "○"
has "tl hiện số window" "$out" "2w"
has "tl rút gọn \$HOME" "$(cd ~ && tp ~/Workspace/personal/dotfiles >/dev/null 2>&1; tl 2>&1)" "~/Workspace"
chk "tk là alias (không phải hàm)" "$(whence -w tk)" "tk: alias"
chk "ta là alias" "$(whence -w ta)" "ta: alias"
chk "tp là hàm" "$(whence -w tp)" "tp: function"

# ═══ 7. TẤT ĐỊNH ═══
sec "7. Tất định qua reboot"
B=$(tmux list-windows -t '=solo' -F '#{window_index}|#{window_name}|#{window_panes}|#{window_layout}')
tmux kill-server 2>/dev/null; sleep 0.2
tp $SP/tw/solo >/dev/null 2>&1
A=$(tmux list-windows -t '=solo' -F '#{window_index}|#{window_name}|#{window_panes}|#{window_layout}')
chk "layout giống hệt sau kill-server" "$A" "$B"

# ═══ 8. SPLIT KẾ THỪA CWD ═══
sec "8. Split kế thừa thư mục"
tmux send-keys -t '=solo:git' "cd $SP/tw" C-m
for _ in {1..20}; do
  [[ "$(tmux display-message -p -t '=solo:git' '#{pane_current_path}')" == "$SP/tw" ]] && break
  sleep 0.1
done
tmux split-window -t '=solo:git' -c "#{pane_current_path}"; sleep 0.3
chk "pane mới kế thừa cwd" "$(tmux display-message -p -t '=solo:git.2' '#{pane_current_path}')" "$SP/tw"

# ═══ 9. EDITOR ═══
sec "9. Bug EDITOR đã sửa"
ED=$(env -i HOME=$HOME USER=$USER TERM=xterm /usr/bin/zsh -lic 'print -r -- $EDITOR' 2>/dev/null | tr -d '\r' | head -1)
chk "EDITOR trong login sạch = code --wait" "$ED" "code --wait"
r=$(cd $SP/tw/solo && echo x > f && git add f && GIT_EDITOR="$ED" timeout 2 git commit 2>&1)
[[ "$r" != *"cannot run"* ]] && ok "git commit không còn lỗi 'cannot run vim'" \
                             || no "git commit" "$r"

clean
print "\n\e[1m═══ KẾT QUẢ: $PASS pass, $FAIL fail ═══\e[0m"
(( FAIL )) && { print "Fail:"; printf '  - %s\n' $FAILED; return 1 }
return 0
