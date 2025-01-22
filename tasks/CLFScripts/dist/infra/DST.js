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
				urls: [
					'https://polygon-bor-rpc.publicnode.com',
					'https://rpc.ankr.com/polygon',
					'https://polygon.llamarpc.com',
					'https://polygon-rpc.com',
					'https://polygon.drpc.org',
				],
				confirmations: 3n,
				chainId: '0x89',
			},
			[`0x${BigInt('4949039107694359620').toString(16)}`]: {
				urls: [
					'https://arbitrum-rpc.publicnode.com',
					'https://rpc.ankr.com/arbitrum',
					'https://arbitrum.llamarpc.com',
					'https://arbitrum-one-rpc.publicnode.com',
					'https://arbitrum.gateway.tenderly.co',
					'https://arbitrum.drpc.org',
				],
				confirmations: 3n,
				chainId: '0xa4b1',
			},
			[`0x${BigInt('15971525489660198786').toString(16)}`]: {
				urls: [
					'https://base-rpc.publicnode.com',
					'https://rpc.ankr.com/base',
					'https://base.gateway.tenderly.co',
					'https://base.blockpi.network/v1/rpc/public',
				],
				confirmations: 3n,
				chainId: '0x2105',
			},
			[`0x${BigInt('6433500567565415381').toString(16)}`]: {
				urls: [
					'https://avalanche-c-chain-rpc.publicnode.com',
					'https://rpc.ankr.com/avalanche',
					'https://avalanche.public-rpc.com',
					'https://1rpc.io/avax/c',
					'https://avalanche.drpc.org',
				],
				confirmations: 3n,
				chainId: '0xa86a',
			},
			[`0x${BigInt('3734403246176062136').toString(16)}`]: {
				urls: [
					'https://optimism-rpc.publicnode.com',
					'https://rpc.ankr.com/optimism',
					'https://optimism.drpc.org',
					'https://optimism.llamarpc.com',
					'https://optimism.gateway.tenderly.co',
				],
				confirmations: 3n,
				chainId: '0xa',
			},
		};
		class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {
			constructor(_url) {
				super(_url);
				this.url = _url;
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
		const {urls: rpcsUrls, confirmations} = chainMap[srcChainSelector];
		let getLogsRetryCounter = 5;
		let index = Math.floor(Math.random() * rpcsUrls.length);
		let provider;
		let latestBlockNumber;
		let logs = [];
		while (getLogsRetryCounter-- > 0 && !logs.length) {
			try {
				provider = new FunctionsJsonRpcProvider(rpcsUrls[index]);
				latestBlockNumber = BigInt(await provider.getBlockNumber());
				logs = await provider.getLogs({
					address: srcContractAddress,
					topics: [ethersId, conceroMessageId],
					fromBlock: BigInt(Math.max(Number(latestBlockNumber - 1000n), 0)),
					toBlock: latestBlockNumber,
				});
			} catch (e) {}
			index = (index + 1) % rpcsUrls.length;
			if (!logs.length) {
				await sleep(3000);
			}
		}
		if (!logs.length) {
			throw new Error(`No logs found ${provider.url}`);
		}
		let log = logs[0];
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
		log = newLogs[0];
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
