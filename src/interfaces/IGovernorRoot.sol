pragma solidity 0.8.10;

interface IGovernorRoot {
    function addVotes(
        uint256 againstVotes,
        uint256 forVotes,
        uint256 abstainVotes,
        bytes32 executionHash,
        uint32 epoch,
        uint64 endTimestamp
    ) external returns (bool);
}
