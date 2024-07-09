async function f() {
	const chainSelectors = {
		[`0x${BigInt('4051577828743386545').toString(16)}`]: {
			urls: [
				`https://polygon-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://polygon.blockpi.network/v1/rpc/public',
				'https://polygon-bor-rpc.publicnode.com',
			],
			chainId: '0x89',
			usdcAddress: '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
			poolAddress: '0x390661e47a0013889b2bA26d1B7d01fdCD8F0bcC',
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
	const promises = [];
	let totalBalance = 0n;
	for (const chain in chainSelectors) {
		const url = chainSelectors[chain].urls[Math.floor(Math.random() * chainSelectors[chain].urls.length)];
		const provider = new FunctionsJsonRpcProvider(url);
		const erc20 = new ethers.Contract(chainSelectors[chain].usdcAddress, erc20Abi, provider);
		const pool = new ethers.Contract(chainSelectors[chain].poolAddress, poolAbi, provider);
		promises.push(erc20.balanceOf(chainSelectors[chain].poolAddress));
		promises.push(pool.s_loansInUse());
	}
	const results = await Promise.all(promises);
	for (let i = 0; i < results.length; i += 2) {
		totalBalance += BigInt(results[i]) + BigInt(results[i + 1]);
	}
	return Functions.encodeUint256(totalBalance);
}
f();
