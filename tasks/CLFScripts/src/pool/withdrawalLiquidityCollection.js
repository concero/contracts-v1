(async () => {
	try {
		const [_, __, ___, liquidityRequestedFromEachPool, withdrawalId] = bytesArgs;

		const chainSelectors = {
			// [`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA}').toString(16)}`]: {
			// 	urls: [
			// 		`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
			// 		'https://arbitrum-sepolia.blockpi.network/v1/rpc/public',
			// 		'https://arbitrum-sepolia-rpc.publicnode.com',
			// 	],
			// 	chainId: '0x66eee',
			// 	usdcAddress: '${USDC_ARBITRUM_SEPOLIA}',
			// 	poolAddress: '${CHILD_POOL_PROXY_ARBITRUM_SEPOLIA}',
			// },
			// [`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_FUJI}').toString(16)}`]: {
			// 	urls: [
			// 		`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`,
			// 		'https://avalanche-fuji-c-chain-rpc.publicnode.com',
			// 		'https://avalanche-fuji.blockpi.network/v1/rpc/public',
			// 	],
			// 	chainId: '0xa869',
			// 	usdcAddress: '${USDC_FUJI}',
			// 	poolAddress: '${CHILD_POOL_PROXY_FUJI}',
			// },
			// mainnets
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_ARBITRUM}').toString(16)}`]: {
				urls: [
					'https://arbitrum.llamarpc.com',
					'https://arbitrum-one-rpc.publicnode.com',
					'https://arbitrum.drpc.org',
				],
				chainId: '0xa4b1',
				usdcAddress: '${USDC_ARBITRUM}',
				poolAddress: '${CHILD_POOL_PROXY_ARBITRUM}',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_POLYGON}').toString(16)}`]: {
				urls: [
					'https://polygon-bor-rpc.publicnode.com',
					'https://rpc.ankr.com/polygon',
					'https://polygon.llamarpc.com',
				],
				chainId: '0x89',
				usdcAddress: '${USDC_POLYGON}',
				poolAddress: '${CHILD_POOL_PROXY_POLYGON}',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_AVALANCHE}').toString(16)}`]: {
				urls: [
					'https://avalanche.public-rpc.com',
					'https://avalanche-c-chain-rpc.publicnode.com',
					'https://rpc.ankr.com/avalanche',
				],
				chainId: '0xa86a',
				usdcAddress: '${USDC_AVALANCHE}',
				poolAddress: '${CHILD_POOL_PROXY_AVALANCHE}',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_OPTIMISM}').toString(16)}`]: {
				urls: ['https://optimism.llamarpc.com', 'https://rpc.ankr.com/optimism', 'https://optimism.drpc.org'],
				chainId: '0xa',
				usdcAddress: '${USDC_OPTIMISM}',
				poolAddress: '${CHILD_POOL_PROXY_OPTIMISM}',
			},
		};

		const getChainIdByUrl = url => {
			for (const chain in chainSelectors) {
				if (chainSelectors[chain].urls.includes(url)) return chainSelectors[chain].chainId;
			}
			return null;
		};

		const baseChainSelector = `0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_BASE}').toString(16)}`;
		// const baseChainSelector = `0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA}').toString(16)}`;

		class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {
			constructor(url) {
				super(url);
				this.url = url;
			}
			async _send(payload) {
				if (payload.method === 'eth_estimateGas') {
					return [{jsonrpc: '2.0', id: payload.id, result: '0x1e8480'}];
				}
				if (payload.method === 'eth_chainId') {
					const _chainId = getChainIdByUrl(this.url);
					return [{jsonrpc: '2.0', id: payload.id, result: _chainId}];
				}

				let resp = await fetch(this.url, {
					method: 'POST',
					headers: {'Content-Type': 'application/json'},
					body: JSON.stringify(payload),
				});
				const res = await resp.json();
				if (res.length === undefined) return [res];
				return res;
			}
		}

		const poolAbi = ['function ccipSendToPool(uint64, uint256, bytes32) external'];

		const promises = [];

		for (const chainSelector in chainSelectors) {
			const url =
				chainSelectors[chainSelector].urls[
					Math.floor(Math.random() * chainSelectors[chainSelector].urls.length)
				];
			const provider = new FunctionsJsonRpcProvider(url);
			const wallet = new ethers.Wallet('0x' + secrets.POOL_MESSENGER_0_PRIVATE_KEY, provider);
			const signer = wallet.connect(provider);
			const poolContract = new ethers.Contract(chainSelectors[chainSelector].poolAddress, poolAbi, signer);
			promises.push(poolContract.ccipSendToPool(baseChainSelector, liquidityRequestedFromEachPool, withdrawalId));
		}

		await Promise.all(promises);

		return Functions.encodeUint256(1n);
	} catch (e) {
		const {message, code} = e;
		if (
			code === 'NONCE_EXPIRED' ||
			message?.includes('replacement fee too low') ||
			message?.includes('already known')
		) {
			return Functions.encodeUint256(1n);
		}
		throw e;
	}
})();
