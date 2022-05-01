// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";

import "./CheatCodes.sol";
import "./ERC20Mintable.sol";
import "../EscrowEpochVoter.sol";

contract EscrowEpochVoterTest is DSTest {

    address constant ACCOUNT = 0x7F101fE45e6649A6fB8F3F8B43ed03D353f2B90c;
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    EscrowEpochVoter voter;
    ERC20Mintable token;

    uint32 epochDuration = 100;

    function setUp() public {
        token = new ERC20Mintable();
        voter = new EscrowEpochVoter("Epoch Voter", "EPCV", 0, epochDuration, token);
    }

    function testDeposit() public {
        token.mint(address(this), 10 ether);
        token.approve(address(voter), 10 ether);
        voter.deposit(10 ether, ACCOUNT);
        assertEq(voter.balanceOf(ACCOUNT), 10 ether);
        assertEq(token.balanceOf(address(voter)), 10 ether);
    }

    function testWithdraw() public {
        token.mint(address(this), 10 ether);
        token.approve(address(voter), 10 ether);
        voter.deposit(10 ether, address(this));
        voter.withdraw(10 ether);
        assertEq(token.balanceOf(address(this)), 10 ether);
        assertEq(token.balanceOf(address(voter)), 0);
    }
}
