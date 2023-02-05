// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "./IEscrow.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/SendAPI.sol";
import {MinerMockAPI} from "./mocks/MinerMockAPI.sol";
import {MinerTypes} from "@zondax/filecoin-solidity/contracts/v0.8/types/MinerTypes.sol";
import {BigIntCBOR} from "@zondax/filecoin-solidity/contracts/v0.8/cbor/BigIntCbor.sol";

/**
 * @title Escrow Contract implements methods for escrow
 * @notice Implements the functions for the given pair of lender and borrower transactions
 * @author Remora
 **/

contract Escrow is IEscrow {

    //-------------------------------- Glabal variables start --------------------------------//

    // Address of the lender
    address public lender;

    // Address of the borrower
    address public borrower;

    // Address of the miner actor
    address payable public minerActor;

    // Amount of loan borrowed (including the interest)
    uint256 public loanAmount;

    // Amount payable monthly 
    uint256 public rateAmount;

    // End timestamp of the loan
    uint256 public end;

    // Start timestamp of the loan
    bool public started;

    // Boolen implying if loan can be terminated
    bool public canTerminate;

    // Last withdrawal timestamp
    uint256 public lastWithdraw;

    // time interval between consecutive withdrawals
    uint256 public withdrawInterval;

    // Amount of the loan paid
    uint256 public loanPaidAmount;

    // Stores the loan parameters
    MinerTypes.WithdrawBalanceParams closeLoanParam;

    //-------------------------------- Glabal variables end --------------------------------//

    //-------------------------------- Initialize code start --------------------------------//

    /**
     * @dev used to initialize the variables in contract
     * @param _lender address of the lender
     * @param _borrower address of the borrower
     * @param _minerActor address of the miner Actor
     * @param _loanAmount  the loan amount requested (including the interest)
     * @param _rateAmount the monthly rate payable by the borrower
     * @param _withdrawInterval time interval between consecutive withdrawals
     * @param _end end timestamp of the loan
     */
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

    //-------------------------------- Initialize code end --------------------------------//

    /**
     * @dev Used to start the loan and initialize the miner and beneficiary addresses
     */
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

    /**
    * @dev Used to transfer amount from the borrower to the miner actor
    * @param amount the amount to transfer
    */
    function transferToMinerActor(uint256 amount) public {
        if (msg.sender != borrower) revert Not_The_Borrower(borrower);
        if (address(this).balance < amount)
            revert Not_Enough_Balance(address(this).balance);
        submit(minerActor, amount);
    }

    /**
    * @dev Used to transfer amount from the miner actor to the escrow
    * @param balanceParams balance of the miner actor
    */
    function transferFromMinerActor(
        MinerTypes.WithdrawBalanceParams memory balanceParams
    ) external {
        if (msg.sender != borrower || msg.sender != lender)
            revert Not_The_Borrower_Or_Lender(borrower, lender);

        return MinerMockAPI(minerActor).withdrawBalance();
    }

    /**
    * @dev Used to calculate the next withdrawal time stamp
    * @return lastWithdraw timestamp for the next allowed withdraw
    */
    function nextWithdraw() public view returns (uint256) {
        return lastWithdraw == 0 ? 0 : (lastWithdraw + withdrawInterval);
    }

    /**
    * @dev Used to repay the loan to the lender
    */
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

    /**
    * @dev Used to withdraw funds from escrow before the loan starts
    */
    function withdrawBeforLoanStarts() external {
        if (msg.sender != lender) revert Not_The_Lender(lender);
        if (started) revert Already_Started();

        emit ClosedLoan(block.timestamp, address(this).balance, 0);
        // selfdescruct and send $FIL back to the lender
        address payable lenderAddress = payable(address(lender));
        selfdestruct(lenderAddress);
    }

    /**
    * @dev Used to close the loan and send funds to the lender
    */
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

    /**
    * @dev Used to transfer funds 
    * @param subject address to send funds to
    * @param value amount of funds to send
    * @return returnData the result of the transfer
    */
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
