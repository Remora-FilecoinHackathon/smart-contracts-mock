import { expect } from "chai";
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import axios from "axios";
import { ethers } from "hardhat";

import { LenderManager } from "../typechain-types/escrow";

describe("Lender Manager Contract", function () {
  const ENDPOINT_ADDRESS = "https://api.hyperspace.node.glif.io/rpc/v1";

  const amount = ethers.utils.parseEther("0.002");
  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
  const unlockTime = currentTimestampInSeconds + ONE_YEAR_IN_SECS;

  async function callRpc(method: string, params?: any) {
    const res = await axios.post(ENDPOINT_ADDRESS, {
      jsonrpc: "2.0",
      method: method,
      params: params,
      id: 1,
    });
    return res.data;
  }

  async function deployLenderManagerFixture() {
    var priorityFee = await callRpc("eth_maxPriorityFeePerGas");

    const [owner, otherAccount, oracleAccount] = await ethers.getSigners();
    const ORACLE_ADDRESS = oracleAccount.address;
    const LenderManager = await ethers.getContractFactory("LenderManager");
    const lenderManager = await LenderManager.deploy(ORACLE_ADDRESS, {
      maxPriorityFeePerGas: priorityFee.result,
    });

    await lenderManager.deployed();

    await lenderManager.connect(otherAccount).deployMockMinerActor();
    const MINER_ADDRESS = await lenderManager.ownerToMinerActor(
      otherAccount.address
    );

    return {
      lenderManager,
      ORACLE_ADDRESS,
      MINER_ADDRESS,
      owner,
      otherAccount,
      oracleAccount,
    };
  }

  describe("Deployments", function () {
    it("Oracle address should be set correctly", async function () {
      const { lenderManager, ORACLE_ADDRESS } = await loadFixture(
        deployLenderManagerFixture
      );

      expect(await lenderManager.oracle()).not.to.equal(0);
      expect(await lenderManager.oracle()).to.equal(ORACLE_ADDRESS);
    });
  });

  describe("Create Lending Position", function () {
    it("Should fail for zero value sent to the function", async function () {
      const { lenderManager } = await loadFixture(deployLenderManagerFixture);

      await expect(
        lenderManager.createLendingPosition(unlockTime, 10)
      ).to.be.revertedWithCustomError(lenderManager, "Empty_Amount");
    });

    it("Should fail for invalid duration sent to the function", async function () {
      const { lenderManager } = await loadFixture(deployLenderManagerFixture);

      await expect(
        lenderManager.createLendingPosition(currentTimestampInSeconds - 1, 10, {
          value: amount,
        })
      ).to.be.revertedWithCustomError(lenderManager, "Loan_Period_Excedeed");
    });

    it("Should fail for invalid interest rate sent to the function", async function () {
      const { lenderManager } = await loadFixture(deployLenderManagerFixture);

      await expect(
        lenderManager.createLendingPosition(unlockTime, 1e5, { value: 1 })
      ).to.be.revertedWithCustomError(lenderManager, "InterestRate_Too_High");
    });

    it("Should pass for the correct params", async function () {
      const { lenderManager, owner } = await loadFixture(
        deployLenderManagerFixture
      );

      const tx = await lenderManager.createLendingPosition(unlockTime, 10, {
        value: 1,
      });
      await tx.wait();

      // param update checks
      let key = await lenderManager.loanKeys(0);
      let lenderPosition = await lenderManager.positions(key);
      // console.log(lenderPosition);

      expect(lenderPosition.lender).to.equal(owner.address);
      expect(lenderPosition.availableAmount).to.equal(1);
      expect(lenderPosition.endTimestamp).to.equal(unlockTime);
      expect(lenderPosition.interestRate).to.equal(10);
    });
  });

  describe("Check Reputation", function () {
    it("Should update the params correctly and emit events", async function () {
      const { lenderManager, MINER_ADDRESS, oracleAccount } = await loadFixture(
        deployLenderManagerFixture
      );

      const id = await lenderManager.currentId();
      await expect(lenderManager.checkReputation(MINER_ADDRESS))
        .to.emit(lenderManager, "CheckReputation")
        .withArgs(id, MINER_ADDRESS.toString());

      //   console.log(MINER_ADDRESS);

      await lenderManager.connect(oracleAccount).receiveReputationScore(id, 2);
    });
  });

  describe("Create Borrow", function () {
    it("Should fail for an invalid loan key sent to the function", async function () {
      const { lenderManager, MINER_ADDRESS, oracleAccount, otherAccount } =
        await loadFixture(deployLenderManagerFixture);

      const tx = await lenderManager.createLendingPosition(unlockTime, 10, {
        value: amount,
      });
      await tx.wait();

      const id = await lenderManager.currentId();
      await expect(lenderManager.checkReputation(MINER_ADDRESS))
        .to.emit(lenderManager, "CheckReputation")
        .withArgs(id, MINER_ADDRESS.toString());

      //   console.log(MINER_ADDRESS);

      await lenderManager.connect(oracleAccount).receiveReputationScore(id, 2);

      await expect(
        lenderManager
          .connect(otherAccount)
          .createBorrow(0, ethers.utils.parseEther("0.001"), MINER_ADDRESS)
      ).to.be.revertedWithCustomError(lenderManager, "Empty_Lender");
    });

    it("Should fail for an invalid amount sent to the function", async function () {
      const { lenderManager, MINER_ADDRESS, oracleAccount, otherAccount } =
        await loadFixture(deployLenderManagerFixture);

      const tx = await lenderManager.createLendingPosition(unlockTime, 10, {
        value: amount,
      });
      await tx.wait();

      let key = await lenderManager.loanKeys(0);

      const id = await lenderManager.currentId();
      await expect(lenderManager.checkReputation(MINER_ADDRESS))
        .to.emit(lenderManager, "CheckReputation")
        .withArgs(id, MINER_ADDRESS.toString());

      //   console.log(MINER_ADDRESS);

      await lenderManager.connect(oracleAccount).receiveReputationScore(id, 2);

      await expect(
        lenderManager
          .connect(otherAccount)
          .createBorrow(key, amount.add(10), MINER_ADDRESS)
      ).to.be.revertedWithCustomError(lenderManager, "Loan_No_More_Available");
    });

    it("Should fail for zero amount sent to the function", async function () {
      const { lenderManager, MINER_ADDRESS, oracleAccount, otherAccount } =
        await loadFixture(deployLenderManagerFixture);

      const tx = await lenderManager.createLendingPosition(unlockTime, 10, {
        value: amount,
      });
      await tx.wait();

      let key = await lenderManager.loanKeys(0);

      const id = await lenderManager.currentId();
      await expect(lenderManager.checkReputation(MINER_ADDRESS))
        .to.emit(lenderManager, "CheckReputation")
        .withArgs(id, MINER_ADDRESS.toString());

      //   console.log(MINER_ADDRESS);

      await lenderManager.connect(oracleAccount).receiveReputationScore(id, 2);

      await expect(
        lenderManager
          .connect(otherAccount)
          .createBorrow(key, ethers.utils.parseEther("0"), MINER_ADDRESS)
      ).to.be.reverted;
    });

    it("Should fail if duration is passed for the given loan", async function () {
      const { lenderManager, MINER_ADDRESS, oracleAccount, otherAccount } =
        await loadFixture(deployLenderManagerFixture);

      const tx = await lenderManager.createLendingPosition(unlockTime, 10, {
        value: amount,
      });
      await tx.wait();

      let key = await lenderManager.loanKeys(0);

      // time travelling to after the unlock time
      await time.increaseTo(unlockTime + 1);

      const id = await lenderManager.currentId();
      await expect(lenderManager.checkReputation(MINER_ADDRESS))
        .to.emit(lenderManager, "CheckReputation")
        .withArgs(id, MINER_ADDRESS.toString());

      //   console.log(MINER_ADDRESS);

      await lenderManager.connect(oracleAccount).receiveReputationScore(id, 2);
      await expect(
        lenderManager
          .connect(otherAccount)
          .createBorrow(key, ethers.utils.parseEther("0.001"), MINER_ADDRESS)
      ).to.be.revertedWithCustomError(lenderManager, "Loan_No_More_Available");
    });

    it("Should fail if the lender is calling the borrow function", async function () {
      const { lenderManager, MINER_ADDRESS, oracleAccount, owner } =
        await loadFixture(deployLenderManagerFixture);

      const tx = await lenderManager.createLendingPosition(unlockTime, 10, {
        value: amount,
      });
      await tx.wait();

      let key = await lenderManager.loanKeys(0);

      const id = await lenderManager.currentId();
      await expect(lenderManager.checkReputation(MINER_ADDRESS))
        .to.emit(lenderManager, "CheckReputation")
        .withArgs(id, MINER_ADDRESS.toString());

      //   console.log(MINER_ADDRESS);

      await lenderManager.connect(oracleAccount).receiveReputationScore(id, 2);

      await expect(
        lenderManager.createBorrow(
          key,
          ethers.utils.parseEther("0.001"),
          MINER_ADDRESS
        )
      ).to.be.revertedWithCustomError(lenderManager, "Impossible_Borrower");
    });

    it("Should pass for the correct params passed to the function", async function () {
      const { lenderManager, MINER_ADDRESS, oracleAccount, otherAccount } =
        await loadFixture(deployLenderManagerFixture);

      const tx = await lenderManager.createLendingPosition(unlockTime, 10, {
        value: amount,
      });
      await tx.wait();

      let key = await lenderManager.loanKeys(0);

      const id = await lenderManager.currentId();
      await expect(lenderManager.checkReputation(MINER_ADDRESS))
        .to.emit(lenderManager, "CheckReputation")
        .withArgs(id, MINER_ADDRESS.toString());

      await lenderManager.connect(oracleAccount).receiveReputationScore(id, 2);

      await lenderManager
        .connect(otherAccount)
        .createBorrow(key, ethers.utils.parseEther("0.001"), MINER_ADDRESS);

      let lenderPosition = await lenderManager.positions(key);
      expect(lenderPosition.availableAmount).to.equal(
        ethers.utils.parseEther("0.001")
      );

      let lendingOrders = await lenderManager.ordersForLending(key, 0);
      expect(lendingOrders.borrower).to.equal(otherAccount.address);

      expect(lendingOrders.loanAmount).to.equal(
        ethers.utils.parseEther("0.001")
      );
    });
  });

  describe("Is controlling Address", function () {
    // TODO function calls fail, need fixing
    // it("Should fail for invalid address", async function () {
    //     const { lenderManager, owner } = await loadFixture(deployLenderManagerFixture);
    //     const result = await lenderManager.isControllingAddress(owner.address);
    //     expect(result).to.equal(true);
    // })
    // it("Should pass for correct miner address", async function () {
    //     const { lenderManager, MINER_ADDRESS } = await loadFixture(deployLenderManagerFixture);
    //     const result = await lenderManager.isControllingAddress(MINER_ADDRESS);
    //     expect(result).to.equal(true);
    // })
  });

  describe("Calculate Interest", function () {
    it("Should fail if conditions are not met", async function () {
      const { lenderManager } = await loadFixture(deployLenderManagerFixture);

      await expect(lenderManager.calculateInterest(10, 883)).to.be.reverted;
    });

    it("Should pass for correct params passed to the function", async function () {
      const { lenderManager } = await loadFixture(deployLenderManagerFixture);

      const Interest = await lenderManager.calculateInterest(100000, 10);
      const calculatedInterest = 100000 + 100000 * 0.1;
      //   console.log(calculatedInterest);

      // expect(Interest[1]).to.equal(calculatedInterest);

      //   console.log(Interest[0]);
      //   console.log(Interest[1]);
    });
  });
});
