async function f() {
	const [_, __, liquidityProvider, tokenAmount] = bytesArgs;

	const chainSelectors = {
		// [`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_FUJI}').toString(16)}`]: {
		// 	urls: [`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`],
		// 	chainId: '0xa869',
		// 	usdcAddress: '${USDC_FUJI}',
		// 	poolAddress: '${CONCEROPOOL_AVALANCHE_FUJI}',
		// },
		// [`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_SEPOLIA}').toString(16)}`]: {
		// 	urls: [
		// 		`https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
		// 		'https://ethereum-sepolia-rpc.publicnode.com',
		// 		'https://ethereum-sepolia.blockpi.network/v1/rpc/public',
		// 	],
		// 	chainId: '0xaa36a7',
		// 	usdcAddress: '${USDC_SEPOLIA}',
		// 	poolAddress: '${CONCEROPOOL_SEPOLIA}',
		// },
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA}').toString(16)}`]: {
			urls: [
				`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://arbitrum-sepolia.blockpi.network/v1/rpc/public',
				'https://arbitrum-sepolia-rpc.publicnode.com',
			],
			chainId: '0x66eee',
			usdcAddress: '${USDC_ARBITRUM_SEPOLIA}',
			poolAddress: '${CHILD_POOL_PROXY_ARBITRUM_SEPOLIA}',
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA}').toString(16)}`]: {
			urls: [
				`https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://optimism-sepolia.blockpi.network/v1/rpc/public',
				'https://optimism-sepolia-rpc.publicnode.com',
			],
			chainId: '0xaa37dc',
			usdcAddress: '${USDC_OPTIMISM_SEPOLIA}',
			poolAddress: '${CHILD_POOL_PROXY_OPTIMISM_SEPOLIA}',
		},
		// [`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_POLYGON_AMOY}').toString(16)}`]: {
		// 	urls: [
		// 		`https://polygon-amoy.infura.io/v3/${secrets.INFURA_API_KEY}`,
		// 		'https://polygon-amoy.blockpi.network/v1/rpc/public',
		// 		'https://polygon-amoy-bor-rpc.publicnode.com',
		// 	],
		// 	chainId: '0x13882',
		// 	usdcAddress: '${USDC_AMOY}',
		// 	poolAddress: '${CONCEROPOOL_POLYGON_AMOY}',
		// },
	};

	class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {
		constructor(url) {
			super(url);
			this.url = url;
		}
		async _send(payload) {
			if (payload.method === 'eth_estimateGas') {
				return [{jsonrpc: '2.0', id: payload.id, result: '0x1e8480'}];
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

	const poolAbi = ['function ccipSendToPool(address, uint256) external returns (bytes32 messageId)'];
	const promises = [];

	console.log('liquidityProvider', liquidityProvider);
	console.log('tokenAmount', tokenAmount);

	for (const chainSelector in chainSelectors) {
		const url = chainSelectors[chainSelector].urls[Math.floor(Math.random() * chainSelectors[chainSelector].urls.length)];
		const provider = new FunctionsJsonRpcProvider(url);
		const wallet = new ethers.Wallet('0x' + secrets.WALLET_PRIVATE_KEY, provider);
		const signer = wallet.connect(provider);
		const poolContract = new ethers.Contract(chainSelectors[chainSelector].poolAddress, poolAbi, signer);
		promises.push(poolContract.ccipSendToPool(liquidityProvider, tokenAmount));
	}

	await Promise.all(promises);

	return Functions.encodeUint256(1n);
}
f();
