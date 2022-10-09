import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("GiftBox", function () {
  const deployContractFixture = async () => {
    const [owner, fundManager, donor1, donor2] = await ethers.getSigners();
    // Deploy a generic ERC20 token to be used as stablecoin for testing
    const TestStableCoin = await ethers.getContractFactory("TestStableCoin");
    const testStableCoin = await TestStableCoin.deploy();

    const GiftBox = await ethers.getContractFactory("GiftBox");
    // Pass the address of stablecoin contract while deploying GiftBox
    const giftBox = await GiftBox.deploy(testStableCoin.address);

    return { giftBox, testStableCoin, fundManager, donor1, donor2 };
  };

  const createFundFixture = async () => {
    const { giftBox, testStableCoin, donor1, donor2 } =
      await deployContractFixture();
    const tx = await giftBox.createFund(
      "Fund 1",
      "Just a test fund",
      "SUMIT",
      []
    );
    const txReceipt = await tx.wait();
    const fundTokenAddress: string =
      txReceipt.events?.at(1)?.args?.fundTokenAddress;

    // Mint 10k stable coins to each donor
    await testStableCoin.mint(donor1.address, 10000);
    await testStableCoin.mint(donor2.address, 10000);

    return {
      giftBox,
      fundTokenAddress,
      donor1,
      donor2,
      testStableCoin,
    };
  };

  describe("Create Fund", () => {
    it("can create fund", async function () {
      const { giftBox } = await loadFixture(deployContractFixture);

      const tx = await giftBox.createFund(
        "Fund 1",
        "Just a test fund",
        "SUMIT",
        []
      );
      const txReceipt = await tx.wait();
      const fundTokenAddress: string =
        txReceipt.events?.at(1)?.args?.fundTokenAddress;

      await expect(tx).not.to.be.reverted;
      await expect(tx)
        .to.emit(giftBox, "CreateFund")
        .withArgs(fundTokenAddress, "Fund 1", "Just a test fund", "SUMIT", []);
    });
  });

  describe("Deposit Stablecoins", () => {
    it("can deposit stablecoins to a fund", async function () {
      const { giftBox, fundTokenAddress, donor1, testStableCoin } =
        await loadFixture(createFundFixture);

      // Donor approves GiftBox to spend 100 stablecoins
      await testStableCoin.connect(donor1).approve(giftBox.address, 100);
      // Donor deposits 100 stablecoins to GiftBox
      const tx = await giftBox
        .connect(donor1)
        .depositStableCoins(fundTokenAddress, 100);

      await expect(tx).not.to.be.reverted;
      await expect(tx)
        .to.emit(giftBox, "DepositStableCoins")
        .withArgs(fundTokenAddress, 100);

      const GiftBoxFundToken = await ethers.getContractFactory(
        "GiftBoxFundToken"
      );
      const fundToken = GiftBoxFundToken.attach(fundTokenAddress);

      // Ensure GiftBox received stablecoin and donor got fund tokens
      expect(await testStableCoin.balanceOf(giftBox.address)).to.equal(100);
      expect(await fundToken.balanceOf(donor1.address)).to.equal(100);
    });
  });
});
