(async () => {
	const chainSelectors = {
		['3478487238524512106']: {
			urls: [`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`],
			chainId: '0x66eee',
			usdcAddress: '0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d',
			poolAddress: '0x08b7325A4fF82F97803ff650A3288E036FB424ea',
		},
		['10344971235874465080']: {
			urls: [`https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`],
			chainId: '0x14a34',
			usdcAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
			poolAddress: '0xD5B19458Ddd36f75Cb8309B0e3bfB607Ccc04EB6',
		},
	};
	const baseChainSelector = '10344971235874465080';
	const erc20Abi = ['function balanceOf(address) external view returns (uint256)'];
	const poolAbi = [
		'function s_loansInUse() external view returns (uint256)',
		'function getDepositsOnTheWay() external view returns (tuple(uint64, bytes32, uint256)[150] memory)',
	];
	const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
	const findChainIdByUrl = url => {
		for (const chain in chainSelectors) {
			if (chainSelectors[chain].urls.includes(url)) return chainSelectors[chain].chainId;
		}
		return null;
	};
	class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {
		constructor(url) {
			super(url);
			this.url = url;
		}
		async _send(payload) {
			if (payload.method === 'eth_chainId') {
				const _chainId = findChainIdByUrl(this.url);
				return [{jsonrpc: '2.0', id: payload.id, result: _chainId}];
			}
			const resp = await fetch(this.url, {
				method: 'POST',
				headers: {'Content-Type': 'application/json'},
				body: JSON.stringify(payload),
			});
			const res = await resp.json();
			if (res.length === undefined) return [res];
			return res.map((r, i) => {
				return {jsonrpc: '2.0', id: payload[i].id, result: r.result};
			});
		}
	}
	const getProviderByChainSelector = _chainSelector => {
		const urls = chainSelectors[_chainSelector].urls;
		const url = urls[Math.floor(Math.random() * urls.length)];
		return new FunctionsJsonRpcProvider(url);
	};
	const baseProvider = getProviderByChainSelector(baseChainSelector);
	const getBaseDepositsOneTheWayArray = () => {
		const pool = new ethers.Contract(chainSelectors[baseChainSelector].poolAddress, poolAbi, baseProvider);
		return pool.getDepositsOnTheWay();
	};
	const getChildPoolsCcipLogs = async ccipLines => {
		const ethersId = ethers.id('CCIPReceived(bytes32,uint64,address,address,uint256)');
		const indexes = {};
		const getCcipLogs = async () => {
			const promises = [];
			for (const chainSelectorsKey in chainSelectors) {
				const reqFromLines = ccipLines.filter(line => BigInt(line.chainSelector) === BigInt(chainSelectorsKey));
				if (!reqFromLines.length) continue;
				const provider = getProviderByChainSelector(chainSelectorsKey);
				if (!indexes[chainSelectorsKey]) {
					indexes[chainSelectorsKey] = 0;
				}
				let i = indexes[chainSelectorsKey];
				for (; i < reqFromLines.length && i < indexes[chainSelectorsKey] + 6; i++) {
					promises.push(
						provider.getLogs({
							address: chainSelectors[chainSelectorsKey].poolAddress,
							topics: [ethersId, reqFromLines[i].ccipMessageId],
							fromBlock: 0,
							toBlock: 'latest',
						}),
					);
				}
				indexes[chainSelectorsKey] = i;
			}
			return await Promise.all(promises);
		};
		const logs1 = await getCcipLogs();
		await sleep(1000);
		const logs2 = await getCcipLogs();
		await sleep(1000);
		const logs3 = await getCcipLogs();
		return logs1.concat(logs2).concat(logs3);
	};
	const getCompletedConceroIdsByLogs = (logs, ccipLines) => {
		if (!logs?.length) return [];
		const conceroIds = [];
		for (const log of logs) {
			if (!log.length) continue;
			const ccipMessageId = log[0].topics[1];
			const ccipLine = ccipLines.find(line => line.ccipMessageId.toLowerCase() === ccipMessageId.toLowerCase());
			conceroIds.push(ccipLine.index);
		}
		return conceroIds;
	};
	const packResult = (_totalBalance, _conceroIds) => {
		const result = new Uint8Array(32 + _conceroIds.length);
		const encodedTotalBalance = Functions.encodeUint256(_totalBalance);
		result.set(encodedTotalBalance, 0);
		for (let i = 0; i < _conceroIds.length; i++) {
			const encodedConceroId = new Uint8Array([Number(_conceroIds[i])]);
			result.set(encodedConceroId, 32 + i);
		}
		return result;
	};
	let promises = [];
	let totalBalance = 0n;
	for (const chain in chainSelectors) {
		if (chain.toLowerCase() === baseChainSelector.toLowerCase()) continue;
		const provider = getProviderByChainSelector(chain);
		const erc20 = new ethers.Contract(chainSelectors[chain].usdcAddress, erc20Abi, provider);
		const pool = new ethers.Contract(chainSelectors[chain].poolAddress, poolAbi, provider);
		promises.push(erc20.balanceOf(chainSelectors[chain].poolAddress));
		promises.push(pool.s_loansInUse());
	}
	promises.push(getBaseDepositsOneTheWayArray());
	const results = await Promise.all(promises);
	for (let i = 0; i < results.length - 2; i += 2) {
		totalBalance += BigInt(results[i]) + BigInt(results[i + 1]);
	}
	const depositsOnTheWayArray = results[results.length - 1];
	const depositsOnTheWay = depositsOnTheWayArray.reduce((acc, [chainSelector, ccipMessageId, amount], index) => {
		if (ccipMessageId !== '0x0000000000000000000000000000000000000000000000000000000000000000') {
			acc.push({index, chainSelector, ccipMessageId, amount});
		}
		return acc;
	}, []);
	let conceroIds = [];
	if (depositsOnTheWay.length) {
		const logs = await getChildPoolsCcipLogs(depositsOnTheWay);
		conceroIds = getCompletedConceroIdsByLogs(logs, depositsOnTheWay);
	}
	return packResult(totalBalance, conceroIds);
})();
