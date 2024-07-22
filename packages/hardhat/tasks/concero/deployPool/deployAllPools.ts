import { task, types } from "hardhat/config";
import { execSync } from "child_process";
import { liveChains } from "../liveChains";

const executeCommand = (command: string) => {
  execSync(command, { stdio: "inherit" });
};

task("deploy-all-pools", "Deploy all pool")
  .addOptionalParam("slotid", "DON-Hosted secrets slot id", 0, types.int)
  .addFlag("mainnet", "is CLF_SUBID_BASE_SEPOLIA deploy")
  .setAction(async taskArgs => {
    const slotId = parseInt(taskArgs.slotid);
    const parentPoolNetwork = taskArgs.mainnet ? "base" : "baseSepolia";

    executeCommand(`yarn hardhat clean`);

    executeCommand(
      `yarn hardhat deploy-parent-pool --network ${parentPoolNetwork} --slotid ${slotId} --deployproxy --skipdeploy --skipsetvars`,
    );

    executeCommand(`yarn hardhat deploy-automations --network ${parentPoolNetwork} --slotid ${slotId}`);

    for (const chain of liveChains) {
      if (chain.name === "base" || chain.name === "baseSepolia") continue;
      executeCommand(`yarn hardhat deploy-child-pool --network ${chain.name} --deployproxy --skipdeploy --skipsetvars`);
    }

    for (const chain of liveChains) {
      if (chain.name === "base" || chain.name === "baseSepolia") continue;
      executeCommand(`yarn hardhat deploy-child-pool --network ${chain.name}`);
    }

    executeCommand(`yarn hardhat deploy-lp-token --network ${parentPoolNetwork}`);

    executeCommand(`yarn hardhat deploy-parent-pool --network ${parentPoolNetwork} --slotid ${slotId}`);
  });

export default {};