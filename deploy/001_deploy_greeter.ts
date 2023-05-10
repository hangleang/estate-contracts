import { DeployFunction } from "hardhat-deploy/types";

import { VERIFICATION_BLOCK_CONFIRMATIONS } from "../utils/constants";

const func: DeployFunction = async ({ getNamedAccounts, deployments, network, run }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const isDev = !network.live;
  const waitConfirmations = network.live ? VERIFICATION_BLOCK_CONFIRMATIONS : undefined;

  if (isDev) {
    // deploy mocks/test contract
  } else {
    // set external contract address
  }

  // the following will only deploy "Greeter" if the contract was never deployed or if the code changed since last deployment
  const args = ["Hello, World!"];
  const greeter = await deploy("Greeter", {
    from: deployer,
    args,
    log: true,
    autoMine: isDev,
    waitConfirmations,
  });

  // Verify the deployment
  if (!isDev) {
    log("Verifying...");
    await run("verify:verify", {
      address: greeter.address,
      constructorArguments: args,
    });
  }
};

export default func;
func.tags = ["all", "Greeter"];
func.dependencies = []; // this contains dependencies tags need to execute before deploy this contract
