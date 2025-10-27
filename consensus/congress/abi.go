package congress

// validatorsInteractiveABI contains all methods to interactive with validator contracts.
const validatorsInteractiveABI = `
[
	{
		"inputs": [
		  {
			"internalType": "address[]",
			"name": "vals",
			"type": "address[]"
		  },
		  {
			"internalType": "address",
			"name": "_proposal",
			"type": "address"
		  },
		  {
			"internalType": "address",
			"name": "_punish",
			"type": "address"
		  },
		  {
			"internalType": "address",
			"name": "_staking",
			"type": "address"
		  }
		],
		"name": "initialize",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "distributeBlockReward",
		"outputs": [],
		"stateMutability": "payable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getTopValidators",
		"outputs": [
		  {
			"internalType": "address[]",
			"name": "",
			"type": "address[]"
		  }
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
		  {
			"internalType": "address[]",
			"name": "newSet",
			"type": "address[]"
		  },
		  {
			"internalType": "uint256",
			"name": "epoch",
			"type": "uint256"
		  }
		],
		"name": "updateActiveValidatorSet",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
		  {
			"internalType": "uint256",
			"name": "epoch",
			"type": "uint256"
		  }
		],
		"name": "updateValidatorSetByStake",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	}
]
`

const punishInteractiveABI = `
[
	{
		"inputs": [
		  {
			"internalType": "address",
			"name": "_validators",
			"type": "address"
		  },
		  {
			"internalType": "address",
			"name": "_proposal",
			"type": "address"
		  }
		],
		"name": "initialize",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
		  {
			"internalType": "address",
			"name": "val",
			"type": "address"
		  }
		],
		"name": "punish",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
		  {
			"internalType": "uint256",
			"name": "epoch",
			"type": "uint256"
		  }
		],
		"name": "decreaseMissedBlocksCounter",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	  }
]
`

const proposalInteractiveABI = `
[
	{
		"inputs": [
		  {
			"internalType": "address[]",
			"name": "vals",
			"type": "address[]"
		  },
		  {
			"internalType": "address",
			"name": "_validators",
			"type": "address"
		  }
		],
		"name": "initialize",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "increasePeriod",
		"outputs": [
		  {
			"internalType": "uint256",
			"name": "",
			"type": "uint256"
		  }
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "receiverAddr",
		"outputs": [
		  {
			"internalType": "address",
			"name": "",
			"type": "address"
		  }
		],
		"stateMutability": "view",
		"type": "function"
	}
]
`

// stakingInteractiveABI contains methods to interact with staking contracts.
const stakingInteractiveABI = `
[
	{
		"type": "function",
		"name": "initialize",
		"inputs": [
			{
				"name": "_validators",
				"type": "address",
				"internalType": "address"
			}
		],
		"outputs": [],
		"stateMutability": "nonpayable"
	},
	{
		"type": "function",
		"name": "distributeRewards",
		"inputs": [
			{
				"name": "validator",
				"type": "address",
				"internalType": "address"
			}
		],
		"outputs": [],
		"stateMutability": "payable"
	},
	{
		"type": "function",
		"name": "distributeBaseReward",
		"inputs": [
			{
				"name": "validator",
				"type": "address",
				"internalType": "address"
			}
		],
		"outputs": [],
		"stateMutability": "payable"
	},
	{
		"type": "function",
		"name": "delegate",
		"inputs": [
			{
				"name": "validator",
				"type": "address",
				"internalType": "address"
			}
		],
		"outputs": [],
		"stateMutability": "payable"
	},
	{
		"type": "function",
		"name": "undelegate",
		"inputs": [
			{
				"name": "validator",
				"type": "address",
				"internalType": "address"
			},
			{
				"name": "amount",
				"type": "uint256",
				"internalType": "uint256"
			}
		],
		"outputs": [],
		"stateMutability": "nonpayable"
	},
	{
		"type": "function",
		"name": "claimRewards",
		"inputs": [
			{
				"name": "validator",
				"type": "address",
				"internalType": "address"
			}
		],
		"outputs": [],
		"stateMutability": "nonpayable"
	},
	{
		"type": "function",
		"name": "registerValidator",
		"inputs": [
			{
				"name": "commissionRate",
				"type": "uint256",
				"internalType": "uint256"
			}
		],
		"outputs": [],
		"stateMutability": "payable"
	},
	{
		"type": "function",
		"name": "getValidatorInfo",
		"inputs": [
			{
				"name": "validator",
				"type": "address",
				"internalType": "address"
			}
		],
		"outputs": [
			{
				"name": "selfStake",
				"type": "uint256",
				"internalType": "uint256"
			},
			{
				"name": "totalDelegated",
				"type": "uint256",
				"internalType": "uint256"
			},
			{
				"name": "commissionRate",
				"type": "uint256",
				"internalType": "uint256"
			},
			{
				"name": "isJailed",
				"type": "bool",
				"internalType": "bool"
			},
			{
				"name": "jailUntilBlock",
				"type": "uint256",
				"internalType": "uint256"
			}
		],
		"stateMutability": "view"
	},
	{
		"type": "function",
		"name": "getTopValidators",
		"inputs": [
			{
				"name": "limit",
				"type": "uint256",
				"internalType": "uint256"
			}
		],
		"outputs": [
			{
				"name": "",
				"type": "address[]",
				"internalType": "address[]"
			}
		],
		"stateMutability": "view"
	}
]
`
