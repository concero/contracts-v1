const ethers = await import('npm:ethers@6.10.0');
const [srcContractAddress, srcChainSelector, _, ...eventArgs] = args;
const messageId = eventArgs[0];
const chainMap = {
	'${CL_CCIP_CHAIN_SELECTOR_FUJI}': {
		url: `https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`,
	},
	'${CL_CCIP_CHAIN_SELECTOR_SEPOLIA}': {
		url: `https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
	},
	'${CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA}': {
		url: `https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
	},
	'${CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA}': {
		url: `https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`,
	},
	'${CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA}': {
		url: `https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
	},
};

const latestBlockParams = {
	url: chainMap[srcChainSelector].url,
	method: 'POST',
	headers: {
		'Content-Type': 'application/json',
	},
	data: {
		jsonrpc: '2.0',
		method: 'eth_blockNumber',
		id: 1,
	},
};
const {data: latestBlockData} = await Functions.makeHttpRequest(latestBlockParams);

if (latestBlockData.error) {
	throw new Error(latestBlockData.error.message);
}

if (!latestBlockData.result.length) {
	throw new Error('Latest block not found');
}

const toBlock = latestBlockData.result;
const fromBlock = BigInt(toBlock) - 1000n;
const params = {
	url: chainMap[srcChainSelector].url,
	method: 'POST',
	headers: {
		'Content-Type': 'application/json',
	},
	data: {
		jsonrpc: '2.0',
		method: 'eth_getLogs',
		id: 1,
		params: [
			{
				address: srcContractAddress,
				topics: [null, messageId],
				fromBlock: `0x${fromBlock.toString(16)}`,
				toBlock: 'latest',
			},
		],
	},
};
const {data} = await Functions.makeHttpRequest(params);

if (data.error) {
	throw new Error(data.error.message);
}

if (!data.result.length) {
	throw new Error('Logs not found');
}

const abi = ['event CCIPSent(bytes32 indexed, address, address, uint8, uint256, uint64)'];
const contract = new ethers.Interface(abi);
const log = {
	topics: [ethers.id('CCIPSent(bytes32,address,address,uint8,uint256,uint64)'), data.result[0].topics[1]],
	data: data.result[0].data,
};
const decodedLog = contract.parseLog(log);
for (let i = 0; i < decodedLog.length; i++) {
	if (decodedLog.args[i].toString().toLowerCase() !== eventArgs[i].toString().toLowerCase()) {
		throw new Error('Message ID does not match the event log');
	}
}
return Functions.encodeUint256(BigInt(messageId));
