pragma solidity 0.8.10;

import "ds-test/test.sol";

import "./CheatCodes.sol";
import "../EscrowEpochVoter.sol";
import "./ERC20Mintable.sol";
import "../GovernorRoot.sol";
import "../GovernorBranch.sol";

contract IntegrationTest is DSTest {

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    GovernorRoot governorRoot;
    EscrowEpochVoter epochVoter;
    GovernorBranch governorBranch;
    ERC20Mintable token;

    uint32 constant epochDuration = 100;

    function setUp() public {
        cheats.clearMockedCalls();
        token = new ERC20Mintable();
        epochVoter = new EscrowEpochVoter("Epoch Voter", "EPCV", 0, epochDuration, token);
        governorBranch = new GovernorBranch(epochVoter);
        IGovernorBranch[] memory branches = new IGovernorBranch[](1);
        branches[0] = governorBranch;
        governorRoot = new GovernorRoot(branches);
        governorBranch.setGovernorRoot(governorRoot);
    }

    function testE2E() public {
        GovernorBranch.Call[] memory calls = new GovernorBranch.Call[](1);
        calls[0] = GovernorBranch.Call({
            chainId: block.chainid,
            caller: address(governorBranch),
            target: address(governorRoot),
            value: 0,
            data: abi.encodeWithSelector(governorRoot.removeBranch.selector, address(governorBranch))
        });

        bytes32 executionHash = governorBranch.computeExecutionHash(calls, 1);
        uint32 epoch = 1;
        uint64 endTimestamp = epochDuration*2 + 5 days;

        token.mint(address(this), 100_000 ether);
        token.approve(address(epochVoter), 100_000 ether);
        epochVoter.deposit(100_000 ether, address(this));
        cheats.warp(epochDuration*2);
        governorBranch.castVote(executionHash, epoch, endTimestamp, 1);
        cheats.warp(endTimestamp);
        governorBranch.addVotes(executionHash, epoch, endTimestamp);
        cheats.warp(endTimestamp + 7 days);
        
        bytes32 proposalHash = keccak256(
            abi.encode(
                executionHash,
                abi.encode(epoch, endTimestamp)
            )
        );
        governorRoot.queueProposal(proposalHash, governorBranch);

        governorBranch.executeProposal(block.chainid, address(governorBranch), 1, calls, abi.encode(epoch, endTimestamp));

        assertTrue(!governorRoot.isBranch(governorBranch), "branch is no longer");
    }

}
