// Copyright 2023 The go-ethereum Authors
// This file is part of the go-ethereum library.
//
// The go-ethereum library is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// The go-ethereum library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.

package forks

// Fork is a numerical identifier of specific network upgrades (forks).
type Fork int

const (
	Frontier         = iota // 主网初始发布（2015）
	FrontierThawing         // 解除初期“冷冻”限制，网络进入常态
	Homestead               // 首个稳定性升级，安全性与网络规则改进
	DAO                     // 为回滚 The DAO 事件资金的硬分叉（分裂出 ETC）
	TangerineWhistle        // EIP-150，Gas 成本上调，缓解 DoS
	SpuriousDragon          // EIP-155 重放保护、状态清理、继续反 DoS
	Byzantium               // 多预编译与隐私改进、区块奖励降至 3 ETH、推迟难度炸弹
	Constantinople          // 多项协议优化（含 SSTORE 变更等）
	Petersburg              // 紧急回滚 Constantinople 中的 EIP-1283 重入风险
	Istanbul                // Gas 调整、更多预编译、合约效率优化
	MuirGlacier             // 再次推迟难度炸弹（Ice Age）
	Berlin                  // 交易类型框架（EIP-2718）、访问列表（EIP-2930）与 Gas 调整
	London                  // EIP-1559 基础费与销毁机制、奖励调整
	ArrowGlacier            // 再次推迟难度炸弹
	GrayGlacier             // 再次推迟难度炸弹
	Paris                   // The Merge，PoW 切换到 PoS，结束挖矿
	Shanghai                // Shapella，质押提款（EIP-4895）等
	Cancun                  // Dencun，EIP-4844 blob 交易（提升 L2 数据可用性）
	Prague                  // (TODO merge 到ju-chain) Pectra 执行层（Prague），关键变更：EIP-7702智能钱包, 用户体验提升
)
