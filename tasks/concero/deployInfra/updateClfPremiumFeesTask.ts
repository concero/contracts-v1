import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { compileContracts } from "../../../utils";
import { conceroNetworks } from "../../../constants";
import { setFunctionsPremiumFees } from "./setContractVariables";

task("update-clf-premium-fees", "Deploy the CCIP infrastructure").setAction(async taskArgs => {
  const hre: HardhatRuntimeEnvironment = require("hardhat");
  compileContracts({ quiet: true });
  const chain = conceroNetworks[hre.network.name];
  if (!chain) {
    throw new Error("Chain not found");
  }

  const { abi } = await import(
    "../../../artifacts/contracts/Libraries/InfraStorageSetters.sol/InfraStorageSetters.json"
  );

  await setFunctionsPremiumFees(chain, abi);
});

export default {};
