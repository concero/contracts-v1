/*
Simulation requirements:
numAllowedQueries: 2 – a minimum to initialise Viem.
 */
// todo: convert var names to single characters
/*BUILD_REMOVES_EVERYTHING_ABOVE_THIS_LINE*/

(async () => {
	const [_, __, ___, dstContractAddress, conceroMessageId, srcChainSelector, dstChainSelector, txDataHash] =
		bytesArgs;
	const messengers = [
		secrets.MESSENGER_0_PRIVATE_KEY,
		secrets.MESSENGER_1_PRIVATE_KEY,
		secrets.MESSENGER_2_PRIVATE_KEY,
	];
	const chainSelectors = {
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_FUJI}').toString(16)}`]: {
			urls: [`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`],
			chainId: '0xa869',
			nativeCurrency: 'avax',
			priceFeed: {
				linkUsd: '',
				usdcUsd: '',
				nativeUsd: '',
				linkNative: '',
				maticUsd: '',
				ethUsd: '',
			},
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_SEPOLIA}').toString(16)}`]: {
			urls: [
				`https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://ethereum-sepolia-rpc.publicnode.com',
			],
			chainId: '0xaa36a7',
			nativeCurrency: 'eth',
			priceFeed: {
				linkUsd: '',
				usdcUsd: '',
				nativeUsd: '',
				linkNative: '',
			},
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA}').toString(16)}`]: {
			urls: [
				`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://arbitrum-sepolia-rpc.publicnode.com',
			],
			chainId: '0x66eee',
			nativeCurrency: 'eth',
			priceFeed: {
				linkUsd: '${LINK_USD_PRICEFEED_ARBITRUM_SEPOLIA}',
				usdcUsd: '${USDC_USD_PRICEFEED_ARBITRUM_SEPOLIA}',
				nativeUsd: '${NATIVE_USD_PRICEFEED_ARBITRUM_SEPOLIA}',
				linkNative: '${LINK_NATIVE_PRICEFEED_ARBITRUM_SEPOLIA}',
			},
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA}').toString(16)}`]: {
			urls: [
				`https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`,
				'https://base-sepolia-rpc.publicnode.com',
			],
			chainId: '0x14a34',
			nativeCurrency: 'eth',
			priceFeed: {
				linkUsd: '${LINK_USD_PRICEFEED_BASE_SEPOLIA}',
				usdcUsd: '${USDC_USD_PRICEFEED_BASE_SEPOLIA}',
				nativeUsd: '${NATIVE_USD_PRICEFEED_BASE_SEPOLIA}',
				linkNative: '${LINK_NATIVE_PRICEFEED_BASE_SEPOLIA}',
				// maticUsd: '${MATIC_USD_PRICEFEED_BASE}',
				// avaxUsd: '${AVAX_USD_PRICEFEED_BASE}',
			},
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA}').toString(16)}`]: {
			urls: [
				`https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://optimism-sepolia-rpc.publicnode.com',
			],
			chainId: '0xaa37dc',
			nativeCurrency: 'eth',
			priceFeed: {
				linkUsd: '${LINK_USD_PRICEFEED_OPTIMISM_SEPOLIA}',
				usdcUsd: '${USDC_USD_PRICEFEED_OPTIMISM_SEPOLIA}',
				nativeUsd: '${NATIVE_USD_PRICEFEED_OPTIMISM_SEPOLIA}',
				linkNative: '${LINK_NATIVE_PRICEFEED_OPTIMISM_SEPOLIA}',
			},
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_POLYGON_AMOY}').toString(16)}`]: {
			urls: [
				`https://polygon-amoy.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://polygon-amoy-bor-rpc.publicnode.com',
			],
			chainId: '0x13882',
			nativeCurrency: 'matic',
			priceFeed: {
				linkUsd: '${LINK_USD_PRICEFEED_POLYGON_AMOY}',
				usdcUsd: '${USDC_USD_PRICEFEED_POLYGON_AMOY}',
				nativeUsd: '${NATIVE_USD_PRICEFEED_POLYGON_AMOY}',
				linkNative: '${LINK_NATIVE_PRICEFEED_POLYGON_AMOY}',
				ethUsd: '${ETH_USD_PRICEFEED_POLYGON_AMOY}',
			},
		},

		// mainnets

		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_BASE}').toString(16)}`]: {
			urls: ['https://base-rpc.publicnode.com', 'https://rpc.ankr.com/base'],
			chainId: '0x2105',
			nativeCurrency: 'eth',
			priceFeed: {
				linkUsd: '${LINK_USD_PRICEFEED_BASE}',
				usdcUsd: '${USDC_USD_PRICEFEED_BASE}',
				nativeUsd: '${NATIVE_USD_PRICEFEED_BASE}',
				linkNative: '${LINK_NATIVE_PRICEFEED_BASE}',
				maticUsd: '${MATIC_USD_PRICEFEED_BASE}',
				avaxUsd: '${AVAX_USD_PRICEFEED_BASE}',
			},
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_ARBITRUM}').toString(16)}`]: {
			urls: ['https://arbitrum-rpc.publicnode.com', 'https://rpc.ankr.com/arbitrum'],
			chainId: '0xa4b1',
			nativeCurrency: 'eth',
			priceFeed: {
				linkUsd: '${LINK_USD_PRICEFEED_ARBITRUM}',
				usdcUsd: '${USDC_USD_PRICEFEED_ARBITRUM}',
				nativeUsd: '${NATIVE_USD_PRICEFEED_ARBITRUM}',
				linkNative: '${LINK_NATIVE_PRICEFEED_ARBITRUM}',
			},
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_POLYGON}').toString(16)}`]: {
			urls: ['https://polygon-bor-rpc.publicnode.com', 'https://rpc.ankr.com/polygon'],
			chainId: '0x89',
			nativeCurrency: 'matic',
			priceFeed: {
				linkUsd: '${LINK_USD_PRICEFEED_POLYGON}',
				usdcUsd: '${USDC_USD_PRICEFEED_POLYGON}',
				nativeUsd: '${NATIVE_USD_PRICEFEED_POLYGON}',
				linkNative: '${LINK_NATIVE_PRICEFEED_POLYGON}',
				ethUsd: '${ETH_USD_PRICEFEED_POLYGON}',
				avaxUsd: '${AVAX_USD_PRICEFEED_POLYGON}',
			},
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_AVALANCHE}').toString(16)}`]: {
			urls: ['https://avalanche-c-chain-rpc.publicnode.com', 'https://rpc.ankr.com/avalanche'],
			chainId: '0xa86a',
			nativeCurrency: 'avax',
			priceFeed: {
				linkUsd: '${LINK_USD_PRICEFEED_AVALANCHE}',
				usdcUsd: '${USDC_USD_PRICEFEED_AVALANCHE}',
				nativeUsd: '${NATIVE_USD_PRICEFEED_AVALANCHE}',
				linkNative: '${LINK_NATIVE_PRICEFEED_AVALANCHE}',
				ethUsd: '${ETH_USD_PRICEFEED_AVALANCHE}',
				maticUsd: '${MATIC_USD_PRICEFEED_AVALANCHE}',
			},
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_OPTIMISM}').toString(16)}`]: {
			urls: ['https://optimism-rpc.publicnode.com', 'https://rpc.ankr.com/optimism', 'https://optimism.drpc.org'],
			chainId: '0xa',
			nativeCurrency: 'eth',
			priceFeed: {
				linkUsd: '${LINK_USD_PRICEFEED_OPTIMISM}',
				usdcUsd: '${USDC_USD_PRICEFEED_OPTIMISM}',
				nativeUsd: '${NATIVE_USD_PRICEFEED_OPTIMISM}',
				linkNative: '${LINK_NATIVE_PRICEFEED_OPTIMISM}',
				ethUsd: '${ETH_USD_PRICEFEED_OPTIMISM}',
				maticUsd: '${MATIC_USD_PRICEFEED_OPTIMISM}',
			},
		},
	};
	const UINT256_BYTES_LENGTH = 32;
	const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
	const getPercent = (value, percent) => (BigInt(value) * BigInt(percent)) / 100n;
	const getPriceRates = async (provider, chainSelector) => {
		const priceFeedsAbi = [
			'function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80)',
		];

		const linkUsdContract = new ethers.Contract(
			chainSelectors[chainSelector].priceFeed.linkUsd,
			priceFeedsAbi,
			provider,
		);
		const usdcUsdContract = new ethers.Contract(
			chainSelectors[chainSelector].priceFeed.usdcUsd,
			priceFeedsAbi,
			provider,
		);
		const nativeUsdContract = new ethers.Contract(
			chainSelectors[chainSelector].priceFeed.nativeUsd,
			priceFeedsAbi,
			provider,
		);
		const linkNativeContract = new ethers.Contract(
			chainSelectors[chainSelector].priceFeed.linkNative,
			priceFeedsAbi,
			provider,
		);

		const promises = [
			linkUsdContract.latestRoundData(),
			usdcUsdContract.latestRoundData(),
			nativeUsdContract.latestRoundData(),
			linkNativeContract.latestRoundData(),
		];

		const promiseUndefined = async () => {
			return new Promise(resolve => {
				resolve(undefined);
			});
		};

		if (chainSelectors[chainSelector].priceFeed.maticUsd) {
			const maticUsdContract = new ethers.Contract(
				chainSelectors[chainSelector].priceFeed.maticUsd,
				priceFeedsAbi,
				provider,
			);
			promises.push(maticUsdContract.latestRoundData());
		} else {
			promises.push(promiseUndefined());
		}
		if (chainSelectors[chainSelector].priceFeed.ethUsd) {
			const ethUsdContract = new ethers.Contract(
				chainSelectors[chainSelector].priceFeed.ethUsd,
				priceFeedsAbi,
				provider,
			);
			promises.push(ethUsdContract.latestRoundData());
		} else {
			promises.push(promiseUndefined());
		}
		if (chainSelectors[chainSelector].priceFeed.avaxUsd) {
			const avaxUsdContract = new ethers.Contract(
				chainSelectors[chainSelector].priceFeed.avaxUsd,
				priceFeedsAbi,
				provider,
			);
			promises.push(avaxUsdContract.latestRoundData());
		} else {
			promises.push(promiseUndefined());
		}

		const [linkUsd, usdcUsd, nativeUsd, linkNative, maticUsd, ethUsd, avaxUsd] = await Promise.all(promises);

		return {
			linkUsdc: linkUsd[1] > 0n ? (linkUsd[1] * 10n ** 18n) / usdcUsd[1] : 0n,
			nativeUsdc: nativeUsd[1] > 0n ? (nativeUsd[1] * 10n ** 18n) / usdcUsd[1] : 0n,
			linkNative: linkNative[1] > 0 ? linkNative[1] : 0n,
			nativeUsd: nativeUsd[1] > 0 ? nativeUsd[1] : 0n,
			maticUsd: maticUsd ? maticUsd[1] : undefined,
			ethUsd: ethUsd ? ethUsd[1] : undefined,
			avaxUsd: avaxUsd ? avaxUsd[1] : undefined,
		};
	};
	const constructResult = items => {
		const encodedValues = items.map(value => Functions.encodeUint256(BigInt(value)));
		const totalLength = encodedValues.length * UINT256_BYTES_LENGTH;
		const result = new Uint8Array(totalLength);

		let offset = 0;
		for (const encoded of encodedValues) {
			result.set(encoded, offset);
			offset += UINT256_BYTES_LENGTH;
		}

		return result;
	};
	const getDstGasPriceInSrcCurrency = (_gasPrice, srcPriceFeeds) => {
		const getGasPriceByPriceFeeds = (nativeUsdPriceFeed, dstAssetUsdPriceFeed, gasPriceInDstCurrency) => {
			if (dstAssetUsdPriceFeed === undefined) return 1n;

			const srcNativeDstNativeRate = nativeUsdPriceFeed / dstAssetUsdPriceFeed;
			if (BigInt(srcNativeDstNativeRate) === 0n) return 1n;

			const dstGasPriceInSrcCurrency = gasPriceInDstCurrency / srcNativeDstNativeRate;

			return dstGasPriceInSrcCurrency < 1n ? 1n : dstGasPriceInSrcCurrency;
		};

		const srcNativeCurrency = chainSelectors[srcChainSelector].nativeCurrency;
		const dstNativeCurrency = chainSelectors[dstChainSelector].nativeCurrency;

		if (srcNativeCurrency !== dstNativeCurrency) {
			return getGasPriceByPriceFeeds(
				srcPriceFeeds.nativeUsd,
				srcPriceFeeds[`${dstNativeCurrency}Usd`],
				_gasPrice,
			);
		}

		return _gasPrice;
	};

	let nonce = 0;
	let retries = 0;
	let gasPrice;
	let maxPriorityFeePerGas;
	let maxFeePerGas;

	const sendTransaction = async (contract, signer, txOptions) => {
		try {
			if ((await contract.s_transactions(conceroMessageId))[0] !== ethers.ZeroHash) return;

			await contract.addUnconfirmedTX(conceroMessageId, srcChainSelector, txDataHash, txOptions);
		} catch (err) {
			const {message, code} = err;
			if (retries >= 5) {
				throw new Error('retries reached the limit ' + err.message?.slice(0, 200));
			} else if (code === 'NONCE_EXPIRED' || message?.includes('replacement fee too low')) {
				await sleep(1000 + Math.random() * 1500);
				retries++;
				await sendTransaction(contract, signer, {
					...txOptions,
					nonce: nonce++,
				});
			} else if (code === 'UNKNOWN_ERROR' && message?.includes('already known')) {
				return;
			} else {
				throw new Error(err.message?.slice(0, 255));
			}
		}
	};
	try {
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
					const _chainId = chainSelectors[srcChainSelector].urls.includes(this.url)
						? chainSelectors[srcChainSelector].chainId
						: chainSelectors[dstChainSelector].chainId;
					return [{jsonrpc: '2.0', id: payload.id, result: _chainId}];
				}
				let resp = await fetch(this.url, {
					method: 'POST',
					headers: {'Content-Type': 'application/json'},
					body: JSON.stringify(payload),
				});
				const res = await resp.json();
				if (res.length === undefined) {
					return [res];
				}
				return res;
			}
		}
		const dstUrl =
			chainSelectors[dstChainSelector].urls[
				Math.floor(Math.random() * chainSelectors[dstChainSelector].urls.length)
			];
		const provider = new FunctionsJsonRpcProvider(dstUrl);
		const messengerPrivateKey = messengers[Math.floor(Math.random() * messengers.length)];
		const wallet = new ethers.Wallet('0x' + messengerPrivateKey, provider);
		const signer = wallet.connect(provider);
		const abi = [
			'function addUnconfirmedTX(bytes32, uint64, bytes32) external',
			'function s_transactions(bytes32) view returns (bytes32, address, address, uint256, uint8, uint64, bool, bytes)',
		];
		const contract = new ethers.Contract(dstContractAddress, abi, signer);
		const [feeData, nonce] = await Promise.all([
			provider.getFeeData(),
			provider.getTransactionCount(wallet.address),
		]);

		gasPrice = feeData.gasPrice + getPercent(feeData.gasPrice, 10);
		maxPriorityFeePerGas = feeData.maxPriorityFeePerGas;
		maxFeePerGas = feeData.maxFeePerGas;

		await sendTransaction(contract, signer, {
			nonce,
			maxPriorityFeePerGas: maxPriorityFeePerGas + getPercent(maxPriorityFeePerGas, 10),
			maxFeePerGas: maxFeePerGas + getPercent(maxFeePerGas, 10),
		});

		const srcUrl =
			chainSelectors[srcChainSelector].urls[
				Math.floor(Math.random() * chainSelectors[srcChainSelector].urls.length)
			];
		const srcChainProvider = new FunctionsJsonRpcProvider(srcUrl);
		const [srcFeeData, srcPriceFeeds] = await Promise.all([
			srcChainProvider.getFeeData(),
			getPriceRates(srcChainProvider, srcChainSelector),
		]);

		const dstGasPriceInSrcCurrency = getDstGasPriceInSrcCurrency(gasPrice, srcPriceFeeds);

		return constructResult([
			dstGasPriceInSrcCurrency,
			srcFeeData.gasPrice,
			dstChainSelector,
			srcPriceFeeds.linkUsdc,
			srcPriceFeeds.nativeUsdc,
			srcPriceFeeds.linkNative,
		]);
	} catch (error) {
		const {message} = error;
		if (message?.includes('Exceeded maximum of 20 HTTP queries')) {
			return new Uint8Array(1);
		} else {
			throw new Error(message?.slice(0, 255));
		}
	}
})();
