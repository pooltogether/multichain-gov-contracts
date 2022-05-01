// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";

import "./CheatCodes.sol";
import "./EpochVoterHarness.sol";

contract EpochVoterTest is DSTest {

    address constant ACCOUNT = 0x7F101fE45e6649A6fB8F3F8B43ed03D353f2B90c;
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    EpochVoterHarness voter;

    uint32 epochDuration = 100;

    function setUp() public {
        voter = new EpochVoterHarness("Epoch Voter", "EPCV", 0, epochDuration);
    }

    function testCurrentVotes() public {
        assertEq(voter.currentVotes(address(this)), 0);
        voter.mint(address(this), 10 ether);
        assertEq(voter.currentVotes(address(this)), 0);
        cheats.warp(epochDuration);
        assertEq(voter.currentVotes(address(this)), 10 ether);
        voter.mint(address(this), 5 ether);
        assertEq(voter.currentVotes(address(this)), 10 ether);
    }

    function testVotesAtEpoch() public {
        voter.mint(address(this), 10 ether);
        cheats.warp(epochDuration);
        assertEq(voter.votesAtEpoch(address(this), 0), 0);
    }

    function testTransfer() public {
        // epoch 0
        voter.mint(address(this), 10 ether);
        cheats.warp(epochDuration);
        // epoch 1
        voter.transfer(ACCOUNT, 5 ether);
        cheats.warp(epochDuration*2);
        // epoch 2
        cheats.warp(epochDuration*3);
        // epoch 3

        assertEq(voter.currentEpoch(), 3);
        assertEq(voter.votesAtEpoch(address(this), 0), 0, "sender has zero at first epoch");
        assertEq(voter.votesAtEpoch(address(this), 1), 5 ether, "sender has 5 at second epoch");
        assertEq(voter.votesAtEpoch(ACCOUNT, 1), 0);
        assertEq(voter.votesAtEpoch(ACCOUNT, 2), 5 ether, "receiver has 5 at third epoch");
    }

    function testBurnSameEpoch() public {
        voter.mint(address(this), 10 ether);
        voter.burn(address(this), 10 ether);
        assertEq(voter.currentVotes(address(this)), 0);
        cheats.warp(epochDuration);
        assertEq(voter.votesAtEpoch(address(this), 0), 0);
    }

    function testBurnNextEpoch() public {
        voter.mint(address(this), 10 ether);
        cheats.warp(epochDuration);
        assertEq(voter.currentVotes(address(this)), 10 ether);
        cheats.warp(epochDuration*2);
        voter.burn(address(this), 10 ether);
        assertEq(voter.currentVotes(address(this)), 0);
        cheats.warp(epochDuration*3);
        assertEq(voter.votesAtEpoch(address(this), 1), 10 ether);
    }
}
