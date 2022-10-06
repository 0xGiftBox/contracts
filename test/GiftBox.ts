import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("GiftBox", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployContractFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const GiftBox = await ethers.getContractFactory("GiftBox");
    const giftBox = await GiftBox.deploy(
      "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"
    );

    return { giftBox, owner, otherAccount };
  }

  describe("Creating Fund", () => {
    it("can create fund", async function () {
      const { giftBox } = await loadFixture(deployContractFixture);

      const tx = giftBox.createFund("Fund 1", "Just a test fund", []);

      await expect(tx).not.to.be.reverted;
      await expect(tx)
        .to.emit(giftBox, "CreateFund")
        .withArgs("Fund 1", "Just a test fund", []);
    });
  });
});
