import { expect } from "chai";
import axios from "axios";
import { ethers } from "hardhat";

describe("Escrow Contract", function () {
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

  async function deployEscrow() {
    var priorityFee = await callRpc("eth_maxPriorityFeePerGas");

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount, oracleAccount] = await ethers.getSigners();
    const ORACLE_ADDRESS = oracleAccount.address;
    const LenderManager = await ethers.getContractFactory("LenderManager");
    const lenderManager = await LenderManager.deploy(ORACLE_ADDRESS, {
      maxPriorityFeePerGas: priorityFee.result,
    });

    await lenderManager.deployed();
    console.log("lenderManager", lenderManager.address);
    priorityFee = await callRpc("eth_maxPriorityFeePerGas");
    let tx = await lenderManager.connect(otherAccount).deployMockMinerActor({
      maxPriorityFeePerGas: priorityFee.result,
    });
    await tx.wait();
    console.log("deployMockMinerActor");
    priorityFee = await callRpc("eth_maxPriorityFeePerGas");
    const MINER_ADDRESS = await lenderManager.ownerToMinerActor(
      otherAccount.address,
      {
        maxPriorityFeePerGas: priorityFee.result,
      }
    );
    console.log("ownerToMinerActor");

    priorityFee = await callRpc("eth_maxPriorityFeePerGas");
    tx = await lenderManager.createLendingPosition(unlockTime, 10, {
      value: amount,
      maxPriorityFeePerGas: priorityFee.result,
    });
    console.log(MINER_ADDRESS);
    console.log("createLendingPosition");
    await tx.wait();

    var loanKey = await lenderManager.loanKeys(0);
    const id = await lenderManager.currentId();

    priorityFee = await callRpc("eth_maxPriorityFeePerGas");
    await expect(
      lenderManager.checkReputation(MINER_ADDRESS, {
        maxPriorityFeePerGas: priorityFee.result,
      })
    )
      .to.emit(lenderManager, "CheckReputation")
      .withArgs(id, MINER_ADDRESS.toString());

    console.log("checkReputation");

    priorityFee = await callRpc("eth_maxPriorityFeePerGas");
    tx = await lenderManager
      .connect(oracleAccount)
      .receiveReputationScore(id, 2, {
        maxPriorityFeePerGas: priorityFee.result,
      });
    console.log("receiveReputationScore");
    await tx.wait();
    priorityFee = await callRpc("eth_maxPriorityFeePerGas");
    tx = await lenderManager
      .connect(otherAccount)
      .createBorrow(loanKey, ethers.utils.parseEther("0.001"), MINER_ADDRESS, {
        maxPriorityFeePerGas: priorityFee.result,
      });
    await tx.wait();
    console.log("createBorrow");

    priorityFee = await callRpc("eth_maxPriorityFeePerGas");
    const escrowAddress = await lenderManager.escrowContracts(loanKey, 0, {
      maxPriorityFeePerGas: priorityFee.result,
    });
    console.log("Escrow Address", escrowAddress);

    const escrowContract = await ethers.getContractAt("Escrow", escrowAddress);

    return {
      lenderManager,
      escrowContract,
      loanKey,
      ORACLE_ADDRESS,
      MINER_ADDRESS,
      owner,
      otherAccount,
    };
  }

  describe("Deployments", function () {
    it("Should deploy to a valid (non-address) address", async function () {
      const { escrowContract } = await deployEscrow();

      expect(escrowContract.address).to.not.equal(0);
    });

    it("All params should be updated correctly", async function () {
      const {
        lenderManager,
        MINER_ADDRESS,
        escrowContract,
        otherAccount,
        owner,
        loanKey,
      } = await deployEscrow();

      // Param update checks
      const lender = (await escrowContract.lender()).toString();
      const borrower = (await escrowContract.borrower()).toString();
      const minerActor = (await escrowContract.minerActor()).toString();
      const loanAmount = await escrowContract.loanAmount();
      const rateAmount = await escrowContract.rateAmount();
      const withdrawInterval = await escrowContract.withdrawInterval();
      const end = await escrowContract.end();

      const endTime = (await lenderManager.positions(loanKey)).endTimestamp;
      const interestRate = (await lenderManager.positions(loanKey))
        .interestRate;
      const interest = await lenderManager.calculateInterest(
        ethers.utils.parseEther("0.001"),
        interestRate
      );

      expect(lender).to.equal(owner.address);
      expect(borrower).to.equal(otherAccount.address);
      // expect(minerActor).to.equal(MINER_ADDRESS.toString());
      expect(loanAmount).to.equal(interest[1]);
      expect(rateAmount).to.equal(interest[0]);
      expect(withdrawInterval).to.equal(30 * 86400);
      expect(end).to.equal(endTime);
    });
  });

  describe("Start Loan", function () {
    it("Should fail if the loan is already started", async function () {
      const { lenderManager, escrowContract } = await deployEscrow();
    });

    it("Test start loan", async function () {
      const { lenderManager, escrowContract, otherAccount } =
        await deployEscrow();
      await escrowContract.connect(otherAccount).startLoan();
    });
  });

  describe("Transfer to miner", function () {
    it("Borrower should not be able to call the function", async function () {
      const { escrowContract } = await deployEscrow();

      await expect(
        escrowContract.transferToMinerActor(10)
      ).to.be.revertedWithCustomError(escrowContract, "Not_The_Borrower");
    });

    it("Shaould fail for invalid amount", async function () {
      const { escrowContract, otherAccount } = await deployEscrow();

      await expect(
        escrowContract
          .connect(otherAccount)
          .transferToMinerActor(ethers.utils.parseEther("0.003"))
      ).to.be.revertedWithCustomError(escrowContract, "Not_Enough_Balance");
    });

    it("Should pass for correct params sent to the function", async function () {
      const { escrowContract, otherAccount } = await deployEscrow();

      await escrowContract
        .connect(otherAccount)
        .transferToMinerActor(ethers.utils.parseEther("0.0001"));
    });
  });

  describe("Transfer from miner", function () {});

  describe("Repay", function () {
    it("Should fail if repaying non-started loan", async function () {
      const { escrowContract } = await deployEscrow();

      var nextWithdraw = await escrowContract.nextWithdraw();
      // console.log(nextWithdraw);
      await expect(escrowContract.repay()).to.be.revertedWithCustomError(
        escrowContract,
        "Loan_Not_Started"
      );

      nextWithdraw = await escrowContract.nextWithdraw();
      // console.log(nextWithdraw);
    });
  });

  describe("Withdraw before Loan Start", function () {
    it("Should fail if the lender is not calling the function", async function () {
      const { escrowContract, otherAccount } = await deployEscrow();

      // Should fail when borrower calls
      await expect(
        escrowContract.connect(otherAccount).withdrawBeforLoanStarts()
      ).to.be.revertedWithCustomError(escrowContract, "Not_The_Lender");
    });

    it("Should fail if loan is already started", async function () {
      const { escrowContract, otherAccount } = await deployEscrow();

      await escrowContract.connect(otherAccount).startLoan();

      // Should fail when borrower calls
      await expect(
        escrowContract.withdrawBeforLoanStarts()
      ).to.be.revertedWithCustomError(escrowContract, "Already_Started");
    });

    it("Should pass if conditions are correct", async function () {
      const { escrowContract } = await deployEscrow();

      await expect(escrowContract.withdrawBeforLoanStarts()).to.emit(
        escrowContract,
        "ClosedLoan"
      );
    });
  });

  describe("Close Loan", function () {
    it("Should fail if loan is not started", async function () {
      const { escrowContract } = await deployEscrow();

      // deadline not reached yet
      await expect(escrowContract.closeLoan()).to.be.revertedWithCustomError(
        escrowContract,
        "Loan_Not_Expired"
      );
    });
  });
});
