async function f() {
	const chainSelectors = {
		[`0x${BigInt('3478487238524512106').toString(16)}`]: {
			urls: [
				`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://arbitrum-sepolia.blockpi.network/v1/rpc/public',
				'https://arbitrum-sepolia-rpc.publicnode.com',
			],
			chainId: '0x66eee',
			usdcAddress: '0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d',
			poolAddress: '0x869a621003BC70fceA9d12267a3B80E49cCbEFE3',
		},
		[`0x${BigInt('5224473277236331295').toString(16)}`]: {
			urls: [
				`https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://optimism-sepolia.blockpi.network/v1/rpc/public',
				'https://optimism-sepolia-rpc.publicnode.com',
			],
			chainId: '0xaa37dc',
			usdcAddress: '0x5fd84259d66Cd46123540766Be93DFE6D43130D7',
			poolAddress: '0xE2E94C32beeB98F1b4D96F0E30a5a92af8f09108',
		},
	};
	const erc20Abi = ['function balanceOf(address) external view returns (uint256)'];
	const poolAbi = ['function s_loansInUse() external view returns (uint256)'];
	class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {
		constructor(url) {
			super(url);
			this.url = url;
		}
		async _send(payload) {
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
	let totalBalance = 0n;
	for (const chain in chainSelectors) {
		const fallBackProviders = chainSelectors[srcChainSelector].urls.map(url => {
			return {
				provider: new FunctionsJsonRpcProvider(url),
				priority: Math.random(),
				stallTimeout: 2000,
				weight: 1,
			};
		});
		const provider = new ethers.FallbackProvider(fallBackProviders, null, {quorum: 1});
		const erc20 = new ethers.Contract(chainSelectors[chain].usdcAddress, erc20Abi, provider);
		const pool = new ethers.Contract(chainSelectors[chain].poolAddress, poolAbi, provider);
		const [poolBalance, commits] = await Promise.all([
			erc20.balanceOf(chainSelectors[chain].poolAddress),
			pool.s_loansInUse(),
		]);
		totalBalance += poolBalance + commits;
	}
	return Functions.encodeUint256(totalBalance);
}
f();
