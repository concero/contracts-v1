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
			[`0x${BigInt('14767482510784806043').toString(16)}`]: {
				urls: [`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`],
				confirmations: 3n,
				chainId: '0xa869',
			},
			[`0x${BigInt('16015286601757825753').toString(16)}`]: {
				urls: ['https://ethereum-sepolia-rpc.publicnode.com'],
				confirmations: 3n,
				chainId: '0xaa36a7',
			},
			[`0x${BigInt('3478487238524512106').toString(16)}`]: {
				urls: ['https://arbitrum-sepolia-rpc.publicnode.com'],
				confirmations: 3n,
				chainId: '0x66eee',
			},
			[`0x${BigInt('10344971235874465080').toString(16)}`]: {
				urls: ['https://base-sepolia-rpc.publicnode.com'],
				confirmations: 3n,
				chainId: '0x14a34',
			},
			[`0x${BigInt('5224473277236331295').toString(16)}`]: {
				urls: ['https://optimism-sepolia-rpc.publicnode.com'],
				confirmations: 3n,
				chainId: '0xaa37dc',
			},
			[`0x${BigInt('16281711391670634445').toString(16)}`]: {
				urls: [
					`https://polygon-amoy.infura.io/v3/${secrets.INFURA_API_KEY}`,
					'https://polygon-amoy.blockpi.network/v1/rpc/public',
					'https://polygon-amoy-bor-rpc.publicnode.com',
				],
				confirmations: 3n,
				chainId: '0x13882',
			},
			[`0x${BigInt('4051577828743386545').toString(16)}`]: {
				urls: ['https://polygon-bor-rpc.publicnode.com', 'https://rpc.ankr.com/polygon'],
				confirmations: 3n,
				chainId: '0x89',
			},
			[`0x${BigInt('4949039107694359620').toString(16)}`]: {
				urls: ['https://arbitrum-rpc.publicnode.com', 'https://rpc.ankr.com/arbitrum'],
				confirmations: 3n,
				chainId: '0xa4b1',
			},
			[`0x${BigInt('15971525489660198786').toString(16)}`]: {
				urls: ['https://base-rpc.publicnode.com', 'https://rpc.ankr.com/base'],
				confirmations: 3n,
				chainId: '0x2105',
			},
			[`0x${BigInt('6433500567565415381').toString(16)}`]: {
				urls: ['https://avalanche-c-chain-rpc.publicnode.com', 'https://rpc.ankr.com/avalanche'],
				confirmations: 3n,
				chainId: '0xa86a',
			},
			[`0x${BigInt('3734403246176062136').toString(16)}`]: {
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
		const url = chainMap[srcChainSelector].urls[Math.floor(Math.random() * chainMap[srcChainSelector].urls.length)];
		const provider = new FunctionsJsonRpcProvider(url);
		let latestBlockNumber = BigInt(await provider.getBlockNumber());
		const confirmations = chainMap[srcChainSelector].confirmations;
		const logs = await provider.getLogs({
			address: srcContractAddress,
			topics: [ethersId, conceroMessageId],
			fromBlock: BigInt(Math.max(Number(latestBlockNumber - 1000n), 0)),
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
		}
		const newLogs = await provider.getLogs({
			address: srcContractAddress,
			topics: [ethersId, conceroMessageId],
			fromBlock: logBlockNumber,
			toBlock: latestBlockNumber,
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
