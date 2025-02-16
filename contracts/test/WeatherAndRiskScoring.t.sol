// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/Test.sol";
import {MockWeatherOracle} from "../src/MockWeatherOracle.sol";
import {DisasterRiskScoring} from "../src/DisasterRiskScoring.sol";
import {IDisasterInsuranceServiceManager} from "../src/IDisasterInsuranceServiceManager.sol";

contract WeatherAndRiskScoringTest is Test {
    MockWeatherOracle public weatherOracle;
    DisasterRiskScoring public riskScoring;

    function setUp() public {
        weatherOracle = new MockWeatherOracle();
        riskScoring = new DisasterRiskScoring(address(weatherOracle));
    }

    function test_WeatherDataUpdate() public {
        // Update San Francisco weather data
        weatherOracle.updateWeatherData(
            "San Francisco",
            185,    // 18.5°C
            25,     // 25 km/h wind
            20,     // 2.0mm rainfall
            75,     // 75% humidity
            1013    // 1013 hPa pressure
        );

        MockWeatherOracle.WeatherData memory data = weatherOracle.getLatestWeatherData("San Francisco");
        assertEq(data.temperature, 185);
        assertEq(data.windSpeed, 25);
        assertEq(data.rainfall, 20);
        assertEq(data.humidity, 75);
        assertEq(data.pressure, 1013);
    }

    function test_LocationData() public {
        MockWeatherOracle.LocationData memory sfData = weatherOracle.getLocationData("San Francisco");
        assertEq(sfData.name, "San Francisco");
        assertEq(sfData.latitude, 37774929);
        assertEq(sfData.longitude, -122419416);
        assertEq(sfData.elevation, 16);
    }

    function test_RiskScoring() public {
        // First update weather data
        weatherOracle.updateWeatherData(
            "San Francisco",
            185,    // 18.5°C
            25,     // 25 km/h wind
            20,     // 2.0mm rainfall
            75,     // 75% humidity
            1013    // 1013 hPa pressure
        );

        // Calculate risk score for earthquake
        uint256 score = riskScoring.calculateRiskScore(
            "San Francisco",
            IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE
        );

        // Should be high due to location
        assertTrue(score >= 70);

        // Add a historical event
        riskScoring.recordHistoricalEvent(
            "San Francisco",
            IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE,
            65, // 6.5 magnitude
            1000 ether
        );

        // Recalculate risk - should be higher due to history
        uint256 newScore = riskScoring.calculateRiskScore(
            "San Francisco",
            IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE
        );

        assertTrue(newScore > score);
    }

    function test_SeasonalRiskFactors() public {
        // Update Miami weather during hurricane season
        vm.warp(1656633600); // July 1, 2022
        weatherOracle.updateWeatherData(
            "Miami",
            320,    // 32.0°C
            120,    // 120 km/h wind (high)
            150,    // 15.0mm rainfall
            85,     // 85% humidity
            980     // 980 hPa (low pressure)
        );

        uint256 hurricaneSeasonScore = riskScoring.calculateRiskScore(
            "Miami",
            IDisasterInsuranceServiceManager.DisasterType.HURRICANE
        );

        // Change to winter
        vm.warp(1672531200); // January 1, 2023
        weatherOracle.updateWeatherData(
            "Miami",
            220,    // 22.0°C
            30,     // 30 km/h wind
            20,     // 2.0mm rainfall
            70,     // 70% humidity
            1015    // 1015 hPa
        );

        uint256 winterScore = riskScoring.calculateRiskScore(
            "Miami",
            IDisasterInsuranceServiceManager.DisasterType.HURRICANE
        );

        assertTrue(hurricaneSeasonScore > winterScore);
        console2.log("Hurricane Season Risk Score:", hurricaneSeasonScore);
        console2.log("Winter Risk Score:", winterScore);
    }

    function test_WeatherHistory() public {
        // Add multiple weather data points
        for (uint256 i = 0; i < 5; i++) {
            weatherOracle.updateWeatherData(
                "San Francisco",
                185 + i * 10,    // Increasing temperature
                25 + i * 5,      // Increasing wind
                20,
                75,
                1013
            );
            vm.warp(block.timestamp + 1 hours);
        }

        // Get last 3 weather records
        MockWeatherOracle.WeatherData[] memory history = weatherOracle.getWeatherHistory("San Francisco", 3);
        assertEq(history.length, 3);
        
        // Verify they're in chronological order
        assertTrue(history[0].timestamp < history[1].timestamp);
        assertTrue(history[1].timestamp < history[2].timestamp);
    }

    function test_RiskFactorCombination() public {
        // Set up high-risk conditions in Miami
        vm.warp(1662921600); // September 2022 (hurricane season)
        weatherOracle.updateWeatherData(
            "Miami",
            320,    // 32.0°C
            150,    // 150 km/h wind (very high)
            200,    // 20.0mm rainfall
            90,     // 90% humidity
            960     // 960 hPa (very low pressure)
        );

        // Add historical events
        riskScoring.recordHistoricalEvent(
            "Miami",
            IDisasterInsuranceServiceManager.DisasterType.HURRICANE,
            85,
            2000 ether
        );

        riskScoring.recordHistoricalEvent(
            "Miami",
            IDisasterInsuranceServiceManager.DisasterType.HURRICANE,
            90,
            3000 ether
        );

        // Calculate risk score with all factors high
        uint256 highRiskScore = riskScoring.calculateRiskScore(
            "Miami",
            IDisasterInsuranceServiceManager.DisasterType.HURRICANE
        );

        DisasterRiskScoring.RiskScore memory riskData = riskScoring.getLocationRiskScore("Miami");
        
        console2.log("High Risk Scenario:");
        console2.log("Base Score:", riskData.baseScore);
        console2.log("Weather Multiplier:", riskData.weatherMultiplier);
        console2.log("Seasonal Multiplier:", riskData.seasonalMultiplier);
        console2.log("Historical Multiplier:", riskData.historicalMultiplier);
        console2.log("Final Score:", highRiskScore);

        assertTrue(highRiskScore > 90);
    }
} 