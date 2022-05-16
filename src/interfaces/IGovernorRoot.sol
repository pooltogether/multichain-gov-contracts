pragma solidity 0.8.10;

interface IGovernorRoot {

    function createProposal(
        bytes32 executionHash
    ) external returns (
        uint256 rootNonce,
        bytes32 proposalHash,
        bytes memory data
    );

    function addVotes(
        uint256 againstVotes,
        uint256 forVotes,
        uint256 abstainVotes,
        bytes32 proposalHash
    ) external returns (bool);

}
