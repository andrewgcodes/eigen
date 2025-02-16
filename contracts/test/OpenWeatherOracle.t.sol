// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/Test.sol";
import {OpenWeatherOracle} from "../src/OpenWeatherOracle.sol";

contract OpenWeatherOracleTest is Test {
    OpenWeatherOracle public oracle;
    address public owner;
    address public operator;

    function setUp() public {
        owner = makeAddr("owner");
        operator = makeAddr("operator");
        
        vm.startPrank(owner);
        oracle = new OpenWeatherOracle();
        oracle.setOperator(operator);
        vm.stopPrank();
    }

    function test_AddLocation() public {
        vm.startPrank(operator);
        
        string memory cityName = "San Francisco";
        int256 latitude = 37774929;  // 37.774929
        int256 longitude = -122419416; // -122.419416
        string memory country = "US";

        oracle.addLocation(cityName, latitude, longitude, country);

        OpenWeatherOracle.Location memory location = oracle.getLocation(cityName);
        assertEq(location.name, cityName);
        assertEq(location.latitude, latitude);
        assertEq(location.longitude, longitude);
        assertEq(location.country, country);

        vm.stopPrank();
    }

    function test_UpdateWeather() public {
        vm.startPrank(operator);
        
        // First add a location
        string memory cityName = "San Francisco";
        oracle.addLocation(
            cityName,
            37774929,
            -122419416,
            "US"
        );

        // Update weather data
        oracle.updateWeather(
            cityName,
            185,        // 18.5°C
            75,         // 75% humidity
            1013,       // 1013 hPa pressure
            25,         // 2.5 m/s wind speed
            180,        // 180° wind direction
            30,         // 30% cloudiness
            0,          // 0mm rainfall
            "Clear",    // weather main
            "clear sky" // weather description
        );

        // Get current weather
        OpenWeatherOracle.WeatherData memory weather = oracle.getCurrentWeather(cityName);
        assertEq(weather.temperature, 185);
        assertEq(weather.humidity, 75);
        assertEq(weather.pressure, 1013);
        assertEq(weather.windSpeed, 25);
        assertEq(weather.windDeg, 180);
        assertEq(weather.cloudiness, 30);
        assertEq(weather.rainfall, 0);
        assertEq(weather.weatherMain, "Clear");
        assertEq(weather.weatherDesc, "clear sky");

        vm.stopPrank();
    }

    function test_WeatherHistory() public {
        vm.startPrank(operator);
        
        // Add location
        string memory cityName = "San Francisco";
        oracle.addLocation(
            cityName,
            37774929,
            -122419416,
            "US"
        );

        // Update weather multiple times
        for (uint i = 0; i < 3; i++) {
            // Simulate time passing
            vm.warp(block.timestamp + 1 hours);
            
            oracle.updateWeather(
                cityName,
                int256(180 + i * 10),  // Increasing temperature
                75,
                1013,
                25,
                180,
                30,
                0,
                "Clear",
                "clear sky"
            );
        }

        // Check history
        OpenWeatherOracle.WeatherData[] memory history = oracle.getWeatherHistory(cityName);
        assertEq(history.length, 3);
        
        // Verify temperatures are increasing
        assertTrue(history[1].temperature > history[0].temperature);
        assertTrue(history[2].temperature > history[1].temperature);

        vm.stopPrank();
    }

    function test_MaxHistoryLimit() public {
        vm.startPrank(operator);
        
        // Add location
        string memory cityName = "San Francisco";
        oracle.addLocation(
            cityName,
            37774929,
            -122419416,
            "US"
        );

        // Update weather more times than MAX_HISTORY
        for (uint i = 0; i < 30; i++) {
            vm.warp(block.timestamp + 1 hours);
            
            oracle.updateWeather(
                cityName,
                int256(180 + i * 10),
                75,
                1013,
                25,
                180,
                30,
                0,
                "Clear",
                "clear sky"
            );
        }

        // Check history length is capped at MAX_HISTORY
        OpenWeatherOracle.WeatherData[] memory history = oracle.getWeatherHistory(cityName);
        assertEq(history.length, 24); // MAX_HISTORY is 24

        vm.stopPrank();
    }

    function test_GetLatestWeatherDescription() public {
        vm.startPrank(operator);
        
        string memory cityName = "San Francisco";
        oracle.addLocation(
            cityName,
            37774929,
            -122419416,
            "US"
        );

        oracle.updateWeather(
            cityName,
            185,
            75,
            1013,
            25,
            180,
            30,
            0,
            "Clear",
            "clear sky"
        );

        (
            int256 temperature,
            uint256 humidity,
            uint256 windSpeed,
            string memory description
        ) = oracle.getLatestWeatherDescription(cityName);

        assertEq(temperature, 185);
        assertEq(humidity, 75);
        assertEq(windSpeed, 25);
        assertEq(description, "clear sky");

        vm.stopPrank();
    }

    function testFail_UnauthorizedOperator() public {
        address unauthorized = makeAddr("unauthorized");
        vm.startPrank(unauthorized);
        
        // Should fail when unauthorized address tries to add location
        oracle.addLocation(
            "San Francisco",
            37774929,
            -122419416,
            "US"
        );

        vm.stopPrank();
    }

    function testFail_UpdateNonexistentLocation() public {
        vm.startPrank(operator);
        
        // Should fail when updating weather for non-existent location
        oracle.updateWeather(
            "Nonexistent City",
            185,
            75,
            1013,
            25,
            180,
            30,
            0,
            "Clear",
            "clear sky"
        );

        vm.stopPrank();
    }
} 