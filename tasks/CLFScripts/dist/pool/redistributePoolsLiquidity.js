(async () => {
	try {
		const [_, __, ___, newPoolChainSelector, distributeLiquidityRequestId, distributionType, chainId] = bytesArgs;
		const chainsMapTestnet = {
			['3478487238524512106']: {
				urls: ['https://arbitrum-sepolia-rpc.publicnode.com'],
				chainId: '0x66eee',
				usdcAddress: '0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d',
				poolAddress: '0x9c561A2D0Cb9bCe69a95F48cdcEbf0FAE14013B2',
			},
			['10344971235874465080']: {
				urls: ['https://base-sepolia-rpc.publicnode.com'],
				chainId: '0x14a34',
				usdcAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
				poolAddress: '0x64CD83B03Ce68E2110A8A4A821AF053D193E881C',
			},
		};
		const chainsMapMainnet = {
			['4949039107694359620']: {
				urls: [
					`https://arbitrum-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`,
					'https://arbitrum.blockpi.network/v1/rpc/public',
					'https://arbitrum-rpc.publicnode.com',
				],
				chainId: '0xa4b1',
				usdcAddress: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
				poolAddress: '0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d',
			},
			['4051577828743386545']: {
				urls: [
					`https://polygon-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`,
					'https://polygon.blockpi.network/v1/rpc/public',
					'https://polygon-bor-rpc.publicnode.com',
				],
				chainId: '0x89',
				usdcAddress: '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
				poolAddress: '0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d',
			},
			['6433500567565415381']: {
				urls: [
					`https://avalanche-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`,
					'https://avalanche.blockpi.network/v1/rpc/public',
					'https://avalanche-c-chain-rpc.publicnode.com',
				],
				chainId: '0xa86a',
				usdcAddress: '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E',
				poolAddress: '0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d',
			},
			['15971525489660198786']: {
				urls: [
					`https://base-mainnet.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`,
					'https://base.blockpi.network/v1/rpc/public',
					'https://base-rpc.publicnode.com',
				],
				chainId: '0x2105',
				usdcAddress: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
				poolAddress: '0x0AE1B2730066AD46481ab0a5fd2B5893f8aBa323',
			},
			['3734403246176062136']: {
				urls: [
					'https://optimism-rpc.publicnode.com',
					'https://rpc.ankr.com/optimism',
					'https://optimism.drpc.org',
				],
				chainId: '0xa',
				usdcAddress: '0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85',
				poolAddress: '0x8698c6DF1E354Ce3ED0dE508EF7AF4baB85D2F2D',
			},
		};
		let chainsMap;
		const chainIdNumber = parseInt(chainId, 16);
		if (chainIdNumber === 84532) {
			chainsMap = chainsMapTestnet;
		} else if (chainIdNumber === 8453) {
			chainsMap = chainsMapMainnet;
		} else {
			throw new Error(`Wrong chain id ${chainIdNumber}`);
		}
		const erc20Abi = ['function balanceOf(address) external view returns (uint256)'];
		const poolAbi = [
			'function s_loansInUse() external view returns (uint256)',
			'function distributeLiquidity(uint64, uint256, bytes32) external',
			'function liquidatePool(bytes32) external',
		];
		const chainSelectorsArr = Object.keys(chainsMap);
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
		const getProviderByChainSelector = _chainSelector => {
			const url =
				chainsMap[_chainSelector].urls[Math.floor(Math.random() * chainsMap[_chainSelector].urls.length)];
			return new FunctionsJsonRpcProvider(url);
		};
		const getSignerByChainSelector = _chainSelector => {
			const provider = getProviderByChainSelector(_chainSelector);
			const wallet = new ethers.Wallet('0x' + secrets.POOL_MESSENGER_0_PRIVATE_KEY, provider);
			return wallet.connect(provider);
		};
		if (distributionType === '0x00') {
			const getPoolsBalances = async () => {
				const getBalancePromises = [];
				for (const chain in chainsMap) {
					if (BigInt(chain) === BigInt(newPoolChainSelector)) continue;
					const provider = getProviderByChainSelector(chain);
					const erc20 = new ethers.Contract(chainsMap[chain].usdcAddress, erc20Abi, provider);
					const pool = new ethers.Contract(chainsMap[chain].poolAddress, poolAbi, provider);
					getBalancePromises.push(erc20.balanceOf(chainsMap[chain].poolAddress));
					getBalancePromises.push(pool.s_loansInUse());
				}
				const results = await Promise.all(getBalancePromises);
				const balances = {};
				for (let i = 0, k = 0; i < results.length; i += 2, k++) {
					balances[chainSelectorsArr[k]] = BigInt(results[i]) + BigInt(results[i + 1]);
				}
				return balances;
			};
			const poolsBalances = await getPoolsBalances();
			const poolsTotalBalance = chainSelectorsArr.reduce((acc, pool) => {
				if (BigInt(pool) === BigInt(newPoolChainSelector)) return acc;
				return acc + BigInt(poolsBalances[pool]);
			}, 0n);
			const newPoolsCount = BigInt(Object.keys(chainsMap).length + 1);
			const newPoolBalance = poolsTotalBalance / newPoolsCount;
			const distributeAmountPromises = [];
			for (const chain in chainsMap) {
				if (BigInt(chain) === BigInt(newPoolChainSelector)) continue;
				const signer = getSignerByChainSelector(chain);
				const poolContract = new ethers.Contract(chainsMap[chain].poolAddress, poolAbi, signer);
				const amountToDistribute = poolsBalances[chain] - newPoolBalance;
				distributeAmountPromises.push(
					poolContract.distributeLiquidity(
						newPoolChainSelector,
						amountToDistribute,
						distributeLiquidityRequestId,
					),
				);
			}
			await Promise.all(distributeAmountPromises);
			return Functions.encodeUint256(1n);
		} else if (distributionType === '0x01') {
		}
		throw new Error('Invalid distribution type');
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
