import {task, types} from 'hardhat/config';
import fs from 'fs';
import secrets from '../../constants/CLFSecrets';
import CLFSimulationConfig from '../../constants/CLFSimulationConfig';
import path from 'path';
import getSimulationArgs from './simulationArgs';
import {simulateScript} from '@chainlink/functions-toolkit';
import {log} from '../../utils';
import buildScript from './build';
import {decodeCLFResponse} from './decodeCLFResponse';

/**
 * Simulates the execution of a script with the given arguments.
 * @param scriptPath - The path to the script file to simulate.
 * @param scriptName - The name of the script to simulate.
 * @param args - The array of arguments to pass to the simulation.
 */
async function simulateCLFScript(scriptPath: string, scriptName: string, args: string[]): Promise<string | undefined> {
	if (!fs.existsSync(scriptPath)) {
		console.error(`File not found: ${scriptPath}`);
		return;
	}

	log(`Simulating ${scriptPath}`, 'simulateCLFScript');
	try {
		const result = await simulateScript({
			source: 'const ethers = await import("npm:ethers@6.10.0"); return' + fs.readFileSync(scriptPath, 'utf8'),
			bytesArgs: args,
			secrets,
			...CLFSimulationConfig,
		});

		const {errorString, capturedTerminalOutput, responseBytesHexstring} = result;

		if (errorString) {
			log(errorString, 'simulateCLFScript – Error:');
		}

		if (capturedTerminalOutput) {
			log(capturedTerminalOutput, 'simulateCLFScript – Terminal output:');
		}

		if (responseBytesHexstring) {
			log(responseBytesHexstring, 'simulateCLFScript – Response Bytes:');
			const decodedResponse = decodeCLFResponse(scriptName, responseBytesHexstring);
			if (decodedResponse) {
				log(decodedResponse, 'simulateCLFScript – Decoded Response:');
			}
			return responseBytesHexstring;
		}
	} catch (error) {
		console.error('Simulation failed:', error);
	}
}

task('clf-script-simulate', 'Executes the JavaScript source code locally')
	.addParam('name', 'Name of the function to simulate', 'pool_get_total_balance', types.string)
	.addOptionalParam('concurrency', 'Number of concurrent requests', 1, types.int)
	.setAction(async taskArgs => {
		await buildScript(true, undefined, true);

		const scriptName = taskArgs.name;
		const basePath = path.join(__dirname, '../', './CLFScripts/dist');
		let scriptPath: string;

		switch (scriptName) {
			case 'infra_src':
				scriptPath = path.join(basePath, './infra/SRC.min.js');
				break;
			case 'infra_dst':
				scriptPath = path.join(basePath, './infra/DST.min.js');
				break;
			case 'pool_get_child_pools_liquidity':
				scriptPath = path.join(basePath, './pool/getChildPoolsLiquidity.min.js');
				break;
			case 'pool_collect_liq':
				scriptPath = path.join(basePath, './pool/withdrawalLiquidityCollection.min.js');
				break;
			case 'pool_redistribute_liq':
				scriptPath = path.join(basePath, './pool/redistributePoolsLiquidity.min.js');
				break;
			default:
				console.error(`Unknown function: ${scriptName}`);
				return;
		}

		const bytesArgs = await getSimulationArgs[scriptName]();
		const concurrency = taskArgs.concurrency;
		const promises = Array.from({length: concurrency}, () => simulateCLFScript(scriptPath, scriptName, bytesArgs));
		await Promise.all(promises);
	});

export default simulateCLFScript;
