pragma solidity 0.8.10;

interface IGovernorRoot {

    function requestProposal(bytes32 executionHash) external returns (bool);

    function addVotes(
        uint256 againstVotes,
        uint256 forVotes,
        uint256 abstainVotes,
        bytes32 proposalHash
    ) external returns (bool);

}
