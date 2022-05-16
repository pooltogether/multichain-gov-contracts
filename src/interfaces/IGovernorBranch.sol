pragma solidity 0.8.10;

interface IGovernorBranch {

    function approveProposal(
        bytes32 proposalHash
    ) external;

}
