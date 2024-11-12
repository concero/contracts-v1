import {task, types} from 'hardhat/config';
import fs from 'fs';
import secrets from '../../constants/CLFSecrets';
import CLFSimulationConfig from '../../constants/CLFSimulationConfig';
import path from 'path';
import getSimulationArgs from './simulationArgs';
import {simulateScript} from '@chainlink/functions-toolkit';
import {log} from '../../utils';
import buildScript from './build';

/**
 * Simulates the execution of a script with the given arguments.
 * @param scriptPath - The path to the script file to simulate.
 * @param args - The array of arguments to pass to the simulation.
 */
async function simulateCLFScript(scriptPath: string, args: string[]): Promise<void> {
	if (!fs.existsSync(scriptPath)) {
		console.error(`File not found: ${scriptPath}`);
		return;
	}

	log(`Simulating ${scriptPath}`, 'simulateCLFScript');
	try {
		const result = await simulateScript({
			source: fs.readFileSync(scriptPath, 'utf8'),
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
		}
	} catch (error) {
		console.error('Simulation failed:', error);
	}
}

task('clf-script-simulate', 'Executes the JavaScript source code locally')
	.addParam('name', 'Name of the function to simulate', 'pool_get_total_balance', types.string)
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
			case 'pool_get_total_balance':
				scriptPath = path.join(basePath, './pool/getTotalBalance.min.js');
				break;
			case 'collect_liq':
				scriptPath = path.join(basePath, './pool/collectLiquidity.min.js');
				break;
			case 'pool_distribute_liq':
				scriptPath = path.join(basePath, './pool/distributeLiquidity.min.js');
				break;
			default:
				console.error(`Unknown function: ${scriptName}`);
				return;
		}

		const bytesArgs = await getSimulationArgs[scriptName]();
		await simulateCLFScript(scriptPath, bytesArgs);
	});

export default simulateCLFScript;
