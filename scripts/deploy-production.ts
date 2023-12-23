import hre from "hardhat";

async function main() {
  const solidgrowth_instance = await hre.viem.deployContract("SolidGrowth", ["0x55d398326f99059ff775485246999027b3197955"]); // address USDT

  console.log(`SolidGrowth deployed to: ${solidgrowth_instance.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
