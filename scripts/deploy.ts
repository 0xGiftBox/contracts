import { ethers } from "hardhat";

const main = async () => {
  const GiftBox = await ethers.getContractFactory("GiftBox");
  const giftBox = await GiftBox.deploy(
    "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"
  );
  await giftBox.deployed();

  console.log("GiftBox contract deployed at", giftBox.address);
};

// Run async main
main().catch((error) => {
  console.error(error);
  process.exit(1);
});
