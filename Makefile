# This Makefile is meant to be used by people that do not usually work
# with Go source code. If you know what GOPATH is then you probably
# don't need to bother with make.

.PHONY: geth evm all test lint fmt clean devtools help

GOBIN = ./build/bin
GO ?= latest
GORUN = go run

#? geth: Build geth.
geth:
	$(GORUN) build/ci.go install ./cmd/geth
	@echo "Done building."
	@echo "Run \"$(GOBIN)/geth\" to launch geth."

#? evm: Build evm.
evm:
	$(GORUN) build/ci.go install ./cmd/evm
	@echo "Done building."
	@echo "Run \"$(GOBIN)/evm\" to launch evm."

#? all: Build all packages and executables.
all:
	$(GORUN) build/ci.go install

#? test: Run the tests.
test: all
	$(GORUN) build/ci.go test

#? lint: Run certain pre-selected linters.
lint: ## Run linters.
	$(GORUN) build/ci.go lint

#? fmt: Ensure consistent code formatting.
fmt:
	gofmt -s -w $(shell find . -name "*.go")

#? clean: Clean go cache, built executables, and the auto generated folder.
clean:
	go clean -cache
	rm -fr build/_workspace/pkg/ $(GOBIN)/*

# The devtools target installs tools required for 'go generate'.
# You need to put $GOBIN (or $GOPATH/bin) in your PATH to use 'go generate'.

#? devtools: Install recommended developer tools.
devtools:
	env GOBIN= go install golang.org/x/tools/cmd/stringer@latest
	env GOBIN= go install github.com/fjl/gencodec@latest
	env GOBIN= go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	env GOBIN= go install ./cmd/abigen
	@type "solc" 2> /dev/null || echo 'Please install solc'
	@type "protoc" 2> /dev/null || echo 'Please install protoc'

#? list: List project structure and components
list:
	@echo "=== Go Ethereum 项目结构 ==="
	@echo ""
	@echo "📂 主要目录:"
	@echo "  ├── cmd/         - 可执行程序"
	@echo "  │   ├── geth/    - 主要以太坊客户端"
	@echo "  │   ├── clef/    - 独立签名工具"
	@echo "  │   ├── bootnode/ - 网络引导节点"
	@echo "  │   ├── devp2p/  - P2P网络工具"
	@echo "  │   ├── abigen/  - ABI代码生成器"
	@echo "  │   ├── evm/     - EVM调试工具"
	@echo "  │   └── rlpdump/ - RLP数据转储工具"
	@echo ""
	@echo "  ├── core/        - 区块链核心逻辑"
	@echo "  ├── consensus/   - 共识算法实现"
	@echo "  ├── miner/       - 挖矿相关功能"
	@echo "  ├── eth/         - 以太坊协议实现"
	@echo "  ├── p2p/         - 点对点网络"
	@echo "  ├── trie/        - Merkle Patricia树"
	@echo "  ├── ethdb/       - 数据库接口"
	@echo "  ├── accounts/    - 账户管理"
	@echo "  ├── crypto/      - 加密算法"
	@echo "  ├── params/      - 网络参数配置"
	@echo "  ├── node/        - 节点框架"
	@echo "  ├── rpc/         - RPC服务"
	@echo "  ├── ethclient/   - 以太坊客户端库"
	@echo "  ├── log/         - 日志系统"
	@echo "  ├── metrics/     - 性能指标"
	@echo "  ├── event/       - 事件系统"
	@echo "  ├── common/      - 通用工具"
	@echo "  ├── internal/    - 内部工具"
	@echo "  ├── build/       - 构建脚本和工具"
	@echo "  └── tests/       - 测试用例"
	@echo ""
	@echo "🛠️  可执行工具:"
	@ls -la $(GOBIN)/ 2>/dev/null | grep -E "^-" | awk '{print "  " $$9}' || echo "  (需要先运行 'make all' 构建工具)"
	@echo ""
	@echo "📦 Go模块信息:"
	@grep "^module\|^go\|^require" go.mod | head -5 2>/dev/null || echo "  go.mod 文件不存在"
	@echo ""
	@echo "💡 使用 'make help' 查看可用命令"

#? list-cmds: List all available commands in cmd/ directory  
list-cmds:
	@echo "=== 可用命令行工具 ==="
	@for cmd in cmd/*/; do \
		if [ -f "$$cmd/main.go" ]; then \
			echo "  📦 $$(basename $$cmd)"; \
			grep -h "// Package.*provides\|//.*command\|//.*tool" "$$cmd"/*.go 2>/dev/null | head -1 | sed 's|^//||' | sed 's|^[ \t]*|    |' || echo "    以太坊工具"; \
		fi \
	done

#? list-packages: List main Go packages structure
list-packages:
	@echo "=== Go包结构 ==="
	@find . -maxdepth 2 -name "*.go" -path "./*" ! -path "./build/*" ! -path "./tests/*" ! -path "./vendor/*" | \
		cut -d'/' -f2 | sort | uniq -c | sort -nr | \
		awk '{printf "  %-20s (%s files)\n", $$2, $$1}'

#? help: Get more info on make commands.
help: Makefile
	@echo ''
	@echo 'Usage:'
	@echo '  make [target]'
	@echo ''
	@echo 'Targets:'
	@sed -n 's/^#?//p' $< | column -t -s ':' |  sort | sed -e 's/^/ /'
