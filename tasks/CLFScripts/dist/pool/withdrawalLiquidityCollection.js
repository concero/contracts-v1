(async () => {
	try {
		const [_, __, ___, liquidityRequestedFromEachPool, withdrawalId] = bytesArgs;
		const chainSelectors = {
			[`0x${BigInt('4949039107694359620').toString(16)}`]: {
				urls: [
					'https://arbitrum.llamarpc.com',
					'https://arbitrum-one-rpc.publicnode.com',
					'https://arbitrum.drpc.org',
				],
				chainId: '0xa4b1',
				usdcAddress: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
				poolAddress: '0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d',
			},
			[`0x${BigInt('4051577828743386545').toString(16)}`]: {
				urls: [
					'https://polygon-bor-rpc.publicnode.com',
					'https://rpc.ankr.com/polygon',
					'https://polygon.llamarpc.com',
				],
				chainId: '0x89',
				usdcAddress: '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
				poolAddress: '0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d',
			},
			[`0x${BigInt('6433500567565415381').toString(16)}`]: {
				urls: [
					'https://avalanche.public-rpc.com',
					'https://avalanche-c-chain-rpc.publicnode.com',
					'https://rpc.ankr.com/avalanche',
				],
				chainId: '0xa86a',
				usdcAddress: '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E',
				poolAddress: '0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d',
			},
			[`0x${BigInt('3734403246176062136').toString(16)}`]: {
				urls: ['https://optimism.llamarpc.com', 'https://rpc.ankr.com/optimism', 'https://optimism.drpc.org'],
				chainId: '0xa',
				usdcAddress: '0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85',
				poolAddress: '0x8698c6DF1E354Ce3ED0dE508EF7AF4baB85D2F2D',
			},
		};
		const getChainIdByUrl = url => {
			for (const chain in chainSelectors) {
				if (chainSelectors[chain].urls.includes(url)) return chainSelectors[chain].chainId;
			}
			return null;
		};
		const baseChainSelector = `0x${BigInt('15971525489660198786').toString(16)}`;
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
