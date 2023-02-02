// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "./IEscrow.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/SendAPI.sol";
import {MinerMockAPI} from "./mocks/MinerMockAPI.sol";
import {MinerTypes} from "@zondax/filecoin-solidity/contracts/v0.8/types/MinerTypes.sol";
import {BigIntCBOR} from "@zondax/filecoin-solidity/contracts/v0.8/cbor/BigIntCbor.sol";

contract Escrow is IEscrow {
    address public lender;
    address public borrower;
    address payable public minerActor;
    uint256 public loanAmount;
    uint256 public rateAmount;
    uint256 public end;
    bool public started;
    bool public canTerminate;
    uint256 public lastWithdraw;
    uint256 public withdrawInterval;
    uint256 public loanPaidAmount;
    MinerTypes.WithdrawBalanceParams closeLoanParam;

    constructor(
        address _lender,
        address _borrower,
        address payable _minerActor,
        uint256 _loanAmount,
        uint256 _rateAmount,
        uint256 _withdrawInterval,
        uint256 _end
    ) {
        lender = _lender;
        borrower = _borrower;
        minerActor = _minerActor;
        loanAmount = _loanAmount;
        rateAmount = _rateAmount;
        withdrawInterval = _withdrawInterval;
        end = _end;
        closeLoanParam.amount_requested = abi.encodePacked(
            address(this).balance
        );
    }

    function startLoan() external {
        if (started) revert Loan_Already_Started();
        // set this contract as the new Owner of the Miner Actor
        MinerMockAPI(minerActor).changeOwnerAddress(
            abi.encodePacked(address(this))
        );

        MinerTypes.ChangeBeneficiaryParams memory params;
        params.new_beneficiary = abi.encodePacked(address(this));
        params.new_quota.val = abi.encodePacked(address(this).balance);
        params.new_expiration = uint64(end - block.timestamp);
        MinerMockAPI(minerActor).changeBeneficiary(params);

        // check on Owner
        MinerTypes.GetOwnerReturn memory getOwnerReturnValue = MinerMockAPI(
            minerActor
        ).getOwner();
        // console.log("BBBB");
        // console.log(string(getOwnerReturnValue.owner));
        address checkOwner = MinerMockAPI(minerActor).bytesToAddress(
            getOwnerReturnValue.owner
        );
        if (checkOwner != address(this)) revert Wrong_Owner();
        // check on Beneficiary
        MinerTypes.GetBeneficiaryReturn
            memory getBeneficiaryReturnValue = MinerMockAPI(minerActor)
                .getBeneficiary();
        address checkBeneficiary = MinerMockAPI(minerActor).bytesToAddress(
            getBeneficiaryReturnValue.active.beneficiary
        );
        if (checkBeneficiary != address(this)) revert Wrong_Beneficiary();

        started = true;
        transferToMinerActor(address(this).balance);
    }

    function transferToMinerActor(uint256 amount) public {
        if (msg.sender != borrower) revert Not_The_Borrower(borrower);
        if (address(this).balance < amount)
            revert Not_Enough_Balance(address(this).balance);
        submit(minerActor, amount);
    }

    function transferFromMinerActor(
        MinerTypes.WithdrawBalanceParams memory balanceParams
    ) external {
        if (msg.sender != borrower || msg.sender != lender)
            revert Not_The_Borrower_Or_Lender(borrower, lender);

        return MinerMockAPI(minerActor).withdrawBalance();
    }

    function nextWithdraw() public view returns (uint256) {
        return lastWithdraw == 0 ? 0 : (lastWithdraw + withdrawInterval);
    }

    function repay() external {
        if (!started) revert Loan_Not_Started();

        if (nextWithdraw() > block.timestamp) revert Too_Early(nextWithdraw());

        if (loanPaidAmount >= loanAmount)
            revert Loan_Already_Repaid(loanPaidAmount);

        if (address(this).balance >= rateAmount) {
            // transfer $fil to lender
            submit(lender, rateAmount);
            loanPaidAmount += rateAmount;
            emit PaidRate(block.timestamp, rateAmount, loanPaidAmount);
        } else {
            canTerminate = true;
            emit FailedPaidRate(block.timestamp);
        }
        lastWithdraw = block.timestamp;
    }

    function withdrawBeforLoanStarts() external {
        if (msg.sender != lender) revert Not_The_Lender(lender);
        if (started) revert Already_Started();

        emit ClosedLoan(block.timestamp, address(this).balance, 0);
        // selfdescruct and send $FIL back to the lender
        address payable lenderAddress = payable(address(lender));
        selfdestruct(lenderAddress);
    }

    function closeLoan() external {
        if (!canTerminate || end > block.timestamp)
            revert Loan_Not_Expired(end);
        MinerMockAPI(minerActor).withdrawBalance();
        // change the owner wallet setting the borrower as the new owner
        MinerMockAPI(minerActor).changeOwnerAddress(abi.encodePacked(borrower));
        // change the beneficiary wallet setting the borrower as the new owner
        MinerTypes.ChangeBeneficiaryParams memory params;
        params.new_beneficiary = abi.encodePacked(borrower);
        // 1 $FIL in Wei
        uint256 quota = 10**18;
        params.new_quota.val = abi.encodePacked(quota);
        params.new_expiration = uint64(block.timestamp + end);
        MinerMockAPI(minerActor).changeBeneficiary(params);

        emit ClosedLoan(block.timestamp, address(this).balance, loanPaidAmount);
        // selfdescruct and send $FIL back to the lender
        address payable lenderAddress = payable(address(lender));
        selfdestruct(lenderAddress);
    }

    function submit(address subject, uint256 value)
        internal
        returns (bytes memory returnData)
    {
        (bool sent, ) = subject.call{value: value}("");
        require(sent, "failed to send FIL");
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
