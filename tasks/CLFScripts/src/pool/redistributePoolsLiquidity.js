(async () => {
	try {
		const [_, __, ___, newPoolChainSelector, distributeLiquidityRequestId, distributionType, chainId] = bytesArgs;
		const chainsMapTestnet = {
			['${CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA}']: {
				urls: ['https://arbitrum-sepolia-rpc.publicnode.com'],
				chainId: '0x66eee',
				usdcAddress: '${USDC_ARBITRUM_SEPOLIA}',
				poolAddress: '${CHILD_POOL_PROXY_ARBITRUM_SEPOLIA}',
			},
			// ['${CL_CCIP_CHAIN_SELECTOR_FUJI}']: {
			// 	urls: ['https://avalanche-fuji-c-chain-rpc.publicnode.com'],
			// 	chainId: '0xa869',
			// 	usdcAddress: '${USDC_FUJI}',
			// 	poolAddress: '${CHILD_POOL_PROXY_FUJI}',
			// },
			['${CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA}']: {
				urls: ['https://base-sepolia-rpc.publicnode.com'],
				chainId: '0x14a34',
				usdcAddress: '${USDC_BASE_SEPOLIA}',
				poolAddress: '${PARENT_POOL_PROXY_BASE_SEPOLIA}',
			},
		};
		const chainsMapMainnet = {
			['${CL_CCIP_CHAIN_SELECTOR_ARBITRUM}']: {
				urls: [
					`https://arbitrum-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`,
					'https://arbitrum.blockpi.network/v1/rpc/public',
					'https://arbitrum-rpc.publicnode.com',
				],
				chainId: '0xa4b1',
				usdcAddress: '${USDC_ARBITRUM}',
				poolAddress: '${CHILD_POOL_PROXY_ARBITRUM}',
			},
			['${CL_CCIP_CHAIN_SELECTOR_POLYGON}']: {
				urls: [
					`https://polygon-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`,
					'https://polygon.blockpi.network/v1/rpc/public',
					'https://polygon-bor-rpc.publicnode.com',
				],
				chainId: '0x89',
				usdcAddress: '${USDC_POLYGON}',
				poolAddress: '${CHILD_POOL_PROXY_POLYGON}',
			},
			['${CL_CCIP_CHAIN_SELECTOR_AVALANCHE}']: {
				urls: [
					`https://avalanche-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`,
					'https://avalanche.blockpi.network/v1/rpc/public',
					'https://avalanche-c-chain-rpc.publicnode.com',
				],
				chainId: '0xa86a',
				usdcAddress: '${USDC_AVALANCHE}',
				poolAddress: '${CHILD_POOL_PROXY_AVALANCHE}',
			},
			['${CL_CCIP_CHAIN_SELECTOR_BASE}']: {
				urls: [
					`https://base-mainnet.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`,
					'https://base.blockpi.network/v1/rpc/public',
					'https://base-rpc.publicnode.com',
				],
				chainId: '0x2105',
				usdcAddress: '${USDC_BASE}',
				poolAddress: '${PARENT_POOL_PROXY_BASE}',
			},
			['${CL_CCIP_CHAIN_SELECTOR_OPTIMISM}']: {
				urls: [
					'https://optimism-rpc.publicnode.com',
					'https://rpc.ankr.com/optimism',
					'https://optimism.drpc.org',
				],
				chainId: '0xa',
				usdcAddress: '${USDC_OPTIMISM}',
				poolAddress: '${CHILD_POOL_PROXY_OPTIMISM}',
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
			// const signer = getSignerByChainSelector(newPoolChainSelector);
			// const poolContract = new ethers.Contract(chainsMap[newPoolChainSelector].poolAddress, poolAbi, signer);
			// await poolContract.liquidatePool(distributeLiquidityRequestId);
			//
			// return Functions.encodeUint256(1n);
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
