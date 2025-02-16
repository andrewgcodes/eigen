// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract OpenWeatherOracle {
    struct WeatherData {
        uint256 timestamp;
        int256 temperature;    // in Celsius * 10 (e.g., 25.5°C = 255)
        uint256 humidity;      // percentage
        uint256 pressure;      // in hPa
        uint256 windSpeed;     // in meters/sec * 10
        uint256 windDeg;       // wind direction in degrees
        uint256 cloudiness;    // percentage
        uint256 rainfall;      // mm in last 3h * 10
        string weatherMain;    // main weather condition
        string weatherDesc;    // detailed weather description
    }

    struct Location {
        string name;
        int256 latitude;      // multiplied by 1e6
        int256 longitude;     // multiplied by 1e6
        string country;
    }

    address public owner;
    address public oracleOperator;
    
    mapping(bytes32 => WeatherData) public currentWeather;
    mapping(bytes32 => Location) public locations;
    mapping(bytes32 => WeatherData[]) public weatherHistory;
    uint256 public constant MAX_HISTORY = 24; // Keep 24 hours of history

    event WeatherUpdated(
        string indexed locationName,
        int256 temperature,
        uint256 humidity,
        uint256 windSpeed,
        string weatherMain
    );

    event LocationAdded(
        string name,
        int256 latitude,
        int256 longitude,
        string country
    );

    constructor() {
        owner = msg.sender;
        oracleOperator = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == oracleOperator, "Only operator can call this function");
        _;
    }

    function setOperator(address _operator) external onlyOwner {
        oracleOperator = _operator;
    }

    function addLocation(
        string calldata name,
        int256 latitude,
        int256 longitude,
        string calldata country
    ) external onlyOperator {
        bytes32 locationHash = keccak256(bytes(name));
        locations[locationHash] = Location({
            name: name,
            latitude: latitude,
            longitude: longitude,
            country: country
        });

        emit LocationAdded(name, latitude, longitude, country);
    }

    function updateWeather(
        string calldata locationName,
        int256 temperature,
        uint256 humidity,
        uint256 pressure,
        uint256 windSpeed,
        uint256 windDeg,
        uint256 cloudiness,
        uint256 rainfall,
        string calldata weatherMain,
        string calldata weatherDesc
    ) external onlyOperator {
        bytes32 locationHash = keccak256(bytes(locationName));
        require(bytes(locations[locationHash].name).length > 0, "Location not registered");

        WeatherData memory newData = WeatherData({
            timestamp: block.timestamp,
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            windSpeed: windSpeed,
            windDeg: windDeg,
            cloudiness: cloudiness,
            rainfall: rainfall,
            weatherMain: weatherMain,
            weatherDesc: weatherDesc
        });

        // Update current weather
        currentWeather[locationHash] = newData;

        // Add to history
        WeatherData[] storage history = weatherHistory[locationHash];
        if (history.length >= MAX_HISTORY) {
            // Remove oldest entry
            for (uint i = 0; i < history.length - 1; i++) {
                history[i] = history[i + 1];
            }
            history.pop();
        }
        history.push(newData);

        emit WeatherUpdated(
            locationName,
            temperature,
            humidity,
            windSpeed,
            weatherMain
        );
    }

    function getCurrentWeather(string calldata locationName)
        external
        view
        returns (WeatherData memory)
    {
        bytes32 locationHash = keccak256(bytes(locationName));
        require(currentWeather[locationHash].timestamp > 0, "No weather data available");
        return currentWeather[locationHash];
    }

    function getLocation(string calldata locationName)
        external
        view
        returns (Location memory)
    {
        bytes32 locationHash = keccak256(bytes(locationName));
        require(bytes(locations[locationHash].name).length > 0, "Location not found");
        return locations[locationHash];
    }

    function getWeatherHistory(string calldata locationName)
        external
        view
        returns (WeatherData[] memory)
    {
        bytes32 locationHash = keccak256(bytes(locationName));
        return weatherHistory[locationHash];
    }

    function getLatestWeatherDescription(string calldata locationName)
        external
        view
        returns (
            int256 temperature,
            uint256 humidity,
            uint256 windSpeed,
            string memory description
        )
    {
        bytes32 locationHash = keccak256(bytes(locationName));
        WeatherData memory data = currentWeather[locationHash];
        require(data.timestamp > 0, "No weather data available");
        
        return (
            data.temperature,
            data.humidity,
            data.windSpeed,
            data.weatherDesc
        );
    }
} 