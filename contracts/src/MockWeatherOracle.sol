// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract MockWeatherOracle {
    struct WeatherData {
        uint256 temperature;     // in Celsius * 10 (e.g., 25.5°C = 255)
        uint256 windSpeed;       // in km/h
        uint256 rainfall;        // in mm * 10
        uint256 humidity;        // percentage
        uint256 pressure;        // in hPa
        uint256 timestamp;
    }

    struct LocationData {
        string name;
        int256 latitude;         // multiplied by 1e6
        int256 longitude;        // multiplied by 1e6
        uint256 elevation;       // in meters
    }

    mapping(bytes32 => WeatherData[]) public locationWeatherHistory;
    mapping(bytes32 => LocationData) public locations;

    event WeatherDataUpdated(
        string location,
        uint256 temperature,
        uint256 windSpeed,
        uint256 rainfall,
        uint256 timestamp
    );

    constructor() {
        // Initialize San Francisco data
        bytes32 sfHash = keccak256(bytes("San Francisco"));
        locations[sfHash] = LocationData({
            name: "San Francisco",
            latitude: 37774929,   // 37.774929
            longitude: -122419416, // -122.419416
            elevation: 16         // meters above sea level
        });

        // Initialize Miami data
        bytes32 miamiHash = keccak256(bytes("Miami"));
        locations[miamiHash] = LocationData({
            name: "Miami",
            latitude: 25761680,
            longitude: -80191790,
            elevation: 2
        });
    }

    function updateWeatherData(
        string memory location,
        uint256 temperature,
        uint256 windSpeed,
        uint256 rainfall,
        uint256 humidity,
        uint256 pressure
    ) external {
        bytes32 locationHash = keccak256(bytes(location));
        require(bytes(locations[locationHash].name).length > 0, "Location not registered");

        WeatherData memory newData = WeatherData({
            temperature: temperature,
            windSpeed: windSpeed,
            rainfall: rainfall,
            humidity: humidity,
            pressure: pressure,
            timestamp: block.timestamp
        });

        locationWeatherHistory[locationHash].push(newData);

        emit WeatherDataUpdated(
            location,
            temperature,
            windSpeed,
            rainfall,
            block.timestamp
        );
    }

    function getLatestWeatherData(string memory location) 
        external 
        view 
        returns (WeatherData memory) 
    {
        bytes32 locationHash = keccak256(bytes(location));
        WeatherData[] storage history = locationWeatherHistory[locationHash];
        require(history.length > 0, "No weather data available");
        return history[history.length - 1];
    }

    function getLocationData(string memory location)
        external
        view
        returns (LocationData memory)
    {
        bytes32 locationHash = keccak256(bytes(location));
        require(bytes(locations[locationHash].name).length > 0, "Location not registered");
        return locations[locationHash];
    }

    function getWeatherHistory(string memory location, uint256 count)
        external
        view
        returns (WeatherData[] memory)
    {
        bytes32 locationHash = keccak256(bytes(location));
        WeatherData[] storage history = locationWeatherHistory[locationHash];
        require(history.length > 0, "No weather data available");
        
        uint256 resultCount = count > history.length ? history.length : count;
        WeatherData[] memory result = new WeatherData[](resultCount);
        
        for (uint256 i = 0; i < resultCount; i++) {
            result[i] = history[history.length - resultCount + i];
        }
        
        return result;
    }
} 