try {
	const ethers = await import('https://raw.githubusercontent.com/ethers-io/ethers.js/v6.10.0/dist/ethers.min.js');
	const c = BigInt(bytesArgs[1]) === 1n ? secrets.DST_JS : secrets.SRC_JS;
	const h = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(c));
	const r = Array.from(new Uint8Array(h))
		.map(b => ('0' + b.toString(16)).slice(-2).toLowerCase())
		.join('');
	const b = bytesArgs[0].toLowerCase();
	if ('0x' + r === b) return await eval(c);
	throw new Error(`0x${r} != ${b}`);
} catch (e) {
	throw new Error(e.message.slice(0, 255));
}
