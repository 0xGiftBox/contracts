import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("GiftBox", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  const deployContractFixture = async () => {
    const [owner, fundManager, donor1, donor2] = await ethers.getSigners();
    // Deploy a generic ERC20 token to be used as USDC for testing
    const TestToken = await ethers.getContractFactory("TestToken");
    const testToken = await TestToken.deploy();

    const GiftBox = await ethers.getContractFactory("GiftBox");
    // Pass the address of USDC contract while deploying GiftBox
    const giftBox = await GiftBox.deploy(testToken.address);

    return { giftBox, testToken, fundManager, donor1, donor2 };
  };

  const createFundFixture = async () => {
    const { giftBox, testToken, donor1, donor2 } =
      await deployContractFixture();
    await giftBox.createFund("Fund 1", "Just a test fund", []);

    // Mint 10k tokens to each donor
    await testToken.mint(donor1.address, 10000);
    await testToken.mint(donor2.address, 10000);

    return { giftBox, fundId: 0, donor1, donor2, testToken };
  };

  describe("Create Fund", () => {
    it("can create fund", async function () {
      const { giftBox } = await loadFixture(deployContractFixture);

      const tx = await giftBox.createFund("Fund 1", "Just a test fund", []);

      await expect(tx).not.to.be.reverted;
      await expect(tx)
        .to.emit(giftBox, "CreateFund")
        .withArgs(0, "Fund 1", "Just a test fund", []);
    });
  });

  describe("Deposit Tokens", () => {
    it("can deposit tokens to a fund", async function () {
      const { giftBox, fundId, donor1, testToken } = await loadFixture(
        createFundFixture
      );

      // Donor approves GiftBox to spend 100 tokens
      await testToken.connect(donor1).approve(giftBox.address, 100);
      // Donor deposits 100 tokens to GiftBox
      const tx = await giftBox.connect(donor1).depositTokens(fundId, 100);

      await expect(tx).not.to.be.reverted;
      await expect(tx).to.emit(giftBox, "DepositTokens").withArgs(fundId, 100);
    });
  });
});
