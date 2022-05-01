pragma solidity 0.8.10;

interface IGovernorRootProxy {

    function requestProposal(
        uint branchChainId,
        address branchAddress,
        uint branchNonce,
        bytes32 callsHash
    ) external;

    function addVotes(
        uint256 branchChainId,
        address branchAddress,
        uint256 yesVotes,
        uint256 noVotes,
        uint256 abstainVotes,
        bytes32 proposalHash
    ) external;

}
