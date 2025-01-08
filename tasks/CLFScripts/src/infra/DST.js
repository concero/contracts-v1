(async () => {
	try {
		const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

		const constructResult = (receiver, amount, compressedDstSwapData) => {
			const encodedReceiver = Functions.encodeUint256(BigInt(receiver));
			const encodedAmount = Functions.encodeUint256(BigInt(amount));
			const encodedCompressedData = ethers.getBytes(compressedDstSwapData);

			const totalLength = encodedReceiver.length + encodedAmount.length + encodedCompressedData.length;
			const result = new Uint8Array(totalLength);

			let offset = 0;
			result.set(encodedReceiver, offset);
			offset += encodedReceiver.length;

			result.set(encodedAmount, offset);
			offset += encodedAmount.length;

			result.set(encodedCompressedData, offset);
			return result;
		};

		const [_, __, ___, srcContractAddress, srcChainSelector, conceroMessageId, txDataHash] = bytesArgs;

		const chainMap = {
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_FUJI}').toString(16)}`]: {
				urls: [`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`],
				confirmations: 3n,
				chainId: '0xa869',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_SEPOLIA}').toString(16)}`]: {
				urls: ['https://ethereum-sepolia-rpc.publicnode.com'],
				confirmations: 3n,
				chainId: '0xaa36a7',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA}').toString(16)}`]: {
				urls: ['https://arbitrum-sepolia-rpc.publicnode.com'],
				confirmations: 3n,
				chainId: '0x66eee',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA}').toString(16)}`]: {
				urls: ['https://base-sepolia-rpc.publicnode.com'],
				confirmations: 3n,
				chainId: '0x14a34',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA}').toString(16)}`]: {
				urls: ['https://optimism-sepolia-rpc.publicnode.com'],
				confirmations: 3n,
				chainId: '0xaa37dc',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_POLYGON_AMOY}').toString(16)}`]: {
				urls: [
					`https://polygon-amoy.infura.io/v3/${secrets.INFURA_API_KEY}`,
					'https://polygon-amoy.blockpi.network/v1/rpc/public',
					'https://polygon-amoy-bor-rpc.publicnode.com',
				],
				confirmations: 3n,
				chainId: '0x13882',
			},

			// mainnets

			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_POLYGON}').toString(16)}`]: {
				urls: ['https://polygon-bor-rpc.publicnode.com', 'https://rpc.ankr.com/polygon'],
				confirmations: 3n,
				chainId: '0x89',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_ARBITRUM}').toString(16)}`]: {
				urls: ['https://arbitrum-rpc.publicnode.com', 'https://rpc.ankr.com/arbitrum'],
				confirmations: 3n,
				chainId: '0xa4b1',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_BASE}').toString(16)}`]: {
				urls: ['https://base-rpc.publicnode.com', 'https://rpc.ankr.com/base'],
				confirmations: 3n,
				chainId: '0x2105',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_AVALANCHE}').toString(16)}`]: {
				urls: ['https://avalanche-c-chain-rpc.publicnode.com', 'https://rpc.ankr.com/avalanche'],
				confirmations: 3n,
				chainId: '0xa86a',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_OPTIMISM}').toString(16)}`]: {
				urls: [
					'https://optimism-rpc.publicnode.com',
					'https://rpc.ankr.com/optimism',
					'https://optimism.drpc.org',
				],
				confirmations: 3n,
				chainId: '0xa',
			},
		};

		class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {
			constructor(url) {
				super(url);
				this.url = url;
			}
			async _send(payload) {
				if (payload.method === 'eth_chainId') {
					return [{jsonrpc: '2.0', id: payload.id, result: chainMap[srcChainSelector].chainId}];
				}
				const resp = await fetch(this.url, {
					method: 'POST',
					headers: {'Content-Type': 'application/json'},
					body: JSON.stringify(payload),
				});
				const result = await resp.json();
				if (payload.length === undefined) {
					return [result];
				}
				return result;
			}
		}
		const abi = ['event ConceroBridgeSent(bytes32 indexed, uint256, uint64, address, bytes)'];
		const ethersId = ethers.id('ConceroBridgeSent(bytes32,uint256,uint64,address,bytes)');
		const contract = new ethers.Interface(abi);

		const fallBackProviders = chainMap[srcChainSelector].urls.map(url => {
			return {
				provider: new FunctionsJsonRpcProvider(url),
				priority: Math.random(),
				stallTimeout: 2000,
				weight: 1,
			};
		});

		const provider = new ethers.FallbackProvider(fallBackProviders, null, {quorum: 2});
		let latestBlockNumber = BigInt(await provider.getBlockNumber());
		const confirmations = chainMap[srcChainSelector].confirmations;

		const confirmedBlockNumber = latestBlockNumber - confirmations;

		if (latestBlockNumber > confirmedBlockNumber) {
			latestBlockNumber = confirmedBlockNumber;
		}

		const logs = await provider.getLogs({
			address: srcContractAddress,
			topics: [ethersId, conceroMessageId],
			fromBlock: Math.max(latestBlockNumber - 1000n, 0n),
			toBlock: latestBlockNumber,
		});

		if (!logs.length) {
			throw new Error('No logs found');
		}

		const log = logs[0];
		const logBlockNumber = BigInt(log.blockNumber);

		while (latestBlockNumber - logBlockNumber < confirmations) {
			await sleep(5000);
			latestBlockNumber = BigInt(await provider.getBlockNumber());
			if (latestBlockNumber < logBlockNumber) {
				throw new Error('Provider fell behind sync.');
			}
		}

		const newLogs = await provider.getLogs({
			address: srcContractAddress,
			topics: [ethersId, conceroMessageId],
			fromBlock: logBlockNumber,
			toBlock: latestBlockNumber - confirmations,
		});

		if (!newLogs.some(l => l.transactionHash === log.transactionHash)) {
			throw new Error('Log no longer exists.');
		}

		const logData = {
			topics: [ethersId, log.topics[1]],
			data: log.data,
		};

		const decodedLog = contract.parseLog(logData);
		const amount = decodedLog.args[1];
		const receiver = decodedLog.args[3];
		const compressedDstSwapData = decodedLog.args[4];
		const eventHashData = new ethers.AbiCoder().encode(
			['bytes32', 'uint256', 'uint64', 'address', 'bytes32'],
			[decodedLog.args[0], amount, decodedLog.args[2], receiver, ethers.keccak256(compressedDstSwapData)],
		);

		const recomputedTxDataHash = ethers.keccak256(eventHashData);
		if (recomputedTxDataHash.toLowerCase() !== txDataHash.toLowerCase()) {
			throw new Error('TxDataHash mismatch');
		}

		return constructResult(receiver, amount, compressedDstSwapData);
	} catch (error) {
		throw new Error(error.message.slice(0, 255));
	}
})();
