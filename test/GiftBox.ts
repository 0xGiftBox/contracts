import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("GiftBox", function () {
  const deployContractFixture = async () => {
    const [owner, fundManager, donor1, donor2, user1, user2] =
      await ethers.getSigners();
    // Deploy a generic ERC20 token to be used as stablecoin for testing
    const TestStableCoin = await ethers.getContractFactory("TestStableCoin");
    const testStableCoin = await TestStableCoin.deploy();

    const GiftBox = await ethers.getContractFactory("GiftBox");
    // Pass the address of stablecoin contract while deploying GiftBox
    const giftBox = await GiftBox.deploy(testStableCoin.address);

    return {
      giftBox,
      testStableCoin,
      fundManager,
      donor1,
      donor2,
      user1,
      user2,
    };
  };

  const createFundFixture = async () => {
    const fixtureResults = await deployContractFixture();
    const { giftBox, testStableCoin, donor1, donor2 } = fixtureResults;

    const tx = await giftBox.createFund("Fund 1", "TEST", []);
    const txReceipt = await tx.wait();
    const fundTokenAddress: string =
      txReceipt.events?.at(1)?.args?.fundTokenAddress;

    // Mint 10k stable coins to each donor
    await testStableCoin.mint(donor1.address, 10000);
    await testStableCoin.mint(donor2.address, 10000);

    return { ...fixtureResults, fundTokenAddress };
  };

  const createFundAndDepositStablecoinsFixture = async () => {
    const fixtureResults = await loadFixture(createFundFixture);
    const { giftBox, fundTokenAddress, donor1, testStableCoin } =
      fixtureResults;

    // Donor approves GiftBox to spend 100 stablecoins
    await testStableCoin.connect(donor1).approve(giftBox.address, 100);
    // Donor deposits 100 stablecoins to GiftBox
    const tx = await giftBox
      .connect(donor1)
      .depositStableCoins(fundTokenAddress, 100);
    await tx.wait();

    return fixtureResults;
  };

  describe("Create Fund", () => {
    it("can create fund", async function () {
      const { giftBox, fundManager } = await loadFixture(deployContractFixture);
      const fundName = "Fund 1";
      const fundSymbolSuffix = "TEST";
      const fundReference =
        "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi";

      // Send transaction
      const tx = await giftBox
        .connect(fundManager)
        .createFund(fundName, fundSymbolSuffix, [fundReference]);
      const txReceipt = await tx.wait();
      const fundTokenAddress: string =
        txReceipt.events?.at(1)?.args?.fundTokenAddress;

      // Ensure transaction succeeded and emitted event
      await expect(tx).not.to.be.reverted;
      await expect(tx)
        .to.emit(giftBox, "CreateFund")
        .withArgs(
          fundTokenAddress,
          fundManager.address,
          fundName,
          fundSymbolSuffix,
          ["ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"]
        );

      // Ensure contract is returning correct data
      expect(await giftBox.numFunds()).to.equal(1);
      const fund = await giftBox.funds(fundTokenAddress);
      expect(fund.manager).to.equal(fundManager.address);
      expect(fund.name).to.equal(fundName);
      expect(fund.isOpen).to.equal(true);

      expect(await giftBox.numFundReferences(fundTokenAddress)).to.equal(1);
      expect(await giftBox.fundReferences(fundTokenAddress, 0)).to.equal(
        fundReference
      );
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

      // Ensure transaction succeeded and emitted event
      await expect(tx).not.to.be.reverted;
      await expect(tx)
        .to.emit(giftBox, "DepositStableCoins")
        .withArgs(fundTokenAddress, donor1.address, 100);

      const GiftBoxFundToken = await ethers.getContractFactory(
        "GiftBoxFundToken"
      );
      const fundToken = GiftBoxFundToken.attach(fundTokenAddress);

      // Ensure GiftBox received stablecoin and donor got fund tokens
      expect(await testStableCoin.balanceOf(giftBox.address)).to.equal(100);
      expect(await fundToken.balanceOf(donor1.address)).to.equal(100);
    });
  });

  describe("Create Withdraw Request", () => {
    it("can create withdraw request", async function () {
      const { giftBox, fundTokenAddress, donor1, testStableCoin, user1 } =
        await loadFixture(createFundAndDepositStablecoinsFixture);
      const withdrawRequestTitle = "Need monet";
      const withdrawRequestAmount = 1000;
      const withdrawRequestReference =
        "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi";

      // Send transaction
      const tx = await giftBox
        .connect(user1)
        .createWithdrawRequest(
          fundTokenAddress,
          withdrawRequestAmount,
          withdrawRequestTitle,
          [withdrawRequestReference]
        );
      const txReceipt = await tx.wait();
      const withdrawRequestId: number = txReceipt.events?.at(0)?.args?.id;

      // Ensure transaction succeeded and emitted event
      await expect(tx).not.to.be.reverted;
      await expect(tx)
        .to.emit(giftBox, "CreateWithdrawRequest")
        .withArgs(
          fundTokenAddress,
          withdrawRequestId,
          withdrawRequestAmount,
          withdrawRequestTitle,
          [withdrawRequestReference]
        );

      // Ensure contract is returning correct data
      expect(await giftBox.numWithdrawRequests(fundTokenAddress)).to.equal(1);
      const withdrawRequest = await giftBox.withdrawRequests(
        fundTokenAddress,
        withdrawRequestId
      );

      expect(withdrawRequest.title).to.equal(withdrawRequestTitle);
      expect(withdrawRequest.amount).to.equal(withdrawRequestAmount);
      expect(withdrawRequest.numVotesAgainst).to.equal(0);
      expect(withdrawRequest.numVotesFor).to.equal(0);
      expect(withdrawRequest.status).to.equal(0);

      expect(
        await giftBox.numWithdrawRequestReferences(
          fundTokenAddress,
          withdrawRequestId
        )
      ).to.equal(1);
      expect(
        await giftBox.withdrawRequestReferences(
          fundTokenAddress,
          withdrawRequestId,
          0
        )
      ).to.equal(withdrawRequestReference);
    });
  });
});
