import { task } from "hardhat/config";
import conceroNetworks from "../../constants/conceroNetworks";

task("test-script", "A test script").setAction(async taskArgs => {
  console.log(hre.network.name);
  const chain = conceroNetworks[hre.network.name];

  console.log("Running test-script");
});

export default {};
