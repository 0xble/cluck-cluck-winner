// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

interface Chicken {
    function ownerOf(uint256 tokenId) external view returns (address);
    function lastTokenId() external view returns (uint256);
    function layEggs(uint256[] calldata tokenIds) external payable;
    function chickens(uint256 tokenId) external view returns (uint8 eggLevel, uint40 nextTimeToLay);
    function calculateEggsRequiredToLevelUp(
        uint8 currentLevel,
        uint8 levelsToIncrease
    )
        external
        view
        returns (uint256);
    function feed(uint8[] calldata levelsToIncrease, uint256[] calldata tokenIdsToLevelUp) external;
    function requestThrowEgg(
        uint256[] calldata tokenIdsToAttack,
        uint8[] calldata numberOfWholeEggsToThrow,
        bool[] calldata areSuperEggs,
        string[] calldata comments
    )
        external
        payable;
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
uint256 constant ATTACK_PHASE_START_AT = 1_728_460_800; // Oct 9, 4AM ET

contract Lay is Script {
    uint256[] public tokenIds;

    function run() public {
        vm.startBroadcast();

        // Lay eggs
        uint256 lastTokenId = CHICKEN.lastTokenId();
        for (uint256 i = 1; i <= lastTokenId; i++) {
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

contract Hatch is Script {
    function run() public {
        vm.startBroadcast();

        // Stop hatching after attack phase
        if (block.timestamp > ATTACK_PHASE_START_AT) {
            console2.log("Attack phase has started, stopped hatching");
            return;
        }

        uint256 superEggsToHatch = EGG.balanceOf(msg.sender) * 2 / 3 / COST_PER_SUPEGG;
        if (superEggsToHatch > 0) {
            console2.log("Hatching %s super eggs", superEggsToHatch);
            SUPER_EGG.mint(superEggsToHatch);
            uint256 incubatorId = INCUBATOR.incubateSuperEggs(uint8(superEggsToHatch));
            INCUBATOR.hatch{ value: VRF_FEE }(incubatorId, uint8(superEggsToHatch));
        } else {
            console2.log("No super eggs to hatch");
        }

        vm.stopBroadcast();
    }
}

contract Level is Script {
    function run() public {
        vm.startBroadcast();

        uint256 lastTokenId = CHICKEN.lastTokenId();
        for (uint256 i = lastTokenId; i > 0; i--) {
            uint256 wholeEggBalance = EGG.balanceOf(msg.sender) / 1e18;
            if (CHICKEN.ownerOf(i) == msg.sender) {
                (uint8 level, uint40 nextTimeToLay) = CHICKEN.chickens(i);
                if (nextTimeToLay <= block.timestamp) {
                    console2.log("Chicken %s is ready to lay at %s", i, nextTimeToLay);
                    uint256[] memory tokenIds = new uint256[](1);
                    tokenIds[0] = i;
                    CHICKEN.layEggs{ value: VRF_FEE }(tokenIds);
                } else {
                    // Skip if can lay in less than 3 hours
                    if (nextTimeToLay < block.timestamp + 3 hours) {
                        continue;
                    }
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

contract Throw is Script {
    struct Player {
        string name;
        address addr;
    }

    struct Attack {
        uint256 tokenId;
        uint8 eggsToThrow;
        bool isSuperEgg;
    }

    Attack[] public attacks;

    function run() public {
        vm.startBroadcast();

        // Begin throwing eggs at attack phase
        if (block.timestamp <= ATTACK_PHASE_START_AT) {
            console2.log("Attack phase has not started, stopping");
            return;
        }

        Player[] memory players = new Player[](8);
        players[0] = Player("John", 0x55708aAD5f83965D5c1D15be63EBb73D234b68ac);
        players[1] = Player("Danny", 0x64Fa20797Fb59d59552fb5921ecd2f2037F2573C);
        players[2] = Player("Steve", 0xba5f2ffb721648Ee6a6c51c512A258ec62f1D6af);
        players[3] = Player("Craig", 0x913f80128E15d8a8e5bB20cc49FBef1B2b81953c);
        players[4] = Player("Michael", 0x85652ed529B05736daDb18702317DF9F7ce5f0Bc);
        players[5] = Player("Marcus", 0x66512B61F855478bfba669e32719dE5fD7a57Fa4);
        players[6] = Player("Blaze", 0xdE83AB8c31585DFD4b25cBA8aD61bd587740336E);
        players[7] = Player("Jeremy", 0x8a00c2f7bA8ec5FDeFECbc0b3fFf8a96EAE0bC24);

        // Find top 2 players by sum of chickens levels
        uint256 lastTokenId = CHICKEN.lastTokenId();
        uint256[] memory levels = new uint256[](players.length);
        for (uint256 i = 0; i < players.length; i++) {
            uint256 sumLevels = 0;
            for (uint256 j = 1; j <= lastTokenId; j++) {
                if (CHICKEN.ownerOf(j) == players[i].addr) {
                    (uint8 level,) = CHICKEN.chickens(j);
                    sumLevels += level;
                }
            }
            levels[i] = sumLevels;
        }

        // Sort levels in descending order
        for (uint256 i = 0; i < levels.length; i++) {
            for (uint256 j = i + 1; j < levels.length; j++) {
                if (levels[i] < levels[j]) {
                    (levels[i], levels[j]) = (levels[j], levels[i]);
                    (players[i], players[j]) = (players[j], players[i]);
                }
            }
        }

        // Throw eggs only at top 2 players
        console2.log("TOP 2 PLAYERS (TARGETS):");
        console2.log("-> 1. %s with %s chicken levels", players[0].name, levels[0]);
        console2.log("-> 2. %s with %s chicken levels", players[1].name, levels[1]);
        console2.log("OTHER PLAYERS:");
        for (uint256 i = 2; i < players.length; i++) {
            console2.log("%s. %s with %s chicken levels", i + 1, players[i].name, levels[i]);
        }

        uint256 eggsAvailable = EGG.balanceOf(msg.sender);
        uint256 superEggsToMint = 0;
        for (uint256 i = 1; i <= lastTokenId; i++) {
            address owner = CHICKEN.ownerOf(i);
            if (owner == players[0].addr || owner == players[1].addr) {
                (uint8 level,) = CHICKEN.chickens(i);
                if (level > 7 && eggsAvailable >= COST_PER_SUPEGG) {
                    // Throw at level 7 or above only if super eggs are available
                    console2.log("Throwing super egg at enemy level %s", level);
                    Attack memory attack = Attack({ tokenId: i, eggsToThrow: 1, isSuperEgg: true });
                    attacks.push(attack);
                    eggsAvailable -= COST_PER_SUPEGG;
                    superEggsToMint++;
                } else if (level > 1) {
                    // Throw eggs if above level 1 and eggs are available
                    Attack memory attack = Attack({ tokenId: i, eggsToThrow: level - 1, isSuperEgg: false });
                    if (eggsAvailable / 1e18 >= attack.eggsToThrow) {
                        console2.log("Throwing %s eggs at enemy level %s", attack.eggsToThrow, level);
                        attacks.push(attack);
                        eggsAvailable -= attack.eggsToThrow * 1e18;
                    }
                }
            }
        }

        if (attacks.length == 0) {
            console2.log("No chickens to throw eggs at");
            return;
        }

        // Mint super eggs to throw
        if (superEggsToMint > 0) {
            SUPER_EGG.mint(superEggsToMint);
        }

        // Throw eggs
        uint256[] memory tokenIds = new uint256[](attacks.length);
        uint8[] memory numEggs = new uint8[](attacks.length);
        bool[] memory areSuperEggs = new bool[](attacks.length);
        string[] memory comments = new string[](attacks.length);
        for (uint256 i = 0; i < attacks.length; i++) {
            Attack memory attack = attacks[i];
            tokenIds[i] = attack.tokenId;
            numEggs[i] = attack.eggsToThrow;
            areSuperEggs[i] = attack.isSuperEgg;
            comments[i] = "ATTACK_PHASE";
        }
        CHICKEN.requestThrowEgg{ value: VRF_FEE }(tokenIds, numEggs, areSuperEggs, comments);

        vm.stopBroadcast();
    }
}
