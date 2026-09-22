# mac/

Script chạy **trên máy công ty macOS**, không phải trên Fedora này.

Tách riêng để không nhầm với script của máy này — `bin/` hay `zsh/functions/`
là của Fedora, thư mục này thì không bao giờ được symlink vào `$PATH` ở đây.

| Tệp | Việc |
|---|---|
| `preflight` | Kiểm tra & chuẩn bị Mac trước khi rời bàn — xem `guides/remote-access-runbook.md` §8 |

## Deploy lên Mac

```bash
macup    # xác nhận Mac đang tỉnh trước đã

ssh mac-cmp-file 'mkdir -p ~/bin && grep -q "HOME/bin" ~/.zshenv \
  || echo "export PATH=\"\$HOME/bin:\$PATH\"" >> ~/.zshenv'
scp mac/preflight mac-cmp-file:~/bin/preflight
ssh mac-cmp-file 'chmod +x ~/bin/preflight && ~/bin/preflight'
```

`.zshenv` chứ không phải `.zshrc`: phiên `ssh host <cmd>` là không tương tác,
zsh chỉ nạp `.zshenv`.
