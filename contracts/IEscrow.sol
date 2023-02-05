// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IEscrow {

    //-------------------------------- Custom Errors start --------------------------------//
    error Loan_Already_Started();

    error Wrong_Owner();

    error Wrong_Beneficiary();

    error Not_The_Borrower(address);

    error Not_Enough_Balance(uint256);

    error Not_The_Borrower_Or_Lender(address, address);

    error Too_Early(uint256);

    error Loan_Already_Repaid(uint256);

    error Not_The_Lender(address);

    error Already_Started();

    error Loan_Not_Expired(uint256);

    error Loan_Not_Started();

    //-------------------------------- Custom Errors end --------------------------------//

    //-------------------------------- Events start --------------------------------//
    
    /**
    * @dev Emitted when some amount is repaid against the loan to the escrow
    * @param time the timestamp of the payment
    * @param amount total period amount payable
    * @param paidAmount the amount repaid
    */
    event PaidRate(uint256 time, uint256 amount, uint256 paidAmount);

    /**
    * @dev Emitted when payment fails
    * @param time the timestamp of the failed payment
    */
    event FailedPaidRate(uint256 time);

    /**
    * @dev Emitted when the loan is closed
    * @param time the timestamp when the loan is closed
    * @param amount the total amount accumulated in the escrow
    * @param paidAmount the total amount repaid by the borrower
    */
    event ClosedLoan(uint256 time, uint256 amount, uint256 paidAmount);

    /**
    * @dev Emitted when some amount is received in the escrow contract
    * @param sender the address that sends the funds
    * @param amount the amount of funds sent to the contract
    */
    event Received(address sender, uint256 amount);

    //-------------------------------- Events end --------------------------------//
}
