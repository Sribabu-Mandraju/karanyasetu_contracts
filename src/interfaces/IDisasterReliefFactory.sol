// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "../../src/LocationDetails.sol";

interface IDisasterReliefFactory {
    event DisasterReliefDeployed(address disasterReliefAddress, string disasterName, uint256 initialFunds);

    function deployDisasterRelief(
        uint256 disasterId,
        string memory disasterName,
        string memory image,
        LocationDetails.Location memory location,
        uint256 donationPeriod,
        uint256 registrationPeriod,
        uint256 waitingPeriod,
        uint256 distributionPeriod,
        uint256 initialFunds
    ) external returns (address);

    function isDisasterRelief(address disasterReliefAddress) external view returns (bool);

    function setZKVerifier(address _zkVerifier) external;
}
