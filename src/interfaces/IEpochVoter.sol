pragma solidity 0.8.10;

import "./IEpochSource.sol";

interface IEpochVoter is IEpochSource {
    function currentVotes(address _account) external view returns (uint112);
    function votesAtEpoch(address _account, uint32 _epoch) external view returns (uint112);
}
