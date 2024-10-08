// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

interface Chicken {
    function ownerOf(uint256 tokenId) external view returns (address);
    function lastTokenId() external view returns (uint256);
    function layEggs(uint256[] calldata tokenIds) external payable;
    function chickens(uint256 tokenId) external view returns (uint8 eggLevel, uint40 nextTimeToLay);
    function calculateEggsRequiredToLevelUp(uint8 currentLevel, uint8 levelsToIncrease) external returns (uint256);
    function feed(uint8[] calldata levelsToIncrease, uint256[] calldata tokenIdsToLevelUp) external;
}

interface Egg {
    function balanceOf(address account) external view returns (uint256);
}

interface SuperEgg {
    function mint(uint256 amount) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function hatch(uint256 amount) external;
}

interface Incubator {
    function incubateSuperEggs(uint8 numSuperEggs) external returns (uint256);
    function hatch(uint256 incubatorId, uint8 numWholeEggs) external payable;
}

Chicken constant CHICKEN = Chicken(0xbBb6Ef38cF324f6739a2D2Ae8D05C9d1dE4cEA7E);
Egg constant EGG = Egg(0x4Db9AdbEbA3b59BA66691f0E5804eD5ebc5E4ce8);
SuperEgg constant SUPER_EGG = SuperEgg(0x2aA7697b5e5Bd919f0FE4600e6A19026c4E60D60);
Incubator constant INCUBATOR = Incubator(0xFa60D8C481f4C26d3E0962BCf637BE79791c6D6A);
uint256 constant VRF_FEE = 0.00001 ether;
uint256 constant COST_PER_SUPEGG = 10e18;

contract LayEggs is Script {
    uint256[] public tokenIds;

    function run() public {
        vm.startBroadcast();

        // Lay eggs
        uint256 lastTokenId = CHICKEN.lastTokenId();
        for (uint256 i = 1; i < lastTokenId; i++) {
            if (CHICKEN.ownerOf(i) == msg.sender) {
                (, uint40 nextTimeToLay) = CHICKEN.chickens(i);
                if (nextTimeToLay <= block.timestamp) {
                    tokenIds.push(i);
                }
            }
        }

        if (tokenIds.length == 0) {
            console2.log("No chickens to lay eggs for");
            return;
        }

        console2.log("Laying eggs for %s chickens", tokenIds.length);
        CHICKEN.layEggs{ value: VRF_FEE }(tokenIds);

        vm.stopBroadcast();
    }
}

contract MintSupereggs is Script {
    function run() public {
        vm.startBroadcast();

        // Buy superegg until less than 10 eggs
        uint256 eggs = EGG.balanceOf(msg.sender);
        uint256 superEggsMinted = eggs / COST_PER_SUPEGG;
        if (superEggsMinted > 0) {
            console2.log("Minting %s super eggs", superEggsMinted);
            SUPER_EGG.mint(superEggsMinted);
        }

        vm.stopBroadcast();
    }
}

contract HatchSuperEggs is Script {
    function run() public {
        vm.startBroadcast();

        uint8 superEggs = uint8(SUPER_EGG.balanceOf(msg.sender, 1) / 1e18);
        if (superEggs > 0) {
            console2.log("Hatching %s super eggs", superEggs);
            uint256 incubatorId = INCUBATOR.incubateSuperEggs(superEggs);
            INCUBATOR.hatch{ value: VRF_FEE }(incubatorId, superEggs);
        } else {
            console2.log("No super eggs to hatch");
        }

        vm.stopBroadcast();
    }
}

contract LevelUpChickens is Script {
    function run() public {
        vm.startBroadcast();

        uint256 eggBalance = EGG.balanceOf(msg.sender);
        if (eggBalance > COST_PER_SUPEGG) {
            console2.log("Too many eggs to level up chickens");
            return;
        }

        uint256 lastTokenId = CHICKEN.lastTokenId();
        for (uint256 i = lastTokenId - 1; i > 0; i--) {
            uint256 wholeEggBalance = EGG.balanceOf(msg.sender) / 1e18;
            if (CHICKEN.ownerOf(i) == msg.sender) {
                (uint8 level, uint40 nextTimeToLay) = CHICKEN.chickens(i);
                if (nextTimeToLay <= block.timestamp) {
                    console2.log("Chicken %s is ready to lay at %s", i, nextTimeToLay);
                    uint256[] memory tokenIds = new uint256[](1);
                    tokenIds[0] = i;
                    CHICKEN.layEggs{ value: VRF_FEE }(tokenIds);
                }
                if (level < 4) {
                    uint256 wholeEggsRequired = CHICKEN.calculateEggsRequiredToLevelUp(level, 1);
                    if (wholeEggBalance >= wholeEggsRequired) {
                        console2.log("Leveling up chicken %s to %s", i, level + 1);
                        uint8[] memory levelsToIncrease = new uint8[](1);
                        levelsToIncrease[0] = 1;
                        uint256[] memory tokenIdsToLevelUp = new uint256[](1);
                        tokenIdsToLevelUp[0] = i;
                        CHICKEN.feed(levelsToIncrease, tokenIdsToLevelUp);
                    }
                }
            }
        }

        vm.stopBroadcast();
    }
}
