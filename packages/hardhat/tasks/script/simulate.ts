import { task } from "hardhat/config";
import fs from "fs";
import secrets from "../../constants/CLFSecrets";
import CLFSimulationConfig from "../../constants/CLFSimulationConfig";
import { execSync } from "child_process";

const { simulateScript, decodeResult } = require("@chainlink/functions-toolkit");

const path = require("path");
const process = require("process");

async function simulate(pathToFile, args) {
  if (!fs.existsSync(pathToFile)) return console.error(`File not found: ${pathToFile}`);
  console.log("Simulating script:", pathToFile);

  const { responseBytesHexstring, errorString, capturedTerminalOutput } = await simulateScript({
    source: fs.readFileSync(pathToFile, "utf8"),
    bytesArgs: args,
    secrets,
    ...CLFSimulationConfig,
  });
  if (errorString) {
    console.log("CAPTURED ERROR:");
    console.log(errorString);
  }

  if (capturedTerminalOutput) {
    console.log("CAPTURED TERMINAL OUTPUT:");
    console.log(capturedTerminalOutput);
  }

  if (responseBytesHexstring) {
    console.log("RESPONSE BYTES HEXSTRING:");
    console.log(responseBytesHexstring);
    console.log("RESPONSE BYTES DECODED:");
    // console.log(decodeResult(responseBytesHexstring, "uint256"));
  }
}

/* run with: bunx hardhat clf-simulate-script */
task("clf-script-simulate", "Executes the JavaScript source code locally")
  // .addOptionalParam("path", "Path to script file", `${__dirn ame}/../Functions-request-config.js`, types.string)
  .setAction(async (taskArgs, hre) => {
    execSync(`bunx hardhat clf-script-build --all`, { stdio: "inherit" });

    // await simulate(path.join(__dirname, "../", "./CLFScripts/dist/eval.min.js"), [
    //   "0x387496908b17af80df7e0029e55b562af3dcdac3db84a04ffabce629fd87474a", // srcJsHashSum
    //   "0x47194641c621f2e78f919eb37feffb32b594e300c567750c7f4424dc07d2d049", // ethers hash sum
    //   "0x0",
    //   process.env.CONCEROCCIP_OPTIMISM_SEPOLIA, // contractAddress
    //   "0x5315f93154194ca637615651c5662cf39a77308927ebe7d31c9e970958681a49", // ccipMessageId
    //   "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // sender
    //   "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // recipient
    //   "0x" + 100000000000000000n.toString(16), // amount
    //   "0x" + BigInt(process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA).toString(16), // srcChainSelector
    //   "0x" + BigInt(process.env.CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA).toString(16), // dstChainSelector
    //   "0x" + 0n.toString(16), // token
    //   "0xA65233", // blockNumber
    // ]);

    await simulate(path.join(__dirname, "../", "./CLFScripts/dist/eval.min.js"), [
      "0xd374600ba406e9ca63bdba9dbc4d5e3eaec0fab8f5fbbf72eab9a165eb5c04f4",
      "0x47194641c621f2e78f919eb37feffb32b594e300c567750c7f4424dc07d2d049", // ethers hash sum
      "0x1",
      process.env.CONCEROCCIP_BASE_SEPOLIA, // srcContractAddress
      "0x" + BigInt(process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA).toString(16), // srcChainSelector, chain to get logs from
      "0x92DA49", // blockNumber
      // event params:
      "0xc957703fb298a67ab8077f691dbf4cdb137be8fd39bd4afab67ef847f99a74c8", // messageId
      "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // sender
      "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // recipient
      "0x" + 0n.toString(16), // token
      "0x" + 40000000000000000n.toString(16), // amount
      "0x" + 5224473277236331295n.toString(16), // dstChainSelector
    ]);
  });

export default {};
