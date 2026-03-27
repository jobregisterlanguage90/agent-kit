# Go 二进制远程传输优化

> 学习笔记: Go 二进制远程传输优化 (2026-03-27)
> 来源: erp-admin 部署基准测试实测 + 文献调研

## 实测数据（erp-admin server, Mac→韩国 nouhaus-kr）

### 体积优化

| 构建方式 | 大小 | 相对原始 | gzip 后 | gzip 率 |
|----------|------|---------|---------|---------|
| 普通 `go build` | 133MB | 100% | 56MB | 60% |
| `-ldflags="-s -w"` | 101MB | 76% (↓24%) | 33MB | 70% |

**结论**: `-s -w` 去掉 DWARF 符号表和调试信息，体积减 ~30%。gzip 对 stripped 二进制压缩率更高（70% vs 60%），因为调试信息本身有较高熵值。

### 传输方式对比

| 方式 | 传输量 | 耗时 | 速率 | 相对基线 |
|------|--------|------|------|---------|
| 裸 scp (133MB 普通) | 133MB | 184s | 0.72 MB/s | 基线 |
| 裸 scp (101MB stripped) | 101MB | 64s | 1.58 MB/s | **2.9x** |
| gzip+ssh 管道 (stripped) | ~33MB | 22s | 1.50 MB/s(等效) | **8.4x** |
| rsync -az (文件相同) | ~35MB | 34s | — | 5.4x |
| rsync -az (微量变更 1 byte) | 3.6KB | 8s | — | **23x** |
| rsync -az (完全不同二进制) | ~39MB | 22s | — | 8.4x |

### 最优组合

**`-ldflags="-s -w"` + `gzip | ssh` 管道 = 22s（原 184s 的 12%）**

## 关键发现

1. **ldflags -s -w 是免费午餐**：零副作用（生产环境不需要 DWARF），30% 体积缩减
2. **gzip+ssh 管道碾压裸 scp**：带宽受限时压缩收益巨大（33MB vs 101MB）
3. **rsync 对 Go 二进制增量传输无效**：Go 编译器不保证 reproducible build，即使小改动也导致二进制大面积变化，rsync delta 算法无法受益
4. **rsync -az ≈ gzip+ssh**：rsync 的 -z 压缩效果和 gzip 管道相当，但多了 checksum 开销
5. **pigz（并行 gzip）可进一步加速**：多核 CPU 下压缩速度可提升 2-4x

## 推荐部署命令

```bash
# 编译（7s）
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w" -o /tmp/server .

# 传输（~22s）
gzip -c /tmp/server | ssh nouhaus-kr "gunzip > /tmp/server"

# 替换+重启（7s）
ssh nouhaus-kr "sudo docker cp /tmp/server gva-server:/go/src/.../server && sudo docker restart gva-server && rm /tmp/server"

# 总计: ~40s（原 208s 的 19%）
```

## 注意事项

- `-s -w` 会移除调试信息，`gdb`/`dlv` 无法调试 → 仅用于生产构建
- `scp -C`（SSH 压缩）效果不如预先 gzip，因为 SSH 用 zlib 流式压缩效率较低
- 带宽充裕时（>10MB/s）压缩反而拖慢速度（CPU 成为瓶颈）
- Go 1.18+ 的 `-trimpath` 可再减少几 MB（去掉源码路径信息）

## 参考资料

- [Reducing Binary Size in Go](https://www.codingexplorations.com/blog/reducing-binary-size-in-go-strip-unnecessary-data-with-ldflags-w-s)
- [Go Binary Size Analysis](https://blog.howardjohn.info/posts/go-binary-size/)
- [IBM: SCP Compression Trade-offs](https://www.ibm.com/support/pages/undesired-negative-effects-compression-scp-file-transfers)
- [Scrap the SCP: pigz + nc](https://blog.cadena-it.com/linux-tips-how-to/scrap-the-scp-how-to-copy-data-fast-using-pigz-and-nc/)
