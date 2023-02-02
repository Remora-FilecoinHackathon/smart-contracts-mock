/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
//
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

// import {BigNumber} from "@zondax/solidity-bignumber/src/BigNumbers.sol";

import "@zondax/filecoin-solidity/contracts/v0.8/types/MinerTypes.sol";

// import "hardhat/console.sol";

/// @title This contract is a proxy to a built-in Miner actor. Calling one of its methods will result in a cross-actor call being performed. However, in this mock library, no actual call is performed.
/// @author Zondax AG
/// @dev Methods prefixed with mock_ will not be available in the real library. These methods are merely used to set mock state. Note that this interface will likely break in the future as we align it
//       with that of the real library!
contract MinerMockAPI {
    bytes owner;
    bool isBeneficiarySet = false;
    CommonTypes.ActiveBeneficiary activeBeneficiary;
    mapping(CommonTypes.SectorSize => uint64) sectorSizesBytes;

    /// @notice the value for number 0 of a BigNumber instance.
    bytes constant ZERO =
        hex"0000000000000000000000000000000000000000000000000000000000000000";

    struct BigNumber {
        bytes val;
        bool neg;
        uint256 bitlen;
    }

    event Received(address, uint256);

    /// @notice (Mock method) Sets the owner of a Miner on contract deployment, which will be returned via get_owner().
    constructor(address _owner) {
        owner = addressToBytes(_owner);
        // console.log("AAAA");
        // console.log(string(owner));

        sectorSizesBytes[CommonTypes.SectorSize._2KiB] = 2 << 10;
        sectorSizesBytes[CommonTypes.SectorSize._8MiB] = 8 << 20;
        sectorSizesBytes[CommonTypes.SectorSize._512MiB] = 512 << 20;
        sectorSizesBytes[CommonTypes.SectorSize._32GiB] = 32 << 30;
        sectorSizesBytes[CommonTypes.SectorSize._64GiB] = 2 * (32 << 30);
    }

    /// @notice (Mock method) Sets the owner of a Miner, which will be returned via get_owner().
    function mockSetOwner(bytes memory addr) public {
        require(owner.length == 0);
        owner = addr;
    }

    /// @notice Income and returned collateral are paid to this address
    /// @notice This address is also allowed to change the worker address for the miner
    /// @return the owner address of a Miner
    function getOwner() public view returns (MinerTypes.GetOwnerReturn memory) {
        require(owner.length != 0);

        bytes memory proposed = "0x00";

        return MinerTypes.GetOwnerReturn(owner, proposed);
    }

    /// @param addr New owner address
    /// @notice Proposes or confirms a change of owner address.
    /// @notice If invoked by the current owner, proposes a new owner address for confirmation. If the proposed address is the current owner address, revokes any existing proposal that proposed address.
    function changeOwnerAddress(bytes memory addr) public {
        owner = addr;
    }

    /// @param params The "controlling" addresses are the Owner, the Worker, and all Control Addresses.
    /// @return Whether the provided address is "controlling".
    function isControllingAddress(
        MinerTypes.IsControllingAddressParam memory params
    ) public view returns (MinerTypes.IsControllingAddressReturn memory) {
        require(params.addr[0] >= 0x00);
        bool isControlling = keccak256(owner) == keccak256(params.addr) ||
            (
                isBeneficiarySet
                    ? keccak256(activeBeneficiary.beneficiary) ==
                        keccak256(params.addr)
                    : false
            );
        return MinerTypes.IsControllingAddressReturn(isControlling);
    }

    /// @return the miner's sector size.
    function getSectorSize()
        public
        view
        returns (MinerTypes.GetSectorSizeReturn memory)
    {
        return
            MinerTypes.GetSectorSizeReturn(
                sectorSizesBytes[CommonTypes.SectorSize._8MiB]
            );
    }

    /// @notice This is calculated as actor balance - (vesting funds + pre-commit deposit + initial pledge requirement + fee debt)
    /// @notice Can go negative if the miner is in IP debt.
    /// @return the available balance of this miner.
    function getAvailableBalance()
        public
        pure
        returns (MinerTypes.GetAvailableBalanceReturn memory)
    {
        return
            MinerTypes.GetAvailableBalanceReturn(
                BigInt(hex"021E19E0C9BAB2400000", false)
            );
    }

    /// @return the funds vesting in this miner as a list of (vesting_epoch, vesting_amount) tuples.
    function getVestingFunds()
        public
        pure
        returns (MinerTypes.GetVestingFundsReturn memory)
    {
        CommonTypes.VestingFunds[]
            memory vesting_funds = new CommonTypes.VestingFunds[](1);
        vesting_funds[0] = CommonTypes.VestingFunds(
            1668514825,
            BigInt(hex"6C6B935B8BBD400000", false)
        );

        return MinerTypes.GetVestingFundsReturn(vesting_funds);
    }

    /// @notice Proposes or confirms a change of beneficiary address.
    /// @notice A proposal must be submitted by the owner, and takes effect after approval of both the proposed beneficiary and current beneficiary, if applicable, any current beneficiary that has time and quota remaining.
    /// @notice See FIP-0029, https://github.com/filecoin-project/FIPs/blob/master/FIPS/fip-0029.md
    function changeBeneficiary(MinerTypes.ChangeBeneficiaryParams memory params)
        public
    {
        if (!isBeneficiarySet) {
            BigNumber memory zero = BigNumber(ZERO, false, 0);
            CommonTypes.BeneficiaryTerm memory term = CommonTypes
                .BeneficiaryTerm(
                    params.new_quota,
                    BigInt(zero.val, zero.neg),
                    params.new_expiration
                );
            activeBeneficiary = CommonTypes.ActiveBeneficiary(
                params.new_beneficiary,
                term
            );
            isBeneficiarySet = true;
        } else {
            activeBeneficiary.beneficiary = params.new_beneficiary;
            activeBeneficiary.term.quota = params.new_quota;
            activeBeneficiary.term.expiration = params.new_expiration;
        }
    }

    /// @notice This method is for use by other actors (such as those acting as beneficiaries), and to abstract the state representation for clients.
    /// @notice Retrieves the currently active and proposed beneficiary information.
    function getBeneficiary()
        public
        view
        returns (MinerTypes.GetBeneficiaryReturn memory)
    {
        require(isBeneficiarySet);

        CommonTypes.PendingBeneficiaryChange memory proposed;
        return MinerTypes.GetBeneficiaryReturn(activeBeneficiary, proposed);
    }

    function withdrawBalance() public {
        require(msg.sender == bytesToAddress(owner));
        (bool sent, ) = msg.sender.call{value: address(this).balance}("");
        require(sent);
    }

    function bytesToAddress(bytes memory bys)
        public
        pure
        returns (address addr)
    {
        addr = address(uint160(bytes20(bys)));
    }

    function addressToBytes(address addr)
        public
        pure
        returns (bytes memory bys)
    {
        bys = abi.encodePacked(addr);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
